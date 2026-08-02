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
  3. Config files (opencode.jsonc, ~/.omo/omo.jsonc) exist and are readable
  4. Disk space on home directory (informational only)
  5. Git working tree state for config files
  5.5. OMO config load validation (omo doctor)
  5.6. Config schema validation (config-schema-check)
  5.7. SQLite WAL size (unbounded-writer guardrail)
  5.8. Local CI gate wiring (pre-push hook + guardrail wrapper)

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
  if [ -f "$HOME/.omo/omo.jsonc" ]; then
    healthy "omo.jsonc present at ~/.omo (OMO unified config)"
  else
    degraded "omo.jsonc not found at ${HOME}/.omo"
  fi
else
  unhealthy "OMO config directory not found: ${OMO_DIR}"
fi

# ── Check 3: Config files readable ──
echo ""
echo "--- Config File Readability ---"

for f in opencode.jsonc omo.jsonc; do
  if [ "$f" = "omo.jsonc" ]; then
    filepath="$HOME/.omo/omo.jsonc"
  else
    filepath="$CONFIG_CHECK_DIR/$f"
  fi
  if [ -f "$filepath" ]; then
    if [ -r "$filepath" ]; then
      healthy "$f is readable (${filepath})"
    else
      unhealthy "$f exists but is not readable (${filepath})"
    fi
  else
    unhealthy "$f not found at ${filepath}"
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

# ── Check 5.6: Config schema validation (installed schema ground truth) ──
echo ""
echo "--- Config Schema Validation (config-schema-check) ---"
if command -v node &>/dev/null; then
  schema_result=$(node scripts/config-schema-check.mjs 2>&1)
  schema_exit=$?
  if [ "$schema_exit" -eq 0 ]; then
    healthy "config-schema-check — all omo.jsonc keys valid against installed schema"
  else
    unhealthy "config-schema-check — schema violations found"
    echo "       $schema_result" | sed 's/^/       /'
  fi
else
  degraded "node not found — skipping config schema validation"
fi

# ── Check 5.7: SQLite WAL size (unbounded-writer guardrail) ──
echo ""
echo "--- SQLite WAL Size ---"
WAL_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db-wal"
if [ -f "$WAL_FILE" ]; then
  wal_bytes=$(stat -c%s "$WAL_FILE" 2>/dev/null || echo 0)
  wal_mb=$((wal_bytes / 1024 / 1024))
  if [ "$wal_mb" -gt 200 ]; then
    unhealthy "SQLite WAL is ${wal_mb}MB (>200MB) — possible unbounded writer (silent retry loop); kill runaway process and wal_checkpoint(TRUNCATE)"
  elif [ "$wal_mb" -gt 100 ]; then
    degraded "SQLite WAL is ${wal_mb}MB (>100MB) — growing; check for silent retry loops"
  else
    healthy "SQLite WAL is ${wal_mb}MB — healthy"
  fi
else
  degraded "opencode WAL file not found at ${WAL_FILE} — skipping WAL check"
fi

# ── Check 5.8: Local CI gate wiring (pre-push hook) ──
echo ""
echo "--- Local CI Gate (pre-push hook) ---"
HOOKS_PATH="$(git config --get core.hooksPath 2>/dev/null || true)"
TRACKED_HOOK="scripts/hooks/pre-push"
if [ "$HOOKS_PATH" = "scripts/hooks" ]; then
  healthy "core.hooksPath → scripts/hooks (tracked)"
else
  unhealthy "core.hooksPath is '${HOOKS_PATH:-unset}' — expected 'scripts/hooks'; local CI gate will NOT run on push"
  echo "       fix: GIT_MASTER=1 git config core.hooksPath scripts/hooks"
fi
if [ -x "$TRACKED_HOOK" ]; then
  healthy "pre-push hook present + executable (${TRACKED_HOOK})"
else
  unhealthy "pre-push hook missing/not-executable at ${TRACKED_HOOK}"
fi
if command -v git-safe-push >/dev/null 2>&1 || [ -x "$HOME/.local/bin/git" ]; then
  healthy "guardrail git wrapper present (~/.local/bin/git blocks --no-verify/--force)"
else
  degraded "guardrail git wrapper missing — --no-verify/--force not blocked"
fi

# ── Check 6: Git repo state for config files ──
echo ""
echo "--- Git Repo State ---"
if git rev-parse --git-dir &>/dev/null 2>&1; then
  dirty_configs=$(git status --short -- opencode.jsonc 2>/dev/null || true)
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
