# EXPLAINER — /shipcheck: Universal Pre-Ship Verification

**Date:** 2026-08-04 | **Version:** 0.1.0 | **Artifact hash:** recorded at review start

## 1. Macro Architecture

/shipcheck is a **thin orchestration skill** over existing verification capability. It does NOT contain scanning engines — it routes a repo's quality dimensions to tools that already exist (semgrep, trivy, the Standards repo's `audit.sh`) and OMO AI-review skills, then aggregates the results into a per-dimension verdict.

```
User / hook ──> SKILL.md ──> shipcheck.py (CLI)
                                 │
                    ┌────────────┼──────────────┐
              verdict.py     checkers.py    dimensions.yaml
           (aggregation)    (subprocess     (taxonomy: dim →
              + render         wrappers)       checkers, severity)
                                 │
                 ┌───────────────┼────────────────┐
             semgrep          trivy           audit.sh
             (SAST)       (secrets/vulns)   (standards)
```

**Design stance:** reuse-not-rebuild (Constitution 3). The orchestrator is the *addition*; the checkers are subprocess boundaries, not imports.

## 2. Data Flow Walk

1. **Entry** — user runs `/shipcheck [repo]`, hook invokes `shipcheck.py`, or shell calls `shipcheck.py <repo> [flags]`. Default repo = cwd; must be a git repo (exit 2 otherwise).
2. **Stack detection** (`verdict.detect_stack`) — sniffs manifests (requirements.txt, package.json, Cargo.toml, go.mod, pom.xml, .github/workflows) → ecosystem tags (e.g. `python, github-actions`). Unknown stacks get `["unknown"]` — still verified, just without stack-specific routing.
3. **Taxonomy load** (`verdict.load_dimensions`) — parses `dimensions.yaml` (stdlib YAML-subset parser): each dimension declares `severity`, `checkers[]`, `ai_review`.
4. **Per-dimension orchestration** (`verdict.run_dimension`) — for each dimension, invokes its checkers via `checkers.py` subprocess wrappers; each returns `Finding[]`.
5. **Aggregation** — findings map to status: any `blocking` finding → `BLOCKING`; non-blocking findings → `WARN`; no findings + tool present → `PASS`; no checker + `ai_review` OR tool missing → `NOT_CHECKED` with reason.
6. **Output** — terminal table (default) or JSON (`--json`). Summary counts per status.
7. **Exit** — 1 if any BLOCKING (or `--strict` with any WARN); 0 otherwise; 2 on env error. The pre-push hook maps exit 1 → block push, timeouts/missing tools → fail-open.

## 3. Module Breakdown

| Module | Responsibility | HIDES | EXPORTS |
|---|---|---|---|
| `SKILL.md` | OMO front-door; degraded-mode routing to AI skills | OMO integration | `/shipcheck` command |
| `scripts/shipcheck.py` | Thin CLI: arg parse, exit codes | argv handling | `main()`, exit code contract |
| `scripts/verdict.py` | Stack detect, taxonomy load, per-dim orchestration, terminal render | routing/aggregation rules | `detect_stack`, `load_dimensions`, `run_dimension`, `build_verdict`, `render_terminal` |
| `scripts/checkers.py` | Subprocess wrappers for semgrep/trivy/audit.sh | tool-specific CLI + JSON parsing | `run_semgrep`, `run_trivy`, `run_audit`, `tool_available` |
| `scripts/model.py` | Shared dataclasses | data shape | `Finding`, `DimensionResult` |
| `scripts/hook-pre-push.sh` | Opt-in fast gate | hook glue, timebox | exit 0/1 |
| `dimensions.yaml` | v1 taxonomy (source of truth) | dimension definitions | schema: severity/checkers/ai_review |

**Dependency direction:** `shipcheck.py → verdict.py → {checkers.py, model.py}`. `checkers.py → model.py` only. No cycles (fixed via `model.py` extraction after initial verdict↔checkers circular import).

## 4. Key Decisions

1. **Orchestrator skill over standalone suite** — reuse audit.sh + semgrep + trivy + OMO skills instead of building scanning engines. Real tradeoff: depends on external CLIs being installed; missing tools degrade to NOT-CHECKED (honest) rather than failing.
2. **Verdict tiers (BLOCKING/WARN/INFO/NOT-CHECKED)** — VALIDATION showed audit.sh emits 62 polish failures on a small repo; flattening them would recreate the industry-wide noise>signal killer (LANDSCAPE finding: 5 tools' documented failures). Real tradeoff: more output structure; WARN can mask real issues without `--strict`.
3. **Runtime stack detection (manifest sniffing)** — no build-time per-repo config; any project works. Real tradeoff: detection is bounded (ambiguous repos → `unknown` → fewer stack-specific checks).
4. **Python stdlib orchestrator** — subprocess calls + JSON aggregation; zero new runtime deps. Real tradeoff: Python 3.10+ required (already present).
5. **Bundled taxonomy, Standards-repo sync deferred** — v1 isolation (premortem patch: don't touch the public Standards repo). Real tradeoff: taxonomy can drift from Standards until v2.

## 5. Quality Guarantees

- **NOT-CHECKED is first-class** — a dimension with no checker or a missing tool is reported NOT-CHECKED with a named reason; the verdict never fabricates a pass (Constitution 1). Verified: JSON output on Password-Generator shows 7 NOT-CHECKED with reasons.
- **BLOCKING always fails the gate** — exit 1 on any blocking finding; the pre-push hook blocks. Verified: Password-Generator → exit 1; hook → exit 1.
- **Signal > noise on real repos** — verified on 3 repos: Password-Generator (mutable action tags — real supply-chain findings), agentic-workflows (SSRF-class urllib, globals() exec-class, HIGH CVE, leaked JWT — all real).
- **Noise containment** — audit.sh standards polish is WARN-tier (never BLOCKING); semgrep runs once (not duplicated across security + supply-chain).
- **Reversibility** — skill is a self-contained directory; hook is opt-in; uninstall = delete dir + remove hook line.

## Mandatory Check

- [x] The verdict reproduces VALIDATION's evidence baseline — mutable GitHub Action tags flagged BLOCKING on Password-Generator (3 findings across ci.yml + dependabot-auto-merge.yml;
≥2 files, matching the baseline class).
- [x] Self-contained: no modification to the Standards repo; no new runtime dependencies.
