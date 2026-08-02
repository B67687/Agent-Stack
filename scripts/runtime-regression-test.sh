#!/usr/bin/env bash
# runtime-regression-test.sh
#
# Boots opencode in a STAGING HOME with the live 4.19.4 plugin + config, then
# asserts the plugin RUNTIME actually consumed the agent model overrides.
#
# Guards the bug class discovered 2026-08-02: the 4.19.4 startup migration wrote
# a models[]-shape omo.jsonc that the plugin's own agent-registration loop could
# not read (it only reads the `model` key), so every agent/category override was
# silently dropped to plugin-default models at runtime — while every static check
# (config parse, migration fidelity, `omo doctor`) reported PASS.
#
# Two phases:
#   Phase 1 (positive): boot staging with the REAL config; assert exit 0, agents
#     loaded, and NO unexpected '[agent-registration] Agent skipped' lines.
#   Phase 2 (marker): plant an impossible model id on hephaestus, boot again;
#     assert the boot SUCCEEDS (exit 0 — opencode tolerates unknown models at
#     registration, logging them as 'Agent skipped') AND the planted marker
#     appears verbatim in the hephaestus skip line's configuredModel field.
#     If the runtime ignored omo.jsonc, the skip line would carry a plugin
#     default model id instead of the marker — deterministic consumption proof.
#     again; assert the boot FAILS (proves the runtime consumed the config —
#     the marker would be invisible if the config were ignored).
#
# Usage: bash scripts/runtime-regression-test.sh
# Exit 0 = both phases pass. Non-zero = regression.
set -uo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
OMO_JSONC="${HOME}/.omo/omo.jsonc"
OPENCODE_BIN="${HOME}/.opencode/bin/opencode"
SCRATCH="${HOME}/.cache/tmp/opencode"
LIVE_OMO_CACHE="${HOME}/.cache/oh-my-opencode"

# Clean up staging dirs on exit (ROOT1/ROOT2 set later; ${var:-} is nounset-safe)
trap 'rm -rf "${ROOT1:-}" "${ROOT2:-}" 2>/dev/null || true' EXIT

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
  # fresh node_modules each run (cp -r nests when dst exists — always fresh dirs)
  cp -r "${CONFIG_DIR}/node_modules/." "${root}/.config/opencode/node_modules/"
  # seed plugin provider/model caches so fetchAvailableModels has data
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
# Phase 1 — real config boots, agents loaded, no unexpected skips
# ---------------------------------------------------------------------------
echo "== Phase 1: real config consumption =="
ROOT1="${SCRATCH}/omo-runtime-1-$(date +%s)"
stage_home "${ROOT1}"
res=$(boot_opencode "${ROOT1}")
code="${res#exit:}"
if [ "$code" = "0" ]; then pass "boot exit 0"; else fail "boot exit 0 (got ${code})"; fi

PLOG1="${ROOT1}/tmp/oh-my-opencode.log"
if [ -f "${PLOG1}" ]; then
  if grep -q '\[config-handler\] agents loaded' "${PLOG1}"; then
    pass "agents loaded (config consumed)"
  else
    fail "no 'agents loaded' in plugin log"
  fi

  # Unexpected skips: any [agent-registration] Agent skipped line whose agent is
  # NOT in the known-acceptable set. Update KNOWN_SKIPS when a skip is reviewed
  # and accepted (each entry must have a documented reason).
  KNOWN_SKIPS="hephaestus"  # plugin requires GPT-5.x for hephaestus; our routing
                            # sends deepseek-v4-flash → pre-existing silent skip
                            # (4.18.0 behaved identically). Pending routing decision.
  skips=$(grep '\[agent-registration\] Agent skipped' "${PLOG1}" | grep -o '"agent":"[^"]*"' | sort -u | tr -d '"' | sed 's/agent://')
  for a in ${skips}; do
    case " ${KNOWN_SKIPS} " in
      *" ${a} "*) echo "  (known skip: ${a})" ;;
      *) fail "unexpected agent skipped: ${a}" ;;
    esac
  done
  # Deterministic consumption proof: the hephaestus skip line carries our
  # configured model value (deepseek-v4-flash — NOT a plugin default). If the
  # runtime ignored omo.jsonc, configuredModel would show a GPT-5.x plugin default
  # (or hephaestus would be absent entirely).
  if grep -q '"agent":"hephaestus","configuredModel":"opencode-go/deepseek-v4-flash"' "${PLOG1}"; then
    pass "hephaestus skip carries OUR configured model (runtime reads model key)"
  else
    fail "hephaestus skip missing or configuredModel != ours (config not consumed)"
  fi
else
  fail "plugin log missing: ${PLOG1}"
fi

# ---------------------------------------------------------------------------
# Phase 2 — marker: impossible model must crash the boot (proves consumption)
# ---------------------------------------------------------------------------
echo "== Phase 2: marker consumption proof =="
ROOT2="${SCRATCH}/omo-runtime-2-$(date +%s)"
stage_home "${ROOT2}"
cat > "${SCRATCH}/plant-marker.mjs" <<'EOF'
// Plant an impossible model id on hephaestus, whose skip line is logged at
// registration carrying its configuredModel. If the runtime reads omo.jsonc,
// the skip line's configuredModel becomes the marker; if config were ignored,
// it would show the plugin default. Deterministic — no crash dependency.
import { readFileSync, writeFileSync } from 'node:fs';
const file = process.argv[2];
const src = readFileSync(file, 'utf8');
const marker = '"model": "opencode-go/ZZZ-MARKER-NOT-A-REAL-MODEL"';
const re = /("hephaestus": \{)([\s\S]*?)("model": "opencode-go\/deepseek-v4-flash")/;
const planted = src.replace(re, (m, open, body, model) => open + body + marker);
if (planted === src) { console.error('MARKER PLANT FAILED: hephaestus block model not found'); process.exit(2); }
writeFileSync(file, planted);
console.log('marker planted on hephaestus agent');
EOF
node "${SCRATCH}/plant-marker.mjs" "${ROOT2}/.omo/omo.jsonc" || fail "marker plant"
res2=$(boot_opencode "${ROOT2}")
code2="${res2#exit:}"
if [ "$code2" != "0" ]; then
  fail "marker boot failed (exit ${code2}) — expected clean boot; hephaestus skip carries the marker"
else
  pass "marker boot exit 0"
fi
PLOG2="${ROOT2}/tmp/oh-my-opencode.log"
if [ -f "${PLOG2}" ] && grep -q '"agent":"hephaestus","configuredModel":"opencode-go/ZZZ-MARKER-NOT-A-REAL-MODEL"' "${PLOG2}"; then
  pass "marker visible in hephaestus skip line → runtime consumed agent model field"
else
  fail "marker NOT in hephaestus skip line (config not consumed)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "== result: ${PASS} passed, ${FAIL} failed =="
[ "${FAIL}" -eq 0 ] && echo "RUNTIME REGRESSION TEST: CLEAN" || echo "RUNTIME REGRESSION TEST: FAILED"
exit "${FAIL}"
