# ADR 006: Attribution Defense Strategy

**Status:** Accepted  
**Date:** 2026-07-03  

## Context

OMO's git-master skill dynamically injects section 5.5 "Commit Footer & Co-Author" whenever the skill is loaded. This adds `Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>` and `Ultraworked with [Sisyphus](...)` to every commit message. For solo development where only the repo owner should appear in commit metadata, this is unwanted.

The injection occurs in OMO's compiled `dist/index.js` at the `skill(name='git-master')` call site via `buildCommitFooterInjection()`. The injector has three call sites and defaults `commit_footer: true`, `include_co_authored_by: true` in its config schema.

## Decision

Deploy three defense layers:

1. **Git hook** (`~/.config/git/ai-commit-hooks/commit-msg`) — strips `Co-authored-by: Sisyphus`, `Ultraworked with`, and `Signed-off-by: Sisyphus` from every commit message at the git level. Survives OMO updates.
2. **Config override** (`oh-my-openagent.jsonc`):
   ```jsonc
   "git_master": { "commit_footer": false, "include_co_authored_by": false }
   ```
3. **Dist patch** (optional) — directly removed the injection function from `dist/index.js`. Overwritten on OMO update.

SKILL.md also strengthened with an explicit "CRITICAL CONSTRAINT — NO Attribution" section as an absolute-rule override.

## Consequences

- **Positive:** Zero Sisyphus attribution in any commit, regardless of OMO version or hook state.
- **Positive:** Git hook is the most robust layer — cannot be bypassed by OMO updates or config reloads.
- **Negative:** Three layers adds maintenance surface. If a future OMO update changes the injection mechanism, the config override may need updating.
- **Neutral:** Attribution defense is invisible during normal work — only matters when committing.
