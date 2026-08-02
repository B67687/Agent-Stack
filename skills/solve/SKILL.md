---
name: solve
description: "Problem-solving technique selector. Uses a decision tree to classify any problem (bug, design, optimization, decision, unfamiliar code) and recommends the best technique(s) from ~70 strategies. MUST USE — orchestrator MUST load this skill before ANY non-trivial problem-solving task: when stuck, unsure which approach fits, debugging unfamiliar territory, design/architecture decisions, optimization, root cause analysis, intermittent/flaky failures, or anytime the approach is not immediately obvious. Reads from PROJECT_ROOT/PROBLEM_SOLVING_TECHNIQUES.md. Triggers: '/solve', 'I'm stuck', 'how should I approach this', 'what technique', 'I don't know how to', 'not sure how to', 'choose a strategy', 'which approach', 'help me think about this', 'how to debug', 'how to decide between', 'what's the best way', 'keeps failing', 'keeps breaking', 'randomly fails', 'random crash', 'intermittent failure', 'flaky test', 'no idea where to start', 'don't even know where to begin', 'tried everything', 'been at this for hours', 'this is frustrating', 'doesn't make sense', 'unexpected behavior', 'unexpected error', 'wrong result', 'silent failure', 'can't figure out', 'can't understand why', 'can't decide', 'not sure which', 'weighing options', 'trade-offs', 'pros and cons', 'how to design', 'how to structure', 'architecture decision', 'need to understand', 'unfamiliar code', 'explain how', 'how does this work'."
---

# /solve — Problem-Solving Technique Selector

## Quick start

```
/solve {describe your problem in 1-3 sentences}
```

The agent will:
1. Classify your problem type via the decision tree below
2. Read the relevant section(s) from `PROBLEM_SOLVING_TECHNIQUES.md` in the project root
3. Return a structured protocol: which technique(s) to use and step-by-step how to apply them

---

## Decision Tree — Classify the Problem

Start here every time. Walk through the levels. **Be honest** — misclassification is the most common failure mode.

```
LEVEL 1 — What kind of problem is this?

  A. Completely unfamiliar / don't know where to start
     → Cynefin (classify domain) → BFS (explore systematically)

  B. Regression — something that worked is now broken
     → Difference Check (what changed?) → Binary Search (bisect to root)

  C. Intermittent / flickering / flaky
     → Scientific Method (hypothesis-driven) + Design of Experiments

  D. Recurring pattern — same issue keeps coming back
     → 5 Whys (drive to systemic cause, not symptom)

  E. Competitive / adversarial — another agent or person opposes
     → Game Theory (model incentives, choose strategy)

  F. Straightforward — I know what to do, just need to execute
     → Skip to Level 2
```

```
LEVEL 2 — What's the scale?

  A. Too large for one pass
     → Divide & Conquer + MECE (partition into independent subproblems)

  B. Moderate but still complex
     → Decompose into ~3-5 subproblems → Level 3 per subproblem

  C. Small / simple
     → Execute directly (no technique needed)
```

```
LEVEL 3 — What's the goal?

  A. Find any working solution (quickly)
     → Forward Reasoning + Generate & Test (try simplest ideas first)

  B. Find the optimal solution (no compromises)
     → A* Search (heuristic-guided) or Decision Matrix (weighted scoring)

  C. Diagnose root cause
     → Abductive Reasoning + Bayesian Reasoning (maintain probabilities)

  D. Design something new / novel
     → First Principles (strip assumptions) + SCAMPER (modify existing)

  E. Meet a very hard criterion (tight perf, reliability, quality target)
     → Gradual Criterion Tightening (staircase of supersets)

  F. Make a decision among options
     → Decision Matrix (weighted criteria) + Pre-Mortem (surface hidden risk)
```

```
LEVEL 4 — Are you stuck?

  Yes?
     → Run the Creative Block Protocol:
       1. Restate the problem in different words
       2. Reframe: what if we called it X instead of Y?
       3. Invert: how would I intentionally cause the opposite?
       4. Analogy: what other domain has the same structure?
       5. Constraint drop: if this constraint vanished, what would I try?
       6. Random entry: pick a random word → force a connection

  No? → Continue, then Verify & Reflect
```

```
LEVEL 5 — Verify & Reflect

  1. Does the solution meet all constraints?
  2. What could go wrong? → Pre-Mortem + Red Team
  3. What did I learn? → Post-Mortem → Generalize for next time
```

---

