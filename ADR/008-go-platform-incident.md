# ADR 008: OpenCode Go Platform Incident (July 2026)

**Status:** Accepted  
**Date:** 2026-07-04  

## Context

On July 3-4 2026, OpenCode experienced a platform incident affecting Go subscribers. Symptoms:
- "Insufficient balance" errors when using ANY model (free-tier AND Go-tier)
- 502 Bad Gateway on Go API endpoints
- Free-tier models incorrectly hitting paid wallet validation gates

Related GitHub issues: #35163 (Bad Gateway), #35149 (free routes hitting paid gates — OPEN, 0 PRs, 2 days silence), #35151 (same), #34885 (DeepSeek Flash rate limiting — closed).

Our overengineering (concurrency 15, maxToolCalls 1000) amplified the blast radius — more parallel requests meant more failures, but the root cause was the platform, not our config.

## Decision

Mitigation stack:

1. **Auth refresh** (`opencode auth login`) — resolved the immediate issue despite no explicit credential expiry. Perhaps the cached auth token had stale routing metadata.
2. **Default model → free-tier** — `opencode/deepseek-v4-flash-free` bypasses Go routing entirely and continues working regardless of Go infrastructure status.
3. **Opencode as fallback default** — The default model is `opencode/deepseek-v4-flash-free` not `opencode-go/*`, so even if Go routing is down, the agent loads on Zen free models.
4. **Documented workaround route** — When Go is down: use `--model opencode/deepseek-v4-flash-free` flag or set default model temporarily.

Do NOT remove Go-tier from agents — the subscription is paid for and should be used when infrastructure is healthy. But the default loading mechanism should be free-tier to ensure the system always comes up.

## Consequences

- **Positive:** Auth refresh worked — system operational again with all free-tier models.
- **Positive:** Documented workaround for future incidents.
- **Negative:** Go-tier models remain unusable until OpenCode patches the routing infrastructure (#35149).
- **Negative:** During the outage, we can't use the Go subscription we're paying for. Budget is effectively wasted during the incident window.
- **Lessons learned:** Overengineering settings should be revisited after incidents — concurrency 15 amplified failure; consider dynamic concurrency reduction as a circuit-breaker response.
