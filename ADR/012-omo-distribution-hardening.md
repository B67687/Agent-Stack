# ADR 012: OMO Distribution Hardening

**Status:** Accepted  
**Date:** 2026-07-14  

## Context

oh-my-openagent ships git-master code that injects attribution into every commit:
- `buildCommitFooterInjection` generates "Ultraworked with [Sisyphus]" + "Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>"
- Called from `injectGitMasterConfig` when git_master config options are enabled
- Even with `commit_footer: false` and `include_co_authored_by: false`, the injection code remains in the dist as dead code
- OMO auto-updates (`auto_update: true`) overwrite any surgical dist edits, re-introducing the injection
- The npm cache (`~/.cache/opencode/packages/`) also stores injection strings — any reinstall or upgrade restores them from cache
- GitHub's contributors widget is append-only — once attributed, removal requires repo deletion

## Decision

Multi-layer defense:

1. **Surgical dist removal**: Delete `buildCommitFooterInjection` function and its call site from `injectGitMasterConfig` in the installed OMO dist file
2. **auto_update disabled**: Set `auto_update: false` so updates never overwrite dist edits without explicit action
3. **Git hooks**: Global `commit-msg` hook strips any remaining "Co-authored-by: Sisyphus" or "Ultraworked with" before commit finalization
4. **Git config overrides**: `git_master.commit_footer: false`, `git_master.include_co_authored_by: false`, `commit.gpgsign: true`
5. **npm cache management**: Clear `~/.cache/opencode/packages/` after updates — prevents stale injection strings from being picked up
6. **Post-upgrade verification**: `omo doctor` + attribution scan + regression tests run after every OMO upgrade
7. **Backup before update**: Config backup created before any OMO update, enabling rollback if dist edits are lost

## Consequences

- **Positive:** Zero attribution strings in OMO plugin tree — no risk of GitHub contributor widget pollution
- **Positive:** Defense-in-depth — even if one layer fails, others catch it (git hooks as last line)
- **Positive:** Backup + verify cycle means recoverable if an update overwrites edits
- **Negative:** Manual update process — can't just accept auto-updates without review
- **Negative:** npm cache clearing means longer first-load times after cache clearance
- **Neutral:** Requires re-applying dist edits after each OMO upgrade
