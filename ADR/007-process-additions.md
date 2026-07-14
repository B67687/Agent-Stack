# ADR 007: Process Additions

**Status:** Accepted  
**Date:** 2026-07-03  

## Context

Raw model quality is only one axis of agent effectiveness. Process-level improvements — how the agent starts sessions, validates work, and persists decisions — compound over time. After reaching diminishing returns on model tuning, the remaining gains came from workflow discipline.

## Decision

Add seven process improvements:

### 1. Execution Bias
Inspired by Codex 5.5 and Claude Opus 4.6 leaked prompts — both independently converged on "execute > ask." Added to Sisyphus/Worker/Review prompt_append:

> Unless the user explicitly asks for a plan, assume they want execution. Pick the most plausible interpretation and proceed. Do not stop at a proposal.

### 2. Pre-Commit Gate
Prompt-level instruction to run `lsp_diagnostics` on every changed file before marking a task complete. Not a hard hook (tool-based, not agent lifecycle), but catches type errors before they compound.

### 3. Project Memory
Session-boundary context persistence:
- **Session start:** Read `.omo/project-context.md` if it exists
- **Session end:** Update with architectural decisions, patterns, config changes

This prevents re-exploration across sessions.

### 4. ADR Records
Architect command template now saves Architecture Decision Records to `.omo/adr/<slug>.md` after each decision. Standard template: context → decision → consequences.

### 5. ralph Loop (Default Mode)
Set `default_mode: "ralph"` with `max_iterations: 200`. Self-continuation loop that keeps working until explicit stopping criteria are met. Mitigates the intermittent stopping issue where DeepSeek V4 Flash stops mid-session.

### 6. Daily Backup Cron
Script at `~/.local/share/opencode/scripts/backup-config.sh` runs daily at 2 AM via crontab. Backs up both config files with 30-day retention.

### 7. Health Check Script
Script at `~/.local/share/opencode/scripts/health-check.sh` validates configs, tools, DB health, disk space, and model connectivity. 16 checks, returns PASS/WARN/FAIL.

## Consequences

- **Positive:** Each improvement independently saves time or catches errors in a way no model tuning could.
- **Positive:** Execution bias alone closes a measurable portion of the harness gap with Codex/Claude.
- **Negative:** Some additions are prompt-prose, not hard gates (pre-commit, project memory) — compliance depends on the agent reading and following instructions.
- **Negative:** ADR persistence requires the architect agent to actually write the file.
