#!/usr/bin/env bash
# verify.sh — Run all OpenCode/OMO verification suites
# Combines health-check, pre-commit verify, omo doctor, and regression tests.
# Usage: ./verify.sh
# Exit codes: 0 = all pass, 1 = any suite failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

TOTAL=0
SUITE_PASS=0
SUITE_FAIL=0

header() { echo ""; echo "═══════════════════════════════════════════════"; echo "  $1"; echo "═══════════════════════════════════════════════"; }
pass() { echo "  ✅ SUITE PASS: $1"; SUITE_PASS=$((SUITE_PASS + 1)); }
fail() { echo "  ❌ SUITE FAIL: $1"; SUITE_FAIL=$((SUITE_FAIL + 1)); }

echo "╔══════════════════════════════════════════════════╗"
echo "║   OpenCode / OMO — Full Verification Suite      ║"
echo "╚══════════════════════════════════════════════════╝"
echo "Date: $(date -Iseconds)"
echo "Config: $CONFIG_DIR"
echo ""

# ── Suite 1: Environment Health Check ──
header "Suite 1/5 — Environment Health Check"
if bash "$SCRIPT_DIR/health-check.sh" "$CONFIG_DIR"; then
  pass "health-check.sh"
else
  fail "health-check.sh"
fi

# ── Suite 2: Pre-Commit Verify ──
header "Suite 2/5 — Pre-Commit Config Verify"
if bash "$SCRIPT_DIR/pre-commit-verify.sh" "$CONFIG_DIR"; then
  pass "pre-commit-verify.sh"
else
  fail "pre-commit-verify.sh"
fi

# ── Suite 3: OMO Runtime Health ──
header "Suite 3/5 — OMO Runtime Health (omo doctor)"
OMO_OUTPUT=$(omo doctor --verbose 2>&1) || true
OMO_EXIT=$?
echo "$OMO_OUTPUT"
# Check for validation errors (not just exit code)
# Check for any issue (not just errors — also catches "Invalid configuration")
if echo "$OMO_OUTPUT" | grep -qE '(Error|error|Invalid configuration|JSONC parse error|CloseBraceExpected|ValueExpected)'; then
  fail "omo doctor reports issues"
elif [ "$OMO_EXIT" -ne 0 ]; then
  fail "omo doctor exit code $OMO_EXIT"
else
  pass "omo doctor"
fi

# ── Suite 4: Regression Tests ──
header "Suite 4/5 — Regression Tests"
if bash "$SCRIPT_DIR/regression-test.sh"; then
  pass "regression-test.sh"
else
  fail "regression-test.sh"
fi

# ── Suite 5: Runtime Regression Test (slow, staged boot) ──
# Gated behind RUN_SLOW_TESTS=1 like tui-validation-path-test.sh in
# pre-commit-verify.sh: boots opencode in a staging HOME (90s worst case
# per phase). Run explicitly or in CI; default verify skips it.
if [ "${RUN_SLOW_TESTS:-0}" = "1" ]; then
  header "Suite 5/5 — Runtime Regression Test (staged boot)"
  if bash "$SCRIPT_DIR/runtime-regression-test.sh"; then
    pass "runtime-regression-test.sh"
  else
    fail "runtime-regression-test.sh"
  fi
else
  header "Suite 5/5 — Runtime Regression Test (staged boot)"
  echo "  ⏭️  Skipped (slow test). Re-run verify.sh with RUN_SLOW_TESTS=1 to enable."
fi


# ── Verdict ──
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Final Verdict"
echo "═══════════════════════════════════════════════════"
if [ "$SUITE_FAIL" -eq 0 ]; then
  echo "  ✅ ALL $SUITE_PASS suite(s) passed"
  exit 0
else
  echo "  ❌ $SUITE_FAIL suite(s) failed, $SUITE_PASS passed"
  exit 1
fi
