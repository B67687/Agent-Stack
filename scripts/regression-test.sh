#!/usr/bin/env bash
# Regression test suite for OMO config + attribution defenses
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/.."

PASS=0
FAIL=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  WARN: $1"; }

echo "=== Regression Tests ==="
echo ""

# ── Test 1: Attribution injection — git hook strips it (through git-master skill) ──
echo "--- Attribution Defense ---"
TESTDIR=$(mktemp -d)
cd "$TESTDIR"
GIT_MASTER=1 git init --initial-branch=main 2>/dev/null
echo "test" > dummy.txt
GIT_MASTER=1 git add dummy.txt
GIT_MASTER=1 git -c user.name=Test -c user.email=test@test.com commit -m "feat: test" -m "" -m "Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>" -m "Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-openagent)" 2>/dev/null || true
MSG=$(GIT_MASTER=1 git log -1 --format=%B)
cd / && rm -rf "$TESTDIR"
if echo "$MSG" | grep -q "Sisyphus"; then
    fail "Attribution present in commit (git-master flow)"
else
    pass "Git hook strips attribution (git-master flow)"
fi

# ── Test 2: Config override prevents injection ──
echo ""
echo "--- Config Override ---"
OVERRIDE_OK=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
gm = omo.get('git_master', {})
if gm.get('commit_footer') is False and gm.get('include_co_authored_by') is False:
    print('ok')
else:
    print('missing')
")
if [ "$OVERRIDE_OK" = "ok" ]; then
    pass "Config override active (commit_footer=false, include_co_authored_by=false)"
else
    fail "Config override missing"
fi

# ── Test 3: All configs parse as valid JSON5 ──
echo ""
echo "--- Config Validity ---"
for f in opencode.jsonc oh-my-openagent.jsonc dcp.jsonc; do
    path="$HOME/.config/opencode/$f"
    if node "$REPO_DIR/scripts/validate-jsonc.js" check "$path" 2>/dev/null; then
        pass "$f parses valid JSONC"
    else
        fail "$f: JSONC parse error"
    fi
done

# ── Test 4: Brace balance ──
echo ""
echo "--- Brace Balance ---"
for f in opencode.jsonc oh-my-openagent.jsonc; do
    path="$HOME/.config/opencode/$f"
    c=$(cat "$path")
    o=$(echo "$c" | grep -o '{' | wc -l)
    cl=$(echo "$c" | grep -o '}' | wc -l)
    if [ "$o" = "$cl" ]; then
        pass "$f: $o = $cl (balanced)"
    else
        fail "$f: $o opens vs $cl closes (unbalanced)"
    fi
done

# ── Test 5: No duplicate fallback_models keys ──
echo ""
echo "--- Duplicate Keys ---"
DUPES=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
dupes = 0
for scope in ['agents', 'categories']:
    for name, obj in omo.get(scope, {}).items():
        fbs = obj.get('fallback_models', [])
        if len(fbs) > 1:
            print(f'{scope}/{name}: {len(fbs)} fallbacks')
            dupes += 1
if dupes == 0:
    print('ok')
")
if [ "$DUPES" = "ok" ]; then
    pass "No duplicate fallback_models"
else
    echo "$DUPES"
    fail "Duplicate fallback_models found"
fi

# ── Test 6: All Go-tier agents have a fallback ──
echo ""
echo "--- Fallback Coverage ---"
MISSING=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
missing = []
for name, agent in omo.get('agents', {}).items():
    model = agent.get('model', '')
    if model.startswith('opencode-go/') and 'fallback_models' not in agent:
        missing.append(name)
if missing:
    print(', '.join(missing))
else:
    print('ok')
")
if [ "$MISSING" = "ok" ]; then
    pass "All Go-tier agents have fallbacks"
else
    fail "Agents missing fallbacks: $MISSING"
fi

