# Config Map: OpenCode + OMO

Exhaustive reference for every non-default setting across `opencode.jsonc` and `oh-my-openagent.jsonc`. Settings are grouped by concern. The DRY split puts agent identity in the main file and model tiering in the OMO overrides (see [ADR 001](ADR/001-dry-split.md)).

## Permission

| Setting                                 | Value   | Rationale                                                                        |
| --------------------------------------- | ------- | -------------------------------------------------------------------------------- |
| `read/write/edit: **/.env`              | `deny`  | Secrets containment — env files, credentials, pem keys, SSH private keys blocked |
| `bash: sudo *`, `rm -rf *`, `chown *`   | `deny`  | Destructive shell operations unconditionally blocked                             |
| `bash: git/npm/npx/node/python3/uv/rtk` | `allow` | Allowlisted common tool prefixes                                                 |
| `websearch, webfetch, skill, lsp`       | `allow` | Read-only tools with no destructive potential                                    |
| `playwright_*`                          | `ask`   | Interactive browser — confirm before each use                                    |
| `external_directory: ~/projects/**`     | `allow` | Agent can write to user project directories                                      |
| `doom_loop`                             | `deny`  | Prevents infinite tool-call loops                                                |

## Provider

| Setting                             | Value                            | Rationale                                                                        |
| ----------------------------------- | -------------------------------- | -------------------------------------------------------------------------------- |
| `provider.deepseek.options.baseURL` | `https://api.deepseek.com/v1`    | Direct DeepSeek API — lower latency than routing through OpenAI-compatible proxy |
|                                     | `model` (default)                | `opencode-go/deepseek-v4-flash`                                                  | Go-tier subscription; 79% SWE-bench at $0.024/task                              |
|                                     | `subagent_depth`                 | **3**                                                                            | Preemptive — needed for OpenCode v1.18.x where subagent nesting defaults to off |
| `disabled_providers`                | `openai, anthropic, google, xai` | Prevents accidental premium API usage                                            |

## Background Task

| Setting              | Current                         | Default | Why                                                   |
| -------------------- | ------------------------------- | ------- | ----------------------------------------------------- |
| `concurrency`        | **15**                          | 5       | More parallel subagents for multi-agent orchestration |
| `maxToolCalls`       | **1000**                        | ~100    | Prevents subagent loops from being killed mid-work    |
| `staleTimeoutMs`     | **300000** (5 min)              | 300000  | Reverted from 900000 — fast failure detection         |
| Provider concurrency | deepseek:3, opencode-go:10      | —       | Provider-specific caps prevent rate limiting          |
| Model concurrency    | flash:10, flash-free:5, mimo:10 | —       | Per-model caps for the 3 model families               |

## Performance

| Setting                   | Value                                                                                                                                                  | Rationale                                                                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `compaction.auto`         | `true`                                                                                                                                                 | Auto-compress context when it grows large                                                                                                          |
| `compaction.prune`        | `true`                                                                                                                                                 | Drop low-value tool outputs during compression                                                                                                     |
| `compaction.reserved`     | 15000                                                                                                                                                  | Reserve 15k tokens for essential context after compaction (raised from 5k after LANDSCAPE audit — was causing agents to run out of working memory) |
| MCP servers               | sequential-thinking, searxng, playwright                                                                                                               | 3 MCPs for reasoning, search, and browser automation                                                                                               |
| `dynamic_context_pruning` | `{enabled: true, notification: detailed, turn_protection: {turns: 10, protected_tools: [bash, edit, write, read, lsp_diagnostics, task, glob, grep]}}` | Context-mode: auto-index tool outputs, retain 10 turns of context before pruning, 7 protected tools always preserved                               |

## Babysitting / DCP

| Setting                                                   | Value              | Rationale                                                                                                             |
| --------------------------------------------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `babysitting.timeout_ms`                                  | **180000** (3 min) | Subagent timeout — longer than 60s default for complex multi-step tasks                                               |
| `dynamic_context_pruning.enabled`                         | `true`             | Auto-prune stale tool outputs — keeps context window fresh                                                            |
| `dynamic_context_pruning.turn_protection.turns`           | **5**              | Default is 3 — we do many turns so prune less aggressively                                                            |
| `dynamic_context_pruning.turn_protection.protected_tools` | 7 tools            | task, todowrite, todoread, lsp_rename, session_read, session_write, session_search — never prune critical tool traces |

