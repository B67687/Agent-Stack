# Troubleshooting

Quick reference for common OpenCode + OMO issues.

---

### 1. Insufficient Balance

**Problem:** "Insufficient balance" errors.
**Check:** `opencode models` to verify auth token.
**Fix:** `opencode auth login` to refresh. Fallback: `opencode --model opencode/mimo-v2.5-free`. (2026-08-25: deepseek-v4-flash-free does not exist; replaced with mimo-v2.5-free)

### 2. Config Not Loading

**Problem:** OpenCode ignores your config file.
**Check:** Brace balance, trailing commas. `opencode` CLI validates on startup.
**Fix:** Fix syntax flagged by CLI validator. Restart.

### 3. Agent Stops Mid-Session

**Problem:** Agent exits unexpectedly.
**Check:** Intermittent stops = DeepSeek tool-calling bug (~10-20%). (The goal-hook iteration cap is DORMANT since 2026-08-03 — `goal.enabled: false`;
`default_max_iterations` is inert.)

### 4. Playwright Fails

**Problem:** 502 errors or browser crashes.
**Check:** Playwright vs OS compatibility (26.04 needs patched >1.60.0). MCP config runs `--headless` only (`--executable-path` dropped for portability).
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
**Check:** Goal Mode requires `goal: {enabled: true, default_max_iterations: 20}` (v4.18.0+ format). **NOTE (2026-08-03, updated 2026-08-04): the goal hook is currently DISABLED** (`goal.enabled: false` only — `"goal"` was removed from `disabled_hooks` 2026-08-04, but the hook stays inert because it is double-gated on `goal.enabled`) — re-enabling it makes every user message set the session objective and crashes on messages >2000 chars (see INCIDENTS.md).
**Fix:** Update config to the new Goals format. Old Ralph Loop configs auto-migrate but produce deprecation warnings.

> **Known issue (v4.19.0 only):** the old `mode: "ralph"` format was removed in OMO v4.19.0. This stack is pinned to 4.19.4 (opencode.jsonc plugin list + tui.json) — the ralph→goal migration has already happened and Goal Mode is DORMANT (`goal.enabled: false`). Old Ralph Loop configs auto-migrate to Goal Mode with deprecation warnings.

---

### 8. Infinite Continuation Injection Loop

**Problem:** Every user message triggers 'Continue working toward the active thread goal' with <untrusted_objective> wrapper, nesting deeper each time.
**Root:** Three separate continuation systems exist in OMO — (1) Goal Hook (gated by `goal.enabled`), (2) Todo Continuation Enforcer (no pluginConfig gate, only `disabled_hooks`), (3) Atlas/Boulder Continuation (no pluginConfig gate, only `disabled_hooks`). Setting `goal.enabled: false` only disables System 1. Systems 2-3 have no pluginConfig gate.
**Fix:** Add `disabled_hooks: ["goal", "todo-continuation-enforcer", "atlas"]` to `~/.omo/omo.jsonc`. This is the ONLY way to disable all three continuation systems since Systems 2 and 3 only check `disabled_hooks`. (Current config truth 2026-08-04: `disabled_hooks = ["todo-continuation-enforcer", "keyword-detector"]` — goal + compaction-context-injector re-armed 2026-08-04 after upstream verification: goal is double-gated by `goal.enabled: false` so it stays inert despite being removed from the list (4.19.2 fixed the native-command provenance bug, PR #6315); compaction-context-injector is bug-free and orthogonal to `preemptive-compaction` (separate live hook). todo-continuation-enforcer + keyword-detector stay disabled: no 4.19.x fixes landed and #5806 (ulw persistence) is unresolved.)

### 9. Silent Retry Loop (WAL Bloat / 100% CPU)

**Problem:** Agent appears hung — process at ~100% CPU, no fresh log lines, SQLite WAL grows unbounded (healthy is KB; >100-200MB = unbounded writer). Root cause: a provider error (e.g. `AI_APICallError: Internal Server Error` on opencode-go) enters a silent retry loop with no backoff, no log output, no stop-and-report.

**Check:**

```bash
pgrep -af opencode            # find the looping PID (high CPU, stale log mtime)
du -h ~/.local/share/opencode/opencode.db-wal   # WAL size — the tell
```

**Fix (kill + recover):**

```bash
kill <PID>                    # kill the runaway process immediately
sqlite3 ~/.local/share/opencode/opencode.db 'PRAGMA wal_checkpoint(TRUNCATE);'
# then optionally: VACUUM;  (frees deleted-page space)
```

**Prevention:** `scripts/health-check.sh` check 5.7 alerts when WAL >200MB (unhealthy) or >100MB (degraded). Guardrails (2026-08-03 state): `runtime_fallback.retry_on_errors` includes 500 so provider errors (AI_APICallError) engage fallback instead of silent retry; keyword-detector hook disabled (no ultrawork expansion); goal hook DISABLED (was re-enabled 2026-08-03 as a cap but caused InvalidObjectiveError on long messages — reverted; the cap would not have caught the ultrawork loop anyway since it hardcodes `max_iterations: undefined`). Never kill without checkpointing — WAL holds committed-but-uncheckpointed data.

### 10. Coreutils (uutils → GNU 9.7 swap, 2026-08-03)

**Problem:** `/usr/bin/timeout` and the rest of the coreutils set were symlinked to Rust uutils 0.8.0 (multi-call binary). uutils `timeout` aborted with SIGABRT (observed 14:43 during incident remediation), and the whole plain-name set was unmanaged.

**Fix (applied 2026-08-03):** `sudo apt-get install --allow-remove-essential gnu-coreutils coreutils-from-gnu rust-coreutils- coreutils-from-uutils-` — removed `rust-coreutils` + `coreutils-from-uutils` + `build-essential` (metapackage only; gcc/g++/make binaries untouched), installed `gnu-coreutils` (9.7, 104 `gnu*`-prefixed binaries) + `coreutils-from-gnu` (plain-name symlinks → GNU). Verified: `timeout/ls/cat --version` = GNU coreutils 9.7.

**Rollback:** re-point symlinks from `~/.cache/tmp/opencode/coreutils-stage/symlink-snapshot-20260803.txt` (symlink snapshot saved pre-swap) or `sudo apt-get install rust-coreutils coreutils-from-uutils`.