# ── Test 7: Only DeepSeek + MiMo models in use ──
echo ""
echo "--- Model Allowlist ---"
BAD=$(python3 -c "
import re, json5
bad = []
for path in ['$HOME/.config/opencode/opencode.jsonc', '$HOME/.config/opencode/oh-my-openagent.jsonc']:
    omo = json5.loads(open(path).read())
    c = open(path).read()
    for m in re.findall(r'\"model\"\s*:\s*\"([a-zA-Z0-9_./-]+)\"', c):
        if 'deepseek' not in m and 'mimo' not in m and 'minimax' not in m and 'qwen' not in m and 'glm' not in m and 'kimi' not in m and 'grok' not in m:
            bad.append(m)
if bad:
    print(', '.join(set(bad)))
else:
    print('ok')
")
if [ "$BAD" = "ok" ]; then
    pass "Only allowlisted models configured (deepseek, mimo, minimax, qwen, glm, kimi, grok)"
else
    fail "Unexpected models found: $BAD"
fi

# ── Test 8: skip_task_agent_fallback is enabled ──
echo ""
echo "--- Premium Model Containment ---"
SKIP=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
rf = omo.get('runtime_fallback', {})
print(rf.get('skip_task_agent_fallback', 'missing'))
")
if [ "$SKIP" = "True" ]; then
    pass "skip_task_agent_fallback enabled"
else
    fail "skip_task_agent_fallback: $SKIP (expected True)"
fi

# ── Test 9: OMO dist does not contain attribution injection ──
echo ""
echo "--- OMO Dist Attribution Check ---"
DIST=""
for p in "$HOME/.cache/opencode/packages/oh-my-openagent@latest/node_modules/oh-my-openagent/dist/index.js" \
        "$HOME/.nvm/versions/node/v22.22.3/lib/node_modules/oh-my-openagent/dist/index.js"; do
    if [ -f "$p" ]; then DIST="$p"; break; fi
done
if [ -n "$DIST" ]; then
    COAUTH=$(grep -c "Co-authored-by: Sisyphus" "$DIST" 2>/dev/null || true)
    ULTRA=$(grep -c "Ultraworked with" "$DIST" 2>/dev/null || true)
    FN=$(grep -c "buildCommitFooterInjection" "$DIST" 2>/dev/null || true)
    TOTAL=$((COAUTH + ULTRA))
    if [ "$TOTAL" -eq 0 ]; then
        pass "OMO dist: no attribution injection found"
    else
        warn "OMO dist: ${COAUTH} co-auth + ${ULTRA} ultra = ${TOTAL} injection points (layers 1+2 still protect)"
    fi
else
    warn "OMO dist not found at expected path (may need restart)"
fi

# ── Test 10: No errant duplications across configs ──
echo ""
echo "--- Cross-Config Duplication ---"
OVERLAP=$(python3 -c "
import json5
oc = set(json5.loads(open('$HOME/.config/opencode/opencode.jsonc').read()).get('agent', {}).keys())
omo = set(json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read()).get('agents', {}).keys())
bad = []
for name in oc & omo:
    oc_agent = json5.loads(open('$HOME/.config/opencode/opencode.jsonc').read()).get('agent', {}).get(name, {})
    if 'model' in oc_agent:
        bad.append(f'{name}: model in opencode.jsonc')
if bad:
    print('; '.join(bad))
else:
    print('ok')
")
if [ "$OVERLAP" = "ok" ]; then
    pass "DRY split: no model assignment in opencode.jsonc agents"
else
    warn "$OVERLAP"
fi

# ── Test 11: Category fallback coverage ──
echo ""
echo "--- Category Fallback Coverage ---"
CAT_MISSING=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
missing = []
for name, cat in omo.get('categories', {}).items():
    model = cat.get('model', '')
    if model.startswith('opencode-go/') and 'fallback_models' not in cat:
        missing.append(name)
if missing:
    print(', '.join(missing))
else:
    print('ok')
")
if [ "$CAT_MISSING" = "ok" ]; then
    pass "All Go-tier categories have fallbacks"
else
    warn "Categories missing fallbacks: $CAT_MISSING"
fi

# ── Test 12: New config features correctly placed ──
echo ""
echo "--- New Config Features ---"
NEW_OK=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
issues = []
for key in ['auto_update', 'telemetry', 'model_fallback']:
    if key not in omo:
        issues.append(f'{key}: missing from top level')
ws = omo.get('websearch', {})
for key in ['auto_update', 'telemetry', 'model_fallback']:
    if key in ws:
        issues.append(f'{key}: NESTED inside websearch (should be top-level)')
if 'keyword_detector' not in omo:
    issues.append('keyword_detector: missing')
if 'agent_order' not in omo:
    issues.append('agent_order: missing')
cats = omo.get('categories', {})
if 'git' not in cats:
    issues.append('categories.git: missing')
if issues:
    for i in issues: print(i)
else:
    print('ok')
")
if [ "$NEW_OK" = "ok" ]; then
    pass "New config features correctly placed (auto_update, telemetry, model_fallback top-level, keyword_detector, agent_order, git category)"
else
    fail "$NEW_OK"
fi

# ── Test 13: All 6 experimental flags present ──
echo ""
echo "--- Experimental Flags ---"
EXP_OK=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
exp = omo.get('experimental', {})
expected = ['disable_omo_env', 'task_system', 'preemptive_compaction', 'truncate_all_tool_outputs', 'safe_hook_creation']
missing = [k for k in expected if k not in exp]
if missing:
    print(', '.join(missing))
else:
    print('ok')
")
if [ "$EXP_OK" = "ok" ]; then
    pass "All 5 experimental flags present"
else
    fail "Missing experimental flags: $EXP_OK"
fi

# ── Test 14: SearXNG MCP responds ──
echo ""
echo "--- SearXNG MCP ---"
if echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | SEARXNG_URL=http://127.0.0.1:8888 timeout 5 mcp-searxng 2>&1 | grep -q 'serverInfo'; then
    pass "SearXNG MCP server responds"
else
    warn "SearXNG MCP: could not connect (may need restart)"
fi

# ── Test 15: DCP settings integrity ──
echo ""
echo "--- DCP Settings ---"
DCP_OK=$(python3 -c "
import json5
try:
    dcp = json5.loads(open('$HOME/.config/opencode/dcp.jsonc').read())
    comp = dcp.get('compress', {})
    tp = dcp.get('turnProtection', {})
    issues = []
    if comp.get('nudgeFrequency') != 1: issues.append(f'nudgeFrequency={comp.get(\"nudgeFrequency\")}')
    if comp.get('minContextLimit') != 12000: issues.append(f'minContextLimit={comp.get(\"minContextLimit\")}')
    if tp.get('turns') != 5: issues.append('turnProtection=' + str(tp.get("turns")))
    if issues:
        print('; '.join(issues))
    else:
        print('ok')
except Exception as e:
    print('error: ' + str(e))
")
if [ "$DCP_OK" = "ok" ]; then
    pass "DCP settings match expected (nudge=1, limit=12k, protection=5)"
else
    warn "DCP drift: $DCP_OK"
fi

# ── Test 16: OpenCode CLI starts without error ──
echo "--- OpenCode Health ---"
OPENCODE_BIN=$(which opencode 2>/dev/null || find /usr/local /opt $HOME/.local $HOME/.opencode -name opencode -type f 2>/dev/null | head -1)
if [ -n "$OPENCODE_BIN" ] && "$OPENCODE_BIN" --version 2>/dev/null | grep -q '[0-9]'; then
    pass "OpenCode CLI responds ($OPENCODE_BIN)"
else
    warn "OpenCode CLI not available (install required)"
fi

# ── Test 17: opencode.jsonc sync (mirror == live, with placeholder substitution) ──
echo "--- Config Sync ---"
REPO_DIR="$REPO_DIR"
SYNC_OK=$(python3 -c "
import json5, os
h = os.environ['HOME']
live = json5.loads(open(h + '/.config/opencode/opencode.jsonc').read())
repo = json5.loads(open('$REPO_DIR/opencode.jsonc').read())
lc = json5.dumps(live, sort_keys=True)
rc = json5.dumps(repo, sort_keys=True)
rc_fixed = rc.replace('{{OPENDATA_DIR}}', h + '/.local/share/opencode').replace('{{PLAYWRIGHT_CHROME}}', h + '/.cache/ms-playwright/chromium-1223/chrome-linux64/chrome')
if lc == rc_fixed:
    print('ok')
else:
    for i, (a,b) in enumerate(zip(lc, rc_fixed)):
        if a != b: print(f'diff at char {i}: live={repr(a)} repo={repr(b)}'); break
")
if [ "$SYNC_OK" = "ok" ]; then
    pass "opencode.jsonc mirror matches live config (with placeholders)"
else
    warn "opencode.jsonc mirror differs from live: $SYNC_OK"
fi

# ── Test 17b: oh-my-openagent.jsonc sync (mirror == live) ──
OMO_SYNC_OK=$(python3 -c "
import json5, os
h = os.environ['HOME']
live = json5.loads(open(h + '/.config/opencode/oh-my-openagent.jsonc').read())
repo = json5.loads(open('$REPO_DIR/oh-my-openagent.jsonc').read())
lc = json5.dumps(live, sort_keys=True)
rc = json5.dumps(repo, sort_keys=True)
if lc == rc:
    print('ok')
else:
    for i, (a,b) in enumerate(zip(lc, rc)):
        if a != b: print(f'diff at char {i}: live={repr(a)} repo={repr(b)}'); break
")
if [ "$OMO_SYNC_OK" = "ok" ]; then
    pass "oh-my-openagent.jsonc mirror matches live config"
else
    warn "oh-my-openagent.jsonc mirror differs from live: $OMO_SYNC_OK"
fi

# ── Test 18: Key prompt_append sections intact ──
echo "--- Prompt Append Integrity ---"
APPEND_OK=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
sis = omo.get('agents', {}).get('sisyphus', {})
pa = sis.get('prompt_append', '')
checks = ['Clarification Protocol', 'lsp_diagnostics', 'Pre-Commit Gate', 'Project Memory']
missing = [c for c in checks if c not in pa]
if missing:
    print(', '.join(missing))
else:
    print('ok')
")
if [ "$APPEND_OK" = "ok" ]; then
    pass "All 4 key prompt_append sections present"
else
    warn "Missing prompt_append sections: $APPEND_OK"
fi

# ── Test 19: dynamic_context_pruning enabled with turn_protection 5 ──
echo ""
echo "--- Dynamic Context Pruning ---"
DCP_OK=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
dcp = omo.get('dynamic_context_pruning', {})
issues = []
if dcp.get('enabled') is not True: issues.append('enabled not True')
tp = dcp.get('turn_protection', {})
if tp.get('enabled') is not True: issues.append('turn_protection.enabled not True')
if tp.get('turns') != 5: issues.append(f'turn_protection.turns={tp.get("turns")} (expected 5)')
if not issues:
    print('ok')
else:
    print('; '.join(issues))
")
if [ "$DCP_OK" = "ok" ]; then
    pass "dynamic_context_pruning enabled with turn_protection 5"
else
    fail "$DCP_OK"
fi

# ── Test 20: babysitting.timeout_ms = 180000 ──
echo ""
echo "--- Babysitting ---"
BS_OK=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
bs = omo.get('babysitting', {})
tm = bs.get('timeout_ms')
if tm == 180000:
    print('ok')
else:
    print(f'timeout_ms={tm} (expected 180000)')
")
if [ "$BS_OK" = "ok" ]; then
    pass "babysitting.timeout_ms = 180000"
else
    fail "$BS_OK"
fi

# ── Test 21: aggressive_truncation absent from config (uses OMO default) ──
echo ""
echo "--- Aggressive Truncation ---"
if python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
exit(0 if 'aggressive_truncation' not in omo else 1)
" 2>/dev/null; then
    pass "aggressive_truncation absent (uses OMO default)"
else
    fail "aggressive_truncation still present in config"
fi

# ── Test 22: truncate_all_tool_outputs is false ──
echo ""
echo "--- Tool Output Truncation ---"
TRUNC_OK=$(python3 -c "
import json5
omo = json5.loads(open('$HOME/.config/opencode/oh-my-openagent.jsonc').read())
exp = omo.get('experimental', {})
val = exp.get('truncate_all_tool_outputs')
if val is False:
    print('ok')
else:
    print(f'truncate_all_tool_outputs={val} (expected false)')
")
if [ "$TRUNC_OK" = "ok" ]; then
    pass "truncate_all_tool_outputs is false"
else
    fail "$TRUNC_OK"
fi

# ── Test 23: 7 auto-rules .mdc files exist ──
echo ""
echo "--- Auto-Rules ---"
RULES_DIR="$REPO_DIR/.opencode/rules"
if [ -d "$RULES_DIR" ]; then
    COUNT=$(ls -1 "$RULES_DIR"/*.mdc 2>/dev/null | wc -l)
    if [ "$COUNT" -ge 9 ]; then
        pass "${COUNT} auto-rules .mdc files exist"
    else
        warn "Auto-rules: found $COUNT .mdc files (expected 9+)"
    fi
else
    warn "Auto-rules directory not found"
fi

# ── Test 24: 7 scripts exist ──
echo ""
echo "--- Scripts ---"
SCRIPTS_DIR="$REPO_DIR/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    SCOUNT=$(ls -1 "$SCRIPTS_DIR"/*.sh "$SCRIPTS_DIR"/*.mjs "$SCRIPTS_DIR"/*.ts "$SCRIPTS_DIR"/*.js 2>/dev/null | wc -l)
    if [ "$SCOUNT" -ge 10 ]; then
        pass "${SCOUNT} scripts in scripts/ directory"
    else
        warn "Scripts: found $SCOUNT files (expected 10+)"
    fi
else
    warn "Scripts directory not found"
fi

# ── Test 25: context-mode tooling in general agent prompt ──
echo ""
echo "--- Context-Mode Tooling ---"
CTX_OK=$(python3 -c "
import json5
oc = json5.loads(open('$HOME/.config/opencode/opencode.jsonc').read())
gen = oc.get('agent', {}).get('general', {})
prompt = gen.get('prompt', '')
checks = ['ctx_search', 'ctx_fetch_and_index', 'ctx_index', 'ctx_batch_execute']
missing = [c for c in checks if c not in prompt]
if missing:
    print(', '.join(missing))
else:
    print('ok')
")
if [ "$CTX_OK" = "ok" ]; then
    pass "Context-mode tooling in general agent prompt (all 4 ctx_* tools)"
else
    warn "General agent missing context-mode tools: $CTX_OK"
fi

 

# ── Test 26: lsp.json structure ──
echo ""
echo "--- LSP Config Structure ---"
LSP_OK=$(python3 -c "
import json5, os
h = os.environ['HOME']
lsp = json5.loads(open(h + '/.config/opencode/lsp.json').read())
issues = []
if 'typescript' not in lsp: issues.append('typescript entry missing')
if 'kotlin-ls' not in lsp: issues.append('kotlin-ls entry missing')
ts = lsp.get('typescript', {})
if 'command' not in ts: issues.append('typescript.command missing')
kl = lsp.get('kotlin-ls', {})
if 'command' not in kl: issues.append('kotlin-ls.command missing')
if issues:
    print('; '.join(issues))
else:
    print('ok')
")
if [ "$LSP_OK" = "ok" ]; then
    pass "lsp.json has typescript + kotlin-ls entries with commands"
else
    fail "lsp.json structure: $LSP_OK"
fi

# ── Test 27: Wrapper scripts exist in Agent-Stack/scripts ──
echo ""
echo "--- Wrapper Scripts ---"
WRAPPER_MISSING=""
for script in resolve-ts-lsp.js zls-lsp-wrapper.js jdtls.sh kotlin-lsp.sh lua-ls.sh; do
    if [ ! -f "$REPO_DIR/scripts/$script" ]; then
        WRAPPER_MISSING="$WRAPPER_MISSING $script"
    fi
done
if [ -z "$WRAPPER_MISSING" ]; then
    pass "All 5 LSP wrapper scripts present"
else
    warn "Missing wrapper scripts:$WRAPPER_MISSING"
fi

# ── Test 28: Model concurrency covers all Go-tier models ──
echo ""
echo "--- Model Concurrency Coverage ---"
CONCUR_OK=$(python3 -c "
import json5, os, re
h = os.environ['HOME']
omo = json5.loads(open(h + '/.config/opencode/oh-my-openagent.jsonc').read())
mc = omo.get('background_task', {}).get('modelConcurrency', {})
# Collect all models used in categories and agents
used_models = set()
for scope in ['categories', 'agents']:
    for name, obj in omo.get(scope, {}).items():
        m = obj.get('model', '')
        if m.startswith('opencode-go/'):
            used_models.add(m)
# Check each used model has a concurrency entry
missing = [m for m in used_models if m not in mc]
if missing:
    print(', '.join(missing))
else:
    print('ok')
")
if [ "$CONCUR_OK" = "ok" ]; then
    pass "All Go-tier models have concurrency settings"
else
    warn "Models missing concurrency: $CONCUR_OK"
fi

# ── Test 29: opencode.jsonc has expected disabled_providers ──
echo ""
echo "--- Disabled Providers ---"
DP_OK=$(python3 -c "
import json5, os
h = os.environ['HOME']
oc = json5.loads(open(h + '/.config/opencode/opencode.jsonc').read())
dp = oc.get('disabled_providers', [])
expected = {'openai', 'anthropic', 'google', 'xai'}
actual = set(dp)
if actual == expected:
    print('ok')
else:
    missing = expected - actual
    extra = actual - expected
    parts = []
    if missing: parts.append('missing: ' + ','.join(missing))
    if extra: parts.append('extra: ' + ','.join(extra))
    print('; '.join(parts))
")
if [ "$DP_OK" = "ok" ]; then
    pass "disabled_providers = {openai, anthropic, google, xai}"
else
    fail "disabled_providers mismatch: $DP_OK"
fi

# ── Post-Run Maintenance ──
echo ""
echo "--- Post-Run Maintenance ---"
BACKUP_DIR="$HOME/.config/opencode/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
cp "$HOME/.config/opencode/opencode.jsonc" "$BACKUP_DIR/opencode.jsonc" 2>/dev/null
cp "$HOME/.config/opencode/oh-my-openagent.jsonc" "$BACKUP_DIR/oh-my-openagent.jsonc" 2>/dev/null
cp "$HOME/.config/opencode/dcp.jsonc" "$BACKUP_DIR/dcp.jsonc" 2>/dev/null
cp "$HOME/.config/opencode/tui.json" "$BACKUP_DIR/tui.json" 2>/dev/null
echo "  📦 Backup created: $BACKUP_DIR"
find "$HOME/.config/opencode/backups/" -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true
if [ -d "$HOME/.cache/opencode/packages" ]; then
    rm -rf "$HOME/.cache/opencode/packages"
fi

# ── Summary ──
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
