# Versions

Tracked versions for the Agent Stack config. Updated 2026-09-03.

## Core Tools

| Tool                  | Version | Source                                          | Notes                                                                                                                                                                                                       |
| --------------------- | ------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OpenCode CLI          | 1.18.26 | ~/.opencode/bin/opencode                        | Latest stable: 1.18.26. Auto-updates for patches — set `autoupdate: false` to pin.                                                                                                                          |
| oh-my-openagent (OMO) | 4.19.4  | ~/.config/opencode/node_modules/oh-my-openagent | Latest stable: 4.19.4 (you're current). v5.0.0-beta.34 is beta channel (opt-in). 1.3-contributor listed on Go 2026-09-03 but probe falls back on 4.19.4 (unknown compat) — keep 1.2 primary until OMO 5 GA. |

## Model Routing

| Setting               | Value                                                                            | Updated    |
| --------------------- | -------------------------------------------------------------------------------- | ---------- |
| Primary model         | opencode-go/muse-spark-1.3-contributor                                           | 2026-08-28 |
| Orchestrator guard    | — (all agents on muse-spark since 2026-08-28, cache bug fixed)                   | 2026-08-28 |
| Intelligence Index    | 61 xhigh / 62 max (1.3), 57 (1.2 fallback), 38 (MiMo)                                                    | —          |
| Cost per task         | ~$0.55 (1.3), $0.40 (1.2 fallback), $0.06 (MiMo)                                              | —          |
| Primary fallback      | 1.3 → 1.2 → mimo-v2.5 → gpt-5.6-luna → mimo-v2.5-free                           | 2026-08-28 |
| Orchestrator fallback | 1.3 → 1.2 → mimo-v2.5 → gpt-5.6-luna → mimo-v2.5-free (same as primary)         | 2026-08-28 |
| modelConcurrency      | muse-spark-1.3=15, muse-spark-1.2=10, mimo-v2.5=10, flash=2, luna=2, minimax=2, glm-5.2=2, mimo-free=10 | 2026-08-28 |

## Key Dates

| Date       | Event                                                                                                                                                    |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-03 | opencode 1.18.13 → 1.18.26 (13 patches, no breaking). Muse Spark 1.3 contributor Go live but probe fallback→mimo on 4.19.4 — deferred shift 1.3→1.2→mimo |
| 2026-08-28 | v1.9: All agents on Muse Spark + `agent-session kill` cache fix                                                                                          |
| 2026-08-27 | v1.8: Muse Spark primary — Intelligence 57 covers all agents except orchestrator                                                                         |
| 2026-08-25 | v1.6: Hy3 routed as primary, Ox Alpha removed, MiMo demoted (superseded)                                                                                 |
| 2026-08-20 | Ox Alpha temporarily routed as primary                                                                                                                   |
| 2026-08-17 | DeepSeek V4 Flash price increase (2× input, 8× quota reduction)                                                                                          |
| 2026-08-03 | Fallback models allowlist added (claude-opus-5 incident)                                                                                                 |
| 2026-08-02 | Budget redesign: qwen3.7-max → deepseek-v4-flash                                                                                                         |
| 2026-07-03 | Initial model tiering (ADR-002)                                                                                                                          |
