#!/usr/bin/env bash
# tui-validation-path-test.sh
#
# Guards the 'config invalid - run doctor' TUI banner bug class (2026-08-02).
# The banner comes from the TUI's validatePluginConfig2 path (dist/tui.js
# 81868) which runs parseConfig safeParse per top-level key +
# findUnknownKeyPaths against the INSTALLED Zod schema. That function is a
# Bun-closure and cannot be imported directly (createPluginModule harness is
# types-only in the published package), so this test covers the same
# inputs/outputs the banner derives from, through the REAL boot path:
#
#   Phase 1 (positive): stage the live config, boot opencode (exit 0, agents
#     loaded), then run scripts/config-schema-check.mjs against the STAGED
#     omo.jsonc — must report CLEAN (exit 0). A banner-invalid config would
#     fail here with the exact unknown-key diagnostics the TUI shows.
#
#   Phase 2 (negative): plant a ghost key (enable_fallback_json_mode inside
#     runtime_fallback — the round-3 offender) in the staged omo.jsonc, run
#     config-schema-check.mjs — must report UNKNOWN KEYS (exit 1) and name
#     '[opencode].runtime_fallback.enable_fallback_json_mode'.
#
# Usage: bash scripts/tui-validation-path-test.sh
# Exit 0 = both phases pass. Non-zero = regression.
set -uo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
OMO_JSONC="${HOME}/.omo/omo.jsonc"
OPENCODE_BIN="${HOME}/.opencode/bin/opencode"
SCRATCH="${HOME}/.cache/tmp/opencode"
LIVE_OMO_CACHE="${HOME}/.cache/oh-my-opencode"
SCHEMA_CHECK="${CONFIG_DIR}/scripts/config-schema-check.mjs"

# Clean up staging dirs on exit (ROOT1/ROOT2 set later; ${var:-} is nounset-safe)
trap 'rm -rf "${ROOT1:-}" "${ROOT2:-}" 2>/dev/null || true' EXIT
SCHEMA_CHECK="${CONFIG_DIR}/scripts/config-schema-check.mjs"

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

# ---------------------------------------------------------------------------
# stage_home <staging_root>  — build a staging HOME from live config + plugin
# ---------------------------------------------------------------------------
stage_home() {
  local root="$1"
  mkdir -p "${root}/.config/opencode/node_modules"
  mkdir -p "${root}/.omo"
  mkdir -p "${root}/.cache/oh-my-opencode"
  mkdir -p "${root}/.cache/opencode"
  cp "${CONFIG_DIR}/opencode.jsonc" "${root}/.config/opencode/"
  cp "${OMO_JSONC}" "${root}/.omo/omo.jsonc"
  cp -r "${CONFIG_DIR}/node_modules/." "${root}/.config/opencode/node_modules/"
  cp "${LIVE_OMO_CACHE}/connected-providers.json" "${root}/.cache/oh-my-opencode/" 2>/dev/null || true
  cp "${LIVE_OMO_CACHE}/provider-models.json"     "${root}/.cache/oh-my-opencode/" 2>/dev/null || true
  cp "${LIVE_OMO_CACHE}/model-capabilities.json"  "${root}/.cache/oh-my-opencode/" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# boot_opencode <staging_root> — run opencode in staging; echoes "exit:<code>"
# ---------------------------------------------------------------------------
boot_opencode() {
  local root="$1"
  local logfile="${root}/boot.log"
  (cd "${root}" && HOME="${root}" XDG_CONFIG_HOME="${root}/.config" TMPDIR="${root}/tmp" \
    timeout 90 "${OPENCODE_BIN}" run 'say hi' > "${logfile}" 2>&1)
  echo "exit:$?"
}

# ---------------------------------------------------------------------------
# Phase 1 — real staged config: boot clean AND schema-check CLEAN on staged file
# ---------------------------------------------------------------------------
echo "== Phase 1: live config validates (boot + installed-schema) =="
ROOT1="${SCRATCH}/tui-val-1-$(date +%s)"
stage_home "${ROOT1}"
res=$(boot_opencode "${ROOT1}")
code="${res#exit:}"
if [ "$code" = "0" ]; then pass "boot exit 0"; else fail "boot exit 0 (got ${code})"; fi

PLOG1="${ROOT1}/tmp/oh-my-opencode.log"
if [ -f "${PLOG1}" ] && grep -q '\[config-handler\] agents loaded' "${PLOG1}"; then
  pass "agents loaded (config chain consumed at boot)"
else
  fail "no 'agents loaded' in plugin log"
fi

# schema parity against the STAGED file (not live) — same input the staged
# boot used, validated against the INSTALLED in-package schema
if [ -x "$(command -v node)" ]; then
  out=$(node "${SCHEMA_CHECK}" "${ROOT1}/.omo/omo.jsonc" 2>&1)
  sret=$?
  if [ "${sret}" = "0" ]; then
    pass "config-schema-check CLEAN on staged omo.jsonc"
  else
    fail "config-schema-check on staged omo.jsonc: exit ${sret}"
    echo "    ${out}" | head -5
  fi
else
  fail "node not found — schema check skipped"
fi

# ---------------------------------------------------------------------------
# Phase 2 — ghost key planted in STAGED omo.jsonc → schema-check must flag it
# ---------------------------------------------------------------------------
echo "== Phase 2: ghost key flagged (round-3 bug class) =="
ROOT2="${SCRATCH}/tui-val-2-$(date +%s)"
stage_home "${ROOT2}"

cat > "${SCRATCH}/plant-ghost.mjs" <<'EOF'
// Plant the round-3 ghost key (enable_fallback_json_mode inside
// runtime_fallback) into a staged omo.jsonc. Mirrors the exact unknown-key
// the 4.19.4 strict validation flagged as 'config invalid - run doctor'.
import { readFileSync, writeFileSync } from 'node:fs';
const file = process.argv[2];
const src = readFileSync(file, 'utf8');
const marker = '"enable_fallback_json_mode": true,';
const re = /("runtime_fallback": \{)/;
const planted = src.replace(re, (m, open) => open + '\n      ' + marker);
if (planted === src) { console.error('GHOST PLANT FAILED: runtime_fallback block not found'); process.exit(2); }
writeFileSync(file, planted);
console.log('ghost planted in runtime_fallback');
EOF
node "${SCRATCH}/plant-ghost.mjs" "${ROOT2}/.omo/omo.jsonc" || fail "ghost plant"

out2=$(node "${SCHEMA_CHECK}" "${ROOT2}/.omo/omo.jsonc" 2>&1)
sret2=$?
if [ "${sret2}" = "1" ] && echo "${out2}" | grep -q 'enable_fallback_json_mode'; then
  pass "ghost key flagged: '[opencode].runtime_fallback.enable_fallback_json_mode' (exit 1)"
elif [ "${sret2}" = "1" ]; then
  fail "ghost flagged (exit 1) but key not named"
  echo "    ${out2}" | head -5
else
  fail "ghost NOT flagged (exit ${sret2}) — validator missed the round-3 bug class"
  echo "    ${out2}" | head -5
fi

# ---------------------------------------------------------------------------
echo ""
echo "== result: ${PASS} passed, ${FAIL} failed =="
[ "${FAIL}" -eq 0 ] && echo "TUI VALIDATION PATH TEST: CLEAN" || echo "TUI VALIDATION PATH TEST: FAILED"
exit "${FAIL}"
