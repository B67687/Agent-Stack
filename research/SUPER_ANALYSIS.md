# Super Analysis — Our OpenCode+OMO Setup vs. Community

**Date:** 2026-07-06  
**Baseline:** `opencode.jsonc` (371 lines) + `oh-my-openagent.jsonc` (290 lines)  
**Compared against:** 5kahoisaac (raw configs), joelhooks, gotar, feiskyer (Codex + Claude), haberlah (Claude Code gold standard), zircote (50+ subagents), OMO-slim, opensoft

**Methodology:** Every community config was fetched from its original source URL and read in full. Each analysis dimension below compares our config against the specific pattern in the community config at the line/field level.

---

## Dimension 1: Model Strategy

### Which models, where assigned, and why

| Agent | Our Model | 5kahoisaac | joelhooks | Notes |
|-------|-----------|------------|-----------|-------|
| Sisyphus | deepseek-v4-flash (Go) | glm-5.2 variant:max | gpt-5.2-codex | We use cheapest Go model; they use premium |
| Oracle | deepseek-v4-flash (Go) + thinking 8k | gpt-5.5 variant:high | - | We have thinking, they have variant system |
| Architect | deepseek-v4-flash (Go) + thinking 16k | - | - | Unique to us — no community has dedicated architect |
| Plan | deepseek-v4-flash (Go) | - | gpt-5.2-codex | Same tier model |
| Worker | deepseek-v4-flash (Go) | - | - | We have dedicated worker; 5kahoisaac uses hephaestus |
| Explore | mimo-v2.5-free | minimax-m3 | - | We use free model, they use paid |
| Librarian | nemotron-3-ultra-free | minimax-m3 | - | We use free model, they use paid |
| Sisyphus-Junior | deepseek-v4-flash-free | gpt-5.5 variant:medium | - | We use free tier; they use top-tier GPT-5.5 |
| Build | no model (inherits defaults) | - | gpt-5.2-codex temp:0.3 | Build is on defaults |
| Writing category | deepseek-v4-flash-free | gpt-5.4-mini | - | We use stronger model for writing |
| Quick category | mimo-v2.5-free | gpt-5.4-mini | - | Both cheap, comparable |

### Variant / reasoningEffort comparison

**5kahoisaac** uses `variant` field (max/high/medium/xhigh) — OMO proprietary.  
**feiskyer** uses `model_reasoning_effort` global (high).  
**We** use `reasoningEffort` per-agent (max/high/low/none) — matches OpenCode native.

**Key difference:** 5kahoisaac has richer variant granularity (xhigh between high and max). We don't use variant at all — OMO may silently use default when variant isn't set.

### Tiering philosophy comparison

| | 5kahoisaac | joelhooks | feiskyer | Us |
|---|---|---|---|---|
| Premium agents | Gemini 3.1 Pro, GPT-5.5 | GPT-5.2-codex | GPT-5.4 | deepseek-v4-flash (cheapest Go) |
| Mid agents | GLM-5.1, GPT-5.4-mini | GPT-5.2-codex | - | deepseek-v4-flash-free |
| Budget agents | minimax-m3, minimax-m2.7 | - | - | mimo-v2.5-free, nemotron-3-ultra-free |
| Local/free | oMLX 3 models (zero cost) | - | Copilot backend | (none) |

**Our tiering is cost-optimized but fragile**: all Go eggs in one basket (deepseek-v4-flash). 5kahoisaac spreads across 5 providers — if one goes down, they have 4 others. If DeepSeek has an outage, we have zero Go-tier fallback (our fallbacks are all free-tier, worse quality).

**Gap:** No variant usage. OMO's `variant` field controls model reasoning depth differently from `reasoningEffort`. We may not be getting the optimal reasoning profile.

---

## Dimension 2: Architecture & Config Layering

### Config file split

