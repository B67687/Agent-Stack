#!/usr/bin/env bash
# bwrap-wrap.sh — Launch opencode under bubblewrap (bwrap) sandbox.
#
# STATUS: Layer-1+2 sandbox (2026-08-05 L1, v3 2026-08-15 adds L2 egress).
# History: pivoted from the abandoned landlock-restrict wrapper (that tool
# never existed on crates.io and landrun, the apt substitute, is stalled since
# Oct 2025). bubblewrap is the freedesktop/containers-maintained sandbox used
# by Flatpak — mainstream, actively maintained, already installed on this box.
#
# READ-ONLY USE: this file is inert until executed. It is NOT the launch path
# for the current agent session (agent-session@agent.service still launches
# bare tmux). To activate: stop the service, start opencode via this wrapper,
# restart the service.
#
# Model (deny-by-default, per the sandbox plan):
#   - --ro-bind / /      : whole filesystem read-only (writes denied by default)
#   - --unshare-all      : new pid/ipc/uts/net/user namespaces + --new-session.
#                          NOTE: --unshare-all already implies --unshare-net —
#                          the sandbox netns is EMPTY (only lo UP, no NICs, no
#                          routes, no DNS). Network is denied by STRUCTURE.
#   - credential shadow  : ~/.ssh, ~/.aws, ~/.config/gh, ~/.gnupg are replaced
#                          by empty tmpfs — the agent cannot read them.
#                          NOTE: auth.json (API keys) is NOT shadowed — the
#                          opencode process itself must read it to call APIs;
#                          it is protected at the tool layer (opencode.jsonc
#                          permission deny-list) instead.
#   - rw-bind workspaces : only ~/projects, skills/, tmp/opencode, storage,
#                          ~/.omo/plans are writable (override the ro-bind).
#   - egress (EGRESS=1)  : the ONLY network path is the L2 allowlist proxy.
#                          The host proxy socket (~/.cache/opencode/egress/
#                          egress.sock) is bind-mounted in and scripts/
#                          egress-relay.sh is exec'd inside the netns: it runs
#                          a loopback socat HTTP relay (127.0.0.1:3128) wired
#                          into that socket and exports HTTP(S)_PROXY env.
#                          Squid on the host allowlists ONLY known endpoints
#                          (egress/egress-allowlist.conf) — everything else is
#                          403 DENIED. FAIL-CLOSED: no socket -> no network.
#
# Requires: bwrap (bubblewrap) on PATH.  Install: sudo apt install bubblewrap
set -euo pipefail

AGENT_CMD="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
EGRESS="${EGRESS:-0}"
EGRESS_DIR="$HOME/.cache/opencode/egress"
EGRESS_SOCK="${EGRESS_SOCK:-$EGRESS_DIR/egress.sock}"
RELAY_SCRIPT="$HOME/.config/opencode/scripts/egress-relay.sh"

# Paths the agent must NEVER read (credentials, keys) — shadowed with empty tmpfs
CREDENTIAL_SHADOW=(
  "$HOME/.ssh"
  "$HOME/.aws"
  "$HOME/.config/gh"
  "$HOME/.gnupg"
)

# Paths where writing IS allowed (workspace + agent's own data). These are
# rw-bound AFTER the ro-bind / so they override it.
WRITE_DIRS=(
  "$HOME/projects"
  "$HOME/.config/opencode/skills"
  "$HOME/.cache/tmp/opencode"
  "$HOME/.local/share/opencode/storage"
  "$HOME/.omo/plans"
)

# Paths the agent may read but must NOT write — kept read-only via ro-bind /
# (they already are, by virtue of the ro-bind / — listed here for clarity).
#   - ~/.config/opencode/opencode.jsonc
#   - ~/.omo/omo.jsonc
#   - ~/.local/share/opencode/opencode.db
# To make a path read-only explicitly on top of a rw parent, add:
#   --ro-bind <path> <path>
# (see WRITE_DIRS handling below for the override pattern).

if ! command -v bwrap >/dev/null 2>&1; then
  echo "ERROR: bwrap not found. Install with: sudo apt install bubblewrap" >&2
  exit 1
fi

ARGS=(--unshare-all --new-session --die-with-parent --ro-bind / / --dev /dev)

# Shadow credential paths with empty dirs so the agent cannot read them.
for p in "${CREDENTIAL_SHADOW[@]}"; do
  [ -d "$p" ] && ARGS+=(--tmpfs "$p")
done

# Re-allow writes to workspace dirs (override the ro-bind /).
for d in "${WRITE_DIRS[@]}"; do
  mkdir -p "$d"
  ARGS+=(--bind "$d" "$d")
done

# Default deny-write on the two config roots the agent must never mutate,
# while keeping their write-allowed children working:
ARGS+=(--ro-bind "$HOME/.config/opencode" "$HOME/.config/opencode")
ARGS+=(--ro-bind "$HOME/.omo" "$HOME/.omo")
for d in "${WRITE_DIRS[@]}"; do
  case "$d" in
    "$HOME/.config/opencode/skills") ARGS+=(--bind "$d" "$d") ;;
    "$HOME/.omo/plans")              ARGS+=(--bind "$d" "$d") ;;
  esac
done

# L2 egress: bind the host proxy socket in and exec the in-sandbox relay.
if [ "$EGRESS" = "1" ]; then
  if [ ! -S "$EGRESS_SOCK" ]; then
    echo "ERROR: egress socket $EGRESS_SOCK not found." >&2
    echo "       Start it with: systemctl --user start egress-proxy@agent" >&2
    exit 1
  fi
  if [ ! -x "$RELAY_SCRIPT" ]; then
    echo "ERROR: relay script not executable: $RELAY_SCRIPT" >&2
    exit 1
  fi
  ARGS+=(--bind "$EGRESS_SOCK" "$EGRESS_SOCK")
  # The relay must be readable+executable inside the sandbox (ro-bind / covers
  # ~/.config/opencode, which is ro-bound above — relay runs from there).
  exec bwrap "${ARGS[@]}" -- "$RELAY_SCRIPT" "$AGENT_CMD" "$@"
fi

echo "Launching: bwrap ${ARGS[*]} -- $AGENT_CMD \"$@\"" >&2
exec bwrap "${ARGS[@]}" -- "$AGENT_CMD" "$@"
