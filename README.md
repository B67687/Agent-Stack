# Agent-Stack — OpenCode + OMO configuration stack

This repo **is** the live configuration directory (`~/.config/opencode/`) for the
OpenCode + Oh-My-OpenAgent agent stack, mirrored to GitHub. It contains the actual
config files, the auto-injected rule docs, the verification scripts, and the full
documentation layer (ADRs, architecture, research) explaining every decision.

The configs are the main content; the docs are the reference for _why_ it is built
this way.

> **Mirror boundary:** this repo tracks configs + docs + redacted data only. Untracked runtime cruft lives beside them in the same directory and is gitignored: `context-mode/` (ctx_* session DBs), `tasks/` (per-project task JSON), `.opencode/node_modules/` + `package-lock.json` (plugin deps), `backups/` (config snapshots), `.omo/` (agent ephemera). It is never committed — only the mirror content is.

## Setup overview

- **Harness**: OpenCode CLI + Oh-My-OpenAgent plugin (pinned `oh-my-openagent@4.19.4`)
- **Plugins** (pinned): `@tarquinen/opencode-dcp@3.1.14`, `oh-my-openagent@4.19.4`, `opencode-command-inject@1.3.0`
- **Subscription**: OpenCode Go ($10/mo) + Zen free tier
- **Models**: opencode-go hybrid routing split by privacy sensitivity (see [docs/AGENTS.md](docs/AGENTS.md) and `model-routing` rule)
- **Agents**: ~19 agent definitions, 9 categories, privacy-sensitive hybrid routing
- **Compaction**: 3 layers (OpenCode auto-prune, OMO DCP hooks, DCP plugin nudges)
- **Auto-Rules**: 11 `.mdc` rule files in `.opencode/rules/` — injected live into agent context (via `~/.opencode/rules` symlink, scanned by the OMO rules-injector)
- **LSP**: basedpyright, css, html, json, markdown, rust-analyzer, typescript (bare PATH-resolvable commands — no machine-specific paths in config)
- **Context-mode**: integrated `ctx_*` tooling for memory search, batch query, web indexing, and sandboxed execution
- **Code viewer**: VSCode for real-time code inspection alongside the agent

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full rationale and [docs/CONFIG_MAP.md](docs/CONFIG_MAP.md) for the complete setting inventory.

## Model routing (per 5-hour window)

| Sensitivity Tier      | Models                                 | Primary agents                                                                                     |
| --------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Sensitive (privacy)   | opencode-go/mimo-v2.5                  | sisyphus, architect, build, worker, oracle, prometheus, metis, momus, ultrabrain, unspecified-high |
| Low-sensitivity       | opencode-go/muse-spark-1.2-contributor | explore, librarian, scout, multimodal-looker, writing, git, quick, unspecified-low, artistry, deep |
| Quality (review/test) | opencode-go/gpt-5.6-luna               | review, test-writer                                                                                |
| Visual (UI/UX)        | opencode-go/minimax-m3                 | visual-engineering                                                                                 |

Full routing rationale (quality scores, pricing, limits, NOT-list guardrails) lives in
`.opencode/rules/model-routing.mdc` (live policy; the older [research/2026-07-18-landscape-refresh.md](research/2026-07-18-landscape-refresh.md) is superseded — see its banner).

## Repository contents

```
Agent-Stack/
├── opencode.jsonc           ← live config (OpenCode)
├── ~/.omo/omo.jsonc        ← live OMO config (post-4.19.4 migration, outside repo)
├── dcp.jsonc, tui.json
├── lsp-install-decisions.json ← LSP install prompt decisions
├── LESSONS.md            ← cross-project knowledge base
├── README.md               ← this file
├── LICENSE                 ← MIT
├── .gitignore              ← excludes backups/, context-mode/, tasks/, lockfiles
├── .github/                ← release tracker workflow
├── ADR/                    ← Architecture Decision Records (001–014)
├── docs/
│   ├── AGENTS.md             ← agent inventory, tiered routing
│   ├── ARCHITECTURE.md       ← two-file split rationale + OMO merge model
│   ├── CONFIG_MAP.md         ← every config setting with value and rationale
│   ├── WORKFLOW.md           ← 9 process additions
│   ├── INCIDENTS.md          ← platform incidents and mitigations
│   ├── TROUBLESHOOTING.md    ← common failure patterns
│   └── CHANGELOG.md          ← change history
├── research/
│   ├── COMMUNITY_CONFIGS.md             ← community config compilation
│   ├── GAP_RESEARCH.md                  ← identified gaps vs community
│   ├── INNOVATIONS_2026_H2.md           ← Agent harness innovations research
│   ├── 2026-07-18-landscape-refresh.md  ← Landscape refresh audit
│   └── SUPER_ANALYSIS.md                ← 16-dimension cross-config analysis
├── .opencode/rules/         ← 11 auto-rule .mdc files (live-injected)
├── skills/                  ← 11 skills (5 tracked: dev-protocol, git-master, meta-learner, rust-workflow, solve; + github-workflow, shipcheck; + 4 OMO symlinks: work-with-pr, tech-debt-audit, github-triage, remove-deadcode)
└── scripts/
    ├── redact-config.sh      ← leak scanner for machine-specific paths (--check)
    ├── regression-test.sh    ← regression tests (all passing)
    ├── cost-report.sh        ← session cost tracking
    ├── model-verifier.sh     ← model existence/availability checker
    ├── post-agent-log.sh     ← audit logger
    ├── pre-commit-verify.sh  ← JSON5 + JSONC validation
    ├── health-check.sh       ← system health check
    ├── verify.sh             ← unified suite runner (4 suites)
    ├── check-updates.sh      ← release update tracker (72h cooldown)
    ├── resolve-ts-lsp.js     ← TS7 Go native LSP proxy + version detection
    ├── config-schema-check.mjs ← installed-schema validator (catches TUI ghost-key bug class)
    ├── runtime-regression-test.sh ← staged-boot runtime consumption proof
    ├── restart-opencode.sh   ← validate config, restart opencode, assert reload took effect
    ├── bwrap-wrap.sh         ← Layer-1+2 sandbox wrapper (bubblewrap: deny-by-default FS + L2 egress via EGRESS=1; inert — not the live launch path)
    ├── egress-proxy.sh       ← host-side egress proxy daemon (Squid allowlist → socat UDS; systemd user unit egress-proxy@)
    ├── egress-relay.sh       ← in-sandbox relay (bind-mounts egress.sock, exports proxy env, execs agent)
    ├── egress-test.sh        ← L2 egress test suite (T1-T8: allow/deny/fail-closed)
    ├── egress-allowlist.conf ← egress allowlist (default-deny; lives in egress/)
    ├── hooks/
    │   └── pre-push          ← local CI gate (redact + docs-sync greps; core.hooksPath → scripts/hooks)
    └── validate-jsonc.js     ← JSONC validator + query helper
```

