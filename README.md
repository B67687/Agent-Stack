# Agent-Stack — OpenCode + OMO configuration reference docs

This repo is a **settings dump** — the actual redacted config files (`opencode.jsonc`, `oh-my-openagent.jsonc`) live here alongside the architectural documentation. The configs are the main content; the docs are QoL reference.

## Repository contents

```
agent-stack/
├── opencode.jsonc           ← redacted live config (settings dump)
├── oh-my-openagent.jsonc   ← redacted live config (settings dump)
├── README.md               ← this file
├── LICENSE                 ← MIT
├── .gitignore              ← explicit-ignore
├── ADR/                    ← Architecture Decision Records (001–010)
├── docs/
│   ├── AGENTS.md           ← agent inventory, Go-tier vs Free-tier
│   ├── ARCHITECTURE.md     ← two-file split rationale + OMO merge model
│   ├── CONFIG_MAP.md       ← every config setting with value and rationale
│   ├── WORKFLOW.md         ← 9 process additions
│   ├── INCIDENTS.md        ← platform incidents and mitigations
│   ├── TROUBLESHOOTING.md  ← common failure patterns
│   └── CHANGELOG.md        ← change history
├── research/
│   ├── COMMUNITY_CONFIGS.md  ← community config compilation
│   ├── GAP_RESEARCH.md       ← identified gaps vs community
│   └── SUPER_ANALYSIS.md     ← 16-dimension cross-config analysis
└── scripts/
    ├── redact-config.sh      ← auto-redact live configs for publishing
    ├── regression-test.sh    ← 29 regression tests
    ├── cost-report.sh        ← session cost tracking
    ├── model-verifier.sh     ← model existence checker
    ├── post-agent-log.sh     ← audit logger
    ├── pre-commit-verify.sh  ← pre-commit validation
    ├── health-check.sh       ← system health check
    └── verify.sh              ← unified suite runner (health + pre-commit + doctor + regression)
```

## About the config files

The redacted configs are copies of `~/.config/opencode/opencode.jsonc` and `~/.config/opencode/oh-my-openagent.jsonc` with personal paths replaced by placeholders (`{{OPENDATA_DIR}}`, `{{PLAYWRIGHT_CHROME}}`). To generate your own, copy the files and replace placeholders with your actual paths.

Use `scripts/redact-config.sh` to update the redacted copies from your live configs.

## Setup overview

- **Harness**: OpenCode CLI v1.17.20
- **Plugin**: oh-my-openagent@latest (v4.18.0)
- **Go subscription**: OpenCode Go ($10/mo)
- **Models**: 3 families across 2 tiers (Go-tier paid pool + Zen free shared pool)
- **Agents**: 19 agent definitions, 9 categories, 2-tier routing
- **Compaction**: 3 layers (OpenCode auto-prune, OMO DCP hooks, DCP plugin nudges)
- **Auto-Rules**: 7 rule files in `.opencode/rules/` auto-activate by path patterns covering Rust, Python, TypeScript/React, Config, Git, Go, and Agent behavior
- **Context-mode**: integrated `ctx_*` tooling for memory search, batch query, web indexing, and sandboxed execution

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full rationale and [docs/CONFIG_MAP.md](docs/CONFIG_MAP.md) for the complete setting inventory.

## Model tier cheat sheet

| Tier | Model | Used by | Cost |
|------|-------|---------|------|
| Go | deepseek-v4-flash | Sisyphus, Plan, Worker, Review, Architect, Prometheus, Oracle, Hephaestus, Atlas, Test-Writer | $10/mo shared pool |
| Free | deepseek-v4-flash-free | Sisyphus-Junior, Librarian, Metis, Momus, Writing, Git | $0 (rate-limited) |
| Free | mimo-v2.5-free | Build, Explore, General, Scout, Multimodal-Looker | $0 |

### Reasoning effort

Key agents with non-default `reasoningEffort`:

| Agent | Effort |
|-------|--------|
| Sisyphus | max |
| Plan | max |
| Build | max |
| Writing | high |
| Atlas | low |

## Significant incidents

| Date | Incident | Impact | Fix |
|------|----------|--------|-----|
| Jul 3-4, 2026 | Go platform #35149 — routing infrastructure broke | Go-tier models blocked with Insufficient Balance | `opencode auth login` + free-tier fallback |
| Jul 4, 2026 | OMO v4.15.1 attribution injection | ithmb codec commits re-attributed | git hook stripping + config override |
| Jul 6, 2026 | 3.5GB DB bloat | Context slowing, WAL 339MB | WAL checkpoint, DB VACUUM deferred |

See [docs/INCIDENTS.md](docs/INCIDENTS.md) for full detail.

## License

MIT — see [LICENSE](LICENSE).

## What's New (v2 — 2026-07-10)

- **Auto-rules system**: 7 rule files in `.opencode/rules/` auto-activate by path patterns covering Rust, Python, TypeScript/React, Config, Git, Go, and Agent behavior
- **Agent prompt specialization**: 10 agents with role-specific system prompts
- **Context-mode tooling**: integrated `ctx_*` tools for memory search, batch execution, web indexing, and sandboxed code execution
- **3 new scripts**: `post-agent-log.sh` (audit logger), `pre-commit-verify.sh` (pre-commit validation), `health-check.sh` (system health check)
- **Reasoning effort optimizations**: Sisyphus, Plan, Build at `max`; Writing at `high`; Atlas at `low`

## What's New (v2.1 — 2026-07-14)

- **Config redacted**: personal paths replaced with `{{OPENDATA_DIR}}`, `{{PLAYWRIGHT_CHROME}}` placeholders
- **Gitignore replaced**: deny-by-default → standard explicit-ignore
- **auto_update locked to false**: prevents OMO auto-updates from overwriting surgical dist edits
- **DCP tuned**: dynamic_context_pruning enabled (10-turn protection), babysitting 120s, truncate_all_tool_outputs false
- **Verify suite**: new `verify.sh` — runs health-check → pre-commit → omo doctor → regression-test in one command
- **OMO 4.18.0 upgrade**: attribution surgically removed from dist, fallback models configured, pre-commit JSONC fix
- **Full adversarial review**: npm cache cleared, backups automated, 29 regression tests all passing
