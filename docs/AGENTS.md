# Agent Inventory

Agents are grouped by access tier and call volume. The Go-tier subscription provides access to `opencode-go/*` models with varying request limits. The Zen models (`opencode/*-free`) are free but rate-limited.

## Go High-Volume Tier (30k-31k requests/5hr)

Primary reasoning, code generation, and orchestration agents. These run most frequently so they get the highest rate limits.

| Agent | Model | Reasoning | Fallbacks | Rationale |
|---|---|---|---|---|
| **sisyphus** | `opencode-go/deepseek-v4-flash` | max | mimo-v2.5-free | Main orchestrator — highest volume, needs max rate |
| **hephaestus** | `opencode-go/mimo-v2.5` | max | mimo-v2.5-free | Primary coder — high volume, good quality |
| **worker** | `opencode-go/mimo-v2.5` | low | mimo-v2.5-free | Leaf executor — runs frequently, no deep reasoning needed |
| **atlas** | `opencode-go/mimo-v2.5` | low | mimo-v2.5-free | Plan executor — systematic execution, moderate volume |
| **deep** (cat) | `opencode-go/deepseek-v4-flash` | max | flash-free | Autonomous research — high volume exploration |
| **artistry** (cat) | `opencode-go/deepseek-v4-flash` | high | flash-free | Creative design — frequent iterations |
| **build** (native) | `opencode-go/deepseek-v4-flash` | max | — | Build orchestration — inherits from OpenCode default |

## Go Medium Tier (3k-4k requests/5hr)

Specialized agents called less frequently. They use stronger models because their total volume is lower.

| Agent | Model | Reasoning | Fallbacks | Rationale |
|---|---|---|---|---|
| **oracle** | `opencode-go/minimax-m3` | max | mimo-v2.5-free | Deep reasoning — strongest SWE-bench in tier |
| **review** | `opencode-go/minimax-m3` | low | mimo-v2.5-free | Bug detection — MiniMax M3 strongest at catching issues |
| **momus** | `opencode-go/minimax-m3` | xhigh | deepseek-v4-flash | Plan critic — critical evaluation needs strong model |
| **prometheus** | `opencode-go/qwen3.7-plus` | max | mimo-v2.5-free | Planning — best at structured multi-step plans |
| **metis** | `opencode-go/qwen3.7-plus` | — | minimax-m3 | Analysis — needs structured reasoning |
| **test-writer** | `opencode-go/qwen3.7-plus` | high | mimo-v2.5-free | Test generation — quality matters, volume low |
| **architect** | `opencode-go/deepseek-v4-pro` | max | mimo-v2.5-free | Architecture — best deep reasoning, called rarely |
| **visual-engineering** (cat) | `opencode-go/minimax-m3` | high | flash-free | UI/design — visual reasoning strength |
| **ultrabrain** (cat) | `opencode-go/deepseek-v4-pro` | xhigh | flash-free | Hard logic — deepest reasoning model |
| **unspecified-high** (cat) | `opencode-go/qwen3.7-plus` | high | flash-free | Important tasks — thorough work |

## Zen Free Tier

Simple, high-volume agents that don't need reasoning models.

| Model | Agents | Rationale |
|---|---|---|
| `opencode/mimo-v2.5-free` | explore, quick, unspecified-low, scout | Lightweight discovery, simple edits, lookups |
| `opencode/deepseek-v4-flash-free` | sisyphus-junior, librarian, multimodal-looker, writing, git | General-purpose free tier, good quality at zero cost |

## Notes

- Model concurrency limits: Flash=10, MiMo=10, Qwen3.7=5, MiniMax M3=3, DS V4 Pro=3
- `disabled_providers: {openai, anthropic, google, xai}` prevents fallback to premium-only models
- Go models with $15/mo budget (DS V4 Pro, MiMo V2.5 Pro) assigned to lowest-volume agents only
- All Go-tier agents and categories have fallback_models defined
- 10 auto-rules `.mdc` files augment agent behavior
