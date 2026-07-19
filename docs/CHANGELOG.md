## 2026-07-20 — v1.3

### LSP Infrastructure

- **19 LSPs installed** (up from 15): added kotlin-ls, texlab, jdtls (Java), csharp-ls
- **TypeScript 7 native LSP**: resolve-ts-lsp proxy detects TS version, dispatches to Go binary directly, fixes `initialized` notification bug (TS7 Go LSP requires `"params":{}` on `initialized`)
- **zls + jdtls + lua-ls fixes**: same `initialized` patch for zls, Java 21 wrapper for jdtls, working directory fix for lua-ls
- **LSP config file**: created `lsp.json` — daemon reads from separate config (not `opencode.jsonc`)
- **LSP daemon config discovery documented**: `LSP_TOOLS_MCP_PARAAM_CONFIG` + `LSP_TOOLS_MCP_USER_CONFIG` env vars

### OMO Model Routing

- **Diversified models** across 18 agents + 9 categories
- Flash + MiMo V2.5 handle high-volume agents (sisyphus, hephaestus, worker)
- MiniMax M3, Qwen3.7 Plus, DeepSeek V4 Pro for specialized agents
- **3 tiers**: Go high-rate (31k/5hr) → Go medium (3-4k/5hr) → Zen free
- Model concurrency settings expanded to cover all Go-tier models

### Config & Documentation

- ADR 013: TypeScript 7 Native LSP Migration
- ADR 014: LSP Infrastructure Expansion
- `check-updates.sh`: 72h cooldown policy (throttle + release-age gate)
- Config audit: removed dead `lsp` server section from `opencode.jsonc`, split oversized agent prompts (build: 4298→350 chars, architect: 3431→200 chars) into 3 `.mdc` rule files
- AGENTS.md updated to reflect new model routing across all tiers
- Atlas removed from `disabled_hooks` (can now auto-start)

### Testing

- **32 regression tests** (up from 27): 4 new tests (LSP structure, wrapper scripts, model concurrency, disabled providers)
- JSONC validation with proper parser (catches trailing commas, brace mismatches)
- Pre-commit-verify.sh enhanced with JSONC + lsp.json validation
- Fixed stale test values (DCP turns 3→5, model allowlist expanded to 7 families)

### ADRs

- **013**: TypeScript 7 Native LSP — Go binary dispatch, initialized notification fix, config location
- **014**: LSP Infrastructure Expansion — 4 new installs, 2 fixes, daemon config discovery

- **Incident 8 fix**: Continuation injection loop (endless 'Continue working toward the active thread goal' spam with nesting <untrusted_objective> wrappers). Root cause: OMO has THREE separate continuation systems — Goal Hook (gated by goal.enabled), Todo Continuation Enforcer (gated ONLY by disabled_hooks), Atlas/Boulder (gated ONLY by disabled_hooks). `goal.enabled: false` only disabled one of three. Fix: added `disabled_hooks: ["goal", "todo-continuation-enforcer", "atlas"]` to oh-my-openagent.jsonc. Docs/TROUBLESHOOTING.md and Docs/INCIDENTS.md updated.

# Changelog

## 2026-07-19

- **Incident 6 fix**: OMO agents (sisyphus, hephaestus) not loading on startup because v4.19.0 `AGENT_MODEL_REQUIREMENTS` blocks agents when no premium fallback models available. Patched dist to use explicit model override when model resolution fails. Docs/INCIDENTS.md updated.

## 2026-07-19

- **Incident 7**: OMO v4.19.0 dist build corruption (1302 lines garbled, missing functions). Downgraded to v4.18.0. Applied model resolution fallback patches.
- **Incident 6 fix**: OMO agents (sisyphus, hephaestus) not loading because model resolution fails when premium fallback models unavailable. Patched dist to use explicit model override. (Applied to v4.18.0)

## 2026-07-17

