## 2026-08-25 — v1.6 (Hy3 Primary, MiMo Demoted)

### Model Routing

- **Hy3 (Tencent) restored as primary**: AA Intelligence Index 42, $0.04/task, 80 t/s, 299B/21B MoE, Apache 2.0
- **MiMo-V2.5 demoted to free fallback only**: no AA benchmark scores (not in top 29), too weak for primary use
- **DeepSeek V4 Flash confirmed NOT free**: no `deepseek-v4-flash-free` variant exists; broken fallback refs fixed → `mimo-v2.5-free`
- **Muse Spark Contributor evaluated but NOT routed**: Intelligence 57 (highest on platform), $0.01/task, but Meta trains on data and GitHub identity risk
- **Ox Alpha removed entirely**: slow CoT latency, removed from model fields and fallback chains
- **Regression test allowlist updated**: added hy3, fixed broken deepseek-v4-flash-free refs

### Why Hy3

- Best intelligence-per-dollar: Intelligence 42 at $0.04/task (3× cheaper than Flash, 4× more intelligent than MiMo)
- Open weights (Apache 2.0), 256k context, reasoning model
- Paid tier = zero-retention (no data training)
- Tencent promotional pricing — may rise; fallback chain hedges against this

## 2026-08-23 — v1.5 (Ox Alpha Retired, MiMo Restored)

### Model Routing

- **Ox Alpha removed from all routing**: primary model field AND fallback chains across 21 agents/categories. modelConcurrency dropped from 10 → 5
- **MiMo-V2.5 restored as primary workhorse**: fast TTFT, ~$0.0004/req, 30,100 req/5h quota, zero data-training
- **Fallback chains updated**: mimo-v2.5 → gpt-5.6-luna → deepseek-v4-flash-free → minimax-m3
- **Regression test allowlist updated**: added mimo-v2.5 and glm-5.2 to fallback allowlist (34/34 passing)

### Why

- Ox Alpha consistently slow across all agents — always-on CoT (reasoning tokens before output) added ~3-5s latency per response
- MiMo-V2.5 is faster, paid but cheap (~$0.0004/req), and does NOT train on user data
- Free-tier models (deepseek-v4-flash-free, mimo-v2.5-free) remain as fallback tail

### Files Changed

- `~/.omo/omo.jsonc` — ox-alpha removed from all model fields and fallback chains
- `.opencode/rules/model-routing.mdc` — full rewrite to reflect current routing
- `scripts/regression-test.sh` — fallback allowlist updated (added mimo-v2.5, glm-5.2)
- `docs/CHANGELOG.md` — this entry

## 2026-08-15 — v1.11

### Sandbox Layer 2: Host-Side Egress Proxy (allowlist network containment)

Closes the network half of the attack-surface audit — L1 (2026-08-05) made the filesystem deny-by-default inside the bwrap sandbox; L2 makes **network egress** deny-by-default too. Architecture (spec `spec-l2-egress-proxy-2026-08-05.md`):

- **Host side**: Squid 7.2 CONNECT-only allowlist proxy on `127.0.0.1:13128` (default-deny `dstdomain` allowlist in `egress/egress-allowlist.conf`: deepseek, opencode, tavily, exa, openrouter, github, npm, crates, pypi) + socat Unix-socket bridge (`egress-proxy.sh`, systemd user unit `egress-proxy@agent.service`, enabled+active). Default Ubuntu `squid.service` disabled (an un-allowlisted open proxy would be a hazard).
- **Sandbox side**: `bwrap-wrap.sh` now `--unshare-net` (netns empty: only `lo`, no NICs/routes/DNS), binds `egress.sock` in, execs `egress-relay.sh` which exposes in-sandbox `http://127.0.0.1:3128` and exports `HTTP(S)_PROXY`/`ALL_PROXY` before exec'ing the agent. **Opt-in via `EGRESS=1`** — the live launch path is untouched; wrapper stays inert by default. Fail-closed: missing socket → launch refused.
- **Bypass hardening** (from 2026 landscape): host-side judging only (never in-sandbox matcher), hostname allowlist (raw-IP and suffix-attack e.g. `api.deepseek.com.evil.com` denied), DNS resolved host-side at the proxy, CONNECT restricted to :443. SOCKS5 leg dropped (Squid speaks HTTP CONNECT only; would need codex-network-proxy — documented deviation). Domain-fronting/TLS-termination out of scope.
- **Verified**: `scripts/egress-test.sh` — 9/9 (T1 allowlisted tunnel-up, T1b npm 200, T2 evil denied, T5 raw-IP denied, T6 suffix-attack denied, T3/T4 in-sandbox via relay allow/deny, T7 netns empty, T8 fail-closed).

