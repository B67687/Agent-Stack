# ADR 003: Overengineering Tunables

**Status:** Accepted  
**Date:** 2026-07-03  

## Context

Default OpenCode/OMO settings are conservative to work for everyone. For power users doing intensive multi-agent work, the defaults create bottlenecks: subagent tasks get killed too early, parallel execution is too limited, self-improvement loops terminate before convergence.

## Decision

Max out all free (cost-free) tunables:

| Setting | Default | Ours | Rationale |
|---------|---------|------|-----------|
| `background_task.concurrency` | 5 | 15 | More parallel subagents for multi-agent orchestration |
| `background_task.maxToolCalls` | ~100 | 1000 | Prevent subagent loops from being killed mid-work |
| `background_task.staleTimeoutMs` | 300000 | 900000 | 15-minute timeout for long-running research agents |
| `ralph_loop.max_iterations` | 30 | 200 | Allow self-improvement loops to converge on complex tasks |
| Agent `steps` | 40 | 50 | More reasoning steps for complex orchestration |

These are **free knobs** — they don't increase API costs, they just raise internal limits.

## Consequences

- **Positive:** Complex multi-agent workflows now complete without hitting artificial limits.
- **Positive:** No additional cost.
- **Negative:** May mask underlying issues (e.g., an agent stuck in a loop runs longer before timing out).
- **Negative:** Higher concurrency amplifies the blast radius of provider outages (we hit the Go routing bug harder with concurrency 15).
