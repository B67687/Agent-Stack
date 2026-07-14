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
**Check:** Ralph loop hitting `max_iterations` (set to 20 — reduced from 200 for faster stop). Intermittent stops = DeepSeek tool-calling bug (~10-20%).
**Fix:** Restart session. If needed, increase `ralph_loop.max_iterations` in oh-my-openagent.jsonc.

### 4. Playwright Fails

**Problem:** 502 errors or browser crashes.
**Check:** Playwright vs OS compatibility (26.04 needs patched >1.60.0). `--headless` and `--executable-path` in MCP config.
**Fix:** Reinstall browsers with patched Playwright. See INCIDENTS.md Incident 2.

### 5. DB Growing Too Large

**Problem:** `opencode.db` takes gigabytes.
**Check:** Weekly VACUUM cron at `0 3 * * 0` — verify with `crontab -l`.
**Fix:** Manual: `sqlite3 ~/.local/share/opencode/opencode.db "VACUUM;"`. WAL: add `PRAGMA wal_checkpoint(TRUNCATE);`.
