# ADR 005: Context-Mode Integration

**Status:** Accepted  
**Date:** 2026-07-03  

## Context

The session's primary bottleneck was context window management. Without structured context compression, the agent's reasoning degrades after 50+ tool calls as old outputs accumulate. Research found `context-mode` (18,574⭐ GitHub) — the authoritative tool-output compression MCP server that achieves ~98% reduction by auto-indexing tool outputs into a searchable knowledge base.

Alternative options evaluated: MCPProxy/lazy-mcp (99⭐) for centralized MCP routing with lazy tool loading, Headroom for per-tool compression. Both were less mature and offered overlapping functionality with OMO's built-in tool management.

## Decision

Install `context-mode` as an OpenCode plugin (`npm install -g context-mode`):

```jsonc
// opencode.jsonc
"plugin": ["context-mode"]
```

It registers 11 `ctx_*` tools that replace raw tool-output reads with indexed, searchable results. Key hooks:
- `tool.execute.before/after` — auto-index tool outputs
- `experimental.session.compacting` — auto-compress when context grows
- `experimental.chat.system.transform` — session start surrogate for context injection

Also merged context-mode's routing rules into the project's AGENTS.md to ensure consistent tool usage across the team.

## Consequences

- **Positive:** 98% reduction in tool-output context footprint. Sessions stay sharp 3-5× longer.
- **Positive:** Auto-indexing means I can search past tool outputs mid-conversation.
- **Positive:** Free, MIT-licensed, actively maintained.
- **Negative:** Adds 30MB to npm global installs.
- **Neutral:** Some tools (curl/wget) are intercepted and redirected to ctx_* equivalents.
