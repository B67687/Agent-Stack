#!/usr/bin/env bash
# pre-commit-verify.sh — Verify config file sanity before committing
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠️  WARN: $1"; }

# ── Usage ──
usage() {
  cat <<EOF
Usage: $(basename "$0") [path-to-config-dir]

Verify config file sanity before committing to the agent-stack repo.

Arguments:
  path-to-config-dir  Directory containing config files (default: current dir)

Checks performed:
  1. opencode.jsonc and oh-my-openagent.jsonc exist
  2. Both files are valid JSON (JSONC comments stripped via sed before jq)
  3. No uncommitted *.pem or .env files in the repository

If jq is not available, JSON validation is skipped with a warning.
EOF
  exit 0
}

case "${1:-}" in
  --help | -h) usage ;;
esac

CONFIG_DIR="${1:-$(pwd)}"

echo "=== Pre-Commit Verification ==="
echo ""

# ── Check 1: Config files exist ──
echo "--- Config File Existence ---"
for f in opencode.jsonc oh-my-openagent.jsonc; do
  if [ -f "$CONFIG_DIR/$f" ]; then
    pass "$f exists"
  else
    fail "$f not found at $CONFIG_DIR/$f"
  fi
done

# ── Check 2: JSON validity (JSON5-aware parser) ──
echo ""
echo "--- JSON Validity ---"
JSON_VALIDATOR=""
if python3 -c "import json5" &>/dev/null 2>&1; then
  JSON_VALIDATOR="python3-json5"
elif command -v jq &>/dev/null; then
  JSON_VALIDATOR="jq"
fi

if [ "$JSON_VALIDATOR" = "python3-json5" ]; then
  for f in opencode.jsonc oh-my-openagent.jsonc; do
    filepath="$CONFIG_DIR/$f"
    if [ ! -f "$filepath" ]; then
      fail "$f: file not found, skipping JSON check"
      continue
    fi
    if python3 -c "
import json5, sys
try:
    json5.load(open('$filepath'))
    sys.exit(0)
except Exception as e:
    print(e, file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
      pass "$f is valid JSON5"
    else
      error_msg=$(python3 -c "
import json5, sys
try:
    json5.load(open('$filepath'))
except Exception as e:
    print(e)
" 2>&1)
      fail "$f: invalid JSON5"
      echo "       error: ${error_msg}"
    fi
  done
elif [ "$JSON_VALIDATOR" = "jq" ]; then
  for f in opencode.jsonc oh-my-openagent.jsonc; do
    filepath="$CONFIG_DIR/$f"
    if [ ! -f "$filepath" ]; then
      fail "$f: file not found, skipping JSON check"
      continue
    fi
    # Strip only line-start and inline (space-prefixed) comments, not URL slashes
    if sed -e 's|^[[:space:]]*//.*||g' -e 's|[[:space:]]\{1,\}//.*||g' "$filepath" | jq . >/dev/null 2>&1; then
      pass "$f is valid JSON"
    else
      error_msg=$(sed -e 's|^[[:space:]]*//.*||g' -e 's|[[:space:]]\{1,\}//.*||g' "$filepath" | jq . 2>&1 || true)
      fail "$f: invalid JSON"
      echo "       jq error: ${error_msg}"
    fi
  done
else
  warn "No JSON validator found — skipping JSON validation"
  warn "Install json5 (pip install json5) or jq (apt install jq)"
fi

# ── Check 3: No uncommitted *.pem or .env files ──
echo ""
echo "--- Sensitive File Check ---"
if git -C "$CONFIG_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
  sensitive=$(git -C "$CONFIG_DIR" ls-files --others --exclude-standard | grep -E '\.(pem|env)$' || true)
  if [ -n "$sensitive" ]; then
    fail "Uncommitted sensitive files detected:"
    echo "$sensitive" | sed 's/^/       /'
  else
    pass "No uncommitted *.pem or .env files"
  fi
else
  warn "Not a git repository — skipping sensitive file check"
fi

# ── Summary ──
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "✅ All checks passed ($PASS passed)"
else
  echo "❌ $FAIL check(s) failed ($PASS passed, $FAIL failed)"
fi
exit $([ "$FAIL" -gt 0 ] && echo 1 || echo 0)
