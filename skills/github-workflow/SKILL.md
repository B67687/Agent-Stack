---
name: github-workflow
description: "MUST USE for any repo with the private-scratchpad / public-release split (a `*-Dev` private origin + a `public` remote). Covers the full loop: Dev-first confirmation, work in the local↔private scratch loop, GitHub CI on private, thematic squash of the release delta into signed conventional commits on explicit user go, propagate local→private→public, append-only release. Use before any public push, any 'squash', or any release. Do not use for ordinary single-repo commits (use git-master)."
---

# GitHub Workflow (Local ↔ Private Scratch → Thematic Squash → Public)

> Canonical source: `standards/private-public-push-workflow-standard.md` in the Standards repo. This skill is the operational playbook and must stay consistent with that standard — it may add procedural detail, never contradict.

## When to use

- The repo has TWO remotes: `origin` (private `*-Dev`) and `public` (`*`).
- The user asks to push public, squash, release, publish, or "make it public".

## Dev-First Confirmation Ritual (EVERY session, before any commit)

```bash
git status
git remote -v
git log --oneline -5
```

`origin` MUST point to the `*-Dev.git` repo. If it does not — STOP and report; do not commit.

## The Work Model

Work happens in the **local ↔ private** loop. The private repo is a SCRATCHPAD — commits land there as you work; working cycles accumulate between releases. Nothing about the scratch is precious or kept for its own sake.

**GitHub CI runs on the PRIVATE repo**, validating scratch work as it happens. If CI is unavailable (e.g. Actions minutes exhausted), run the repo's local check instead (e.g. `./scripts/check.sh`).

Release happens ONLY on an explicit user decision that the scratch is good enough. At release: thematically squash the delta since the last release tip, propagate local → private → public. After release, private and public mirror each other — identical content, identical squashed history. No raw history is retained anywhere.

## The Release Loop

1. **Work private only** — all commits to `origin` (private). Never push public unless the user explicitly says go.

   ```bash
   GIT_MASTER=1 GIT_COMMITTER_DATE="$(git log -1 --format=%aD)" git-safe-commit -S -m "<msg>"
   git-safe-push origin main
   ```

2. **On explicit user go** ("ready to publish" / "push public"):
   - Squash thematically the DELTA since the last release tip: one commit per logical unit (`feat:`/`fix:`/`docs:`/`refactor:`/`chore:`), imperative mood, ~50-char subject
   - Verify: `git log --oneline` shows the themed list; `git log --format="%h %G?"` shows `G` on EVERY commit

3. **Propagate local → private → public**:
   - Push the squashed history to private: `git-safe-push origin main`
   - On explicit user go, push public: `git-safe-push public main`

4. **Verify** — public main == private main == local main (same SHA), working tree CLEAN.

5. **Next release**: append the next squash on top. Never rewrite published commits.

## Rules

- **NO attribution ever**: no `Co-authored-by`, no tool footers. The repo owner is the sole author (a global `commit-msg` hook strips these as defense-in-depth).
- **Append-only**: squash only the delta since the last release tip; published commits are NEVER rewritten. Full-history resets are not a routine option.
- **Value judgement**: when to make an appended thematic commit is a session-time decision between the user and the agent — never schedule or force it proactively.
- Public push requires EXPLICIT user go. Never assume; never push raw WIP/history to public.
- Sign every commit (`-S`); verify `%G?` = `G` after any history rewrite.
- Never force-push (`git-safe-push` blocks it by design). CI runs on the PRIVATE repo — do not rely on public CI.
- `.omo/` and other private-only paths never enter the tracked tree.

## One-time reset (delete + re-upload) — NOT routine

For establishing clean history ONCE per repo (e.g. first standardization of a repo that was pushed raw). Executed for Development-Protocol on 2026-08-06 (62 raw → 12 themed). Do not treat as a routine release path:

1. User confirms the private repo is exactly as wanted AND gives explicit go.
2. Delete the public repo on GitHub (`gh repo delete B67687/<Project>` — user must run it; agent permission-denied), recreate empty with the same name.
3. From private HEAD: `git checkout --orphan public-clean`; optionally split the final state into thematic commits; strip private-only paths (e.g. `.omo/`) from every commit.
4. `git push public main` (a fresh repo accepts it as the root commit).
5. Verify tree equality: `git ls-tree` diff shows public tree == private tree, zero private-only paths.
6. Collapse the private repo to the same squashed history so the two repos mirror each other.

## Evidence to report

After any release: public and private SHAs, the themed commit list (hash + subject), signature check output (`%h %G?`), and working-tree state.