## Context-Mode Tooling

| Setting            | Value                                               | Rationale                                                                                                        |
| ------------------ | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Plugin             | `@tarquinen/opencode-dcp@latest`                    | Dynamic Context Protocol — 11 `ctx_*` tools for indexed context management                                       |
| Wired agents       | sisyphus, librarian, general                        | prompt_append instructions for context-mode tools in oh-my-openagent.jsonc                                       |
| Key tools          | `ctx_search`, `ctx_index`, `ctx_fetch_and_index`    | Search project memory, store findings, ingest web docs into FTS5 searchable index                                |
| Workflow           | search before ask, batch queries, sandbox execution | `ctx_search(sort: "timeline")` on resume; `ctx_batch_execute` for bulk; `ctx_execute(js)` for portable filtering |
| Blocked/Redirected | `curl`, `wget`, inline HTTP                         | Intercepted and redirected to ctx equivalents — prevents raw HTML flooding context                               |

## Mode

| Setting                         | Value  | Rationale                                                              |
| ------------------------------- | ------ | ---------------------------------------------------------------------- |
| `default_mode`                  | `goal` | Goal-driven execution — works toward explicit completion criteria      |
| `default_max_iterations` (goal) | **20** | Reduced from 200 — stops promptly when task done, no wasted iterations |
| `doom_loop`                     | `deny` | Safety valve — goal mode does not bypass the doom loop detector        |

## Auto-Rules

| Setting    | Value                                                                                                     | Rationale                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Directory  | `.opencode/rules/`                                                                                        | 7 `.mdc` files auto-activate based on glob-patterned triggers                                     |
| Files      | agent-behavior, config-files, git-workflow, go-workflow, python-workflow, rust-workflow, typescript-react | One rule per domain — agent protocols, config conventions, git discipline, per-language standards |
| Activation | Glob-patterned file matching                                                                              | agent-behavior always fires; language rules activate when editing matching file types             |
| Purpose    | Contextual behavior enforcement                                                                           | Separates standards from prompts — .mdc rules fire only when relevant, keeping agent prompts lean |

## Experimental Features

| Setting                     | Value             | Rationale                                                                      |
| --------------------------- | ----------------- | ------------------------------------------------------------------------------ |
| `disable_omo_env`           | `true`            | Prevents OMO from injecting env vars into agents                               |
| `task_system`               | `true`            | File-based todo persistence — survives crashes                                 |
| `aggressive_truncation`     | `false` (removed) | Default — removed as unnecessary explicit override                             |
| `preemptive_compaction`     | `true`            | Compacts at 85% context before hitting hard limit                              |
| `truncate_all_tool_outputs` | `false`           | Context budget management via DCP — full tool outputs available for inspection |
| `safe_hook_creation`        | `true`            | One hook failure won't crash the plugin                                        |

## OMO Features

| Setting                               | Value                                                   | Rationale                                                                                       |
| ------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `team_mode.enabled`                   | `true`                                                  | Enables parallel subagent orchestration                                                         |
| `agent_order`                         | `[hephaestus, sisyphus, prometheus, atlas]`             | Tab-cycling priority — most-used first                                                          |
| `git_master.commit_footer`            | `false`                                                 | Attribution defense — prevents Co-authored-by injection                                         |
| `git_master.include_co_authored_by`   | `false`                                                 | Same defense, additional injection path                                                         |
| `keyword_detector.enabled_expansions` | `["ultrawork"]`                                         | Type "ultrawork" to auto-activate mode                                                          |
| `model_fallback`                      | `true`                                                  | Proactive fallback at chat params level                                                         |
| `auto_update`                         | `false`                                                 | Disabled — prevents OMO auto-updates from overwriting surgical dist edits (attribution removal) |
| `telemetry`                           | `false`                                                 | Opt out of anonymous telemetry                                                                  |
| `hashline_edit`                       | `true`                                                  | Use Line#ID edit format for precise, safe modifications                                         |
| `comment_checker`                     | `{}`                                                    | Enable comment-checker validation                                                               |
| `runtime_fallback`                    | freeze detection, retry 400/429/503/529, max 3 attempts | Comprehensive error recovery                                                                    |

## Scripts

