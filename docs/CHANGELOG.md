## 2026-07-14

- **Critical: auto_update true→false** (prevents OMO auto-updates from overwriting attribution dist edits)
- **Auto-rules made live**: 7 .mdc files copied from mirror to `~/.config/opencode/.opencode/rules/`
- **Config redacted**: personal paths replaced with `{{OPENDATA_DIR}}`, `{{PLAYWRIGHT_CHROME}}` placeholders
- **Gitignore replaced**: deny-by-default → standard explicit-ignore with `.opencode/rules/` exception (7 .mdc rules now tracked for GitHub)
- **CONFIG_MAP.md fixed**: auto_update row corrected to false
- **Regression tests**: expanded 21→29, removed outdated, added post-run maintenance (auto-backup + cache clear)
- **Cache cleared**: `~/.cache/opencode/packages/` (freed 964M, removed attribution injection source)
- **DCP tuning**: dynamic_context_pruning enabled (10-turn protection), babysitting 120s, aggressive_truncation removed, truncate_all_tool_outputs false
- **SearXNG fine-tuned**: request_timeout 10.0→5.0, max 20.0→10.0, SEARXNG_TIMEOUT_MS 60000, limiter:false
- **OMO 4.16.2→4.18.0 upgraded**: attribution surgically removed from dist (`buildCommitFooterInjection` deleted + call site)
- **Full adversarial review**: 0 attribution matches in OMO plugin tree, no secrets/API keys in configs, 3 projects with config drift fixed
- **Pre-commit review**: all 31 tracked files clean, no raw paths/secrets, 29/29 regression pass
- **GitHub release v1.0.0**: created with full changelog, repo renamed Agent-Stack, description + topics set
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

# Changelog

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
