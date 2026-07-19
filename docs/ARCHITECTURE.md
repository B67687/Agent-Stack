# Architecture: Two-File Config Split

The OpenCode + OMO configuration is split across two files to keep concerns separate. This was decided in ADR-001 after an initial period where model tiering and agent identity lived in the same file, making it unclear where to change a setting.

## How OMO Merges Agent Overrides

OMO (Oh My Openagent) reads `opencode.jsonc` for base agent definitions. Then it layers overrides from `oh-my-openagent.jsonc` on top. The merge is per-agent: if an agent exists in both files, OMO combines the settings. If an agent exists only in one file, it still works — OMO has built-in defaults for agents like Prometheus and Oracle that have no entry in `opencode.jsonc`.

Settings like `prompt_append` in `oh-my-openagent.jsonc` are appended to the base prompt from `opencode.jsonc`. Model settings (model, reasoningEffort, temperature) from `oh-my-openagent.jsonc` override or fill in gaps on the OpenCode side.

## Responsibility Split

| Aspect                        | `opencode.jsonc`              | `oh-my-openagent.jsonc`                   |
| ----------------------------- | ----------------------------- | ----------------------------------------- |
| Agent mode                    | primary / subagent            | —                                         |
| Steps (tool call budget)      | per-agent limit               | —                                         |
| Prompt / system message       | Yes (via prompt field)        | prompt_append only                        |
| Permission rules              | read, edit, write, bash, task | —                                         |
| Model assignment              | default model only            | per-agent model                           |
| reasoningEffort               | —                             | none / low / high / max                   |
| Temperature                   | —                             | per-agent override                        |
| fallback_models               | —                             | ordered fallback chain                    |
| Thinking budget               | —                             | enabled + budgetTokens                    |
| Category routing              | —                             | category field (maps to tier)             |
| Plugins, MCP, LSP, formatters | Yes                           | —                                         |
| Global OMO settings           | —                             | team_mode, goal, overengineering tunables |

Two additional configuration layers extend this base. **Auto-rules** (10 `.mdc` files under `.opencode/rules/`) activate automatically by path glob, injecting context for task scoping, verification, security, and operations. **Context-mode tooling** integrates `ctx_*` tools for session memory persistence and FTS5-backed search, augmented by `ctx_batch_execute` and `ctx_execute` for sandboxed computation.
In short: `opencode.jsonc` says _who_ an agent is. `oh-my-openagent.jsonc` says _which model_ it uses and _how_ that model should reason.
