# Workflow: Process Additions

Nine process-level improvements layered on top of model tuning. Each addresses a failure mode that no model change could fix. See [ADR 007](ADR/007-process-additions.md) for the original decision record.

## 1. Execution Bias

**What:** A prompt-level instruction injected into Sisyphus, Worker, and Review agents via `prompt_append` in `oh-my-openagent.jsonc`.

**How it works:** The instruction states: "Unless the user explicitly asks for a plan, asks a question about the code, or otherwise makes clear they do not want code changes yet, assume they want you to execute. When minor details are unspecified, pick the most plausible interpretation, proceed, and briefly note the assumption. Do not stop at a proposal; implement the fix."

**Why it matters:** Codex 5.5 and Claude Opus 4.6 leaked prompts independently converged on "execute over ask" as their most impactful instruction. It closes a measurable portion of the harness gap with proprietary agents. Without it, agents default to proposing instead of doing.

## 2. Pre-Commit Gate

**What:** A prompt-level instruction telling agents to run LSP diagnostics on every changed file before marking a task complete.

**How it works:** The prompt append directs the agent to call `lsp_diagnostics` on each modified file. If the LSP reports errors, the agent must fix them before proceeding. It is not a hard hook (the agent can skip it), but compliance is reinforced by the ralph loop doing post-fix verification.

**Why it matters:** Catches type errors, missing imports, and undefined symbols before they compound into later failures. A single missing import can cascade into 10 minutes of debugging.

## 3. Project Memory

**What:** Session-boundary context persistence via `.omo/project-context.md`.

**How it works:** The Sisyphus prompt_append instructs: "At session start, read `.omo/project-context.md` if it exists. At session end, update it with any new architectural decisions, patterns discovered, or configuration changes." The file is a living document that accumulates cross-session knowledge.

**Why it matters:** Prevents re-exploration across sessions. Without it, every fresh session starts from zero — no memory of past decisions, discovered patterns, or known pitfalls.

## 4. ADR Records

**What:** The Architect command template saves Architecture Decision Records to `.omo/adr/<slug>.md` after each decision.

**How it works:** The `architect` command (`opencode.jsonc` commands section) includes a template that tells the agent: "After each decision, save an ADR to `.omo/adr/<slug>.md` with context, decision, consequences, and alternatives considered." The standard template matches the format already used in `./ADR/`. Reduced to 20 in ADR-009.

**Why it matters:** Architectural decisions become searchable, reviewable artifacts. Six months later, "why did we do X" has a written answer instead of requiring reverse engineering from commit history.

## 5. Goal Mode (Default Mode)

**What:** The agent's default operating mode is `goal`, a goal-driven continuation loop with up to 20 iterations.

**How it works:** When configured with `goal: {enabled: true, default_max_iterations: 20}`, the agent automatically continues working toward the stated goal after completing each action. It only stops when it decides the goal is met, hits the iteration limit, or the user intervenes.

**Why it matters:** The ralph loop (the predecessor) was renamed to goal mode to clarify intent: the agent drives toward explicit completion criteria rather than self-perpetuating. The 20-iteration ceiling (down from 200) stops promptly when tasks complete while still allowing multi-phase workflows to converge.

## 6. Daily Backup Cron

**What:** A cron job at 2 AM daily running `~/.local/share/opencode/scripts/backup-config.sh`.

**How it works:** The script copies `opencode.jsonc`, `oh-my-openagent.jsonc`, `tui.json`, and `dcp.jsonc` (if present) to `~/.config/opencode/backups/` with a `YYYYMMDD-` prefix. It prunes backups older than 30 days by file modification time.

**Why it matters:** Config files are the product of weeks of tuning. A single bad edit or OMO update can wipe overrides. The backup gives a 30-day recovery window with zero operational cost.

## 7. Health Check Script

**What:** `~/.local/share/opencode/scripts/health-check.sh` - a standalone diagnostic with 7 checks (binary, plugin dir, config readability, disk, omo doctor, git state).

**How it works:** Validates in order:

1. OpenCode binary - exists in PATH and returns version
2. OMO plugin config directory - exists at XDG_CONFIG_HOME/opencode
3. Config file readability - both opencode.jsonc and oh-my-openagent.jsonc are present and readable
4. Disk space - home directory usage (informational warning at 90%)
5. OMO config load - `omo doctor --verbose` confirms configs parse and load correctly
6. Git repo state - config files have no uncommitted changes

Each check outputs PASS, WARN, or FAIL with an exit code equal to the failure count.

**Why it matters:** When a session breaks, this script rules out the common causes in 2 seconds. Without it, debugging a broken config can take 15 minutes of manual checks. Serves as the first step in any incident response.

## 8. Auto-Rules System

**What:** Seven `.mdc` rule files in `.opencode/rules/` that auto-activate by path glob pattern, eliminating manual `load_skills` calls for per-language standards.

**How it works:** Each rule file declares a `glob` field matching file paths (e.g., `*.ts` for TypeScript rules, `*.py` for Python). When an agent opens or edits a matching file, the corresponding rules load automatically into context. No prompt-level `load_skills`, no manual injection — the path decides which standards apply.

**Why it matters:** Removes the overhead of remembering which rules cover which languages. A Python file triggers Python conventions; a Go file triggers Go idioms. The agent gets the right guardrails without thinking about it. Also prevents cross-language rule conflicts, since each file only loads rules matching its extension.

## 9. Context-Mode Tooling

**What:** A family of `ctx_*` tools — `ctx_search`, `ctx_index`, `ctx_fetch_and_index` — that give sisyphus, librarian, and general agents persistent memory across sessions and the ability to ingest web documentation.

**How it works:** `ctx_search` queries a persistent FTS5 index spanning all past indexed content, returning relevant snippets. `ctx_index` stores new knowledge into that index. `ctx_fetch_and_index` fetches web pages and indexes them in one step. Together they form a long-term memory that survives `/clear`, compaction, and session boundaries.

**Why it matters:** Before context-mode, every fresh session started from zero — no recall of past decisions, no searchable knowledge base. Now agents can retrieve previous architectural choices without re-exploration, search ingested docs in one call, and capture web API pages as structured index entries. The memory gap that forced redundant exploration across sessions is closed.
