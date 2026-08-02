# Agent Inventory

Agents are grouped by access tier and call volume. The Go-tier subscription provides access to `opencode-go/*` models with varying request limits. The Zen models (`opencode/*-free`) are free but rate-limited.

## Go Tier — deepseek-v4-flash workhorse

Consolidated 2026-08-02: the entire paid text stack routes to `opencode-go/deepseek-v4-flash` (official 0731 build — re-post-trained Jul 31 2026, TB2.1 82.7, "far exceeding V4-Pro-Preview" per DeepSeek; $0.14/$0.28, $60/mo pool). Only two slots deviate: review/test-writer (gpt-5.6-luna, low-reasoning budget lane) and visual-engineering (minimax-m3, the sole image/video-capable slot).

| Agent | Model | Fallbacks | Rationale |
|---|---|---|---|
| sisyphus | deepseek-v4-flash | 5-entry allowlist | |
| build | deepseek-v4-flash | 5-entry allowlist | |
| hephaestus | deepseek-v4-flash | 5-entry allowlist | |
| worker | deepseek-v4-flash | 5-entry allowlist | |
| atlas | deepseek-v4-flash | 5-entry allowlist | |
| oracle | deepseek-v4-flash | 5-entry allowlist | |
| architect | deepseek-v4-flash | 5-entry allowlist | |
| prometheus | deepseek-v4-flash | 5-entry allowlist | |
| metis | deepseek-v4-flash | 5-entry allowlist | |
| momus | deepseek-v4-flash | 5-entry allowlist | |
| **deep** (cat) | `opencode-go/deepseek-v4-flash` | 5-entry allowlist | Autonomous research — high volume exploration |
| **artistry** (cat) | `opencode-go/deepseek-v4-flash` | 5-entry allowlist | Creative design — frequent iterations |
| **ultrabrain** (cat) | `opencode-go/deepseek-v4-flash` | 5-entry allowlist | Hard logic — deepest reasoning model |
| **unspecified-high** (cat) | `opencode-go/deepseek-v4-flash` | 5-entry allowlist | Important tasks — thorough work |

## Go budget-frontier — gpt-5.6-luna

| Agent | Model | Fallbacks | Rationale |
|---|---|---|---|
| review | gpt-5.6-luna | 5-entry allowlist | |
| test-writer | gpt-5.6-luna | 5-entry allowlist | |

## Go visual — minimax-m3

| Agent | Model | Fallbacks | Rationale |
|---|---|---|---|
| visual-engineering | minimax-m3 | 5-entry allowlist | |

## Zen Free Tier

Simple, high-volume agents that don't need reasoning models.

| Model | Agents | Rationale |
|---|---|---|
| `opencode/mimo-v2.5-free` | explore, quick, unspecified-low, scout, general | Lightweight discovery, simple edits, lookups |
| `opencode/deepseek-v4-flash-free` | sisyphus-junior, librarian, multimodal-looker, writing, git | General-purpose free tier, good quality at zero cost |

## Notes

- Model concurrency limits (2026-08-02; qwen3.7-plus removed 2026-08-04): deepseek-v4-flash=8, GPT-5.6-luna=2, MiniMax M3=2, Flash-free=5, MiMo-free=10, Qwen3.7-max=0 (budget-blocked)
- `disabled_providers: {openai, anthropic, google, xai}` prevents fallback to premium-only models
- NOT routed (2026-08-02): deepseek-v4-pro (Apr preview — dominated by flash 0731 official), mimo-v2.5 (Xiaomi — same price as flash, weaker), kimi-k2.7-code, kimi-k3, grok-4.5, glm-5.2, hy3
- fallback_models allowlist (2026-08-03): every agent/category carries the same 5-model allowlist (opencode-go/deepseek-v4-flash, gpt-5.6-luna, minimax-m3, deepseek-v4-flash-free, mimo-v2.5-free) — suppresses OMO's hardcoded AGENT_MODEL_REQUIREMENTS chain (was claude-opus-5 on transient errors despite disabled_providers; Test 5 is the permanent guard)
- Agent/category models use the `model` key (single string) — validate against installed schema via `scripts/config-schema-check.mjs`
- 11 auto-rules `.mdc` files augment agent behavior
