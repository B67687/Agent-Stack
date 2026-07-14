# ADR 010: Search Infrastructure

**Status:** Accepted  
**Date:** 2026-07-11  

## Context

Paid search APIs (Tavily $0-24/mo, Exa $0-168/mo, Serper $0-50/mo) were the initial search backends for AI agent tooling. Each introduced per-query costs, rate limits, and sent query traffic to third-party services. AI agents need unlimited queries, high concurrency, and no rate limits — paid APIs cap all three. Alternatives evaluated: Tavily (paid, rate-limited), Exa (paid, narrow focus), Serper (paid), SearXNG (free, self-hosted, open-source). Privacy requirements demanded keeping search queries local.

## Decision

Self-host SearXNG in Docker on localhost:8888, bridged to OpenCode via the `mcp-searxng` npm package (instead of a custom server.js bridge). Configuration specifics:

- **Limiter:** `false` — no reverse proxy means no `X-Forwarded-For` header, so the rate limiter was disabled.
- **Timeouts:** `request_timeout: 5.0`, `max_request_timeout: 10.0` (up from SearXNG defaults of 3s/10s) to accommodate slower engines.
- **Engines:** 20 enabled (Bing, Presearch, Yep, etc.); known-broken engines removed (Google, DuckDuckGo, Startpage, Qwant, Yahoo, Baidu, Yandex, Mojeek).
- **MCP env:** `SEARXNG_TIMEOUT_MS: 60000` — 60s window for mcp-searxng to SearXNG communication.
- **Valkey:** Deployed for compatibility but unused (limiter disabled).
- **Binding:** `127.0.0.1:8888` only — not network-accessible.

## Consequences

- **Positive:** Free, unlimited queries, private (no third-party API calls), high concurrency (200 pool_connections, 20 pool_maxsize).
- **Positive:** 16-20 working engines deliver diverse results (30-190+ per query).
- **Negative:** Not portable — requires Docker on the host machine.
- **Negative:** Slower than paid APIs (engines take 2-10s).
- **Negative:** No `X-Forwarded-For` means the rate limiter is disabled; upstream bot detection may still happen.
- **Neutral:** Requires maintenance (config edits via Alpine helper, engine list may need updating).
- **Neutral:** Valkey container runs unnecessarily — future cleanup opportunity.