---

## 2026-08-06 — v1.10

### Toolbox Wiring: 4 OMO Skills Activated (13 shipped, 9 deliberately skipped)

The OMO npm package (`oh-my-openagent@4.19.4`, `.agents/skills/`) ships 13 skills that were never wired into the active toolbox. Four are now symlinked into `~/.config/opencode/skills/` — **visible only after opencode restart** (the skill registry is snapshotted at session start):

- **work-with-pr** — full PR lifecycle: atomic PRs → implement with QA evidence → PR creation → verify loop → merge/cleanup
- **tech-debt-audit** — 9-dimension file-cited debt audit → `TECH_DEBT_AUDIT.md`
- **github-triage** — read-only issue/PR triage; 1 item = 1 background agent; zero GitHub mutations
- **remove-deadcode** — LSP-verified dead-code removal; atomic commits

The other 9 were **deliberately skipped** (not forgotten): `hyperplan` (already a builtin command), `security-research` (already wired via `~/.cache/opencode/skills/`), `codex-qa`/`opencode-qa`/`omomomo` (OMO self-QA machinery), `get-unpublished-changes`/`publish`/`pre-publish-review` (OMO npm release machinery), `work-with-pr-workspace` (eval artifacts only). Documented so the selection is never re-litigated.

Final toolbox: **11 entries** in `~/.config/opencode/skills/` (dev-protocol, github-workflow, git-master, meta-learner, rust-workflow, shipcheck, solve + the 4 symlinks) + **2** in `~/.cache/opencode/skills/` (security-research, security-review).

### hyper-sisyphus Removed (experiment discontinued)

The `hyper-sisyphus` self-improvement-loop skill (Gödel-agent inspect → propose → sandbox-evaluate → merge/archive; prototype at `prototype/hyper_proto.py`) was an experiment that was never continued and whose stability is unproven — **removed from the toolbox 2026-08-06 by user decision**. `/improve`, `/ledger-verify`, `/archive-status` are no longer available. The `prototype/` reference implementation remains in the agentic-workflows repo (untouched).

---

## 2026-08-05 — v1.9

### Sandbox Prep (inert — first layer of attack-surface hardening)

- **Credential deny-list expanded in `opencode.jsonc`** (8 new entries, 4 per permission block): `**/.config/gh/hosts.yml`, `**/.gitconfig`, `**/.local/share/opencode/auth.json`, `**/.ssh/config` now `deny` for read+edit — closes the attack-surface audit finding that credential files were readable by the agent (auth.json API keys, GitHub OAuth, SSH config). **Inert until opencode restart.**
- **`scripts/bwrap-wrap.sh` added (Layer-1 sandbox wrapper, inert)**: launches opencode under bubblewrap — deny-by-default (`--unshare-all --ro-bind / /`), credential paths (~/.ssh, ~/.aws, ~/.config/gh, ~/.gnupg) tmpfs-shadowed, workspace dirs (projects/skills/tmp/storage/plans) rw via `--bind`, config roots ro. Bubblewrap = freedesktop/containers-maintained, Flatpak's sandbox, actively developed, already installed 0.11.1. Pivot rationale: the initially-planned `landlock-restrict` tool never existed on crates.io, and landrun (2.3k★) has been stalled since Oct 2025 — rejected on the mainstream+maintained bar. Verified: 3 smoke tests pass (creds shadowed / workspace writable / config write denied). Not the live launch path.
- **Sandbox plan (3-layer) documented**: L1 bubblewrap wrapper first (~0.5-1d), L2 bubblewrap+socat egress proxy second (~2-3d), L3 rootless container end-state. Threat model: single-user box more exposed (no org boundary); protect config-planting surfaces + egress. See `.omo/plans/sandbox-plan-2026-08-05.md` (agentic-workflows).

