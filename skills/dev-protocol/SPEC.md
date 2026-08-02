# /dev-protocol — As-Built Specification

**Date:** 2026-07-26
**Version:** v1.0.0
**Status:** COMMIT (post-VALIDATION)

## Overview

The `/dev-protocol` command and `dev-protocol` skill allow invoking the Development Protocol in any project directory by typing `/dev-protocol`. The skill reads the protocol dynamically from the Development-Protocol repo — whatever pipeline it defines is what gets executed. No hardcoded steps.

## Artifacts

### 1. Skill Definition

- **Path:** `~/.config/opencode/skills/dev-protocol/SKILL.md`
- **Size:** 106 lines
- **Purpose:** Instructs the agent to read the protocol repo and execute its pipeline

### 2. Command Registration

- **Path:** `~/.config/opencode/opencode.jsonc` → `command.dev-protocol`
- **Target agent:** `build`
- **Subtask:** false (runs as primary task, not subagent)
- **Template:** Loads the skill, reads from the protocol repo path

## Architecture

```
User types /dev-protocol
         │
         ▼
opencode.jsonc command dispatches to build agent
         │
         ▼
Template: skill(name='dev-protocol') + instructions
         │
         ▼
Agent reads SKILL.md → executes protocol:
  1. Read Development-Protocol/README.md (current pipeline)
  2. Read each step's .md file
  3. Execute steps in order, saving to .omo/plans/
  4. Track progress via .omo/protocol-state.md
```

## Key Design Decisions

| Decision                          | Choice                   | Rationale                                                                                       |
| --------------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------- |
| **Dynamic vs hardcoded steps**    | Dynamic (reads repo)     | Protocol evolves; skill should adapt automatically                                              |
| **Command + skill vs skill-only** | Both                     | Command provides explicit entry point; skill enables auto-discovery via opencode-command-inject |
| **State persistence**             | `.omo/protocol-state.md` | Standard OMO artifact location, resumable across sessions                                       |
| **Target agent**                  | `build`                  | Same pattern as review-work; needs tool access for research + implementation                    |

## Success Criteria Check

- [x] **Usage frequency:** Ready for use — user invokes `/dev-protocol` to start
- [x] **Pipeline completion:** Handles the full pipeline via dynamic repo reading
- [x] **Friction reduction:** One command vs manually typing "run the dev protocol"

## Future Considerations (not v1)

- Session resume from any step with state recovery
- Protocol version detection (git describe in the protocol repo)
- Per-project protocol configuration (e.g., skip certain steps)
