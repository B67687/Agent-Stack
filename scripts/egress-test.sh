#!/usr/bin/env bash
# egress-test.sh — L2 egress gate test suite (spec T1-T10).
#
# Tests the host-side Squid allowlist proxy + in-sandbox relay. Two phases:
#   Phase 1 (host): Squid policy itself (CONNECT tunnel / 403 deny).
#   Phase 2 (sandbox): end-to-end via bwrap-wrap.sh EGRESS=1 relay.
#
# Usage: bash scripts/egress-test.sh   (requires squid running via egress-proxy)
# Exit 0 = all pass. Prints PASS/FAIL per test.
set -uo pipefail

EGRESS_DIR="$HOME/.cache/opencode/egress"
EGRESS_SOCK="$EGRESS_DIR/egress.sock"
SQUID_PORT=13128
PROXY="http://127.0.0.1:$SQUID_PORT"
PASS=0; FAIL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$2' got '$3')"; fi
}

echo "== Phase 1: host Squid policy =="

# T1: allowlisted CONNECT tunnel works (401 = upstream unauthenticated, 200 = ok; both prove the tunnel)
code=$(curl -s -o /dev/null -w '%{http_code}' -x "$PROXY" https://api.deepseek.com/ 2>/dev/null)
if [ "$code" = "401" ] || [ "$code" = "200" ]; then
  ok "T1 allowlisted CONNECT api.deepseek.com tunnel-up (HTTP $code)"
else
  bad "T1 allowlisted CONNECT api.deepseek.com (got HTTP $code — expected 200/401)"
fi

# T1b: npm registry allowlisted
code=$(curl -s -o /dev/null -w '%{http_code}' -x "$PROXY" https://registry.npmjs.org/ 2>/dev/null)
check "T1b registry.npmjs.org allowed (got $code)" "200" "$code"

# T2: non-allowlisted host DENIED (curl gets 000 — proxy refuses CONNECT, no tunnel)
code=$(curl -s -o /dev/null -w '%{http_code}' -x "$PROXY" https://evil.example.com/ 2>/dev/null)
check "T2 evil.example.com no-tunnel" "000" "$code"

# T5: raw IP exfil denied
code=$(curl -s -o /dev/null -w '%{http_code}' -x "$PROXY" https://1.1.1.1/ --resolve 1.1.1.1:443:1.1.1.1 2>/dev/null)
check "T5 raw-IP 1.1.1.1 no-tunnel" "000" "$code"

# T6: suffix-attack hostname denied (api.deepseek.com.evil.com is NOT in allowlist)
code=$(curl -s -o /dev/null -w '%{http_code}' -x "$PROXY" https://api.deepseek.com.evil.com/ 2>/dev/null)
check "T6 api.deepseek.com.evil.com no-tunnel" "000" "$code"

echo "== Phase 2: sandbox end-to-end (bwrap EGRESS=1) =="

if [ ! -S "$EGRESS_SOCK" ]; then
  echo "  SKIP: egress socket $EGRESS_SOCK not present (is egress-proxy@ running?)"
else
  # T3: in-sandbox, allowlisted host reachable through relay
  out=$(OPENCODE_BIN=/bin/bash EGRESS=1 "$HOME/.config/opencode/scripts/bwrap-wrap.sh" -c 'curl -s -o /dev/null -w "%{http_code}" -x http://127.0.0.1:3128 https://registry.npmjs.org/' 2>/dev/null)
  check "T3 in-sandbox allowlisted registry reachable via relay" "200" "$out"

  # T4: in-sandbox, non-allowlisted host denied (000 = no tunnel)
  out=$(OPENCODE_BIN=/bin/bash EGRESS=1 "$HOME/.config/opencode/scripts/bwrap-wrap.sh" -c 'curl -s -o /dev/null -w "%{http_code}" -x http://127.0.0.1:3128 https://evil.example.com/' 2>/dev/null)
  check "T4 in-sandbox evil.example.com no-tunnel via relay" "000" "$out"

  # T7: netns has no NICs/routes (lo only)
  out=$(OPENCODE_BIN=/bin/bash EGRESS=1 "$HOME/.config/opencode/scripts/bwrap-wrap.sh" -c 'ip -o link show 2>/dev/null | wc -l')
  check "T7 sandbox netns interface count (expect 1 = lo)" "1" "$out"

  # T8: fail-closed — no socket => relay refuses to start (simulate by pointing at missing sock)
  out=$(EGRESS_SOCK="$EGRESS_DIR/nonexistent.sock" OPENCODE_BIN=/bin/echo EGRESS=1 "$HOME/.config/opencode/scripts/bwrap-wrap.sh" hi 2>&1 | head -1)
  case "$out" in
    *"not found"*) ok "T8 fail-closed: missing egress socket blocks launch ($out)" ;;
    *) bad "T8 fail-closed missing socket (got: $out)" ;;
  esac
fi

echo
echo "== Result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