- **Correction (2026-08-05): bwrap userns works because Ubuntu ships the `bwrap-userns-restrict` AppArmor profile** (`/etc/apparmor.d/bwrap-userns-restrict`) — it is what permits bwrap's user-namespace + capability use despite `kernel.apparmor_restrict_unprivileged_userns=1`. The initially-committed custom `apparmor-bwrap-profile` was redundant with this system profile and was removed; no custom profile is needed. CVE-2026-41163 (setuid-mode ptrace escalation in bwrap 0.11.0-0.11.1) does **not** apply here — `/usr/bin/bwrap` is not setuid (runs unprivileged via userns); the 0.11.2 upgrade is deferred until Ubuntu packages it.

---

## 2026-08-04 — v1.8

### Hook Reconciliation (upstream-verified)

- **`disabled_hooks` reduced from 4 entries to 2**: `["goal", "todo-continuation-enforcer", "compaction-context-injector", "keyword-detector"]` → `["todo-continuation-enforcer", "keyword-detector"]`. Change applied to `~/.omo/omo.jsonc` (backup: `omo.jsonc.pre-hook-reconcile.bak`), schema-validated (config-schema-check CLEAN), health-check 12/12. **Requires opencode restart to load.**
- **Evidence**: upstream git diff v4.19.0→v4.19.4 shows ZERO changes to all four hook dirs (CHANGELOG.md stale at 4.14.0 — git history is authoritative). `goal` re-armed safely: double-gated on `goal.enabled: false` (stays inert), and 4.19.2 fixed the native-command provenance bug (PR #6315). `compaction-context-injector` re-armed safely: no known bugs, orthogonal to the separate `preemptive-compaction` hook (still live, not in disabled_hooks). `todo-continuation-enforcer` + `keyword-detector` KEPT disabled: no 4.19.x fixes; #5806 (ulw persistence) unresolved.
- **Original disablement was security-motivated** (2026-08-02 injection strip from the 5-agent review), NOT breakage-driven — documented in project-context 2026-08-02 session notes.
- **Docs synced**: README (guardrail state + incident table), docs/TROUBLESHOOTING.md §7/§8 config-truth, docs/WORKFLOW.md §5 goal-mode note. CONFIG_MAP.md keyword_detector row unchanged (still inert).

### Local CI Gate Hardened (self-verifying)

- **Pre-push hook moved into the repo** (`.git/hooks/pre-push` → `scripts/hooks/pre-push`, now tracked/versioned) with `core.hooksPath = scripts/hooks`. Previously it lived in untracked `.git/hooks/` — a re-clone would silently lose the local CI gate.
- **health-check.sh Check 5.8 added**: verifies (a) `core.hooksPath` → scripts/hooks, (b) hook present + executable, (c) guardrail git wrapper present. Runs the gate on every health-check — the wiring is now self-verifying, not trust-based.
- **Regression + health-check both green**: 12/12 health checks, 31/31 regression tests.

### GitHub CI Removal

- **`ci.yml` deleted** (2026-08-04): it was a strict subset of the local pre-push hook (redact + same 6 docs-sync greps), and could not run schema-check/regression anyway (they need `~/.omo/omo.jsonc`, outside the clone). Local gate covers everything. `check-updates.yml` (release tracker) retained — its 2-day schedule + GitHub issue creation genuinely need GitHub.
- **Pre-push hook comment fixed**: previously claimed the full regression-test.sh runs in GH Actions — false; it never did. Now documents: run `bash scripts/regression-test.sh` on demand.

---

## 2026-08-03 — v1.7

### Incident Remediation + Tooling

- **Goal-hook regression found + reverted**: re-enabling the goal hook (guardrail from v1.6) caused `InvalidObjectiveError: Objective exceeds maximum length of 2000 characters` on any message >2000 chars — `handleGoalMessage` treats every user message as a new objective. Reverted to `goal.enabled: false` + `"goal"` back in `disabled_hooks` (config-level fix survives upgrades; the v4.19.0 manual dist patch from Incident 5 was lost in the 4.19.4 install). Documented as Incident 9.
- **`scripts/restart-opencode.sh` added** (commit 0299867): fail-fast config validation → clean stop of opencode → relaunch via agent-session (isolated cgroup) → asserts new process start-time is newer than `~/.omo/omo.jsonc` mtime (reload proof).
- **coreutils swapped from Rust uutils 0.8.0 to GNU 9.7** (whole `/usr/bin` set was uutils symlinks): `apt-get install gnu-coreutils coreutils-from-gnu rust-coreutils- coreutils-from-uutils- --allow-remove-essential` — removed build-essential metapackage + rust-coreutils + coreutils-from-uutils; `timeout`/`ls`/`cat` now GNU coreutils 9.7. Rollback snapshot at `coreutils-stage/symlink-snapshot-20260803.txt`.
- **Public Agent-Stack synced** to 5110448 (fast-forward) — public/private/local all in agreement.
- **Evidence posted** on anomalyco/opencode #37495 (WAL unbounded), #37821 (crash on corrupted DB), #37239 (silent retry) from the Aug 2 incident (5.48GB WAL, SIGABRT at 'booting location services', silent 2h retry).
- **#6565 downgraded to bug report** (code-yeongyu/oh-my-openagent): retitled 'bug(resolve-ts-lsp)... fork-bomb recursion', restructured per CONTRIBUTING.md, comment offers validated local fix + PR.
- **Delete-semantics verdict**: opencode UI Delete = hard DELETE (RemoveInput → FK CASCADE); UI Archive = soft (time_archived). Zero archived rows in DB — deleted sessions are truly gone; the bloated C#-to-Rust session was simply never deleted on this host.
- **C#-to-Rust session trimmed** (ses_0da9a7666ffe, 'Understanding repo for C# to Rust', Ithmb-Codec): 10,506→20 messages, 41,865→75 parts, 147,482→500 events; integrity ok; pre-trim snapshot at `~/.cache/tmp/opencode/quarantine/opencode.db.pre-csharp-trim-20260803` (since deleted after user approval).
- **Docs consistency pass** (kotlin-ls removal, disabled_hooks 4-entry truth, modelConcurrency truth, runtime_fallback incl 500) across README, docs/CONFIG_MAP.md, docs/TROUBLESHOOTING.md, docs/INCIDENTS.md, docs/WORKFLOW.md, ADR/002, ADR/014.

---

## 2026-08-02 — v1.6 (evening)

### Model Routing Consolidation (research-driven)

- **Whole paid stack consolidated onto `opencode-go/deepseek-v4-flash`** (official 0731 build, re-post-trained Jul 31 2026): oracle/architect/prometheus, metis/momus (off minimax-m3), worker/hephaestus/atlas (off mimo-v2.5), ultrabrain/unspecified-high categories. DeepSeek's changelog confirms flash 0731 "far exceeding V4-Pro-Preview" (TB2.1 82.7 vs 61.8) while the V4-Pro API stayed on the Apr preview — flash wins on strength, price ($0.14/$0.28 vs $0.435/$0.87), and pool ($60 vs $15/mo).
- **deepseek-v4-pro and mimo-v2.5 (Xiaomi) removed from routing + modelConcurrency** — dominated by flash 0731 on strength at equal-or-lower price.
- **minimax-m3 demoted to visual-engineering only** (the sole image/video-capable slot); BenchLM ranks it weak on agentic (#96/128).
- **qwen3.7-plus kept at concurrency 3** as fallback reserve only.
- **Docs synced**: README routing table, docs/AGENTS.md, docs/CONFIG_MAP.md, docs/ARCHITECTURE.md example, ADR 002 supersession note.

---

## 2026-08-02 — v1.5

### OMO Upgrade + Config Migration

- **Oh-My-OpenAgent upgraded 4.18.0 → 4.19.4** (resolved v4.19.0 dist build corruption; syntax clean, `collectDisabledSkillAliases` restored, tree-shaking fixed — see Incident 7 status)
- **Config surface migrated**: OMO settings moved from `~/.config/opencode/oh-my-openagent.jsonc` (agent/category overrides, two-file split per ADR 001) to the unified `~/.omo/omo.jsonc` single source of truth (post-4.19.4 migration). Old file deleted.
- **Agent/category model key**: agents and categories now use the `model` key (single string) under the `[opencode]` scope — validate against installed schema via `scripts/config-schema-check.mjs`

### Budget Redesign

- **Frontier trio downgraded**: oracle / architect / prometheus / ultrabrain (category) `opencode-go/qwen3.7-max` → `opencode-go/qwen3.7-plus` ($0.40/$1.60 vs $2.50/$7.50 per 1M tokens; qwen3.7-max also hit a China-region 403 opt-in gate)
- **Concurrency caps tightened**: qwen3.7-max concurrency set to 0 (budget-blocked); per-model `modelConcurrency` is now the hard budget enforcement layer
- **Dead budget files deleted** (commit a8cb111): `cost-guard.config.json` + `token-monitor.json` removed — budget enforcement now via routing + modelConcurrency caps

### Testing

- **Added `scripts/config-schema-check.mjs`**: validates `~/.omo/omo.jsonc` against the INSTALLED OMO Zod schema (catches the ghost-key bug class the TUI surfaces as 'config invalid - run doctor')
- **Added `scripts/runtime-regression-test.sh`**: staged-HOME boot proves the plugin runtime actually consumes the agent `model` field (guards the round-1 silent-drop bug class)
- **Added `scripts/tui-validation-path-test.sh`**: staged boot + ghost-key regression covers the exact TUI validation path the doctor banner derives from
- **Bus-Hop repo cleanup** (separate repo, not this one): history re-signed, dependabot/CI removed

---

## 2026-08-01 — v1.4

### Model Routing Reassessment (dev-protocol run)

- **Frontier trio**: oracle, architect, prometheus, ultrabrain → `opencode-go/qwen3.7-max` (fallback kimi-k2.7-code)
- **Budget frontier**: test-writer, review → `opencode-go/gpt-5.6-luna` (fallback qwen3.7-plus) — top coding rank #6 at 1/12 price
- **Mid-tier**: metis → `minimax-m3` (fallback deepseek-v4-flash); momus keeps minimax-m3
- **Retired**: removed `qwen3.6-plus` + `minimax-m2.7` from modelConcurrency (superseded; qwen3.6-plus had tool-call-loop bug)
- **Added to modelConcurrency**: qwen3.7-max:3, gpt-5.6-luna:3, kimi-k2.7-code:3
- Prometheus now `qwen3.7-max` (was deepseek-v4-flash)

### Config Fixes

- **fallback_models added**: build (mimo-v2.5), git/quick/unspecified-low (v4-flash-free), writing (mimo-v2.5-free); subagent_mapping +3 (git, librarian, multimodal-looker → v4-flash-free); momus +reasoningEffort high; general prompt +ctx_batch_execute
- **rust-analyzer wired** into opencode.jsonc lsp section (bare `rust-analyzer`, `.rs`); lsp-install-decisions rust → allowed
- **tui.json** plugin pinned `oh-my-openagent@4.18.0` (was @latest)
- **package.json**: removed opencode-supermemory dep (custom lib, not OMO-bundled); lockfile regenerated (omo 4.18.0)
- **Scripts**: pre-commit-verify.sh crash fixed ($OMO_JSONC_PARSER → validate-jsonc.js), dead lsp.json block removed, Check 3→4 numbering; regression-test.sh Test 7 allowlist +gpt, Test 9 nvm→npm root -g, Test 13 comment All 5, Test 26 lsp.json→opencode.jsonc lsp section
- **Docs sync**: AGENTS.md + README add `general` agent; CONFIG_MAP LSP table note (only 5-6 wired); incidents/TROUBLESHOOTING atlas claims aligned (config truth: disabled_hooks has no atlas)

---

## 2026-07-20 — v1.3

### LSP Infrastructure

- **19 LSPs installed** (up from 15): added kotlin-ls, texlab, jdtls (Java), csharp-ls
- **TypeScript 7 native LSP**: resolve-ts-lsp proxy detects TS version, dispatches to Go binary directly, fixes `initialized` notification bug (TS7 Go LSP requires `"params":{}` on `initialized`)
- **zls + jdtls + lua-ls fixes**: same `initialized` patch for zls, Java 21 wrapper for jdtls, working directory fix for lua-ls
- **LSP config file**: created `lsp.json` — daemon reads from separate config (not `opencode.jsonc`)
- **LSP daemon config discovery documented**: `LSP_TOOLS_MCP_PARAAM_CONFIG` + `LSP_TOOLS_MCP_USER_CONFIG` env vars

### OMO Model Routing

- **Diversified models** across 18 agents + 9 categories
- Flash + MiMo V2.5 handle high-volume agents (sisyphus, hephaestus, worker)
- MiniMax M3, Qwen3.7 Plus, DeepSeek V4 Pro for specialized agents
- **3 tiers**: Go high-rate (31k/5hr) → Go medium (3-4k/5hr) → Zen free
- Model concurrency settings expanded to cover all Go-tier models

### Config & Documentation

- ADR 013: TypeScript 7 Native LSP Migration
- ADR 014: LSP Infrastructure Expansion
- `check-updates.sh`: 72h cooldown policy (throttle + release-age gate)
- Config audit: removed dead `lsp` server section from `opencode.jsonc`, split oversized agent prompts (build: 4298→350 chars, architect: 3431→200 chars) into 3 `.mdc` rule files
- AGENTS.md updated to reflect new model routing across all tiers
- Atlas removed from `disabled_hooks` (can now auto-start)

### Testing

- **32 regression tests** (up from 27): 4 new tests (LSP structure, wrapper scripts, model concurrency, disabled providers)
- JSONC validation with proper parser (catches trailing commas, brace mismatches)
- Pre-commit-verify.sh enhanced with JSONC + lsp.json validation
- Fixed stale test values (DCP turns 3→5, model allowlist expanded to 7 families)

### ADRs

- **013**: TypeScript 7 Native LSP — Go binary dispatch, initialized notification fix, config location
- **014**: LSP Infrastructure Expansion — 4 new installs, 2 fixes, daemon config discovery

- **Incident 8 fix**: Continuation injection loop (endless 'Continue working toward the active thread goal' spam with nesting <untrusted_objective> wrappers). Root cause: OMO has THREE separate continuation systems — Goal Hook (gated by goal.enabled), Todo Continuation Enforcer (gated ONLY by disabled_hooks), Atlas/Boulder (gated ONLY by disabled_hooks). `goal.enabled: false` only disabled one of three. Fix: added `disabled_hooks: ["goal", "todo-continuation-enforcer", "atlas"]` to oh-my-openagent.jsonc. Docs/TROUBLESHOOTING.md and Docs/INCIDENTS.md updated.

# Changelog

## 2026-07-19

- **Incident 6 fix**: OMO agents (sisyphus, hephaestus) not loading on startup because v4.19.0 `AGENT_MODEL_REQUIREMENTS` blocks agents when no premium fallback models available. Patched dist to use explicit model override when model resolution fails. Docs/INCIDENTS.md updated.

## 2026-07-19

- **Incident 7**: OMO v4.19.0 dist build corruption (1302 lines garbled, missing functions). Downgraded to v4.18.0. Applied model resolution fallback patches.
- **Incident 6 fix**: OMO agents (sisyphus, hephaestus) not loading because model resolution fails when premium fallback models unavailable. Patched dist to use explicit model override. (Applied to v4.18.0)

## 2026-07-17

- **Release tracker**: `.github/workflows/check-updates.yml` + `scripts/check-updates.sh` — checks OMO and OpenCode GitHub releases every 2 days, creates issues on updates
- **Prometheus model fixed**: was missing from `agents` section → defaulting to claude-opus-4-7. Now explicit `opencode-go/deepseek-v4-flash`
- **PRODUCTION_QUALITY.md**: OSS benchmark quality reference (35 projects) added to docs/
- **VERSIONS.md**: tracked versions file for release update checker
- **README restructured**: removed "What's New" (moved to CHANGELOG), License → bottom, fixed code fence, added .github/ and .opencode/rules/ to tree
- **LSP coverage 5→14**: installed typescript-language-server, vscode-langservers-extracted (HTML/CSS/ESLint), bash-language-server, yaml-language-server, zls, clangd, gopls, lua-language-server, dockerfile-language-server-keyword, html-validate
- **Workflow integration docs**: WORKFLOW_INTEGRATION.md (Dev Protocol + start-work combined flow)
- **LANDSCAPE audit + 8 config fixes**:
  - `truncate_all_tool_outputs: false` — agents retain full tool context
  - `compaction.reserved: 15000` — agents keep enough working memory after compaction
  - `showCompression: true` — visibility into context pruning
  - DCP/OMO turn protection aligned to 5 turns
  - `babysitting.timeout_ms: 180000` — complex subagents not killed prematurely
  - `MaxSessions 5` — SSH sufficient for VSCode multi-session
  - `GatewayPorts no` — VSCode port forwards bound to localhost only
  - `patch-attribution.sh` dynamic Node path (no longer hardcoded version)

## 2026-07-18

- **Preemptive subagent_depth added**: `subagent_depth: 3` to opencode.jsonc (inactive on v1.17.20, needed for v1.18.x where subagent nesting defaults to off)
- **Innovations research**: INNOVATIONS_2026_H2.md — 5 notable agent harness innovations (Shofer, Juggler, MCP stateless, bbarit-oss, Orca)
- **Full-stack LANDSCAPE audit**: 5 parallel audit lanes across LSP/tools, runtime behavior, infrastructure, VSCode, and process quality
- **8 config fixes applied**: truncation, compaction, DCP, babysitting, SSH hardening, etc.
- **Config audit (v2)**: 6-point audit — subagent_depth added, shared/ prefix clean, DeepSeek aliases clean, OpenRouter noted (45% savings), Ralph Loop clean, OMO v4.16.1 vs README v4.18.2 discrepancy
- **Landscape refresh research**: `research/2026-07-18-landscape-refresh.md` — audit findings, OpenRouter recommendation, OMO version drift
- **OMO v4.18.2 → v4.19.0**: Upgraded OMO plugin. Goals feature replaces Ralph Loop. 8 attribution injection points patched.
- **Goals migration**: default_mode changed from `{mode: "ralph", max_iterations: 20}` to `{ultrawork: false, goal: true}` with `goal: {enabled: true, auto_start: false, default_max_iterations: 20}`.
- **dcp.jsonc fixed**: Missing comma at "showCompression: true" fixed — was causing silent JSON5 parse failure.
- **Doc restructure**: PRODUCTION_QUALITY.md and WORKFLOW_INTEGRATION.md moved to Development-Protocol repo — these are methodology docs (quality standards, workflow composition), not config docs. Agent-stack is now pure config+rationale+tooling.
- **Docs overhaul**: 8 files updated — ralph→goal migration across CONFIG_MAP, WORKFLOW, ARCHITECTURE, TROUBLESHOOTING; AGENTS.md duplicate heading fixed; VERSIONS.md versions corrected; CHANGELOG catch-up.

## 2026-07-14

- **Critical: auto_update true→false** (prevents OMO auto-updates from overwriting attribution dist edits)
- **Auto-rules made live**: 7 .mdc files copied from mirror to `~/.config/opencode/.opencode/rules/`
- **Config redacted**: personal paths replaced with `{{OPENDATA_DIR}}`, `{{PLAYWRIGHT_CHROME}}` placeholders
- **Gitignore replaced**: deny-by-default → standard explicit-ignore with `.opencode/rules/` exception
- **CONFIG_MAP.md fixed**: auto_update row corrected to false
- **Regression tests**: expanded 21→29, added post-run maintenance (auto-backup + cache clear)
- **Cache cleared**: `~/.cache/opencode/packages/` (freed 964M, removed attribution injection source)
- **DCP tuning**: dynamic_context_pruning enabled (10-turn protection), babysitting 120s, aggressive_truncation removed, truncate_all_tool_outputs false
- **SearXNG fine-tuned**: request_timeout 10.0→5.0, max 20.0→10.0, SEARXNG_TIMEOUT_MS 60000, limiter:false
- **OMO 4.16.2→4.18.0 upgraded**: attribution surgically removed from dist
- **Full adversarial review**: 0 attribution matches in OMO plugin tree, no secrets/API keys in configs
- **Pre-commit review**: all 31 tracked files clean, no raw paths/secrets, 29/29 regression pass
- **GitHub release v1.0.0**: created with full changelog, description + topics set
- Squashed and pushed to GitHub: single commit on origin/main

## 2026-07-12

- Architecture clarified: ~/.config/opencode/ is authoritative live config; opencode-config/ is mirror + docs layer (GitHub-published)
- Drift discovered & fixed: Mirror was ahead of live configs with all v2 changes. Live configs updated, mirror overwritten with live as authoritative source
- Live opencode.jsonc: 5 changes — build/worker/general prompts, SearXNG timeout (60s), compaction indent fix
- Live oh-my-openagent.jsonc: 18 changes — reasoningEffort tuning, atlas prompt_append + low effort, prompt_append added to 10 agents, multimodal-looker model fix, context-mode on sisyphus
- Added .omo/ and .opencode/ to .gitignore (agent ephemera excluded from repo)
- Squashed and pushed to GitHub: 35442f8 on origin/main (32 files, 3600 insertions, single commit)
- Updated Self-Hosted-Search/README.md (226 lines, mcp-searxng, limiter:false, 20 engines)
- Created ADR 010: Search Infrastructure (SearXNG self-hosted, mcp-searxng bridge)

## 2026-07-10

- Repo restructured: added redacted config files (opencode.jsonc, oh-my-openagent.jsonc) as main content
- Added scripts/redact-config.sh — auto-redacts personal paths for publishing
- Updated README to reflect dual purpose (settings dump + documentation)

- Added research/ dir with community config analysis (COMMUNITY_CONFIGS.md, GAP_RESEARCH.md, SUPER_ANALYSIS.md)
- V1 optimization round: build/plan reasoningEffort high→max; sisyphus added reasoningEffort:max;
  atlas added reasoningEffort:low + prompt_append verification gate; hephaestus added prompt_append
  verification gate; prometheus added prompt_append verification gate; artistry reasoningEffort
  max→high; writing reasoningEffort max→high; multimodal-looker model
  mimo-v2.5-free→deepseek-v4-flash-free
- Added 7 .mdc auto-rules in .opencode/rules/ (rust-workflow, python-workflow, typescript-react,
  config-files, git-workflow, go-workflow, agent-behavior)
- Added 10 agent prompt_append specializations to oh-my-openagent.jsonc
- Wired context-mode tooling into sisyphus, librarian, and general agents
- Added 3 new scripts: post-agent-log.sh, pre-commit-verify.sh, health-check.sh
- Added verification gates on build and worker prompts in opencode.jsonc

## 2026-07-09

- Created omo-install script at ~/.local/bin/omo-install — auto-patches attribution on every install/upgrade
- Fixed: removed 10 OMO agent entries from opencode.jsonc (broke TUI — OMO registers them via plugin hooks)
- Added 10 OMO agents (oracle, prometheus, metis, momus, etc.) to opencode.jsonc for TUI Tab-cycling access (later reverted)
- Fixed missing comma after agent block in opencode.jsonc
- Updated all docs to match current config state
- Upgraded OMO v4.12.0→v4.16.1 (fork bomb fix, ledger compaction)
- Patched OMO v4.16.1 dist: removed 8 attribution injection points
- Rearchitected Sisyphus: removed max reasoningEffort (speed), trimmed prompt_append ~70%
- Added Clarification Protocol to Sisyphus (based on 80-pt research gap)
- Fixed SearXNG MCP (broken file ref → working mcp-searxng)
- Added 14 config features: task_system, aggressive_truncation, preemptive_compaction,
  truncate_all_tool_outputs, safe_hook_creation, agent_order, keyword_detector,
  model_fallback, auto_update, telemetry:false, git category, mcp-searxng
- Added 3 regression tests (config feature placement, experimental flags, SearXNG health) → now 18 tests
- Found and fixed config bug: auto_update/telemetry/model_fallback were nested inside websearch
- Updated regression-test.sh to 18 tests

## 2026-07-08

- Added regression-test.sh (initially 15 tests: attribution, config validity, brace balance,
  model containment, OMO dist patch, cross-config DRY, category fallbacks, DCP integrity)
- Patched OMO v4.16.0 dist: removed 8 attribution injection points
- model-verifier now detects new premium models automatically
- Removed hyper-sisyphus agent, improve/ledger-verify/archive-status commands from both configs
  (skill files preserved locally)
- Added model-verifier.sh (validates configured models against available)
- Added cost-report.sh (reads SQLite DB for per-session cost data)
- Wired all 3 scripts into health-check.sh
- OMO v4.16.0 available (not yet activated in plugin cache)

## 2026-07-07

- Initial publish: ADRs (001-008), architecture, model tiering, workflow docs, incident reports
- 17 files, 722 lines
