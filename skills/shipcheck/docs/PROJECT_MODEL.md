# PROJECT_MODEL — /shipcheck

**Version:** 0.1.0 | **Date:** 2026-08-04 | **Mandated by:** SPECIFICATION §2

## States

```
IDEA → SPEC'D → PROTOTYPED → IMPLEMENTED → POLISHED → SHIPPED → MAINTAINED → EVOLVED
```

Current state: **SHIPPED** (v0.1.0).

## Valid transitions

| From | To | Trigger |
|---|---|---|
| SPEC'D | PROTOTYPED | VALIDATION spike (breadboard on Password-Generator) |
| PROTOTYPED | IMPLEMENTED | EXECUTOR delivered skill + tests |
| IMPLEMENTED | POLISHED | independent REVIEW fixes (this doc, regression tests, count fix) |
| POLISHED | SHIPPED | REVIEW clean / conditional-pass resolved |
| SHIPPED | MAINTAINED | bugfix (new checker bug, parsing fix) |
| SHIPPED | EVOLVED | v2 feature: Scorecard integration, taxonomy sync, CI tier |

## Invalid transitions

- `IMPLEMENTED → SHIPPED` without passing POLISHED (REVIEW gate)
- `SHIPPED → EVOLVED` without a ratified spec amendment (no scope creep, authority rule 6)
- Any transition that modifies the Standards repo in v1 (constitution 9)

## Invariants (must never change during any transition)

1. Verdict never claims a check that didn't run — NOT-CHECKED is first-class (Constitution 1).
2. BLOCKING always fails the gate (exit 1; pre-push hook blocks).
3. No modification of the Standards repo in v1 (Constitution 9).
4. Reuse-not-rebuild: no new scanning engine in the orchestrator (Constitution 3).
5. stdlib-only runtime in shipcheck.py (Constitution 7).

## Blast radius map

| Change | Must also check |
|---|---|
| verdict.py aggregation/status logic | verdict tests + integration on Password-Generator |
| checkers.py tool invocation / JSON parsing | checkers tests + audit.sh JSON contract |
| dimensions.yaml (new dim/checker) | load_dimensions test + routing test |
| SKILL.md degraded-mode wording | README + EXPLAINER |
| hook-pre-push.sh | hook contract (10s, fail-open) |

Co-change cluster: {shipcheck.py, verdict.py, checkers.py, model.py} change together; {dimensions.yaml, README} change together; {SKILL.md, README} change together.
