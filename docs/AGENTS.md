# Agent Inventory

Agents are grouped by access tier and call volume. The Go-tier subscription provides access to `opencode-go/*` models with varying request limits. The Zen models (`opencode/*-free`) are free but rate-limited.

## Model Routing (muse-spark-primary 2026-08-27)

### Muse Spark — primary for all agents (except orchestrator)

Expanded 2026-08-27: Muse Spark (Intelligence 57, $0.01/task) is now primary for ALL agents except sisyphus. Intelligence 57 beats MiMo's 38 on every metric. Privacy: Meta trains on prompts — acceptable for code/architecture work (no PII in agent contexts).

| Agent                      | Model                    | Fallbacks         | Rationale                             |
| -------------------------- | ------------------------ | ----------------- | ------------------------------------- |
| architect                  | muse-spark               | 5-entry allowlist | System design, meta decisions         |
| build                      | muse-spark               | 5-entry allowlist | Default agent, edits config           |
| worker                     | muse-spark               | 5-entry allowlist | Fresh-context implementation          |
| oracle                     | muse-spark               | 5-entry allowlist | Debugging, full context               |
| prometheus                 | muse-spark               | 5-entry allowlist | Planning, full context                |
| metis                      | muse-spark               | 5-entry allowlist | Pre-planning, full context            |
| momus                      | muse-spark               | 5-entry allowlist | Plan review, full context             |
| explore                    | muse-spark               | 5-entry allowlist | Code search only                      |
| scout                      | muse-spark               | 5-entry allowlist | External docs                         |
| librarian                  | muse-spark               | 5-entry allowlist | External research                     |
| multimodal-looker          | muse-spark               | 5-entry allowlist | Media analysis                        |
| sisyphus-junior            | muse-spark               | 5-entry allowlist | Focused executor                      |
| writing                    | muse-spark               | 5-entry allowlist | Documentation, prose                  |
| git                        | muse-spark               | 5-entry allowlist | Git operations                        |
| quick                      | muse-spark               | 5-entry allowlist | Fast trivial tasks                    |
| unspecified-low            | muse-spark               | 5-entry allowlist | Simple tasks                          |
| **ultrabrain** (cat)       | `opencode-go/muse-spark` | 5-entry allowlist | Hard logic — Intelligence 57          |
| **unspecified-high** (cat) | `opencode-go/muse-spark` | 5-entry allowlist | Important tasks — Intelligence 57     |
| **deep** (cat)             | `opencode-go/muse-spark` | 5-entry allowlist | Autonomous research — Intelligence 57 |
| **artistry** (cat)         | `opencode-go/muse-spark` | 5-entry allowlist | Creative design — Intelligence 57     |
| **general** (cat)          | `opencode-go/muse-spark` | 5-entry allowlist | General-purpose — Intelligence 57     |

### Sisyphus — MiMo-V2.5 (orchestrator guard)

Sisyphus stays on MiMo (Intelligence 38, zero-retention, no training) because it's the main orchestrator — sees full context including file paths, user intent, and config. Privacy matters here.

| Agent    | Model     | Fallbacks         | Rationale                          |
| -------- | --------- | ----------------- | ---------------------------------- |
| sisyphus | mimo-v2.5 | 5-entry allowlist | Main orchestrator, sees everything |

### Go budget-frontier — gpt-5.6-luna

| Agent       | Model        | Fallbacks         | Rationale    |
| ----------- | ------------ | ----------------- | ------------ |
| review      | gpt-5.6-luna | 5-entry allowlist | Quality gate |
| test-writer | gpt-5.6-luna | 5-entry allowlist | Quality gate |

### Go visual — minimax-m3

| Agent              | Model      | Fallbacks         | Rationale  |
| ------------------ | ---------- | ----------------- | ---------- |
| visual-engineering | minimax-m3 | 5-entry allowlist | Multimodal |

### Zen Free Tier

Last-resort fallback. All free models train on user data.

| Model                     | Usage                | Rationale                            |
| ------------------------- | -------------------- | ------------------------------------ |
| `opencode/mimo-v2.5-free` | Last-resort fallback | Free tier, good quality at zero cost |

## Notes

- Model concurrency limits (2026-08-27): muse-spark=15, mimo-v2.5=10, gpt-5.6-luna=2, minimax-m3=2, glm-5.2=2, mimo-v2.5-free=10
- `disabled_providers: {openai, anthropic, google, xai}` prevents fallback to premium-only models
- NOT routed: hy3 (too slow), kimi-k2.7-code, kimi-k3, grok-4.5, ox-alpha-free
- fallback_models allowlist (2026-08-03; updated 2026-08-27): every agent/category carries the same 7-model allowlist (opencode-go/muse-spark-1.2-contributor, opencode-go/mimo-v2.5, opencode-go/gpt-5.6-luna, opencode-go/minimax-m3, opencode-go/glm-5.2, opencode-go/deepseek-v4-flash, opencode/mimo-v2.5-free) — suppresses OMO's hardcoded AGENT_MODEL_REQUIREMENTS chain (Test 5 is the permanent guard)
- Agent/category models use the `model` key (single string) — validate against installed schema via `scripts/config-schema-check.mjs`
- 11 auto-rules `.mdc` files augment agent behavior

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

| Model                     | Agents          | Rationale                                            |
| ------------------------- | --------------- | ---------------------------------------------------- |
| `opencode/mimo-v2.5-free` | sisyphus-junior | General-purpose free tier, good quality at zero cost |

## Notes

- Model concurrency limits (2026-08-02; updated 2026-08-26): mimo-v2.5=10, muse-spark=15, gpt-5.6-luna=2, minimax-m3=2, glm-5.2=2, mimo-v2.5-free=10, qwen3.7-max=0 (budget-blocked)
- `disabled_providers: {openai, anthropic, google, xai}` prevents fallback to premium-only models
- NOT routed (2026-08-02; updated 2026-08-26): hy3 (too slow — dethroned), kimi-k2.7-code, kimi-k3, grok-4.5, ox-alpha-free
- fallback_models allowlist (2026-08-03; updated 2026-08-26): every agent/category carries the same 6-model allowlist (opencode-go/mimo-v2.5, opencode-go/muse-spark-1.2-contributor, opencode-go/gpt-5.6-luna, opencode-go/minimax-m3, opencode-go/glm-5.2, opencode/mimo-v2.5-free) — suppresses OMO's hardcoded AGENT_MODEL_REQUIREMENTS chain (was claude-opus-5 on transient errors despite disabled_providers; Test 5 is the permanent guard)
- Agent/category models use the `model` key (single string) — validate against installed schema via `scripts/config-schema-check.mjs`
- 11 auto-rules `.mdc` files augment agent behavior
