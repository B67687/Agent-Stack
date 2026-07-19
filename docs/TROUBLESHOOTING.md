# Troubleshooting

Quick reference for common OpenCode + OMO issues.

---

### 1. Insufficient Balance

**Problem:** "Insufficient balance" errors.
**Check:** `opencode models` to verify auth token.
**Fix:** `opencode auth login` to refresh. Fallback: `opencode --model opencode/deepseek-v4-flash-free`.

### 2. Config Not Loading

**Problem:** OpenCode ignores your config file.
**Check:** Brace balance, trailing commas. `opencode` CLI validates on startup.
**Fix:** Fix syntax flagged by CLI validator. Restart.

### 3. Agent Stops Mid-Session

**Problem:** Agent exits unexpectedly.
**Check:** Goal mode hitting `default_max_iterations` (set to 20). Intermittent stops = DeepSeek tool-calling bug (~10-20%).
**Fix:** Restart session. If needed, increase `goal.default_max_iterations` in oh-my-openagent.jsonc.

### 4. Playwright Fails

**Problem:** 502 errors or browser crashes.
**Check:** Playwright vs OS compatibility (26.04 needs patched >1.60.0). `--headless` and `--executable-path` in MCP config.
**Fix:** Reinstall browsers with patched Playwright. See INCIDENTS.md Incident 2.

### 5. DB Growing Too Large

**Problem:** `opencode.db` takes gigabytes.
**Check:** Weekly VACUUM cron at `0 3 * * 0` — verify with `crontab -l`.
**Fix:** Manual: `sqlite3 ~/.local/share/opencode/opencode.db "VACUUM;"`. WAL: add `PRAGMA wal_checkpoint(TRUNCATE);`.

### 6. dcp.jsonc Not Loading / Context Pruning Issues

**Problem:** Session still running out of context despite DCP being enabled.
**Check:** dcp.jsonc is valid JSON5 — missing commas cause silent failure. `showCompression: true` must have trailing comma.
**Fix:** Validate with `python3 -c "import json5; json5.load(open('dcp.jsonc'))"`. Ensure all lines have proper commas.

### 7. Goals Mode Not Working After OMO Update

**Problem:** Updated OMO but still getting Ralph Loop behavior or Goals not activating.
**Check:** Config has `default_mode: {goal: true}` and `goal: {enabled: true, default_max_iterations: 20}`. The old `mode: "ralph"` format was removed in OMO v4.19.0.
**Fix:** Update config to the new Goals format. Old Ralph Loop configs auto-migrate but produce deprecation warnings.

---

### 8. Infinite Continuation Injection Loop

**Problem:** Every user message triggers 'Continue working toward the active thread goal' with <untrusted_objective> wrapper, nesting deeper each time.
**Root:** Three separate continuation systems exist in OMO — (1) Goal Hook (gated by `goal.enabled`), (2) Todo Continuation Enforcer (no pluginConfig gate, only `disabled_hooks`), (3) Atlas/Boulder Continuation (no pluginConfig gate, only `disabled_hooks`). Setting `goal.enabled: false` only disables System 1. Systems 2-3 have no pluginConfig gate.
**Fix:** Add `disabled_hooks: ["goal", "todo-continuation-enforcer", "atlas"]` to oh-my-openagent.jsonc. This is the ONLY way to disable all three continuation systems since Systems 2 and 3 only check `disabled_hooks`.
