# Community AI Agent Configurations — Raw Data Compilation

**Compiled:** 2026-07-06
**Sources:** GitHub, Reddit r/opencodeCLI, Medium, personal blogs
**Status:** All source URLs verified as of compile date

---

## 1. OpenCode + OMO — Full Production Configs

### 1.1 5kahoisaac/opencode-configs (Most Complete Public Reference)

**Source:** https://github.com/5kahoisaac/opencode-configs
**Updated:** 2 weeks ago
**Size:** opencode.json + oh-my-openagent.json

**Providers (5):** oMLX (local), NVIDIA, OpenAI, OpenCode (Zen), Z.AI Coding Plan, GitHub Copilot

**opencode.json Key Settings:**
- `model`: openai/gpt-5.4
- `small_model`: openai/gpt-5.4-mini
- `compaction`: auto true, prune true
- `watcher.ignore`: node_modules, dist, .git, *.lock, *.log, .cache, build, __pycache__, .venv, venv
- `permission`: skill:* allow, todoread allow, todowrite allow
- `enabled_providers`: ["omlx", "nvidia", "openai", "opencode", "zai-coding-plan", "github-copilot"]
- `plugin`: ["@nick-vi/opencode-type-inject@latest", "oh-my-openagent@latest"]
- Local provider: oMLX (http://127.0.0.1:8080/v1) with Gemma 4 26B, Qwen3.6 35B, Qwythos 9B
- GitHub Copilot: whitelist of 9 models (GPT-4.1 through Gemini 3.1 Pro)
- OpenCode Zen: 45-model blacklist to avoid paid models
- MCP: mcp-proxy (remote :8081) + headroom (local)
- **No agents defined in opencode.json** — all agent config in oh-my-openagent.json

**oh-my-openagent.json Key Settings:**
- `sisyphus_agent.default_builder_enabled`: true
- `codegraph`: disabled
- `disabled_mcps`: context7, websearch, ast_grep, grep_app, codegraph (uses MCPProxy instead)
- `team_mode`: enabled with tmux_visualization
- Sisyphus: zai-coding-plan/glm-5.2 max → fallback gpt-5.5 medium → glm-5.1 → big-pickle
- Metis: glm-5.2 max → gpt-5.5 high
- Prometheus: gpt-5.5 high → glm-5.2 max → gemini-3.1-pro high
- Hephaestus: gpt-5.4 medium (ultrawork: gpt-5.5 medium)
- Oracle: gpt-5.5 high → gemini-3.1-pro high → glm-5.2 max → glm-5.1
- Momus: gpt-5.5 xhigh → gemini-3.1-pro high → glm-5.2 max → glm-5.1
- Explore: nvidia/minimaxai/minimax-m3 → minimax-m2.7 → gpt-5.4-mini → gemini-3-flash
- Librarian: same as explore
- Sisyphus-Junior: gpt-5.5 medium → minimax-m3 → minimax-m2.7 → big-pickle
- Categories: visual-engineering → gemini-3.1-pro high, ultrabrain → gpt-5.5 xhigh, deep → gpt-5.5 medium, writing → gpt-5.4-mini, git → gpt-5-mini
- `runtime_fallback`: enabled, retry 400/429/503/529, max 3 attempts, 60s cooldown
- `background_task`: defaultConcurrency 5, staleTimeoutMs 60000, per-provider concurrency (omlx 1, nvidia 3, openai 5, opencode 10, github-copilot 10, zai 10)

### 1.2 joelhooks/opencode-config (Swarm Multi-Agent)

**Source:** https://github.com/joelhooks/opencode-config
**Key Feature:** swarmtools — multi-agent orchestration with outcome-based learning

**Structure:**
```
.
├── opencode.jsonc              # Main config
├── AGENTS.md                   # Workflow instructions + tool preferences
├── plugin/
│   └── swarm.ts                # Multi-agent orchestration plugin
├── agent/                      # Specialized subagents
├── knowledge/                  # Context files (tdd, effect, nextjs, etc.)
└── skills/                     # 7 injectable knowledge packages
```

**Proviers:** Not explicit in config — uses BYOK model.

**opencode.jsonc Key Settings:**
- `model`: openai/gpt-5.2-codex
- `small_model`: openai/gpt-5.2
- `autoupdate`: true
- `formatter`: biome (js/jsx/ts/tsx/json/jsonc)
- `permission.read`: .env, .env.*, .env-* allow
- `permission.external_directory`: allow
- `permission.bash`: git push allow, sudo deny, rm -rf / deny, fork bomb deny
- Plan agent: model same, temp 0.1, write/edit/patch denied, bash * denied (whitelist only git/rg/tree/wc/head/tail/pnpm)
- Security agent: read-only, Snyk tools, write/edit/patch denied
- Test-writer agent: can only write **/*.test.ts, **/*.spec.ts, **/*.test.tsx, **/*.spec.tsx
- Docs agent: model same, temp 0.3, can only write **/*.md, **/*.mdx
- MCP: next-devtools, chrome-devtools, context7 (remote), mcp-server-fetch

### 1.3 gotar/opencode-config (Agent-File Structure)

**Source:** https://github.com/gotar/opencode-config
**Updated:** ~1 week ago

**Structure:**
```
.
├── opencode.jsonc
├── AGENTS.md
├── agent/
│   ├── openagent.md             # Universal primary agent
│   ├── opencoder.md             # Coding specialist
│   └── subagents/
│       ├── code/                # Code-focused (analyst, builder, coder, reviewer, tester)
│       ├── core/                # Core workflow (documentation, planning)
│       └── specialist/          # Domain-specific
└── skills/
```

**Key Feature:** Pure OpenCode agent file pattern (no OMO). Agents defined as .md files with frontmatter in agent/ directory.

---

## 2. Claude Code — Production Configs

### 2.1 haberlah/dotfiles-claude (Gold Standard)

**Source:** https://github.com/haberlah/dotfiles-claude
**Also:** https://medium.com/@haberlah/configure-claude-code-to-power-your-agent-team-90c8d3bca392
**Updated:** February 2026

**Architecture:**
- `dotfiles-as-code` pattern — forkable, setup.sh, git-backed
- 7 optimization priorities: output quality, truncation prevention, safety, etc.
- `CLAUDE.md` + skills + MCPProxy + tmux team mode

**Key Settings:**
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`: 1 (research preview)
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS`: 64000 (reserves 64k for responses)
- `MCP_TIMEOUT` and `MCP_TOOL_TIMEOUT`: separate thresholds
- `alwaysThinkingEnabled`: true (quality gains far outweigh token cost)
- `showTurnDuration`: true (per-turn timing)
- MCP: github-mcp-server (Docker), other MCPs via MCPProxy shared endpoint

### 2.2 zircote/.claude (10-Category Agent Directory)

**Source:** https://github.com/zircote/.claude
**Updated:** February 2026

**Structure:**
```
.claude/
├── CLAUDE.md
├── agents/           # 10 categories, 50+ agents
│   ├── 01-core-development/
│   ├── 02-language-specialists/
│   ├── 03-infrastructure/
│   ├── 04-quality-security/
│   ├── 05-data-ai/
│   ├── 06-developer-experience/
│   ├── 07-specialized-domains/
│   ├── 08-business-product/
│   ├── 09-meta-orchestration/
│   └── 10-research-analysis/
├── skills/
├── commands/
│   └── git/
├── includes/        # Language & framework standards
└── docs/
```

**Key Feature:** Most organized agent directory found. All 50+ agents in `.md` files with YAML frontmatter, categorized with number prefixes.

### 2.3 feiskyer/claude-code-settings

**Source:** https://github.com/feiskyer/claude-code-settings
**Proviers:** LiteLLM proxy (github-copilot backend)

**Key Settings:**
- `model`: opusplan (custom)
- `env.DISABLE_NON_ESSENTIAL_MODEL_CALLS`: 1
- `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`: 1
- `env.CLAUDE_CODE_ATTRIBUTION_HEADER`: 0
- `alwaysThinkingEnabled`: true
- `attribution.commit`: "" (empty — no Sisyphus-style attribution)
- Permissions: allow/deny/ask three-tier system
  - Allow: 4 skills + Bash(codex:*)
  - Deny: rm -rf, .env reads, .ssh, .aws, *credential*, *secret*, *.pem, *.key
  - Ask: sudo, chmod 777, git push --force, git reset --hard, npm publish, eval

### 2.4 citypaul/.dotfiles (Viral CLAUDE.md)

**Source:** https://github.com/citypaul/.dotfiles
**Went viral** for its CLAUDE.md file — development guidelines for AI-assisted programming.
Supporting 40+ coding agents via `skills.sh --agent` flag (Claude Code, Cursor, Codex, Copilot, OpenCode, Gemini CLI, etc.)

### 2.5 Claude Code Config Pack (starmorph.com)

**Source:** https://starmorph.com/config/cf-claude-code-config
CLAUDE.md for global settings or per-project. "Who I Am" + tech stack sections.

---

## 3. Codex CLI — Production Configs

### 3.1 feiskyer/codex-settings

**Source:** https://github.com/feiskyer/codex-settings
**Proviers:** LiteLLM proxy (github-copilot backend)

**config.toml:**
- `model`: gpt-5.4
- `model_provider`: github
- `model_verbosity`: medium
- `approval_policy`: on-request
- `sandbox_mode`: workspace-write
- `model_reasoning_effort`: high
- `features`: skills, unified_exec, shell_snapshot, multi_agent, steer, collaboration_modes, personality, voice_transcription
- MCP servers: claude (mcp serve), chrome-devtools
- TUI status line: 10 fields including model, context remaining, git branch, token usage

**Key Feature:** LiteLLM proxy pattern for multi-provider routing in Codex's config.toml format.

### 3.2 OpenAI Codex CLI Official Docs

**Source:** https://developers.openai.com/codex/config-basic
**References:**
- Config basics (April 23, 2026)
- CLI reference (May 10, 2026)
- https://shipyard.build/blog/codex-cli-cheat-sheet/ (April 13, 2026)
- https://www.digitalapplied.com/blog/codex-cli-deep-dive-config-profiles-sandbox-2026 (May 10, 2026)

**Codex Config Features (config.toml):**
- Profiles system — per-workload configs
- Approval policy: 4 tiers (never / on-failure / untrusted / on-request)
- Sandbox modes: workspace-read, workspace-write, os-level
- Shell environment policy
- Commit attribution toggle
- MCP server config
- Hooks system (pre/post run)
- OpenTelemetry tracing
- AGENTS.md: read by Codex for project instructions

---

## 4. OMO-Slim Variants

### 4.1 alvinunreal/oh-my-opencode-slim

**Source:** https://github.com/alvinunreal/oh-my-opencode-slim
**Key Feature:** Lighter OMO fork with fewer subagents, lower token usage.

### 4.2 Reddit r/opencodeCLI — $20 OMO-Slim config

**Source:** https://www.reddit.com/r/opencodeCLI/comments/1snr3yz/here_is_my_20_omoslim_config/
**Presets-based config structure:**
```json
{
  "preset": "my-mix",
  "presets": {
    "my-mix": {
      "orchestrator": {
        "model": "opencode-go/qwen3.5-plus",
        "variant": "low",
        "skills": ["*"],
        "mcps": []
      },
      "oracle": {
        "model": "opencode-go/glm-5.1",
        "variant": "high",
        "skills": [],
        "mcps": []
      },
      "librarian": {
        "model": "opencode-go/minimax-m2.5",
        "variant": "low",
        "skills": [],
        "mcps": ["websearch", "context7", "grep_app"]
      },
      "explorer": {
        "model": "opencode-go/minimax-m2.7",
        "variant": "low",
        "skills": [],
        "mcps": []
      },
      "designer": {
        "model": "github-copilot/gemini-3.1-pro-preview",
        "variant": "medium",
        "skills": ["agent-browser"],
        "mcps": []
      }
    }
  }
}
```

**Key Pattern:** Per-agent MCP whitelisting (librarian gets websearch + context7 + grep_app, others get none). Variant-based reasoning control.

### 4.3 opensoft/oh-my-opencode

**Source:** https://github.com/opensoft/oh-my-opencode
**Claims:** #1 OpenCode Plugin. Async subagents. Claude Code compatible layer.
**Config location:** `.opencode/oh-my-opencode.json` (project) or `~/.config/opencode/oh-my-opencode.json` (user)

---

## 5. Cost Optimization Patterns

### 5.1 Free-Tier First + Go Subscription Mix

**Pattern from 5kahoisaac:**
- 45-model blacklist prevents accidental paid model usage
- Free default model keeps routine workflows cheap
- Specific agents pinned to premium models only when needed
- Per-provider concurrency limits prevent race conditions

### 5.2 Local-First + Cloud Fallback

**Pattern from 5kahoisaac:**
- oMLX local provider (http://127.0.0.1:8080/v1) for cheap/fast models
- 3 local models: Gemma 4 26B, Qwen3.6 35B, Qwythos 9B
- Concurrency limit 1 for local (prevents GPU OOM)

### 5.3 BYOK Multi-Provider

**Pattern from joelhooks:**
- No paid subscription — uses own API keys
- OpenAI GPT-5.2-codex for heavy work
- Knowledge files instead of MCP for context (free, no API costs)

### 5.4 GitHub Copilot Backend

**Pattern from feiskyer:**
- LiteLLM proxy → GitHub Copilot (flat $10/mo, no per-token costs)
- Same model routing across Codex + Claude Code + OpenCode
- Copilot Pro+Opus: $10/mo for Claude-quality models

---

## 6. Awesome Lists & Indexes

| List | URL | Contents |
|------|-----|----------|
| awesome-opencode/awesome-opencode | https://github.com/awesome-opencode/awesome-opencode | Curated OpenCode tools, setup guide |
| weisser-dev/awesome-opencode | https://github.com/weisser-dev/awesome-opencode | 108 agents, 15 skills, 18 MCP servers, live MCP registry |
| hesreallyhim/awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code | Curated Claude Code resources, subagents, skills |
| VoltAgent/awesome-codex-subagents | https://github.com/VoltAgent/awesome-codex-subagents | 171+ subagent templates for Codex CLI |
| feiskyer/claude-code-settings | https://github.com/feiskyer/claude-code-settings | Claude Code+Codex configs, skills, agents |
| feiskyer/codex-settings | https://github.com/feiskyer/codex-settings | Codex CLI settings, prompts |
| wesammustafa/OpenCode-Everything-You-Need-to-Know | https://github.com/wesammustafa/OpenCode-Everything-You-Need-to-Know | Ultimate OpenCode guide — install to expert |

---

## 7. Key Community Discussion Threads

| Thread | URL | Key Insights |
|--------|-----|--------------|
| "Share your opencode.json" | https://www.reddit.com/r/opencodeCLI/comments/1slpd0z/share_your_opencodejson/ | Requests for example configs, few responses |
| "Share your OMO configs" | https://www.reddit.com/r/opencodeCLI/comments/1so3pqx/share_your_ohmyopenagent_ex_ohmyopencode_configs/ | Multi-provider mixes shared |
| "$20 OMO-slim config" | https://www.reddit.com/r/opencodeCLI/comments/1snr3yz/here_is_my_20_omoslim_config/ | Presets-based, per-agent MCP |
| "OMO config swap TUI" | https://www.reddit.com/r/opencodeCLI/comments/1rrcuwe/i_made_a_tui_app_that_allows_me_to_swap_omo_configs/ | Profile-based symlink config switching |
| "Oh My Opencode config" | https://www.reddit.com/r/opencodeCLI/comments/1q975n5/oh_my_opencode_configuration/ | GLM-4.7-free Sisyphus + Gemini/Antigravity agents |
| Claude Code setup blog | https://freek.dev/3026-my-claude-code-setup | Dotfiles repo under config/claude/ |
| "IMO the OmO agent is crap" | https://www.reddit.com/r/ClaudeCode/comments/1pp2tyw/ohmyopencode_has_been_a_gamechanger/ | Token-heavy, limited, some users revert to vanilla |

---

## 8. Config Patterns Summary by Platform

### OpenCode + OMO (our platform)
| Feature | 5kahoisaac | joelhooks | gotar | Our Config |
|---------|-----------|-----------|-------|-----------|
| # Providers | 5 | 1 | 1 | 2 (Go+Zen/Zen only) |
| Compaction | auto+prune | not set | not set | not set |
| Runtime fallback | yes | no | no | yes |
| MCP strategy | MCPProxy + Headroom | Direct | Direct | Playwright+seq-think+SearXNG |
| Agent file pattern | OMO overrides | .md agent files | .md agent files | OMO overrides |
| Team mode | yes | no | no | yes (tmux) |
| Multi-tier fallbacks | extensive chains | none | none | simple chains |
| ADR/docs | none | AGENTS.md | AGENTS.md | 15 files + 8 ADRs |

### Claude Code
| Feature | haberlah | zircote | feiskyer |
|---------|---------|---------|----------|
| Agent teams | yes (experimental) | not explicit | yes |
| Agent directory | not explicit | 10 categories, 50+ agents | not explicit |
| MCP strategy | MCPProxy | Direct | LiteLLM proxy |
| Permission model | not explicit | not explicit | allow/deny/ask three-tier |
| Attribution | not explicit | not explicit | empty (disabled) |
| Thinking | always on | not explicit | always on |

### Codex CLI
| Feature | feiskyer | Official |
|---------|---------|---------|
| Approval policy | on-request | 4-tier |
| Sandbox | workspace-write | 3-tier |
| Profiles | not explicit | multi-profile |
| Model provider | LiteLLM proxy | OpenAI native |

---

## 9. Notable Gaps vs Our Setup

| Capability | Community | Us |
|-----------|-----------|----|
| Comprehensive ADR/decision log | None | 8 ADRs |
| Config documentation repo | None (3 partial) | 15 files |
| Incident log | None | INCIDENTS.md |
| Two-file DRY split | None | Done |
| Auto backup | None | cron-driven |
| Health check script | None | health-check.sh |
| Project memory instruction | None | In prompt |
| Model tiering with free-tier first | 5kahoisaac (partial) | Done |
| Per-agent MCP whitelisting | OMO-slim only | Not yet |
| Compaction auto | 5kahoisaac only | Not enabled |
| LiteLLM multi-provider proxy | feiskyer only | Not set up |
| Pre-commit gate | zircote (partial) | Done |
| Context-mode compression | Not seen | Done (removed) |
| Harness self-improvement loop | Self-Harness paper | Manual only |

---

*End of compilation. All URLs verified 2026-07-06.*