## Portability

The configs are **portable** — no machine-specific absolute paths. LSP and formatter
commands use bare PATH-resolvable names (opencode spawns them without a shell, so
`~`/env expansion does not happen there); agent prompt templates and docs use `~`
(those run through a real shell). Local tools referenced by scripts (`git-safe-commit`,
`git-safe-push`, `gh-safe-pr-create`, `basedpyright-langserver`,
`resolve-ts-lsp`) must be on `$PATH`.

Run `bash scripts/redact-config.sh --check` to scan all tracked files for
absolute-home paths, personal commit identity, and possible API keys.

## System Dependencies

The config expects these global tools to be installed:

- **prettier** — formatter for JS/TS/JSON/YAML/MD
- **gofmt**, **rustfmt**, **ruff** — language formatters
- **basedpyright-langserver** — Python LSP (`uv tool install basedpyright`)
- **resolve-ts-lsp** — Node.js proxy for TS7 Go native LSP (in `scripts/`, symlinked to `~/.local/bin/`)
- **mcp-searxng** — SearXNG MCP bridge (loopback `127.0.0.1:8888`)
- **Playwright** — browser automation (`playwright install chromium`)

See [scripts/health-check.sh](scripts/health-check.sh) for runtime dependency validation.

## Companion

[Development Protocol](https://github.com/B67687/Development-Protocol) — Methodology
governance layer: autonomy levels, execution discipline, scope calibration. Complements
the config stack with how-to-work rules.

## Significant incidents

Full detail: [docs/INCIDENTS.md](docs/INCIDENTS.md). Current guardrail state:
`disabled_hooks = ["todo-continuation-enforcer", "keyword-detector"]` (2026-08-04 — goal + compaction-context-injector re-armed; goal stays inert via `goal.enabled: false`)

| Date     | Incident                                                          | Fix                                                               |
| -------- | ----------------------------------------------------------------- | ----------------------------------------------------------------- |
| Jun 2026 | Playwright 502 on Ubuntu 26.04                                    | patched version check + headless                                  |
| Jul 2026 | Go platform #35149 routing break                                  | auth login + free-tier fallback                                   |
| Jul 2026 | Sisyphus attribution injection                                    | git hook + config override + dist patch                           |
| Jul 2026 | DB bloat (WAL 339MB)                                              | WAL checkpoint + weekly VACUUM cron                               |
| Jul 2026 | Goal handler bug (v4.19.0) — **recurred Aug (Incident 9)**        | config-level fix: goal hook disabled                              |
| Jul 2026 | Agent registration failure / dist corruption                      | dist patches; rollback → v4.19.4                                  |
| Jul 2026 | Continuation injection loop                                       | 4-entry disabled_hooks (reduced to 2-entry 2026-08-04)            |
| Aug 2026 | v1.7 privacy routing migration + Hy3 removal + OMO sidebar enable | hybrid split config + deprecated Hy3 references + sidebar enabled |

## Versions

| Package         | Current Version | Source Repo                                                                     | Last Checked |
| --------------- | --------------- | ------------------------------------------------------------------------------- | ------------ |
| oh-my-openagent | v4.19.4         | [code-yeongyu/oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | 2026-08-02   |
| OpenCode        | v1.18.13        | [anomalyco/opencode](https://github.com/anomalyco/opencode)                     | 2026-08-26   |

Release tags from GitHub — when upstream publishes a new tag, the update tracker creates an issue.

## License

MIT — see [LICENSE](LICENSE).