| Script                 | Purpose                                                                         | Added      |
| ---------------------- | ------------------------------------------------------------------------------- | ---------- |
| `redact-config.sh`     | Auto-redact personal paths for public publishing                                | Initial    |
| `regression-test.sh`   | 32 regression tests — config validity, attribution defense, model containment   | 2026-07-08 |
| `cost-report.sh`       | Session cost tracking from SQLite DB                                            | 2026-07-08 |
| `model-verifier.sh`    | Validate configured models against available model pool                         | 2026-07-08 |
| `post-agent-log.sh`    | XDG-compliant structured audit logger per agent session                         | 2026-07-10 |
| `pre-commit-verify.sh` | Config file sanity validation before git commit                                 | 2026-07-10 |
| `health-check.sh`      | OpenCode/OMO agent environment health check                                     | 2026-07-10 |
| `verify.sh`            | Unified suite runner — health-check + pre-commit + omo doctor + regression-test | 2026-07-14 |
| `check-updates.sh`     | Release update tracker — checks OMO and OpenCode GitHub releases every 2 days   | 2026-07-17 |

## Agent Defaults (Steps & Modes)

| Agent     | Mode     | Steps   | Notes                                                                                                                               |
| --------- | -------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Sisyphus  | primary  | default | Main orchestrator. prompt_append carries Clarification Protocol + Verification + Pre-Commit + Project Memory + Context-Mode Tooling |
| Build     | primary  | 40      | Full-access build agent with sequential-thinking permission                                                                         |
| Worker    | subagent | 30      | Fresh-context implementation lane. Edit requires `ask` permission                                                                   |
| Plan      | subagent | 15      | Planning only. Edit and bash are denied                                                                                             |
| Review    | subagent | 15      | Code review only. Edit denied                                                                                                       |
| Architect | subagent | 15      | Full delegation tree, saves ADRs after decisions                                                                                    |
| Scout     | subagent | 10      | Read-only dependency research. Edit denied                                                                                          |

## Agent prompt_append Inventory

| Agent           | prompt_append Contains                                                                      | Purpose                                                                                   |
| --------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Sisyphus        | Clarification Protocol, Verification, Pre-Commit Gate, Project Memory, Context-Mode Tooling | Full orchestrator discipline — clarify before coding, verify after edits, persist context |
| Worker          | lsp_diagnostics after every edit, max 30 calls, report partial on stuck                     | Leaf executor safety rails                                                                |
| Review          | Code reviewer — bugs, regressions, security, tests, ordered by severity                     | Review mode role enforcement                                                              |
| Test-Writer     | Test specialist — happy paths, edge cases, failure modes, Given/When/Then                   | Test-only behavior isolation                                                              |
| Hephaestus      | Verification: lsp_diagnostics after every edit                                              | Build/forge safety gate                                                                   |
| Prometheus      | Verification: check constraints, scope, edge cases before plan presentation                 | Planning quality gate                                                                     |
| Atlas           | Verification: check delegated results before marking done                                   | Research synthesis check                                                                  |
| Oracle          | Read-only consultation — analyze and explain, no code edits                                 | Strict evaluation role                                                                    |
| Scout           | External research — clone repos, inspect source, read-only, no edits                        | Isolation enforcement                                                                     |
| General         | Research before coding, use context-mode tools                                              | Context-aware generalist                                                                  |
| Librarian       | Use MCP tools (context7, codegraph), context-mode for research                              | Codebase reference researcher                                                             |
| Metis           | Pre-planning — identify hidden intentions, ambiguities, AI failure points                   | Intent clarification                                                                      |
| Momus           | Plan critic — adversarial review of plans and implementations                               | Quality adversarial check                                                                 |
| Sisyphus-Junior | Follow precisely, no delegation, verify after each step, stop after 3 stuck attempts        | Leaf executor discipline                                                                  |

5 categories (visual-engineering, deep, quick, writing, git) also carry prompt_append for domain-specific behavior.

## Model Tiering (oh-my-openagent.jsonc)

| Tier       | Model                             | Agents                                                           | Reasoning                                                   |
| ---------- | --------------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------- |
| Go         | `opencode-go/deepseek-v4-flash`   | Sisyphus, Architect, Oracle, Prometheus, Hephaestus, Plan, Build | `max` — critical path reasoning quality                     |
| Go         | `opencode-go/deepseek-v4-flash`   | Test-Writer                                                      | `high` — moderate reasoning for test edge cases             |
| Go         | `opencode-go/deepseek-v4-flash`   | Atlas, Worker, Review                                            | `low` — leaf executors, code review, systematic exploration |
| Free Flash | `opencode/deepseek-v4-flash-free` | Sisyphus-Junior, Librarian, Metis, Momus, Writing, Git           | `high` on writing for prose quality; default on others      |
| Free MiMo  | `opencode/mimo-v2.5-free`         | Explore, Multimodal-looker, General, Scout                       | `none` or unset — cheapest model for cheap tasks            |

