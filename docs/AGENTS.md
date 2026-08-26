# Agent Inventory

Agents are grouped by access tier and call volume. The Go-tier subscription provides access to `opencode-go/*` models with varying request limits. The Zen models (`opencode/*-free`) are free but rate-limited.

## Hybrid Privacy Routing

### Sensitive agents — MiMo-V2.5 (privacy-safe)

Consolidated 2026-08-26: sensitive tasks (config, security, full context) route to `opencode-go/mimo-v2.5` (AA Intelligence Index 38, $0.14/$0.28, 30,100 req/5h, zero-retention, no training). Privacy-safe for config/security work.

| Agent                      | Model                   | Fallbacks         | Rationale                            |
| -------------------------- | ----------------------- | ----------------- | ------------------------------------ |
| sisyphus                   | mimo-v2.5               | 5-entry allowlist | Main orchestrator, sees everything   |
| build                      | mimo-v2.5               | 5-entry allowlist | Default agent, edits config          |
| worker                     | mimo-v2.5               | 5-entry allowlist | Fresh-context implementation         |
| oracle                     | mimo-v2.5               | 5-entry allowlist | Debugging, full context              |
| architect                  | mimo-v2.5               | 5-entry allowlist | System design, meta decisions        |
| prometheus                 | mimo-v2.5               | 5-entry allowlist | Planning, full context               |
| metis                      | mimo-v2.5               | 5-entry allowlist | Pre-planning, full context           |
| momus                      | mimo-v2.5               | 5-entry allowlist | Plan review, full context            |
| **ultrabrain** (cat)       | `opencode-go/mimo-v2.5` | 5-entry allowlist | Hard logic — deepest reasoning model |
| **unspecified-high** (cat) | `opencode-go/mimo-v2.5` | 5-entry allowlist | Important tasks — thorough work      |

### Low-sensitivity agents — Muse Spark (cheapest, strongest)

Consolidated 2026-08-26: low-sensitivity tasks (research, exploration, writing) route to `opencode-go/muse-spark-1.2-contributor` (AA Intelligence Index 57, $0.10/$0.20, 45,300 req/5h, Meta trains on data). Intelligence 57 at $0.01/task is unbeatable value.

| Agent              | Model                    | Fallbacks         | Rationale                                     |
| ------------------ | ------------------------ | ----------------- | --------------------------------------------- |
| explore            | muse-spark               | 5-entry allowlist | Code search only                              |
| scout              | muse-spark               | 5-entry allowlist | External docs                                 |
| librarian          | muse-spark               | 5-entry allowlist | External research                             |
| multimodal-looker  | muse-spark               | 5-entry allowlist | Media analysis                                |
| **deep** (cat)     | `opencode-go/muse-spark` | 5-entry allowlist | Autonomous research — high volume exploration |
| **artistry** (cat) | `opencode-go/muse-spark` | 5-entry allowlist | Creative design — frequent iterations         |

## Go budget-frontier — gpt-5.6-luna

| Agent       | Model        | Fallbacks         | Rationale |
| ----------- | ------------ | ----------------- | --------- |
| review      | gpt-5.6-luna | 5-entry allowlist |           |
| test-writer | gpt-5.6-luna | 5-entry allowlist |           |

## Go visual — minimax-m3

| Agent              | Model      | Fallbacks         | Rationale |
| ------------------ | ---------- | ----------------- | --------- |
| visual-engineering | minimax-m3 | 5-entry allowlist |           |

## Zen Free Tier

Simple, high-volume agents that don't need reasoning models.

| Model                     | Agents                                                      | Rationale                                                                                                                                             |
| ------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `opencode/mimo-v2.5-free` | explore, quick, unspecified-low, scout, general             | Lightweight discovery, simple edits, lookups                                                                                                          |
| `opencode/mimo-v2.5-free` | sisyphus-junior, librarian, multimodal-looker, writing, git | General-purpose free tier, good quality at zero cost (2026-08-25: deepseek-v4-flash-free does not exist on platform — consolidated to mimo-v2.5-free) |

## Notes

- Model concurrency limits (2026-08-02; updated 2026-08-26): mimo-v2.5=10, muse-spark=15, deepseek-v4-flash=2, gpt-5.6-luna=2, minimax-m3=2, glm-5.2=2, mimo-v2.5-free=10, qwen3.7-max=0 (budget-blocked)
- `disabled_providers: {openai, anthropic, google, xai}` prevents fallback to premium-only models
- NOT routed (2026-08-02; updated 2026-08-26): deepseek-v4-pro (Apr preview), hy3 (too slow — dethroned), kimi-k2.7-code, kimi-k3, grok-4.5, ox-alpha-free
- fallback_models allowlist (2026-08-03; updated 2026-08-26): every agent/category carries the same 7-model allowlist (opencode-go/mimo-v2.5, opencode-go/muse-spark-1.2-contributor, opencode-go/gpt-5.6-luna, opencode-go/minimax-m3, opencode-go/deepseek-v4-flash, opencode-go/glm-5.2, opencode/mimo-v2.5-free) — suppresses OMO's hardcoded AGENT_MODEL_REQUIREMENTS chain (was claude-opus-5 on transient errors despite disabled_providers; Test 5 is the permanent guard)
- Agent/category models use the `model` key (single string) — validate against installed schema via `scripts/config-schema-check.mjs`
- 11 auto-rules `.mdc` files augment agent behavior