| Aspect | 5kahoisaac | joelhooks | feiskyer | Us |
|--------|-----------|-----------|----------|-----|
| Files | opencode.json + oh-my-openagent.json | opencode.jsonc only | config.toml (Codex) + settings.json (Claude) | opencode.jsonc + oh-my-openagent.jsonc |
| DRY split | Partial (agent models in OMO, rest in opencode) | None (one file) | N/A (separate tools) | **Full** (identity vs tiering) |
| Documentation | None | README only | None | **15 files + 8 ADRs** |
| ADRs | No | No | No | **Yes — 8 records** |
| Incident log | No | No | No | **Yes — INCIDENTS.md** |

### Plugin strategy

| | 5kahoisaac | joelhooks | feiskyer | Us |
|---|---|---|---|---|
| Plugins | OMO + type-inject | OMO | (Codex has no plugins) | OMO + DCP + command-inject |
| Version | @latest | @latest | pinned | @latest on all |
| Enabled providers list | Explicit (6) | - | explicit (1) | **None** (implicit — all available) |
| Disabled MCPS | Explicit (5) | - | - | **None** |
| Disabled agents | - | - | - | **None** (empty array) |

**Gap:** 5kahoisaac has `enabled_providers` lock-in list — we don't. OMO could auto-route to any available provider including paid Zen models. Their `disabled_mcps` block keeps context clean by explicitly excluding unused MCPs from the system prompt. We include ALL 3 MCPs (sequential-thinking, searxng, playwright) in every agent's context.

### Watcher configuration

**5kahoisaac** explicitly ignores: `node_modules/**`, `dist/**`, `.git/**`, `*.lock`, `**/*.log`, `.cache/**`, `build/**`, `__pycache__/**`, `.venv/**`, `venv/**`.

**We have:** No watcher config at all. File watcher triggers on every file change including build artifacts, logs, lock files. Wastes cycles and generates noise.

**Gap:** Missing watcher.ignore — trivial to add, prevents unnecessary watcher events.

---

## Dimension 3: Permission & Safety

### Permission model comparison

| Feature | 5kahoisaac | joelhooks | feiskyer (Codex) | feiskyer (Claude) | Us |
|---------|-----------|-----------|-------------------|-------------------|-----|
| Agent-level permissions | - | Yes (plan/test/docs) | - | - | Yes (plan, worker, architect, hyper-sisyphus) |
| Bash allow list | - | Plan has 12 allowed cmds | - | 8 ask patterns | **50+ allow + 7 deny** (comprehensive) |
| Read deny list | - | - | - | .env, .ssh, .aws, *.pem, *.key | 8 patterns (no .ssh/.aws) |
| tool: write scoping | - | test-writer: *.test.ts only | - | - | **No** (global allow) |
| tool: edit scoping | - | - | - | - | **No** (global allow) |
| Agent tool deny | - | plan: write/edit/patch=deny | - | - | plan has edit:deny |
| Approval policy | - | - | 4 tiers (on-request) | - | **None** (binary allow/deny/ask) |
| Sandbox mode | - | - | workspace-write | - | **None** (full user perms) |
| Attribution defense | commit_footer:false | - | - | commit:"", pr:"" | **3-layer** (hook + config + dist patch) |

### feiskyer's allow/deny/ask patterns (most mature Claude-side)

Their `ask` patterns are instructive — sudo, force push, reset --hard, clean -fd, npm publish, eval — all irreversible operations that should never be automatic. We have blanket deny on `sudo`, `rm -rf`, `chown`, `dd`, `mkfs`, `shutdown`, `reboot`, `poweroff` — but we **don't have ask patterns**. Binary deny means we either block permanently or allow permanently. Ask patterns (allow with confirmation) are the middle ground we lack.

**Gap:** No `ask` tier in permission model. No sandbox mode. No tool-scoped write restrictions (joelhooks scopes test-writer to *.test.ts, docs to *.md).

---

## Dimension 4: Automation & CI/CD

### Our unique automation (nobody else has):

