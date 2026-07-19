# Agent-Stack Landscape Refresh — 2026-07-18

**Date:** 2026-07-18
**Scope:** Config audit across live `~/.config/opencode/` and Agent-Stack repo mirror

## Audit Summary

| Check                               | Status                                                   | Action                                                   |
| ----------------------------------- | -------------------------------------------------------- | -------------------------------------------------------- |
| `subagent_depth`                    | **MISSING** — not in either config                       | Added `"subagent_depth": 3`                              |
| `shared/` prefix in prompts/configs | CLEAN — no matches                                       | No fix needed                                            |
| DeepSeek legacy aliases             | CLEAN — only in OMO node_modules internals               | No fix needed                                            |
| OpenRouter vs DeepSeek provider     | Direct DeepSeek (`api.deepseek.com/v1`)                  | Optional: switch to OpenRouter for ~45% V4 Flash savings |
| Ralph Loop references               | `"mode": "ralph"` exists as `default_mode` — intentional | No fix needed                                            |
| OMO version                         | v4.16.1 installed (README claims v4.18.2)                | README version drift — needs reconciliation              |

## Changes Applied

1. **`subagent_depth: 3`** added to `opencode.jsonc` — placed alongside other top-level keys (`default_agent`, `instructions`). Required before upgrading past OpenCode v1.17.20 where subagent nesting defaults to off.

2. **Mirror synced** — same change applied to `Agent-Stack/opencode.jsonc`.

## Findings Detail

### subagent_depth

OpenCode v1.18.x changes subagent nesting behavior. Without an explicit `subagent_depth` value, the platform defaults to disabling nested subagents. Setting `"subagent_depth": 3` preserves the current delegation behavior where agents like `build` can spawn `worker`, `scout`, and `explore` subagents.

The build agent's prompt already instructs: "Maximum allowed depth is 3. Do NOT delegate if at max depth." The config key now matches the prompt behavior.

### OpenRouter vs Direct DeepSeek

Current provider config uses DeepSeek's API directly:

```jsonc
"provider": {
  "deepseek": {
    "options": {
      "baseURL": "https://api.deepseek.com/v1"
    }
  }
}
```

OpenRouter offers V4 Flash at ~45% lower cost with the same model. Switching requires changing `baseURL` to `https://openrouter.ai/api/v1` and updating model identifiers. **This change is optional and was not applied** — direct API has lower latency and no dependency on a third-party proxy.

### OMO Version Drift

`omo --version` reports v4.16.1, but README.md states v4.18.2. This is a documentation discrepancy — the installed binary may lag the stated version. No config changes needed; the README should be updated to reflect actual installed version.

### Ralph Mode

`oh-my-openagent.jsonc` has `"default_mode": {"mode": "ralph"}`. This is the standard OMO Ralph mode (self-referential development loop), not the `/ralph-loop` command or a legacy artifact. No action needed.

## Recommendations

1. **Update README.md** version claim from v4.18.2 to match actual installed version (v4.16.1)
2. **Consider OpenRouter migration** for cost savings on Go-tier models
3. **Monitor OpenCode v1.18.x release** — `subagent_depth: 3` is now in place for when the upgrade happens