- **Release tracker**: `.github/workflows/check-updates.yml` + `scripts/check-updates.sh` — checks OMO and OpenCode GitHub releases every 2 days, creates issues on updates
- **Prometheus model fixed**: was missing from `agents` section → defaulting to claude-opus-4-7. Now explicit `opencode-go/deepseek-v4-flash`
- **PRODUCTION_QUALITY.md**: OSS benchmark quality reference (35 projects) added to docs/
- **VERSIONS.md**: tracked versions file for release update checker
- **README restructured**: removed "What's New" (moved to CHANGELOG), License → bottom, fixed code fence, added .github/ and .opencode/rules/ to tree
- **LSP coverage 5→14**: installed typescript-language-server, vscode-langservers-extracted (HTML/CSS/ESLint), bash-language-server, yaml-language-server, zls, clangd, gopls, lua-language-server, dockerfile-language-server-keyword, html-validate
- **Workflow integration docs**: WORKFLOW_INTEGRATION.md (Dev Protocol + start-work combined flow)
- **LANDSCAPE audit + 8 config fixes**:
  - `truncate_all_tool_outputs: false` — agents retain full tool context
  - `compaction.reserved: 15000` — agents keep enough working memory after compaction
  - `showCompression: true` — visibility into context pruning
  - DCP/OMO turn protection aligned to 5 turns
  - `babysitting.timeout_ms: 180000` — complex subagents not killed prematurely
  - `MaxSessions 5` — SSH sufficient for VSCode multi-session
  - `GatewayPorts no` — VSCode port forwards bound to localhost only
  - `patch-attribution.sh` dynamic Node path (no longer hardcoded version)

## 2026-07-18

- **Preemptive subagent_depth added**: `subagent_depth: 3` to opencode.jsonc (inactive on v1.17.20, needed for v1.18.x where subagent nesting defaults to off)
- **Innovations research**: INNOVATIONS_2026_H2.md — 5 notable agent harness innovations (Shofer, Juggler, MCP stateless, bbarit-oss, Orca)
- **Full-stack LANDSCAPE audit**: 5 parallel audit lanes across LSP/tools, runtime behavior, infrastructure, VSCode, and process quality
- **8 config fixes applied**: truncation, compaction, DCP, babysitting, SSH hardening, etc.
- **Config audit (v2)**: 6-point audit — subagent_depth added, shared/ prefix clean, DeepSeek aliases clean, OpenRouter noted (45% savings), Ralph Loop clean, OMO v4.16.1 vs README v4.18.2 discrepancy
- **Landscape refresh research**: `research/2026-07-18-landscape-refresh.md` — audit findings, OpenRouter recommendation, OMO version drift
- **OMO v4.18.2 → v4.19.0**: Upgraded OMO plugin. Goals feature replaces Ralph Loop. 8 attribution injection points patched.
- **Goals migration**: default_mode changed from `{mode: "ralph", max_iterations: 20}` to `{ultrawork: false, goal: true}` with `goal: {enabled: true, auto_start: false, default_max_iterations: 20}`.
- **dcp.jsonc fixed**: Missing comma at "showCompression: true" fixed — was causing silent JSON5 parse failure.
- **Doc restructure**: PRODUCTION_QUALITY.md and WORKFLOW_INTEGRATION.md moved to Development-Protocol repo — these are methodology docs (quality standards, workflow composition), not config docs. Agent-stack is now pure config+rationale+tooling.
- **Docs overhaul**: 8 files updated — ralph→goal migration across CONFIG_MAP, WORKFLOW, ARCHITECTURE, TROUBLESHOOTING; AGENTS.md duplicate heading fixed; VERSIONS.md versions corrected; CHANGELOG catch-up.

## 2026-07-14

- **Critical: auto_update true→false** (prevents OMO auto-updates from overwriting attribution dist edits)
- **Auto-rules made live**: 7 .mdc files copied from mirror to `~/.config/opencode/.opencode/rules/`
- **Config redacted**: personal paths replaced with `{{OPENDATA_DIR}}`, `{{PLAYWRIGHT_CHROME}}` placeholders
- **Gitignore replaced**: deny-by-default → standard explicit-ignore with `.opencode/rules/` exception
- **CONFIG_MAP.md fixed**: auto_update row corrected to false
- **Regression tests**: expanded 21→29, added post-run maintenance (auto-backup + cache clear)
- **Cache cleared**: `~/.cache/opencode/packages/` (freed 964M, removed attribution injection source)
- **DCP tuning**: dynamic_context_pruning enabled (10-turn protection), babysitting 120s, aggressive_truncation removed, truncate_all_tool_outputs false
- **SearXNG fine-tuned**: request_timeout 10.0→5.0, max 20.0→10.0, SEARXNG_TIMEOUT_MS 60000, limiter:false
- **OMO 4.16.2→4.18.0 upgraded**: attribution surgically removed from dist
- **Full adversarial review**: 0 attribution matches in OMO plugin tree, no secrets/API keys in configs
- **Pre-commit review**: all 31 tracked files clean, no raw paths/secrets, 29/29 regression pass
- **GitHub release v1.0.0**: created with full changelog, description + topics set
- Squashed and pushed to GitHub: single commit on origin/main

## 2026-07-12

