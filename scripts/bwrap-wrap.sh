#!/usr/bin/env bash
# bwrap-wrap.sh — Launch opencode under bubblewrap (bwrap) sandbox.
#
# STATUS: Layer-1 sandbox (2026-08-05, v2 — pivoted from the abandoned
# landlock-restrict wrapper: that tool never existed on crates.io and landrun
# (the apt substitute) is stalled since Oct 2025. bubblewrap is the
# freedesktop/containers-maintained sandbox used by Flatpak — mainstream,
# actively maintained, already installed on this box).
#
# READ-ONLY USE: this file is inert until executed. It is NOT the launch path
# for the current agent session (agent-session@agent.service still launches
# bare tmux). To activate: stop the service, start opencode via this wrapper,
# restart the service.
#
# Model (deny-by-default, per the sandbox plan):
#   - --ro-bind / /      : whole filesystem read-only (writes denied by default)
#   - credential shadow  : ~/.ssh, ~/.aws, ~/.config/gh, ~/.gnupg are replaced
#                          by empty tmpfs — the agent cannot read them.
#                          NOTE: auth.json (API keys) is NOT shadowed — the
#                          opencode process itself must read it to call APIs;
#                          it is protected at the tool layer (opencode.jsonc
#                          permission deny-list) instead.
#   - rw-bind workspaces : only ~/projects, skills/, tmp/opencode, storage,
#                          ~/.omo/plans are writable (override the ro-bind).
#   - --unshare-all      : new pid/ipc/uts/net/user namespaces + --new-session.
#                          (Network egress stays OPEN — Layer-1 is filesystem
#                          containment only; Layer-2 adds the egress proxy.)
#
# Requires: bwrap (bubblewrap) on PATH.  Install: sudo apt install bubblewrap
set -euo pipefail

AGENT_CMD="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"

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

ARGS=(--unshare-all --new-session --die-with-parent --ro-bind / /)

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


echo "Launching: bwrap ${ARGS[*]} -- $AGENT_CMD \"$@\"" >&2
exec bwrap "${ARGS[@]}" -- "$AGENT_CMD" "$@"
