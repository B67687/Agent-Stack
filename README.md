# Agent-Stack — OpenCode + OMO configuration reference docs

This repo is a **settings dump** — the actual redacted config files (`opencode.jsonc`, `oh-my-openagent.jsonc`, `lsp.json`) live here alongside the architectural documentation. The configs are the main content; the docs are QoL reference.

## Setup overview

- **Harness**: OpenCode CLI v1.18.3
- **Plugin**: oh-my-openagent@latest (v4.18.0)
- **Subscription**: OpenCode Go ($10/mo) + Zen free tier
- **Models**: 7 families across 3 tiers (Go high-volume 31k/5hr — Go medium 3-4k/5hr — Zen free)
- **Agents**: 18 agent definitions, 9 categories, 2-tier routing, diversified model assignments
- **Compaction**: 3 layers (OpenCode auto-prune, OMO DCP hooks, DCP plugin nudges)
- **Auto-Rules**: 10 rule files in `.opencode/rules/` covering Rust, Python, TypeScript/React, Config, Git, Go, Agent behavior, Build workflow, Build meta-learning, and Architect methodology
- **LSP**: 20 language servers, 5 custom wrapper scripts + 2 dedicated web LSPs for LSP fixes
- **Context-mode**: integrated `ctx_*` tooling for memory search, batch query, web indexing, and sandboxed execution
- **Code viewer**: VSCode for real-time code inspection alongside the agent

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full rationale and [docs/CONFIG_MAP.md](docs/CONFIG_MAP.md) for the complete setting inventory.

## Model tier cheat sheet (per 5-hour window)

| Tier           | Rate/5hr | Models                                    | Primary Agents                                                   |
| -------------- | -------- | ----------------------------------------- | ---------------------------------------------------------------- |
| Go high-volume | 30k-31k  | deepseek-v4-flash, mimo-v2.5              | sisyphus, hephaestus, worker, atlas, deep, artistry              |
| Go medium      | 3k-4k    | minimax-m3, qwen3.7-plus, deepseek-v4-pro | oracle, review, momus, prometheus, metis, architect, test-writer |
| Zen free       | free     | deepseek-v4-flash-free, mimo-v2.5-free    | explore, quick, sisyphus-junior, librarian, scout, writing, git  |

### Reasoning effort

| Agent      | Effort | Agent                    | Effort |
| ---------- | ------ | ------------------------ | ------ |
| sisyphus   | max    | architect                | max    |
| prometheus | max    | ultrabrain (cat)         | xhigh  |
| oracle     | max    | test-writer              | high   |
| hephaestus | max    | unspecified-high (cat)   | high   |
| deep (cat) | max    | artistry (cat)           | high   |
| momus      | xhigh  | writing (cat)            | high   |
| review     | low    | atlas                    | low    |
| worker     | low    | visual-engineering (cat) | high   |

## Repository contents

```
Agent-Stack/
├── opencode.jsonc           ← redacted live config (settings dump)
├── oh-my-openagent.jsonc   ← redacted live config (OMO settings dump)
├── lsp.json                 ← LSP daemon config (separate from opencode.jsonc)
├── README.md               ← this file
├── LICENSE                 ← MIT
├── .gitignore              ← explicit-ignore
├── .github/                ← release tracker workflow
├── ADR/                    ← Architecture Decision Records (001–014)
├── docs/
│   ├── AGENTS.md             ← agent inventory, 3-tier routing
│   ├── ARCHITECTURE.md       ← two-file split rationale + OMO merge model
│   ├── CONFIG_MAP.md         ← every config setting with value and rationale
│   ├── WORKFLOW.md           ← 9 process additions
│   ├── WORKFLOW_INTEGRATION.md ← combined Dev Protocol + start-work flow
│   ├── PRODUCTION_QUALITY.md ← OSS benchmark quality standards
│   ├── VERSIONS.md           ← tracked release versions for update checking
│   ├── INCIDENTS.md          ← platform incidents and mitigations
│   ├── TROUBLESHOOTING.md    ← common failure patterns
│   └── CHANGELOG.md          ← change history
├── research/
│   ├── COMMUNITY_CONFIGS.md             ← community config compilation
│   ├── GAP_RESEARCH.md                  ← identified gaps vs community
│   ├── INNOVATIONS_2026_H2.md           ← Agent harness innovations research
│   ├── 2026-07-18-landscape-refresh.md  ← Landscape refresh audit
│   └── SUPER_ANALYSIS.md                ← 16-dimension cross-config analysis
├── .opencode/rules/         ← 10 auto-rule .mdc files
└── scripts/
    ├── redact-config.sh      ← auto-redact live configs for publishing
    ├── regression-test.sh    ← 32 regression tests (all passing)
    ├── cost-report.sh        ← session cost tracking
    ├── model-verifier.sh     ← model existence checker
    ├── post-agent-log.sh     ← audit logger
    ├── pre-commit-verify.sh  ← JSON5 + JSONC + lsp.json validation
    ├── health-check.sh       ← system health check
    ├── verify.sh             ← unified suite runner (4 suites)
    ├── check-updates.sh      ← release update tracker (72h cooldown)
    ├── resolve-ts-lsp.js     ← TS7 Go native LSP proxy + version detection
    ├── zls-lsp-wrapper.js    ← zls initialized-notification fix
    ├── jdtls.sh              ← Java 21 JDT Language Server wrapper
    ├── kotlin-lsp.sh         ← kotlin-ls --stdio wrapper
    └── lua-ls.sh             ← lua-language-server path fix wrapper
```

