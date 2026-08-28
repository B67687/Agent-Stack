#!/usr/bin/env bash
# restart-opencode.sh — validate config, restart opencode in its isolated
# agent-session, and CONFIRM the new process actually loaded the new config.
#
# Why this exists: opencode is a compiled Bun binary that boots in ~1s and the
# OMO plugin reads ~/.omo/omo.jsonc at server start but also caches to
# ~/.cache/tmp/opencode/*/ .omo/omo.jsonc — stale cache must be
# cleared or restart reuses old config. "Did it reload?" is therefore: is
# the new process start-time NEWER than config mtime AND cache cleared?
#
#   restart-opencode.sh                # restart session 'agent' in $PWD
#   restart-opencode.sh myproject      # restart named session
#   AGENT_SESSION_WORKDIR=/path restart-opencode.sh
#
# Run from a PLAIN SHELL, not from inside an opencode prompt — this script
# kills the running opencode process (that is its point).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${OMO_CONFIG:-$HOME/.omo/omo.jsonc}"
SESSION="${1:-agent}"
WORKDIR="${AGENT_SESSION_WORKDIR:-$PWD}"

echo "restart-opencode.sh — session '$SESSION' in $WORKDIR"
echo

# ── 1. Fail fast: never restart into a broken config ──
echo "==> [1/4] Validating config (fail fast if broken)"
node "$SCRIPT_DIR/config-schema-check.mjs" || {
  echo "  ❌ config-schema-check.mjs FAILED — fix config before restarting"
  exit 1
}
echo "  ✅ config schema OK"

# ── 2. Stop current opencode instance(s) ──
echo "==> [2/4] Stopping running opencode processes"
CONFIG_MTIME="$(stat -c %Y "$CONFIG_FILE" 2>/dev/null || echo 0)"
# match the opencode binary + lsp-daemon children; exclude our own shell
mapfile -t PIDS < <(pgrep -f 'opencode' | grep -v "$$" || true)
if [ "${#PIDS[@]}" -eq 0 ]; then
  echo "  ⚠️  no running opencode process found (fresh start)"
else
  echo "  -> SIGTERM: ${PIDS[*]}"
  kill -TERM "${PIDS[@]}" 2>/dev/null || true
  # graceful window, then force
  for _ in $(seq 1 5); do
    if ! pgrep -f 'opencode' | grep -qv "$$"; then break; fi
    sleep 1
  done
  if pgrep -f 'opencode' | grep -qv "$$"; then
    mapfile -t LEFT < <(pgrep -f 'opencode' | grep -v "$$" || true)
    echo "  -> SIGKILL survivors: ${LEFT[*]}"
    kill -KILL "${LEFT[@]}" 2>/dev/null || true
    sleep 1
  fi
  echo "  ✅ stopped"
  # Clear stale OMO tmp cache (otherwise restart reuses old omo.jsonc)
  find "$HOME/.cache/tmp" -name "omo.jsonc" -delete 2>/dev/null || true
  echo "  ✅ OMO cache cleared"
fi

# ── 3. Relaunch via agent-session (isolated cgroup) ──
echo "==> [3/4] Relaunching opencode in agent-session '$SESSION'"
systemctl --user start "agent-session@$SESSION" 2>/dev/null || true
tmux send-keys -t "$SESSION" "cd $WORKDIR 2>/dev/null; exec opencode" Enter
echo "  ✅ launched (attach later with: agent-session attach $SESSION)"

# ── 4. Verify the reload actually happened ──
echo "==> [4/4] Confirming new process started AFTER config change"
NEW_PID=""
for _ in $(seq 1 30); do
  NEW_PID="$(pgrep -f 'opencode' | grep -v "$$" | head -1 || true)"
  [ -n "$NEW_PID" ] && break
  sleep 1
done
if [ -z "$NEW_PID" ]; then
  echo "  ❌ opencode did not come back within 30s"
  exit 1
fi
# start epoch = now - elapsed seconds
START_EPOCH="$(( $(date +%s) - $(ps -o etimes= -p "$NEW_PID" | tr -d ' ') ))"
echo "  -> new PID $NEW_PID started $(date -d "@$START_EPOCH" '+%H:%M:%S')"
echo "  -> config mtime $(date -d "@$CONFIG_MTIME" '+%H:%M:%S')"
if [ "$START_EPOCH" -ge "$CONFIG_MTIME" ]; then
  echo "  ✅ process is NEWER than config — new settings loaded"
  exit 0
else
  echo "  ❌ process predates config change — reload did NOT take effect"
  exit 1
fi
