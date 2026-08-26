# ADR 002: Model Tiering Strategy

**Status:** Accepted  
**Date:** 2026-07-03  
**Supersedes:** Initial gap-fill (2026-07-02)

## Context

OpenCode Go subscription ($10/month) provides access to Go-tier models (`opencode-go/*`). Free-tier Zen models (`opencode/*-free`) cost $0 but have rate limits. Need to allocate the Go budget where it provides the most quality improvement while keeping exploration agents on free-tier.

Research showed DeepSeek V4 Flash at 79% SWE-bench Verified, $0.024/task — 4.2× better quality-per-dollar than Claude Haiku 4.5.

## Decision

Allocate Go-tier budget to agents that directly impact output quality:

| Tier       | Model                             | Used by                                                                                       | Rationale                                                         |
| ---------- | --------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Go         | `opencode-go/deepseek-v4-flash`   | Sisyphus, Prometheus, Oracle, Architect, Plan, Hephaestus, Worker, Review, Atlas, Test-Writer | Primary reasoning, planning, code generation, architecture design |
| Free Flash | `opencode/deepseek-v4-flash-free` | Sisyphus-Junior, Librarian, Metis, Momus, Writing, Git                                        | Subagent tasks, research, simple queries, git ops                 |
| Free MiMo  | `opencode/mimo-v2.5-free`         | Explore, Build, General, Scout, Multimodal-Looker                                             | Discovery, critique, build orchestration, cheap lookups           |

_hyper-sisyphus removed (discontinued), nemotron-3-ultra-free removed (replaced by mimo)_

ReasoningEffort: "max" on reasoning agents, "high" on builders, "low" on workers/reviewers (sufficient for execution verification).

## Consequences

- **Positive:** Go budget concentrated on highest-impact agents.
- **Positive:** Free agents handle 80%+ of tool-call volume, keeping costs predictable.
- **Negative:** Go provider routing failure (#35149) blocks all Go-tier agents simultaneously.
- **Negative:** DeepSeek V4 Flash has a ~10-20% tool calling intermittent bug (emits text instead of structured calls) which mostly affects low-effort agents.

---

## Superseded (2026-08-02)

**Status:** Superseded in part by budget redesign

The 2026-08-02 budget redesign downgraded the frontier tier from `opencode-go/qwen3.7-max` to `opencode-go/qwen3.7-plus` for oracle, architect, prometheus, and the ultrabrain category. Pricing: qwen3.7-plus at $0.40/$1.60 per 1M tokens vs qwen3.7-max at $2.50/$7.50 (6.25×/4.7× savings). qwen3.7-max also hit a China-region 403 opt-in gate that made it unavailable without explicit subscription. qwen3.7-max concurrency is now 0 (budget-blocked). The historical tiering rationale (2026-07-03) is preserved below for context; the live routing table is in `.opencode/rules/model-routing.mdc`.

**Further superseded (2026-08-02 evening):** The qwen3.7-plus frontier detour was itself replaced the same day — the entire paid stack now routes to `opencode-go/deepseek-v4-flash` (official 0731 build). DeepSeek re-post-trained flash on 2026-07-31 with agentic benchmarks "far exceeding V4-Pro-Preview" (TB2.1 82.7 vs 61.8) while leaving the V4-Pro API on the Apr preview; flash wins on strength, price ($0.14/$0.28 vs $0.435/$0.87), and usage pool ($60 vs $15/mo). qwen3.7-plus survives only as a concurrency-3 fallback reserve; minimax-m3 stays only on visual-engineering (image/video); gpt-5.6-luna stays on review/test-writer. Live routing table: `.opencode/rules/model-routing.mdc`.

**Further superseded (2026-08-25):** Hy3 (Tencent) replaced DeepSeek V4 Flash as primary workhorse. AA Intelligence Index 42 at $0.04/task — 3× cheaper than Flash (52 at $0.11). MiMo-V2.5 demoted to free fallback only (no AA benchmark scores). Ox Alpha removed entirely (slow CoT latency). Fallback chains updated: hy3 → gpt-5.6-luna → mimo-v2.5-free. Live routing table: `.opencode/rules/model-routing.mdc`.