- Architecture clarified: ~/.config/opencode/ is authoritative live config; opencode-config/ is mirror + docs layer (GitHub-published)
- Drift discovered & fixed: Mirror was ahead of live configs with all v2 changes. Live configs updated, mirror overwritten with live as authoritative source
- Live opencode.jsonc: 5 changes — build/worker/general prompts, SearXNG timeout (60s), compaction indent fix
- Live oh-my-openagent.jsonc: 18 changes — reasoningEffort tuning, atlas prompt_append + low effort, prompt_append added to 10 agents, multimodal-looker model fix, context-mode on sisyphus
- Added .omo/ and .opencode/ to .gitignore (agent ephemera excluded from repo)
- Squashed and pushed to GitHub: 35442f8 on origin/main (32 files, 3600 insertions, single commit)
- Updated Self-Hosted-Search/README.md (226 lines, mcp-searxng, limiter:false, 20 engines)
- Created ADR 010: Search Infrastructure (SearXNG self-hosted, mcp-searxng bridge)

## 2026-07-10

- Repo restructured: added redacted config files (opencode.jsonc, oh-my-openagent.jsonc) as main content
- Added scripts/redact-config.sh — auto-redacts personal paths for publishing
- Updated README to reflect dual purpose (settings dump + documentation)

- Added research/ dir with community config analysis (COMMUNITY_CONFIGS.md, GAP_RESEARCH.md, SUPER_ANALYSIS.md)
- V1 optimization round: build/plan reasoningEffort high→max; sisyphus added reasoningEffort:max;
  atlas added reasoningEffort:low + prompt_append verification gate; hephaestus added prompt_append
  verification gate; prometheus added prompt_append verification gate; artistry reasoningEffort
  max→high; writing reasoningEffort max→high; multimodal-looker model
  mimo-v2.5-free→deepseek-v4-flash-free
- Added 7 .mdc auto-rules in .opencode/rules/ (rust-workflow, python-workflow, typescript-react,
  config-files, git-workflow, go-workflow, agent-behavior)
- Added 10 agent prompt_append specializations to oh-my-openagent.jsonc
- Wired context-mode tooling into sisyphus, librarian, and general agents
- Added 3 new scripts: post-agent-log.sh, pre-commit-verify.sh, health-check.sh
- Added verification gates on build and worker prompts in opencode.jsonc

## 2026-07-09

- Created omo-install script at ~/.local/bin/omo-install — auto-patches attribution on every install/upgrade
- Fixed: removed 10 OMO agent entries from opencode.jsonc (broke TUI — OMO registers them via plugin hooks)
- Added 10 OMO agents (oracle, prometheus, metis, momus, etc.) to opencode.jsonc for TUI Tab-cycling access (later reverted)
- Fixed missing comma after agent block in opencode.jsonc
- Updated all docs to match current config state
- Upgraded OMO v4.12.0→v4.16.1 (fork bomb fix, ledger compaction)
- Patched OMO v4.16.1 dist: removed 8 attribution injection points
- Rearchitected Sisyphus: removed max reasoningEffort (speed), trimmed prompt_append ~70%
- Added Clarification Protocol to Sisyphus (based on 80-pt research gap)
- Fixed SearXNG MCP (broken file ref → working mcp-searxng)
- Added 14 config features: task_system, aggressive_truncation, preemptive_compaction,
  truncate_all_tool_outputs, safe_hook_creation, agent_order, keyword_detector,
  model_fallback, auto_update, telemetry:false, git category, mcp-searxng
- Added 3 regression tests (config feature placement, experimental flags, SearXNG health) → now 18 tests
- Found and fixed config bug: auto_update/telemetry/model_fallback were nested inside websearch
- Updated regression-test.sh to 18 tests

## 2026-07-08

- Added regression-test.sh (initially 15 tests: attribution, config validity, brace balance,
  model containment, OMO dist patch, cross-config DRY, category fallbacks, DCP integrity)
- Patched OMO v4.16.0 dist: removed 8 attribution injection points
- model-verifier now detects new premium models automatically
- Removed hyper-sisyphus agent, improve/ledger-verify/archive-status commands from both configs
  (skill files preserved locally)
- Added model-verifier.sh (validates configured models against available)
- Added cost-report.sh (reads SQLite DB for per-session cost data)
- Wired all 3 scripts into health-check.sh
- OMO v4.16.0 available (not yet activated in plugin cache)

## 2026-07-07

- Initial publish: ADRs (001-008), architecture, model tiering, workflow docs, incident reports
- 17 files, 722 lines
