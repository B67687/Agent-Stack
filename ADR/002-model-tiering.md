# ADR 002: Model Tiering Strategy

**Status:** Accepted  
**Date:** 2026-07-03  
**Supersedes:** Initial gap-fill (2026-07-02)  

## Context

OpenCode Go subscription ($10/month) provides access to Go-tier models (`opencode-go/*`). Free-tier Zen models (`opencode/*-free`) cost $0 but have rate limits. Need to allocate the Go budget where it provides the most quality improvement while keeping exploration agents on free-tier.

Research showed DeepSeek V4 Flash at 79% SWE-bench Verified, $0.024/task — 4.2× better quality-per-dollar than Claude Haiku 4.5.

## Decision

Allocate Go-tier budget to agents that directly impact output quality:

| Tier | Model | Used by | Rationale |
|------|-------|---------|-----------|
| Go | `opencode-go/deepseek-v4-flash` | Sisyphus, Prometheus, Oracle, Architect, Plan, Hephaestus, Worker, Review, Atlas, Test-Writer | Primary reasoning, planning, code generation, architecture design |
| Free Flash | `opencode/deepseek-v4-flash-free` | Sisyphus-Junior, Librarian, Metis, Momus, Writing, Git | Subagent tasks, research, simple queries, git ops |
| Free MiMo | `opencode/mimo-v2.5-free` | Explore, Build, General, Scout, Multimodal-Looker | Discovery, critique, build orchestration, cheap lookups |

*hyper-sisyphus removed (discontinued), nemotron-3-ultra-free removed (replaced by mimo)*

ReasoningEffort: "max" on reasoning agents, "high" on builders, "low" on workers/reviewers (sufficient for execution verification).

## Consequences

- **Positive:** Go budget concentrated on highest-impact agents.
- **Positive:** Free agents handle 80%+ of tool-call volume, keeping costs predictable.
- **Negative:** Go provider routing failure (#35149) blocks all Go-tier agents simultaneously.
- **Negative:** DeepSeek V4 Flash has a ~10-20% tool calling intermittent bug (emits text instead of structured calls) which mostly affects low-effort agents.