## V1 Optimization Changes

| Change                      | Old Value        | New Value | Rationale                                                     |
| --------------------------- | ---------------- | --------- | ------------------------------------------------------------- |
| build reasoningEffort       | high             | max       | Build orchestration needs full reasoning for multi-step tasks |
| plan reasoningEffort        | high             | max       | Plan decomposition benefits from full chain-of-thought        |
| sisyphus reasoningEffort    | (removed on 7/9) | max       | Re-added — orchestrator delegation decisions need reasoning   |
| atlas reasoningEffort       | (none)           | low       | Systematic exploration benefits from minimal reasoning        |
| artistry reasoningEffort    | max              | high      | Creative work doesn't need max reasoning — cost saving        |
| writing reasoningEffort     | max              | high      | Prose quality doesn't need max reasoning — cost saving        |
| worker reasoningEffort      | (none)           | low       | Leaf executor — sufficient for following instructions         |
| review reasoningEffort      | (none)           | low       | Code review is verification, not discovery                    |
| test-writer reasoningEffort | (none)           | high      | Test generation needs moderate reasoning for edge cases       |

## Thinking Mode

| Agent         | Budget     | Rationale                                                       |
| ------------- | ---------- | --------------------------------------------------------------- |
| Oracle        | 8k tokens  | Single-turn deep analysis — benefits most from chain-of-thought |
| Architect     | 16k tokens | Complex architecture design needs longer reasoning paths        |
| Sisyphus      | disabled   | Orchestrator makes tool calls; thinking wastes tokens           |
| Worker/Review | disabled   | Simple execution tasks don't benefit from CoT                   |

## Omitted Features (Skip Decision)

| Feature                | Reason                                                            |
| ---------------------- | ----------------------------------------------------------------- |
| `monitor`              | Context cost + security surface don't justify for solo dev        |
| `mcp-server-fetch`     | Redundant with OMO's built-in webfetch + websearch                |
| `caveman` prompting    | 8-15% savings not worth quality risk on architecture work         |
| `hyper-sisyphus` agent | Discontinued self-improvement loop; skill files preserved locally |

## LSP Server Installations

OpenCode auto-detects installed language servers. Installed via `npm install -g` or platform package manager. All servers are lazy-loaded (zero overhead until a matching file is opened).

| Language      | LSP Server                                                             | Installed | Source         |
| ------------- | ---------------------------------------------------------------------- | --------- | -------------- |
| TypeScript/JS | `typescript-language-server` + `eslint` + `biome`                      | ✅        | npm            |
| HTML          | `vscode-html-language-server` (via `vscode-langservers-extracted`)     | ✅        | npm            |
| CSS           | `vscode-css-language-server` (via `vscode-langservers-extracted`)      | ✅        | npm            |
| Rust          | `rust-analyzer`                                                        | ✅        | rustup         |
| Go            | `gopls`                                                                | ✅        | go install     |
| Zig           | `zls`                                                                  | ✅        | GitHub release |
| Python        | `pyright` + `ty` + `ruff`                                              | ✅        | pip/npm        |
| C/C++         | `clangd`                                                               | ✅        | apt            |
| Lua           | `lua-language-server`                                                  | ✅        | GitHub release |
| Bash          | `bash-language-server`                                                 | ✅        | npm            |
| YAML          | `yaml-language-server`                                                 | ✅        | npm            |
| Docker        | `dockerfile-language-server-nodejs`                                    | ✅        | npm            |
| JSON/JSONC    | `biome` (built-in)                                                     | ✅        | npm/OpenCode   |
| Markdown      | `vscode-markdown-language-server` (via `vscode-langservers-extracted`) | ✅        | npm            |

**Not installed** (not commonly used): Java (jdtls, needs JVM), Kotlin (kotlin-language-server, manual install), Ruby (ruby-lsp), PHP (intelephense), Dart (dart language-server SDK).
