#!/usr/bin/env bash
# health-check.sh — Check OpenCode/OMO agent environment health
set -euo pipefail

HEALTHY=0
DEGRADED=0
UNHEALTHY=0

healthy() { echo "  ✅ $1"; HEALTHY=$((HEALTHY + 1)); }
degraded() { echo "  ⚠️  $1"; DEGRADED=$((DEGRADED + 1)); }
unhealthy() { echo "  ❌ $1"; UNHEALTHY=$((UNHEALTHY + 1)); }

# ── Usage ──
usage() {
  cat <<EOF
Usage: $(basename "$0")

Check OpenCode / OMO agent environment health.

Checks performed:
  1. OpenCode binary available in PATH
  2. OMO plugin config directory exists
  3. Config files (opencode.jsonc, oh-my-openagent.jsonc) exist and are readable
  4. Disk space on home directory (informational only)
  5. Git working tree state for config files

Exit codes:
  0 = HEALTHY  — all critical checks pass
  1 = DEGRADED — non-critical issues found (e.g., dirty config, low disk)
  2 = UNHEALTHY — critical components missing or broken
EOF
  exit 0
}

case "${1:-}" in
  --help | -h) usage ;;
esac

# Accept config directory as optional first argument
if [ -n "${1:-}" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
  CONFIG_CHECK_DIR="$1"
else
  CONFIG_CHECK_DIR="."
  if [ -d "./Agent-Stack" ]; then
    CONFIG_CHECK_DIR="./Agent-Stack"
  fi
fi

echo "=== OpenCode / OMO Health Check ==="
echo ""

# ── Check 1: OpenCode binary ──
echo "--- OpenCode Binary ---"
if command -v opencode &>/dev/null; then
  opencode_path=$(command -v opencode)
  version=$(opencode --version 2>/dev/null || echo "version info unavailable")
  healthy "OpenCode CLI found: ${opencode_path} (${version})"
else
  unhealthy "OpenCode CLI not found in PATH"
fi

# ── Check 2: OMO plugin directory ──
echo ""
echo "--- OMO Plugin Directory ---"
OMO_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
if [ -d "$OMO_DIR" ]; then
  healthy "OMO config directory exists: ${OMO_DIR}"
  # Check for OMO plugin config presence
  if [ -f "$OMO_DIR/oh-my-openagent.jsonc" ]; then
    healthy "oh-my-openagent.jsonc present in OMO directory"
  else
    degraded "oh-my-openagent.jsonc not found in ${OMO_DIR}"
  fi
else
  unhealthy "OMO config directory not found: ${OMO_DIR}"
fi

# ── Check 3: Config files readable ──
echo ""
echo "--- Config File Readability ---"

for f in opencode.jsonc oh-my-openagent.jsonc; do
  filepath="$CONFIG_CHECK_DIR/$f"
  if [ -f "$filepath" ]; then
    if [ -r "$filepath" ]; then
      healthy "$f is readable (${filepath})"
    else
      unhealthy "$f exists but is not readable (${filepath})"
    fi
  else
    unhealthy "$f not found in ${CONFIG_CHECK_DIR}"
  fi
done

# ── Check 4: Disk space (informational only) ──
echo ""
echo "--- Disk Space ---"
df_output=$(df -h ~ | tail -1)
avail=$(echo "$df_output" | awk '{print $4}')
use_pct=$(echo "$df_output" | awk '{print $5}' | sed 's/%//')
echo "  Home directory: ${avail} available (${use_pct}% used)"
if [ "$use_pct" -gt 90 ]; then
  echo "  ⓘ  Disk usage above 90% — consider freeing space"
fi

# ── Check 5.5: OMO config load validation (omo doctor) ──
echo ""
echo "--- OMO Config Load Validation ---"
if command -v omo &>/dev/null; then
  DOCTOR_OUTPUT=$(omo doctor --verbose 2>&1) || true
  DOCTOR_EXIT=$?
  if echo "$DOCTOR_OUTPUT" | grep -qE '(Error|error|critical|CRITICAL|invalid|not found)'; then
    degraded "omo doctor reports potential issues"
    echo "       $(echo "$DOCTOR_OUTPUT" | grep -E '(Error|error|critical|CRITICAL|invalid|not found)' | head -3 | tr '\n' ';')"
  else
    healthy "omo doctor — config loads correctly"
  fi
else
  degraded "omo CLI not found in PATH — skipping OMO config validation"
fi

# ── Check 6: Git repo state for config files ──
echo ""
echo "--- Git Repo State ---"
if git rev-parse --git-dir &>/dev/null 2>&1; then
  dirty_configs=$(git status --short -- opencode.jsonc oh-my-openagent.jsonc 2>/dev/null || true)
  if [ -n "$dirty_configs" ]; then
    degraded "Config files have uncommitted changes:"
    echo "$dirty_configs" | sed 's/^/       /'
  else
    healthy "Config files are clean (no uncommitted changes)"
  fi
else
  degraded "Not inside a git repository — skipping git state check"
fi

# ── Verdict ──
echo ""
echo "=== Verdict ==="
if [ "$UNHEALTHY" -gt 0 ]; then
  echo "UNHEALTHY — ${HEALTHY} healthy, ${DEGRADED} degraded, ${UNHEALTHY} unhealthy"
  exit 2
elif [ "$DEGRADED" -gt 0 ]; then
  echo "DEGRADED — ${HEALTHY} healthy, ${DEGRADED} degraded, ${UNHEALTHY} unhealthy"
  exit 1
else
  echo "HEALTHY — ${HEALTHY} healthy, ${DEGRADED} degraded, ${UNHEALTHY} unhealthy"
  exit 0
fi
