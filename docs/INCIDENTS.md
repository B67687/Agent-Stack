# Incidents

Known errors, root causes, fixes, and current status for the OpenCode + OMO stack.

---

## Incident 1: Insufficient Balance (Jul 2026)

**Error:** "Insufficient balance. Manage your billing here..."

**Root:** OpenCode Go platform routing bug (#35149). Free models were hitting paid wallet validation gates. The Go auth token may also have carried stale routing metadata that directed requests through the billing gate.

**Fix:** `opencode auth login` re-authenticated the token. The auth refresh cleared whatever routing metadata was incorrectly filtering requests through the Go billing gate. If that doesn't work, bypass Go entirely with `opencode --model opencode/deepseek-v4-flash-free`.

**Status:** Mitigated. Go routing is still broken per #35149 (OPEN). The `--model` bypass remains the reliable workaround.

---

## Incident 2: Playwright 502 Bad Gateway (Jun 2026)

**Error:** Playwright MCP returns 502 Bad Gateway on any browser operation.

**Root:** Ubuntu 26.04 is not supported by Playwright 1.60.0 browser builds. The Playwright version check rejects any Ubuntu major >= 26 during browser launch.

**Fix:** Patched `playwright-core`'s `coreBundle.js` at line 7749 — changed the version check from `major < 26` to `major < 28`. All browsers were installed via the patched Playwright. Added `--headless` and `--executable-path` to the MCP config.

**Status:** Fixed. Works in headless mode on Ubuntu 26.04.

---

## Incident 3: Sisyphus Attribution in Commits

**Error:** Git commits include `Co-authored-by: Sisyphus` and `Ultraworked with Sisyphus` lines against the user's wishes.

**Root:** The OMO git-master skill dynamically injects section 5.5 (attribution footer) at runtime via `buildCommitFooterInjection()`.

**Fix:** Three-layer defense: (1) a git hook strips attribution from every commit, (2) a config override disables the injection, (3) a dist patch removes the `buildCommitFooterInjection()` function entirely.

**Status:** Fixed. All three layers persist across OMO updates — the hook is update-proof.

---

## Incident 4: OpenCode DB Bloat

**Error:** `opencode.db` reached 3.5 GB with a 339 MB WAL file.

**Root:** Long-running sessions accumulate history. No automatic WAL checkpoint was configured, so the Write-Ahead Log grew unbounded.

**Fix:** Ran `sqlite3 opencode.db "PRAGMA wal_checkpoint(TRUNCATE);"` to checkpoint and trim the WAL. A weekly VACUUM cron job (`0 3 * * 0`) was added to prevent recurrence.

**Status:** Monitored. The WAL grows naturally with use; the weekly VACUUM keeps it under control.

---

## Incident 5: Goal Handler Parsing Bug (Jul 2026)

**Error:** `InvalidObjectiveError: Objective exceeds maximum length of 2000 characters` on any long user message.

**Root:** OMO v4.19.0 `handleGoalMessage()` calls `parseGoalCommand()` with the full user prompt text instead of `/goal` command args. Since `parseGoalCommand`'s default case returns `{ kind: "setObjective", objective: <text> }` for any non-empty string, every user message is treated as a goal command. Messages <2000 chars silently overwrite the goal; >2000 chars crash.

**Fix:** Patched `handleGoalMessage` early return at dist index.js line 160315 — added `|| !pluginConfig.default_mode?.goal` guard. The `/goal` slash command is handled separately in `createCommandExecuteBeforeHandler` (properly uses `input.command` + `input.arguments`), so this doesn't break explicit `/goal` usage.

**Upstream:** Reported at code-yeongyu/oh-my-openagent#6214.

**Status:** Patched downstream. The upstream OMO should honor explicit user agent models regardless of fallback chain availability.

---

## Incident 7: OMO v4.19.0 Dist Build Corruption (Jul 2026)

**Error:** OMO agents not loading at all — TUI shows only native OpenCode agents (build, plan). Plugin fails to load with `SyntaxError`.

**Root:** The published OMO v4.19.0 npm package has multiple build corruption issues in `dist/index.js`:

1. **Template literal corruption**: 1302 lines of garbled markdown/spec text embedded into the `removedCommitFooterInjection` function, causing `SyntaxError: Invalid or unexpected token`
2. **Missing function**: `collectDisabledSkillAliases` is called in 4 places but never defined — the bundler tree-shook it out
3. **Cascading missing functions**: `readOpencodeConfigSkills` and likely more were also dropped

The bundler (esbuild/tsup) aggressively tree-shook internal dependencies, removing functions that are used at runtime. Combined with a template literal that wasn't properly closed, the entire dist is unloadable by Node.js.

**Fix:** Downgraded from OMO v4.19.0 to v4.18.0 which has a clean build. Applied safety patches for model resolution fallback (sisyphus/hephaestus). Cleared corrupted npm cache.

**Upstream:** Should be reported at code-yeongyu/oh-my-openagent — the v4.19.0 build pipeline has a bundler configuration issue.

**Status:** Fixed by version rollback to v4.18.0. Do NOT update to v4.19.x until upstream confirms the build issue is resolved.

**Error:** OpenCode TUI shows only native agents (build, plan) instead of OMO agents (sisyphus, hephaestus, prometheus, atlas). Plugin loads but agents aren't registered in the resolved config.

**Root:** OMO v4.19.0 introduced `AGENT_MODEL_REQUIREMENTS` with `requiresAnyModel: true` for sisyphus and hephaestus. The `maybeCreateSisyphusConfig()` and `maybeCreateHephaestusConfig()` functions call `applyModelResolution()` which returns `undefined` when none of the internal fallback chain models (claude-opus, gpt-5.5, kimi, glm — all premium) are available. This happens with our config where all premium providers are disabled. The explicit agent override in oh-my-openagent.jsonc (`"sisyphus": { "model": "opencode-go/deepseek-v4-flash" }`) was not used as a fallback, causing the agent to be skipped.

**Fix:** Patched `maybeCreateSisyphusConfig()` and `maybeCreateHephaestusConfig()` in the dist to fall back to the user's explicit model override when `applyModelResolution()` returns `undefined`. Atlas already had this fallback. Patch applied to both runtime (`~/.config/opencode/node_modules/`) and npm cache (`~/.cache/opencode/packages/`).

**Status:** Patched downstream. The upstream OMO should honor explicit user agent models regardless of fallback chain availability.

---

## Incident 8: Continuation Injection Loop (Jul 2026)

**Error:** Every user message triggers 'Continue working toward the active thread goal' with <untrusted_objective> HTML-escaped nesting wrapper. The wrapping deepens on each message — `&lt;untrusted_objective&gt;` → `&amp;lt;untrusted_objective&amp;gt;` → `&amp;amp;lt;untrusted_objective&amp;amp;gt;`.

**Root:** OMO has THREE separate continuation injection systems, each independently capable of re-injecting the continuation prompt:

1. **Goal Hook** (`packages/omo-opencode/src/hooks/goal/prompt.ts`): Generates 'Continue working toward the active thread goal' text. Gated by `isHookEnabled('goal') && goal.enabled`.
2. **Todo Continuation Enforcer** (`hooks/todo-continuation-enforcer/`): Generates 'Incomplete tasks remain in your todo list'. Gated ONLY by `disabled_hooks` — has NO `pluginConfig` gate.
3. **Atlas/Boulder Continuation** (`hooks/atlas/`): Generates 'You have an active work plan'. Gated ONLY by `disabled_hooks` — has NO `pluginConfig` gate.

Setting `goal.enabled: false` only disables System 1. Systems 2 and 3 ignore `goal.enabled` — they only check `disabled_hooks`. The nesting happens because `escapeXmlText()` wraps the previous turn's already-escaped output, creating exponential HTML entity encoding on each re-injection.

**Fix:** Added `disabled_hooks: ["goal", "todo-continuation-enforcer", "atlas"]` to oh-my-openagent.jsonc. This is the definitive fix since Systems 2 and 3 only gate on `disabled_hooks`.

**Note:** The OMO codebase has a design flaw here — systems 2 and 3 should also check `goal.enabled` or their own `pluginConfig` gate. Until upstream fixes this, `disabled_hooks` is the only effective control.

**Status:** Fixed via config. The `disabled_hooks` list blocks all three continuation systems.
