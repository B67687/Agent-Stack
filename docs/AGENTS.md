# Agent Inventory

Agents are grouped by access tier and call volume. The Go-tier subscription provides access to `opencode-go/*` models with varying request limits. The Zen models (`opencode/*-free`) are free but rate-limited.

## Model Routing (muse-spark-1.3-primary 2026-09-03)

### Muse Spark — primary for ALL agents

Shifted 2026-09-03: Muse Spark 1.3 (Intelligence 61 xhigh/62 max, ~$0.55/task) primary for ALL agents, 1.2 first fallback. 1.3 is +7 AA, +56% speed vs 1.2 at same $0.10/$0.20 pricing. Privacy: Meta trains — acceptable (no PII).

| Agent                      | Model                    | Fallbacks         | Rationale                             |
| -------------------------- | ------------------------ | ----------------- | ------------------------------------- |
| sisyphus                   | muse-spark               | 6-entry allowlist | Main orchestrator — Intelligence 57   |
| architect                  | muse-spark               | 6-entry allowlist | System design, meta decisions         |
| build                      | muse-spark               | 6-entry allowlist | Default agent, edits config           |
| worker                     | muse-spark               | 6-entry allowlist | Fresh-context implementation          |
| oracle                     | muse-spark               | 6-entry allowlist | Debugging, full context               |
| prometheus                 | muse-spark               | 6-entry allowlist | Planning, full context                |
| metis                      | muse-spark               | 6-entry allowlist | Pre-planning, full context            |
| momus                      | muse-spark               | 6-entry allowlist | Plan review, full context             |
| explore                    | muse-spark               | 6-entry allowlist | Code search only                      |
| scout                      | muse-spark               | 6-entry allowlist | External docs                         |
| librarian                  | muse-spark               | 6-entry allowlist | External research                     |
| multimodal-looker          | muse-spark               | 6-entry allowlist | Media analysis                        |
| sisyphus-junior            | muse-spark               | 6-entry allowlist | Focused executor                      |
| writing                    | muse-spark               | 6-entry allowlist | Documentation, prose                  |
| git                        | muse-spark               | 6-entry allowlist | Git operations                        |
| quick                      | muse-spark               | 6-entry allowlist | Fast trivial tasks                    |
| unspecified-low            | muse-spark               | 6-entry allowlist | Simple tasks                          |
| **ultrabrain** (cat)       | `opencode-go/muse-spark` | 6-entry allowlist | Hard logic — Intelligence 57          |
| **unspecified-high** (cat) | `opencode-go/muse-spark` | 6-entry allowlist | Important tasks — Intelligence 57     |
| **deep** (cat)             | `opencode-go/muse-spark` | 6-entry allowlist | Autonomous research — Intelligence 57 |
| **artistry** (cat)         | `opencode-go/muse-spark` | 6-entry allowlist | Creative design — Intelligence 57     |
| **general** (cat)          | `opencode-go/muse-spark` | 6-entry allowlist | General-purpose — Intelligence 57     |

### Go budget-frontier — gpt-5.6-luna

| Agent       | Model        | Fallbacks         | Rationale    |
| ----------- | ------------ | ----------------- | ------------ |
| review      | gpt-5.6-luna | 6-entry allowlist | Quality gate |
| test-writer | gpt-5.6-luna | 6-entry allowlist | Quality gate |

### Go visual — minimax-m3

| Agent              | Model      | Fallbacks         | Rationale  |
| ------------------ | ---------- | ----------------- | ---------- |
| visual-engineering | minimax-m3 | 6-entry allowlist | Multimodal |

### Zen Free Tier

Last-resort fallback. All free models train on user data.

| Model                     | Usage                | Rationale                            |
| ------------------------- | -------------------- | ------------------------------------ |
| `opencode/mimo-v2.5-free` | Last-resort fallback | Free tier, good quality at zero cost |

## Notes

- Model concurrency limits (2026-09-03): muse-spark-1.3=15, muse-spark-1.2=10, mimo-v2.5=10, gpt-5.6-luna=2, minimax-m3=2, glm-5.2=2, mimo-v2.5-free=10
- `disabled_providers: {openai, anthropic, google, xai}` prevents fallback to premium-only models
- NOT routed: hy3 (too slow), kimi-k2.7-code, kimi-k3, grok-4.5, ox-alpha-free
- fallback_models allowlist (2026-08-03; updated 2026-08-27): every agent/category carries the same 8-model allowlist (opencode-go/muse-spark-1.3-contributor, opencode-go/muse-spark-1.2-contributor, opencode-go/mimo-v2.5, opencode-go/gpt-5.6-luna, opencode-go/minimax-m3, opencode-go/glm-5.2, opencode-go/deepseek-v4-flash, opencode/mimo-v2.5-free) — suppresses OMO's hardcoded AGENT_MODEL_REQUIREMENTS chain (Test 5 is the permanent guard)
- Agent/category models use the `model` key (single string) — validate against installed schema via `scripts/config-schema-check.mjs`
- 11 auto-rules `.mdc` files augment agent behavior
