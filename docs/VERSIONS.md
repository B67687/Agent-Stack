# Versions

Tracked versions for the Agent Stack config. Updated 2026-08-26.

## Core Tools

| Tool                  | Version | Source                                          | Notes                                                                              |
| --------------------- | ------- | ----------------------------------------------- | ---------------------------------------------------------------------------------- |
| OpenCode CLI          | 1.18.13 | ~/.opencode/bin/opencode                        | Latest stable: 1.18.23. Auto-updates for patches — set `autoupdate: false` to pin. |
| oh-my-openagent (OMO) | 4.19.4  | ~/.config/opencode/node_modules/oh-my-openagent | Latest stable: 4.19.4 (you're current). v5.0.0-beta.19 is beta channel (opt-in).   |

## Model Routing

| Setting            | Value                                                                            | Updated    |
| ------------------ | -------------------------------------------------------------------------------- | ---------- |
| Sensitive primary  | opencode-go/mimo-v2.5                                                            | 2026-08-26 |
| Low-sens primary   | opencode-go/muse-spark-1.2-contributor                                           | 2026-08-26 |
| Intelligence Index | 38 (MiMo), 57 (Muse)                                                             | —          |
| Cost per task      | $0.06 (MiMo), $0.01 (Muse)                                                       | —          |
| Sensitive fallback | mimo-v2.5 → gpt-5.6-luna → mimo-v2.5-free                                        | 2026-08-26 |
| Low-sens fallback  | muse-spark → mimo-v2.5 → gpt-5.6-luna → mimo-v2.5-free                           | 2026-08-26 |
| modelConcurrency   | mimo-v2.5=10, muse-spark=15, flash=2, luna=2, minimax=2, glm-5.2=2, mimo-free=10 | 2026-08-26 |

## Key Dates

| Date       | Event                                                                       |
| ---------- | --------------------------------------------------------------------------- |
| 2026-08-26 | v1.7: Hybrid routing — Muse Spark (low-sensitivity) + MiMo-V2.5 (sensitive) |
| 2026-08-25 | v1.6: Hy3 routed as primary, Ox Alpha removed, MiMo demoted (superseded)    |
| 2026-08-20 | Ox Alpha temporarily routed as primary                                      |
| 2026-08-17 | DeepSeek V4 Flash price increase (2× input, 8× quota reduction)             |
| 2026-08-03 | Fallback models allowlist added (claude-opus-5 incident)                    |
| 2026-08-02 | Budget redesign: qwen3.7-max → deepseek-v4-flash                            |
| 2026-07-03 | Initial model tiering (ADR-002)                                             |