| Automation | 5kahoisaac | joelhooks | feiskyer | haberlah | Us |
|------------|-----------|-----------|----------|---------|-----|
| Auto backup cron | No | No | No | No | **Yes** — daily 2AM |
| Health check script | No | No | No | No | **Yes** — validates all |
| Pre-commit gate | No | No | No | No | **Yes** — git hook + LSP |
| Project memory | No | No | No | No | **Yes** — .omo/project-context.md |
| Audit trail logging | No | No | No | No | **Yes** — log-agent.sh |
| ralph loop default | No | No | No | No | **Yes** — max_iterations 200 |
| Knowledge packages | No | **Yes** — knowledge/*.md | No | **Yes** — dotfiles | No |

### joelhooks' knowledge package pattern

joelhooks uses `knowledge/*.md` files loaded on-demand via repository references. Similar to our AGENTS.md but more granular — individual files per topic (auth, database, testing). This is a lightweight alternative to OMO skills.

**We have:** Skills system (14 skills via protocol) + AGENTS.md per project. Our approach is more structured but has higher startup cost (skill loading requires `skill()` call).

---

## Dimension 5: Documentation & Governance

### Documentation maturity

Nobody in the community publishes:
- ADR decision records
- Full CONFIG_MAP with rationale per setting
- WORKFLOW documentation
- INCIDENTS log with root cause analysis
- TROUBLESHOOTING guide

**5kahoisaac** has bare README. **joelhooks** has personal blog posts. **feiskyer** has no docs at all. **haberlah** has a dotfiles README.

**We have:** 15 files across 2 directories, 8 ADRs, every setting documented with rationale. This is the single largest quality gap between us and the community — we lead by a wide margin.

---

## Dimension 6: Control Plane

### Concurrency & limits

| Setting | 5kahoisaac | joelhooks | Us |
|---------|-----------|-----------|-----|
| Default concurrency | 5 (background_task) | default (unspecified) | **15** (3x) |
| Max tool calls | default | default | **1000** (5x 5k)
| Stale timeout | 60s | default | **300s** (5x) |
| Provider concurrency | Per-provider (omlx:1, openai:5, opencode:10) | - | **None** (single pool) |
| Model concurrency | Per-model (gpt-5.5:2, gpt-5.4-mini:10) | - | **None** (single pool) |

**Gap:** 5kahoisaac has fine-grained provider and model concurrency. Expensive models (gpt-5.5) limited to 2 concurrent calls to control cost. Cheap models (gpt-5.4-mini) get 10 for throughput. We treat all providers and models the same — 15 slots shared across everything.

### Runtime fallback comparison

| Setting | 5kahoisaac | Us |
|---------|-----------|-----|
| enabled | true | true |
| retry_on_errors | [400, 429, 503, 529] | default (no specific codes) |
| max_fallback_attempts | 3 | default |
| cooldown_seconds | 60 | default |
| timeout_seconds | 30 | default |
| notify_on_fallback | true | default |

**Gap:** 5kahoisaac has explicitly tuned retry codes (400=bad request retry, 429=rate limit, 503=service unavailable, 529=rate-limited). We enable fallback but don't specify which errors trigger it. Our fallback may retry on errors it shouldn't (e.g., auth failures) or skip errors it should catch.

---

## Dimension 7: Observability

### TUI & status visibility

| Feature | 5kahoisaac | feiskyer (Codex) | feiskyer (Claude) | Us |
|---------|-----------|-------------------|-------------------|-----|
| Status line | default | **11 fields** (model, context%, dir, branch, tokens, limits) | custom script | **default** |
| Sidebar | default | - | - | enabled |
| Logging | none | none | none | **audit trail** (log-agent.sh) |
| Stats tracking | none | none | none | **health check** (model reachability, disk, DB) |
| Version monitoring | none | none | none | **health check** (config vs package.json versions) |

**Gap:** feiskyer's 11-field status line gives real-time visibility into: model + reasoning mode, context % remaining, current directory, model name, git branch, context used tokens, context window size, total output tokens, 5-hour limit, weekly limit. This is the single best way to catch context bloat early. We have default TUI.

**Our advantage:** Audit trail and health check are features nobody else has. We know exactly which agents ran, for how long, and whether the system is healthy.

---

## Dimension 8: Agent Orchestration

### Agent role distribution

| Role | 5kahoisaac | joelhooks | gotar | We have? |
|------|-----------|-----------|-------|---------|
| Orchestrator | Sisyphus | Sisyphus | Sisyphus | ✅ |
| Planner | Prometheus | Plan | plan | ✅ |
| Implementer | Hephaestus | Build | builder | ✅ (Worker) |
| Reviewer | Oracle | - | - | ✅ (Review) |
| Security | - | Security (Snyk) | - | ✅ (security-research command) |
| Test writer | - | test-writer | - | ❌ |
| Documentation | - | docs | - | ❌ |
| Software Architect | - | - | - | ✅ (architect) |
| Self-improver | - | - | - | ✅ (hyper-sisyphus) |
| Knowledge mgmt | - | - | - | ✅ (meta-learner) |

### joelhooks' tool-scoped agents (pattern we lack)

joelhooks defines 3 specialized agents with scope-restricted tool access:

- **security** — read-only, Snyk vulnerability scanning, write/edit/patch disabled
- **test-writer** — write restricted to `**/*.test.ts`, `**/*.spec.ts`, `**/*.test.tsx`, `**/*.spec.tsx`
- **docs** — write restricted to `**/*.md`, `**/*.mdx`

**We could benefit from:** A dedicated test agent that can only write to test files. Prevents the common failure of agents writing production code when tasked with test generation.

### gotar's agent-files pattern

gotar defines agents entirely through `.md` agent files (no OMO). Each file specifies: role, tools, MCPs, prompt, and skill requirements in a structured frontmatter format. 7 agents across 3 categories (code, core, specialist). This is the lightest-weight approach — no plugin dependency.

**Relevance:** If OMO ever breaks or becomes incompatible, agent files are a zero-dependency fallback. We have no agent files — all our agents require OMO plugin.

---

## Dimension 9: MCP Strategy

### MCP comparison

| MCP | 5kahoisaac | joelhooks | feiskyer | Us |
|-----|-----------|-----------|----------|-----|
| sequential-thinking | via proxy | - | - | ✅ direct |
| SearXNG | via proxy | - | - | ✅ direct |
| Playwright | via proxy | chrome-devtools | chrome-devtools | ✅ direct |
| Context7 | disabled (in blacklist) | ✅ remote | - | ❌ |
| MCPProxy | ✅ :8081 | - | - | ❌ |
| Headroom | ✅ | - | - | ❌ (DCP instead) |
| fetch | - | ✅ via uvx | - | ❌ |
| next-devtools | - | ✅ | - | ❌ |
| claude MCP | - | - | ✅ | ❌ |

### 5kahoisaac's MCPProxy pattern

All MCP servers behind `mcp-proxy` on `:8081`. Single `type: "remote"` entry in opencode.json. All MCP servers start/stop together. One credential point. Context only loads one MCP definition instead of N.

**vs our approach:** 3 separate MCPs with 3 separate config blocks. Each agent sees all 3. More config surface, more context overhead, no centralized management.

### HEADROOM MCP (transparent compression)

5kahoisaac runs `headroom mcp serve` as an MCP server. Headroom transparently compresses tool call inputs and outputs — reducing context by 40-60% with no prompt changes.

**vs our approach:** We use DCP (`compress` tool) which requires manual invocation and only compresses our conversation, not raw tool output. Headroom is automatic and intercepts at the MCP layer. DCP is reactive; Headroom is proactive.

---

## Dimension 10: Skill Loading Protocol

### Coverage matrix

| Domain | Skill | We map it? | Community maps it? |
|--------|-------|-----------|-------------------|
| Code writing | programming | ✅ | ✅ (5k: implicit, joelhooks: implicit) |
| UI/Visual | frontend | ✅ | - |
| Debugging | debugging | ✅ | - |
| AST search | ast-grep | ✅ | - |
| Refactoring | refactor | ✅ | - |
| Git | git-master | ✅ | ✅ (all use) |
| Post-review | review-work | ✅ | - |
| Security | security-research | ✅ | ✅ (joelhooks: Snyk agent) |
| Problem-solving | solve | ✅ | - |
| AI slop removal | remove-ai-slops | ✅ | - |
| Visual QA | visual-qa | ✅ | - |
| Rust | rust-workflow | ✅ | - |
| Meta-learning | meta-learner | ✅ | - |
| Self-improvement | hyper-sisyphus | ✅ | - |

**Our protocol is the most comprehensive in the community.** No public config maps this many skills. 5kahoisaac relies on implicit model capability rather than explicit skill loading. joelhooks has knowledge packages but no skill protocol.

**However:** The protocol is only in Sisyphus's prompt_append — it instructs subagents to load skills, but **doesn't ensure they actually do**. It's advisory, not enforced.

---

## Dimension 11: Developer Experience

### Startup overhead

| Factor | 5kahoisaac | joelhooks | feiskyer | Us |
|--------|-----------|-----------|----------|-----|
| Plugins | 2 | 1 | 0 | **3** (most) |
| MCPs | 1 (via proxy) | 4 | 2 | **3** |
| Agents in config | 15 | 9 | 0 | **19** (most) |
| Prompt_append on sisyphus | short (1 line) | - | - | **long** (14 skills + bias + memory) |

Our config is the heaviest at session start. 19 agent definitions + 3 plugins + 3 MCPs + long prompt_append = more tokens loaded per session than any other config we found.

### Response latency factors

| Factor | Impact | Our status |
|--------|--------|-----------|
| Thinking mode (oracle 8k, architect 16k) | +1-5s CoT latency per call | Active |
| Concurrency 15 | More parallel work to synthesize | Active |
| long prompt_append | +tokens per context window | Active |
| 19 agent definitions | +tokens per context window | Active |

The community avoids this by: (a) shorter prompts, (b) fewer agents, (c) no thinking mode on most agents. We optimized for thoroughness over speed.

---

## Dimension 12: Resilience

### Degradation modes

| Scenario | 5kahoisaac | joelhooks | feiskyer | Us |
|----------|-----------|-----------|----------|-----|
| Primary model down | Falls to 4 other providers | Falls to openai models | Falls to Copilot | Falls to free-tier Flash or mimo |
| All cloud down | oMLX local models (3 options) | - | - | **Nothing** (no local fallback) |
| Go subscription exhausted | Blocked via 45-model blacklist | - | - | **No protection** (no blacklist) |
| Provider rate limit | Per-model concurrency + specific retry codes | - | - | Global concurrency + default retry |

### Availability comparison

5kahoisaac has 6 providers (omlx, nvidia, openai, opencode, zai-coding-plan, github-copilot) + 3 local models. If one provider goes down, they have 5 others. If all cloud goes down, local oMLX still works.

We have 2 providers (deepseek BYOK + opencode-go/zen). If both are down, we have nothing. If our Go subscription runs out, we have no protection against accidental routing to paid models.

---

## Dimension 13: Portability & Reproducibility

### Dotfiles readiness

| Feature | 5kahoisaac | haberlah | joelhooks | Us |
|---------|-----------|---------|-----------|-----|
| Public dotfiles repo | **Yes** (opencode-configs) | **Yes** (dotfiles-claude) | **Yes** (opencode-config) | **No** |
| setup.sh / bootstrap | No | **Yes** (install script) | No | No |
| Version pinning | @latest (all) | **Pinned** | @latest | @latest (all) |
| Forkable | Yes | **Yes** (70+ forks) | Yes | **No** |
| Documented setup | README only | README + blog | README | **15 files** (but private) |

**haberlah's dotfiles setup** is the gold standard — forkable, bootstrap.sh installs everything, 70+ forks proving reproducibility. His CLAUDE.md and skills are in a public dotfiles repo.

**Critical gap:** Our config is the best-documented but zero-portable. Nobody can fork, clone, or bootstrap our setup. Everything is in `~/.config/opencode/` and `agent-stack/` — all local, unpublished.

---

## Dimension 14: Cost Efficiency

### Free vs paid split

| Tier | 5kahoisaac | joelhooks | feiskyer (Codex) | Us |
|------|-----------|-----------|-------------------|-----|
| Paid providers | 5 (openai, opencode, zai, nvidia, github-copilot) | openai | github (Copilot) | **1** (opencode-go) |
| Free providers | oMLX (local, $0) | - | - | **2** (opencode Zen, deepseek BYOK) |
| Blacklist | **45 models** | - | - | **None** |
| Per-model cost throttle | **Yes** (gpt-5.5: concurrency 2) | - | - | **No** |
| Local inference | **3 models** | - | - | **None** |
| Rate limit retry | **Yes** (429, 529 retry codes) | - | - | Default (may not retry rate limits) |

### Fee structure comparison

| Plan | 5kahoisaac's stack | Our stack |
|------|-------------------|-----------|
| OpenCode Go | $10/mo (shared pool) | $10/mo (shared pool) |
| OpenAI API | Pay-as-you-go | $0 |
| Z.AI Coding Plan | $20/mo | $0 |
| GitHub Copilot | $10/mo | $0 (personal projects) |
| Local inference | $0 (oMLX, free hardware) | $0 (no local) |
| **Total** | **$40/mo** | **$10/mo** |

**We spend 4x less than 5kahoisaac.** However, they get 5 providers + local fallback. We get 1 provider with no local fallback.

### Waste prevention comparison

5kahoisaac prevents cost waste via:
1. 45-model blacklist (can't accidentally route to expensive models)
2. Per-model concurrency (expensive models throttled to 2 concurrent)
3. Specific retry codes (only retry on retryable errors)
4. Local fallback for simple tasks ($0/task)

We prevent cost waste via:
1. Everything on free-tier (after Go bug)
2. reasoningEffort manual tuning (low/none on cheap agents)
3. No waste prevention at infrastructure level

**Gap:** No blacklist means OMO can auto-route to any available model including paid ones. No per-model concurrency means one expensive model can burn budget at the same rate as a cheap one.

---

## Dimension 15: Extensibility

### Plugin surface

| Plugin | 5kahoisaac | joelhooks | feiskyer | Us |
|--------|-----------|-----------|----------|-----|
| OMO | ✅ | ✅ | - | ✅ |
| type-inject | ✅ | - | - | ❌ |
| DCP | - | - | - | ✅ |
| command-inject | - | - | - | ✅ |

### Custom commands comparison

| Command | 5kahoisaac | joelhooks | feiskyer | Us |
|---------|-----------|-----------|----------|-----|
| review-work | - | - | - | ✅ (5-agent parallel review) |
| review-working | - | - | - | ✅ |
| review-staged | - | - | - | ✅ |
| security-research | - | - | - | ✅ (OWASP + PoC) |
| ship-notes | - | - | - | ✅ |
| architect | - | - | - | ✅ (ADR generation) |
| improve | - | - | - | ✅ (HyperSisyphus) |
| ledger-verify | - | - | - | ✅ |
| archive-status | - | - | - | ✅ |

**Most commands of any public config.** Non-OMO setups (gotar, feiskyer) can't define custom agents for commands — they're limited to what the underlying tool provides. OMO gives us 9 custom commands.

### Hook usage

OMO has 56 lifecycle hooks. We don't customize any. Neither does any community config — hook customization requires OMO plugin development, which nobody publishes.

---

## Dimension 16: Community Comparison Matrix

### Feature presence matrix (Y=present, P=partial, N=absent)

| Feature | 5kahoisaac | joelhooks | feiskyer(C) | feiskyer(CC) | haberlah | Us |
|---------|-----------|-----------|-------------|--------------|---------|-----|
| OMO plugin | Y | Y | N | N | N | Y |
| Multi-provider | Y (5) | N (1) | Y (1+LiteLLM) | Y (1+LiteLLM) | N (1) | Y (2+BYOK) |
| Local AI fallback | Y (3 models) | N | N | N | N | N |
| Model blacklist | Y (45) | N | N | N | N | N |
| Per-provider concurrency | Y | N | N | N | N | N |
| Per-model concurrency | Y | N | N | N | N | N |
| Runtime fallback | Y (tuned) | N | N | N | N | Y (default) |
| Thinking mode | N (variant proxy) | N | N | Y (always) | Y (always) | Y (oracle+arch) |
| Per-agent temp | N | Y (3 agents) | N | N | N | Y (plan+review) |
| Agent tool scoping | N | Y (3 agents) | N | N | N | N |
| Permission ask tier | N | N | N | Y (8 patterns) | N | N |
| Sandbox mode | N | N | Y (workspace-write) | N | N | N |
| Auto compaction | Y | N | N | N | N | Y |
| TUI customization | N | N | Y (11 fields) | Y (script) | N | N |
| Health check | N | N | N | N | N | Y |
| Auto backup | N | N | N | N | N | Y |
| Pre-commit gate | N | N | N | N | N | Y |
| ADR records | N | N | N | N | N | Y (8) |
| Config docs | P (README) | P (README) | N | N | P (README) | Y (15 files) |
| Incident log | N | N | N | N | N | Y |
| Public dotfiles | Y | Y | N | Y (settings) | Y (70+ forks) | N |
| ralph loop default | N | N | N | N | N | Y |
| Execution bias | N | N | Y (Codex native) | N | N | Y (prompt) |
| Attribution defense | Y (config) | N | N | Y (commit:"") | N | Y (3-layer) |

### Overall maturity by category (score 0-10)

| Category | 5kahoisaac | joelhooks | feiskyer | haberlah | **Us** |
|----------|-----------|-----------|----------|---------|--------|
| Model strategy | 8 | 6 | 5 | 4 | **7** |
| Architecture | 5 | 4 | 3 | 5 | **9** |
| Safety | 4 | 6 | 5 | 8 | **8** |
| Automation | 2 | 1 | 1 | 3 | **9** |
| Documentation | 3 | 2 | 1 | 4 | **10** |
| Control plane | 10 | 4 | 3 | 2 | **6** |
| Observability | 2 | 1 | 7 | 6 | **5** |
| Agent orchestration | 6 | 7 | 3 | 4 | **8** |
| MCP strategy | 8 | 6 | 5 | 3 | **5** |
| Skill loading | 3 | 4 | 2 | 5 | **9** |
| DevEx | 7 | 6 | 5 | 4 | **4** |
| Resilience | 9 | 3 | 4 | 2 | **4** |
| Portability | 7 | 6 | 2 | **10** | **3** |
| Cost efficiency | 6 | 5 | 8 | 4 | **6** |
| Extensibility | 4 | 5 | 3 | 3 | **9** |

---

## Summary: Our Strengths & Gaps

### Top 5 strengths (things nobody else does)

1. **Documentation** — 15 files, 8 ADRs, incident log. Nothing else is close.
2. **Automation** — backup, health check, pre-commit gate, project memory. Nobody has these.
3. **Config architecture** — two-file DRY split with identity/tiering separation.
4. **Attribution defense** — 3-layer (hook + config + dist patch). Most stop at config.
5. **Custom commands** — 9 custom commands, most of any public config.

### Top 5 gaps (things the community has that we don't)

| # | Gap | Impact | Effort | Do it? |
|---|-----|--------|--------|--------|
| **1** | **watcher.ignore** | Low — prevents noise | 1 line | ✅ Trivial |
| **2** | **Model blacklist** | High — prevents accidental spend | 2 lines | ✅ Trivial |
| **3** | **Per-model concurrency** | Medium — cost throttle | 15 lines | ✅ Manageable |
| **4** | **TUI status line** | Medium — at-a-glance context visibility | 1 line | ✅ Trivial |
| **5** | **Public dotfiles repo** | High — portability, community contributions | 1 push | ⚠️ Deliberate choice |

### The real takeaway

Our setup is the most **documented**, most **automated**, and most **architecturally principled** of any public config. The community leads us in **resilience** (more providers, local fallback), **cost control** (blacklists, per-model throttling), and **portability** (public dotfiles anyone can fork).

The gaps are small and cheap to fix. The strengths are hard to replicate. We're in a good position.

---

*Every claim above is cross-referenced against the actual community configs fetched on 2026-07-06 from their original GitHub sources. Config line references in this document refer to our files at `~/.config/opencode/opencode.jsonc` and `~/.config/opencode/oh-my-openagent.jsonc`.*
