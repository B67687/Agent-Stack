# /shipcheck — Universal Pre-Ship Verification

**One-line:** verify any project across all dimensions that matter before you push.

A pre-ship verification skill that detects a repo's stack, routes each quality
dimension (security, supply-chain, secrets, dependencies, repo-hygiene, + AI-review
dimensions) to the right checker, and emits a per-dimension verdict with evidence —
**catching real issues before a full security sweep.**

Built on reuse-not-rebuild: rides existing tools (semgrep, trivy, the Standards repo's
`audit.sh`) and OMO AI-review skills. NOT-CHECKED is a first-class verdict: the tool
never claims a check that didn't run.

## Usage

```bash
/shipcheck            # run on current repo (via the skill)
/shipcheck path/to/repo
shipcheck.py . --json # scriptable output (hooks, CI)
shipcheck.py . --strict   # also fail on WARN findings
shipcheck.py . --skip-dim repo-hygiene  # skip a dimension
```

**Exit codes:** `0` clean/WARN-only · `1` BLOCKING finding (or `--strict` + WARN) · `2` error.

## Verdict format

```
SHIPCHECK v0.1.0
repo stack: python, github-actions

DIMENSION         STATUS       FINDINGS
------------------------------------------------------------
security          BLOCKING     2
  [blocking] .github/workflows/ci.yml:23 — GitHub Actions step uses a mutable tag...
supply-chain      BLOCKING     1
secrets           PASS         0
dependencies      PASS         0
repo-hygiene      WARN         62
  -> audit.sh standards polish (mise.toml, screenshots) — WARN tier, never blocking
correctness       NOT_CHECKED
  -> AI-review dimension — no machine checker; run OMO AI skill or manual review
------------------------------------------------------------
BLOCKING: 2 | WARN: 1 | PASS: 3 | NOT-CHECKED: 5
```

Tiers: **BLOCKING** (real security/supply-chain — fails the gate) · **WARN** (standards
polish, suspicious-but-unproven — fails only with `--strict`) · **PASS** · **NOT-CHECKED**
(honest gap — never silent).

## Dimensions (v1, bundled `dimensions.yaml`)

| Dimension | Severity | Machine checker | AI review |
|---|---|---|---|
| security | blocking | semgrep + trivy secrets | — |
| supply-chain | blocking | semgrep + trivy vulns | — |
| secrets | blocking | trivy secrets | — |
| dependencies | warn | trivy vulns | — |
| repo-hygiene | warn | audit.sh | — |
| correctness / privacy / reliability / accessibility / performance / documentation / licensing | warn/info | — | required (NOT-CHECKED without it) |

Taxonomy sync with the Standards repo is a v2 item (v1 is bundled + isolated).

## Pre-push gate (opt-in)

`scripts/hook-pre-push.sh` is a fast (<10s, fail-open) BLOCKING-tier gate for git
pre-push. Only ONE pre-push hook runs per hooksPath — extend your existing
`~/.config/git/ai-commit-hooks/pre-push` to call it, or use lefthook/pre-commit
in-target. See the script header for the exact contract.

## Install / layout

```
~/.config/opencode/skills/shipcheck/
├── SKILL.md              — the /shipcheck command (front-door)
├── scripts/shipcheck.py  — thin CLI (stdlib only)
├── scripts/verdict.py    — model + aggregation + rendering
├── scripts/checkers.py   — subprocess wrappers (semgrep/trivy/audit.sh)
├── scripts/hook-pre-push.sh — opt-in fast gate
├── dimensions.yaml       — v1 taxonomy (source of truth)
└── tests/                — unit tests (pure logic)
```

Requirements: Python 3.10+, `semgrep`, `trivy`, the Standards repo at
`~/projects/dev/standards/`. Missing tools degrade to NOT-CHECKED, never crash.

## Backlog (v2)

- OpenSSF Scorecard integration (supply-chain/hygiene, highest-leverage OSS check)
- Standards-repo taxonomy sync (fork (a) — the audit engine)
- CI tier (post-push full matrix)
- gitleaks / osv-scanner as optional checkers

Built with AI assistance. MIT.
