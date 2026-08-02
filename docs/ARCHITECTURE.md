# Architecture: Unified OMO Config

The OpenCode + OMO configuration lives in two files with a clear responsibility split. This was decided in ADR-001 after an initial period where model tiering and agent identity lived in the same file, making it unclear where to change a setting.

## File Layout

- **`opencode.jsonc`** (`~/.config/opencode/opencode.jsonc`) — OpenCode base config: agent identity (mode, prompt, permissions), plugins, MCP, LSP, providers, `disabled_providers`, formatters.
- **`~/.omo/omo.jsonc`** — OMO unified config (user scope, outside the git repo). All OMO settings live under the literal `"[opencode]"` key (accessed as `omo['[opencode]']`): `agent_order`, `agents`, `categories`, `background_task.modelConcurrency`, `sisyphus_agent.subagent_mapping`, `disabled_hooks`, `team_mode`, `websearch`, `auto_update`, `telemetry`, and the rest of the OMO tunables.

## Migration (OMO 4.19.4)

OMO 4.19.4 replaced the old `oh-my-openagent.jsonc` file (which lived in `~/.config/opencode/`) with the unified `~/.omo/omo.jsonc`. The startup migration consumed the old file on 2026-08-02; a byte-exact backup is retained at `~/.omo/migration-backup-2026-08-02T00-21-52-636Z-opencode-config/`. The `_migrations` journal records the applied migrations:

- `2026-07-opencode-config-unification`
- `2026-08-reasoning-unification`

## Model Configuration

Agent and category models use the `model` key: a single model string per agent/category (e.g. `"model": "opencode-go/deepseek-v4-flash"`). This is the shape the 4.19.4 runtime's agent-registration code actually reads (`override?.model`); the `models[]` array shape that the `2026-08-reasoning-unification` migration wrote is NOT consumable by the plugin's own registration loop (falls to plugin-default models) — we converted back to `model`-key shape on 2026-08-02. Example:

```jsonc
"architect": {
  "model": "opencode-go/deepseek-v4-flash"
}
```

The `model` key is the single source of truth for agent/category routing. `fallback_models` is the ACTIVE 5-entry allowlist on every agent/category (added 2026-08-03 — suppresses OMO's hardcoded claude-opus-5 fallback chain; regression Test 5 enforces it); `models[]` and `reasoningEffort` are migration-era shapes and unused. `model_fallback: true` (plus `runtime_fallback.retry_on_errors`) provides the runtime fallback safety net on retryable errors; the UI model picker in the TUI overrides everything. Validate every key against the installed schema with `scripts/config-schema-check.mjs` before restarting (this catches the unknown-key class of bugs the TUI reports as 'config invalid - run doctor').

## Responsibility Split

| Aspect                        | `opencode.jsonc`              | `~/.omo/omo.jsonc` (under `"[opencode]"`)        |
| ----------------------------- | ----------------------------- | ------------------------------------------------ |
| Agent mode                    | primary / subagent            | —                                                |
| Steps (tool call budget)      | per-agent limit               | —                                                |
| Prompt / system message       | Yes (via prompt field)        | prompt_append only                               |
| Permission rules              | read, edit, write, bash, task | —                                                |
| Model assignment              | default model only            | per-agent `model` key                            |
| Reasoning                     | —                             | none — reasoning keys removed 2026-08 reasoning-unification                  |
| Temperature                   | —                             | per-agent override                               |
| Fallback chain                | —                             | runtime_fallback + model_fallback (global)       |
| Thinking budget               | —                             | none — provider_options removed 2026-08 reasoning-unification                |
| Category routing              | —                             | category field (maps to tier)                    |
| Plugins, MCP, LSP, formatters | Yes                           | —                                                |
| Global OMO settings           | —                             | team_mode, goal, overengineering tunables        |

Two additional configuration layers extend this base. **Auto-rules** (11 `.mdc` files under `.opencode/rules/`) activate automatically by path glob, injecting context for task scoping, verification, security, and operations. **Context-mode tooling** integrates `ctx_*` tools for session memory persistence and FTS5-backed search, augmented by `ctx_batch_execute` and `ctx_execute` for sandboxed computation.

In short: `opencode.jsonc` says _who_ an agent is. `~/.omo/omo.jsonc` (under `"[opencode]"`) says _which model_ it uses and _how_ that model should reason.