## About the config files

The redacted configs are copies of `~/.config/opencode/opencode.jsonc` and `~/.config/opencode/oh-my-openagent.jsonc` with personal paths replaced by placeholders (`{{OPENDATA_DIR}}`, `{{PLAYWRIGHT_CHROME}}`). To generate your own, copy the files and replace placeholders with your actual paths.

Use `scripts/redact-config.sh` to update the redacted copies from your live configs.

The LSP daemon config at `lsp.json` uses absolute paths — `$HOME` expansion is not supported by the daemon.

## System Dependencies

The config expects these global tools to be installed:

- **Biome** (`@biomejs/biome`) — LSP diagnostics for JSON, JSONC, JS, TS, CSS. Run `npm i -g @biomejs/biome`.
- **Prettier** — formatter for JS/TS/JSON/YAML/MD. Usually ships with Node.
- **mcp-searxng** — SearXNG MCP bridge. Installed globally via npm.
- **Playwright** — browser automation. Installed via `playwright install chromium`.
- **resolve-ts-lsp** — Node.js proxy for TS7 Go native LSP. Installed to `~/.local/bin/`.
- **zls-lsp-wrapper** — Node.js proxy for zls initialized-notification fix. Installed to `~/.local/bin/`.

See [scripts/health-check.sh](scripts/health-check.sh) for runtime dependency validation.

## Companion

[Development Protocol](https://github.com/B67687/Development-Protocol) — Methodology governance layer: autonomy levels, execution discipline, scope calibration. Complements the config stack with how-to-work rules. WORKFLOW_INTEGRATION.md and PRODUCTION_QUALITY.md documentation lives in that repo.

## Significant incidents

| Date    | Incident                                          | Impact                                           | Fix                                        |
| ------- | ------------------------------------------------- | ------------------------------------------------ | ------------------------------------------ |
| Jul 3-4 | Go platform #35149 — routing infrastructure broke | Go-tier models blocked with Insufficient Balance | `opencode auth login` + free-tier fallback |
| Jul 4   | OMO v4.15.1 attribution injection                 | ithmb codec commits re-attributed                | git hook stripping + config override       |
| Jul 6   | 3.5GB DB bloat                                    | Context slowing, WAL 339MB                       | WAL checkpoint, DB VACUUM deferred         |

See [docs/INCIDENTS.md](docs/INCIDENTS.md) for full detail.

## Repository Rules

This repo is the **only** directory in the `agent-stack-workspace/` container pushed to GitHub.
See the [workspace root README](../README.md) for the full set of workspace-level rules.

### Single-Commit Policy

This repo must always have **exactly one commit**. The commit preserves the latest
commit's author and date. Squash flow:

```bash
# Capture latest commit metadata
AUTHOR="$(git log -1 --format='%an <%ae>')"
DATE="$(git log -1 --format='%aD')"
MSG="$(git log -1 --format='%s')"

git add -A
git reset --soft "$(git rev-list --max-parents=0 HEAD)"
git commit --amend --author="$AUTHOR" --date="$DATE" -m "$MSG"
git push --force-with-lease origin main
```

### Mirroring Live Configs

We edit the **global configs** at `~/.config/opencode/`, then mirror them here:

```bash
bash scripts/redact-config.sh
```

The script replaces personal paths with placeholders (`{{OPENDATA_DIR}}`, etc.) for
safe publishing.

## License

MIT — see [LICENSE](LICENSE).
