# ADR 011: Auto-Rules System

**Status:** Accepted  
**Date:** 2026-07-14  

## Context

Before auto-rules, per-language standards required manual `load_skills` calls in agent prompts. This meant:

- Agents had to remember which skills to load for each language
- Cross-language rule conflicts were possible (e.g., Python rules loading for a Rust file)
- Skill dispatch was an extra cognitive step every time context switched languages
- Many standards simply didn't get loaded, causing quality drift

Research of top practitioner configs (danielmiessler ~200+ .mdc, nicknisi ~70+ .mdc, matchai ~30+ .mdc) showed that path-globbed .mdc rules were the industry standard for contextual behavior enforcement.

## Decision

Use OpenCode's built-in `.opencode/rules/` directory with `.mdc` files.

Each rule file:

1. Declares YAML frontmatter with `description`, `glob` pattern, and optional `always` flag
2. Auto-activates when an agent opens or edits a file matching its glob pattern
3. `agent-behavior.mdc` has no glob (always active) — agent protocols, verification discipline, guardrails
4. Language-specific rules (rust-workflow, python-workflow, typescript-react, go-workflow) glob on `*.rs`, `*.py`, `*.{ts,tsx}`, `*.go` respectively
5. Cross-cutting rules (git-workflow, config-files) glob on broad patterns or always active

Initial 7 rules deployed:

- `agent-behavior.mdc` — agent protocols, verification requirements, failure handling
- `config-files.mdc` — JSONC conventions, permission patterns, environment variables
- `git-workflow.mdc` — atomic commits, history discipline, rebase safety
- `go-workflow.mdc` — Go idioms, error handling, project structure
- `python-workflow.mdc` — Python conventions, import style, test patterns
- `rust-workflow.mdc` — Rust safety, borrow checker patterns, test discipline
- `typescript-react.mdc` — TypeScript strict mode, React patterns, component structure

## Consequences

- **Positive:** Per-language standards activate automatically — no manual `load_skills` overhead
- **Positive:** Cross-language rule conflicts eliminated — only matching glob patterns fire
- **Positive:** Easy to add new rules — just add a `.mdc` file with the right glob
- **Positive:** Rules are version-controlled alongside the config — visible in git history
- **Negative:** Large rule count increases context load per file edit (mitigated by glob precision)
- **Neutral:** Rules live in `.opencode/rules/` which is gitignored by default — must add explicit negation to .gitignore for sharing
