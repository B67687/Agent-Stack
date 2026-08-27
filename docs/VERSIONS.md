# Versions

Tracked versions for the Agent Stack config. Updated 2026-08-26.

## Core Tools

| Tool                  | Version | Source                                          | Notes                                                                              |
| --------------------- | ------- | ----------------------------------------------- | ---------------------------------------------------------------------------------- |
| OpenCode CLI          | 1.18.13 | ~/.opencode/bin/opencode                        | Latest stable: 1.18.23. Auto-updates for patches — set `autoupdate: false` to pin. |
| oh-my-openagent (OMO) | 4.19.4  | ~/.config/opencode/node_modules/oh-my-openagent | Latest stable: 4.19.4 (you're current). v5.0.0-beta.19 is beta channel (opt-in).   |

## Model Routing

| Setting               | Value                                                                            | Updated    |
| --------------------- | -------------------------------------------------------------------------------- | ---------- |
| Primary model         | opencode-go/muse-spark-1.2-contributor                                           | 2026-08-27 |
| Orchestrator guard    | opencode-go/mimo-v2.5 (sisyphus only)                                            | 2026-08-27 |
| Intelligence Index    | 57 (Muse), 38 (MiMo)                                                             | —          |
| Cost per task         | $0.01 (Muse), $0.06 (MiMo)                                                       | —          |
| Primary fallback      | muse-spark → mimo-v2.5 → gpt-5.6-luna → mimo-v2.5-free                           | 2026-08-27 |
| Orchestrator fallback | mimo-v2.5 → gpt-5.6-luna → mimo-v2.5-free                                        | 2026-08-27 |
| modelConcurrency      | muse-spark=15, mimo-v2.5=10, flash=2, luna=2, minimax=2, glm-5.2=2, mimo-free=10 | 2026-08-27 |

## Key Dates

| Date       | Event                                                                            |
| ---------- | -------------------------------------------------------------------------------- |
| 2026-08-27 | v1.8: Muse Spark primary — Intelligence 57 covers all agents except orchestrator |
| 2026-08-25 | v1.6: Hy3 routed as primary, Ox Alpha removed, MiMo demoted (superseded)         |
| 2026-08-20 | Ox Alpha temporarily routed as primary                                           |
| 2026-08-17 | DeepSeek V4 Flash price increase (2× input, 8× quota reduction)                  |
| 2026-08-03 | Fallback models allowlist added (claude-opus-5 incident)                         |
| 2026-08-02 | Budget redesign: qwen3.7-max → deepseek-v4-flash                                 |
| 2026-07-03 | Initial model tiering (ADR-002)                                                  |
