# ADR-009: Config Optimization Session (Jul 9-10)

## Status

Accepted

## Context

Multi-day deep optimization session covering performance, intent clarification, OMO features, community pattern adoption, and repo restructuring.

## Decisions

### 1. Performance: Sisyphus reasoningEffort removed
Sisyphus is an orchestrator — deep thinking is wasted on delegation decisions. Removed `reasoningEffort: "max"` to default behavior, cutting thought latency.

### 2. Performance: ralph max_iterations 200→20
200 iterations kept the continuation loop running long after work was done. Reduced to 20 — enough for multi-step tasks, stops promptly on completion.

### 3. Performance: prompt_append trimmed ~70%
Redundant sections (search tool ordering, parallel delegation boilerplate) removed. Kept: verification, pre-commit gate, project memory, and the new Clarification Protocol.

### 4. Intent Clarification Protocol
Research showed 80-pt accuracy penalty on ambiguous tasks when agents guess instead of asking. Added Clarification Protocol to Sisyphus prompt_append. OMO sub-agents have their own built-in clarification (Metis, Plan, Oracle) but Sisyphus lacked it.

### 5. 11 config features enabled
All validated against authoritative sources (OMO schema, GitHub, community):
- `task_system`, `aggressive_truncation`, `preemptive_compaction`
- `truncate_all_tool_outputs`, `safe_hook_creation`, `agent_order`
- `keyword_detector`, `model_fallback`, `auto_update`, `telemetry: false`
- `git` custom category

### 6. Bug found: config values nested inside websearch
`auto_update`, `telemetry`, `model_fallback` were accidentally placed inside the `websearch` object instead of at top level.

### 7. Attestation injection: physically removed from dist
All 6 injection strings (3 co-auth, 3 ultra) removed from compiled OMO JS. 3-layer defense: config override + git hook + dist patching.

### 8. Repo restructured: settings dump is primary purpose
Redacted configs added to root. Research/ added with community analysis. Single commit forever on main.

### 9. auto_update disabled
Caused npm registry ping on every startup, adding latency. Disabled — can update manually via `omo-install upgrade`.

## Consequences

- Faster thought response from Sisyphus (reasoningEffort default)
- Continuation loop stops promptly (ralph 20)
- No attribution injection can reach commits (3-layer defense)
- Repo serves dual purpose: settings dump + documentation
- `omo-install` script handles future OMO updates automatically
