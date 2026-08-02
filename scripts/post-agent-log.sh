#!/usr/bin/env bash
# post-agent-log.sh — Append a structured agent session summary to an audit log
set -euo pipefail

# ── Usage ──
usage() {
  cat <<EOF
Usage: $(basename "$0") <agent-name> <action> [status] [duration-secs]

Append a structured agent session summary to the audit log.

Arguments:
  agent-name    Agent identifier (e.g., sisyphus, librarian, explorer)
  action        Action performed (e.g., explore, delegate, review, generate)
  status        Status: started | completed | failed | skipped (default: auto)
  duration-secs Duration in seconds (optional)

If status is omitted, auto-detects between "started" (first call) and
"completed" (second call) for the same agent+action pair, assuming a
start → completion lifecycle.

Format:
  ISO-8601 TIMESTAMP | AGENT | ACTION | STATUS | DURATION | WORKDIR

Log file: \${XDG_DATA_HOME:-~/.local/share}/opencode/logs/agent-audit.log
Directory is created automatically if it does not exist.
EOF
}

# ── Parse arguments ──
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
esac

if [ $# -lt 2 ]; then
  echo "❌ Error: agent-name and action are required" >&2
  echo "" >&2
  usage
  exit 1
fi

agent="$1"
action="$2"
status="${3:-}"
duration="${4:-}"

# ── Log file path ──
LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/logs"
LOG_FILE="$LOG_DIR/agent-audit.log"

mkdir -p "$LOG_DIR"

# ── Default status detection ──
if [ -z "$status" ]; then
  if [ -f "$LOG_FILE" ]; then
    last_line=$(grep "| ${agent} | ${action} |" "$LOG_FILE" 2>/dev/null | tail -1)
    if echo "$last_line" | grep -q "| started |"; then
      status="completed"
    else
      status="started"
    fi
  else
    status="started"
  fi
fi

# ── Write entry ──
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
workdir="${PWD}"
duration_display="${duration:--}"
echo "${timestamp} | ${agent} | ${action} | ${status} | ${duration_display} | ${workdir}" >> "$LOG_FILE"
echo "✅ Logged: ${agent} / ${action} / ${status}" >&2
