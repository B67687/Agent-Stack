---
name: shipcheck
description: "Universal pre-ship verification. Detects a repo's stack, routes each quality dimension (security, supply-chain, secrets, dependencies, repo-hygiene, + AI-review) to the right checker (semgrep, trivy, Standards-repo audit.sh, OMO AI skills), and emits a per-dimension verdict with evidence — catching real issues before a full security sweep. NOT-CHECKED is a first-class verdict. Triggers: '/shipcheck', 'shipcheck', 'is this repo safe to push', 'pre-ship check', 'pre-push security check', 'run a security sweep', 'check this project before pushing', 'verify project before shipping'."
---

# /shipcheck — Universal Pre-Ship Verification

Runs the shipcheck orchestrator on a repo and interprets/acts on its verdict.

## When to use

- User wants to know if a project is safe to push/ship (before a full security sweep)
- User asks for a pre-ship / pre-push check across all dimensions
- Any "is this repo safe / does it have problems" question before release

## Procedure

1. **Run the orchestrator** (default: current repo, or the repo the user names):
   ```bash
   python3 ~/.config/opencode/skills/shipcheck/scripts/shipcheck.py <repo> [--json] [--strict] [--skip-dim D]
   ```
2. **Interpret the verdict.** Exit code 1 = BLOCKING findings → report them FIRST with
   file/line/evidence, then give remediation pointers. Exit 0 = clean or WARN-only →
   summarize per-dimension status. NOT-CHECKED dims → name why (missing tool or AI-review
   dimension) and offer to run the relevant OMO skill.
3. **Offer deep sweep for AI-review dimensions** (correctness, privacy, reliability,
   accessibility, performance, documentation, licensing): these are NOT-CHECKED by
   default because they need judgment. If the user wants them checked:
   - Security deep dive → load the `security-research` skill (requires team-mode; if
     team-mode is unavailable, say so and fall back to scanners-only + manual review)
   - Code quality / correctness → `review-work`
   - UI / accessibility → `visual-qa`
   - The orchestrator never fabricates these — it reports NOT-CHECKED honestly.
4. **Pre-push gate:** if the user wants auto-blocking, point them to
   `scripts/hook-pre-push.sh` (opt-in; extend the existing pre-push hook; <10s; fail-open).

## Degraded mode (MUST follow)

- If `semgrep`/`trivy` are missing → affected dims are NOT-CHECKED with the tool named.
  Do NOT claim they passed. Offer to install or to run AI-only review.
- If `security-research` requires team-mode and it is off → say so explicitly; do not
  silently skip security. Fall back to scanners + `review-work`.
- If the target is not a git repo → report the error; do not scan arbitrary directories.

## Constraints

- Own repos only. Never run security tooling on untrusted external code.
- Never convert NOT-CHECKED to PASS. Honesty is the constitution.
- Do not modify the Standards repo — v1 taxonomy is bundled in dimensions.yaml.
- stdlib only — do not add dependencies to shipcheck.py.
