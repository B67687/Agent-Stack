# ADR 001: DRY Config Split

**Status:** Accepted  
**Date:** 2026-07-03  

## Context

Two config files manage the OpenCode + OMO setup: `opencode.jsonc` (OpenCode native) and `oh-my-openagent.jsonc` (OMO plugin overrides). Initially, `opencode.jsonc` held both agent identity (mode, prompt, permission) AND model tiering (model, reasoningEffort, temperature). This duplicated configuration and made it unclear where to change a setting.

## Decision

Split concerns:

| File | Owns | Example |
|------|------|---------|
| `opencode.jsonc` | Agent identity | mode, steps, prompt, permission, description |
| `oh-my-openagent.jsonc` | Model tiering | model, reasoningEffort, temperature, fallback_models, thinking, category |

OMO merges agent overrides from `oh-my-openagent.jsonc` on top of OpenCode's base agent definitions. Settings like `prompt_append` are appended to the base prompt.

## Consequences

- **Positive:** Single source of truth for model decisions. Changing a model requires editing only one file.
- **Positive:** Agent prompts and permissions remain visible in the main config where they're naturally edited.
- **Negative:** Requires understanding the merge model. A new contributor needs to know which file owns what.
- **Neutral:** Some agents exist only in one file or the other (OMO built-in agents like Prometheus, Oracle have no opencode.jsonc entry; they are fully defined by OMO defaults + overrides).

---

## Superseded (2026-08-02)

**Status:** Superseded by unified config surface

The OMO 4.18.0 → 4.19.4 upgrade migrated all OMO settings from the two-file split (`opencode.jsonc` + `oh-my-openagent.jsonc`) to a single unified config at `~/.omo/omo.jsonc`. The DRY split this ADR documented no longer applies — there is now one source of truth for agent identity AND model tiering under the `[opencode]` scope of `~/.omo/omo.jsonc`. The original historical decision (2026-07-03) is preserved below for context; the current live config layout is the unified surface.
