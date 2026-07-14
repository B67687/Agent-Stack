# Agent Inventory

Agents are grouped by access tier. The Go-tier subscription ($10/month) provides access to `opencode-go/*` models. The Zen models (`opencode/*-free`) are free but rate-limited. Note the distinction: `opencode-go/deepseek-v4-flash` is the PAID Zen model (Go-tier), while `opencode/deepseek-v4-flash-free` is the FREE Zen model. Same base model, different access tier.

## Go-Tier Agents (opencode-go/deepseek-v4-flash)

Primary reasoning, planning, code generation, and architecture agents. Assigned to the paid Go tier because their output directly drives quality.

## Go-Tier Agents (opencode-go/deepseek-v4-flash)

| Agent | ReasoningEffort | Thinking | Fallbacks | Rationale |
|-------|----------------|----------|-----------|-----------|
| **sisyphus** | max | — | flash-free, mimo-v2.5-free | Main orchestrator — max effort for highest quality reasoning
| **prometheus** | max | — | flash-free, mimo-v2.5-free | Planning consultant — decomposes ambiguous work
| **oracle** | max | enabled (8K tokens) | flash-free, mimo-v2.5-free | Deep evaluation — thinking mode for structured analysis
| **architect** | max | enabled (16K tokens) | flash-free | Strategic architecture — thinking for cross-domain pattern transfer
| **plan** | max | — | flash-free | Plan generation — temperature 0.1 for consistency
| **hephaestus** | max | — | flash-free, mimo-v2.5-free | Build/forge agent — complex multi-step implementation
| **worker** | low | — | flash-free | Leaf executor — sufficient for following instructions
| **review** | low | — | flash-free | Code review — temperature 0.1, low effort enough for verification
| **build** | max | — | flash-free | Build orchestration — inherits default model from opencode.jsonc
| **atlas** | low | — | flash-free, mimo-v2.5-free | Research synthesis — systematic exploration needs low reasoning
| **test-writer** | high | — | flash-free | Test generation — writes only to test files
| **artistry** | high | — | flash-free, mimo-v2.5-free | Creative/design agent — aesthetic judgment needs moderate reasoning
| **writing** | high | — | flash-free, mimo-v2.5-free | Prose/documentation agent — clear communication needs moderate reasoning

## Free-Tier Agents (DeepSeek V4 Flash Free + MiMo)

| Tier | Model | Agents | Rationale |
|------|-------|--------|-----------|
| Free Flash | `opencode/deepseek-v4-flash-free` | sisyphus-junior, librarian, metis, momus, writing, git | General-purpose free tier with 79% SWE-bench quality
| Free MiMo | `opencode/mimo-v2.5-free` | explore, multimodal-looker, general, scout | Lightweight discovery and lookup

## Notes
- hyper-sisyphus agent was removed — skill files preserved locally
- librarian: nemotron → deepseek-v4-flash-free for better quality
- scout: deepseek-v4-flash-free → mimo-v2.5-free (raw lookups don't need reasoning)
- prompt_append specializations: 10 specialized agents (general, librarian, metis, momus, oracle, scout, sisyphus-junior, review, test-writer, worker) + 4 team agents (sisyphus, hephaestus, prometheus, atlas) = 14 total with custom prompt_append in oh-my-openagent.jsonc
- context-mode tooling available on sisyphus, librarian, and general agents for context-aware interactions
