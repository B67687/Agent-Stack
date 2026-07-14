# ADR 004: Thinking Mode on Reasoning Agents

**Status:** Accepted  
**Date:** 2026-07-03  

## Context

DeepSeek V4 Flash supports `thinking` mode — chain-of-thought reasoning before generating a response. Research shows +9.6pp on SWE-bench and +36.4 on LiveCodeBench with Think High vs non-think, at approximately 2× token cost. However, there's a known issue where multi-turn tool calls with thinking fail unless `reasoning_content` is preserved in the response round-trip.

## Decision

Enable thinking mode on agents where reasoning quality matters most and the single-turn use case dominates:

| Agent | Budget | Rationale |
|-------|--------|-----------|
| Oracle | 8k tokens | Deep analysis, single-turn consultation — benefits most from CoT |
| Architect | 16k tokens | Complex architecture design, needs deeper reasoning path |

Do NOT enable on:
- **Sisyphus** — orchestrator that primarily makes tool calls; thinking wastes tokens and conflicts with tool-calling patterns
- **Worker/Review** — simple execution tasks don't benefit from CoT
- **Agents with thinking on free-tier models** — free models don't support thinking

## Consequences

- **Positive:** Oracle and Architect produce higher quality reasoning for complex problems.
- **Positive:** Token cost increase limited to two agents used for deep work.
- **Negative:** If the `reasoning_content` round-trip bug affects multi-turn Oracle sessions, thinking mode may cause failures in rare edge cases.
- **Neutral:** Sisyphus as orchestrator gets no thinking benefit — its value is in tool orchestration, not deep reasoning.
