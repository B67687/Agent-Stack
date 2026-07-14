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