## Technique Reference — Sections in PROBLEM_SOLVING_TECHNIQUES.md

Once you've classified the problem, read the corresponding section(s) from `PROBLEM_SOLVING_TECHNIQUES.md` in the project root.

| Classification | Section(s) to read | Why |
|---|---|---|
| Unfamiliar / don't know where to start | §1.2 Cynefin, §4.1 BFS, §4.2 DFS | Classify domain → systematic exploration |
| Regression (was working) | §7.5 Difference Check, §7.3 Binary Search | Find what changed → isolate to root |
| Intermittent / flaky | §7.1 Scientific Method, §7.8 Design of Experiments | Hypothesis → controlled experiment |
| Recurring issue | §7.4 Root Cause Analysis (5 Whys), §7.6 Causal Chain | Drive past symptoms to system cause |
| Large / too big | §3.1 Divide & Conquer, §3.2 MECE | Partition → parallelize |
| Need any solution fast | §2.7 Forward Reasoning, §4.5 Generate & Test, §9.1 Satisficing | Low-friction path to working solution |
| Need optimal solution | §4.6 A\* Search, §6.1 Decision Matrix | Heuristic-guided search or weighted scoring |
| Diagnose root cause | §2.3 Abductive Reasoning, §2.9 Bayesian Reasoning | Inference to best explanation + probability tracking |
| Design something new | §2.5 First Principles, §5.2 SCAMPER, §5.3 Analogical | Strip assumptions → generate alternatives |
| Hard criterion to meet | §9.7 Gradual Criterion Tightening | Staircase of supersets → progressive refinement |
| Decision among options | §6.1 Decision Matrix, §6.2 Decision Trees, §9.4 Pre-Mortem | Score → model uncertainty → surface risk |
| Competing priorities | §6.3 Pareto (80/20), §6.4 Opportunity Cost | Find the vital few, name what you're not doing |
| Systems / recurring structure | §8.1 Systems Thinking, §8.2 Feedback Loops, §8.5 Bottleneck Analysis | Find leverage points, break constraints |
| Creative block / stuck | §5.1–5.6 (all of Creative), §10.10 Einstellung | Divergent techniques, break fixation |
| Adversarial / competition | §9.9 Game Theory | Model incentives, choose equilibrium |
| Cognitive bias suspected | §10.1–10.11 pick relevant safeguard | Match bias to countermeasure |
| Any non-trivial task | §1.1 Polya (4-step), §11.4 Decision Tree, §12 Agent Protocols | Meta-framework + workflow integration |

---

## Agent Protocol — What to do when invoked

When the agent receives a `/solve` invocation, execute this protocol:

```
1. COLLECT: Ask user for problem description if not provided inline
2. CLASSIFY: Walk the Decision Tree (Levels 1-5) with the user's input
3. READ: Read the recommended section(s) from PROBLEM_SOLVING_TECHNIQUES.md
   - Use the Technique Reference table above
   - Read enough to extract concrete steps (not the full file)
4. SYNTHESIZE: Combine classification result + technique details into a protocol:
   - "Problem type: {classification}"
   - "Recommended technique(s): {sections}"
   - "Protocol: {step-by-step with the technique's agent protocol}"
5. OUTPUT: Present to user with:
   - Decision tree path taken (transparent reasoning)
   - The protocol to follow
   - Optionally: suggest alternatives if this doesn't work
6. EXECUTE: Offer to carry out the protocol: "Shall I proceed with this approach?"
```

## User-less invocation (background / passive)

If another agent or automation loads this skill without a direct user input, run:

1. **Context scan**: What is the current task? What phase is it in?
2. **Is there a problem?** → If no problem detected, do nothing.
3. **Is the current approach making progress?** → If yes, do nothing.
4. **If stuck or regressing** → Classify, read, and return a technique recommendation.

---

## Common pitfalls

| Pitfall | Mitigation |
|---------|-----------|
| Classifying as "complicated" when it's "complex" (over-confidence) | If unsure whether analysis will yield answer, treat as complex → probe first |
| Skipping Level 2 (scale) and picking wrong-grained technique | Always ask: "Can I hold this whole problem in my head at once?" |
| Applying the same technique you always use (Einstellung Effect) | After classifying, pause: "Am I picking this because it fits or because it's familiar?" |
| Reading the entire file instead of one section | Use the table above — read only the relevant 2-3 sections |
| Forgetting to verify | Always run Level 5 before calling the problem solved |
