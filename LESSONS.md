# Cross-Project Knowledge Base

> Loaded every session. Each entry is a lesson learned from a project.
> Scope conditions matter — lessons are NOT universal truths.
> Entries are append-only. Deprecate, don't delete.
> Half-life tagging: [permanent] [semi-permanent:YYYY] [ephemeral:YYYY-MM]

---

## Architecture & Design

### [permanent] Module boundaries are one-way doors

- **Project:** Bus-Hop (v0.5.0 monolithic to module split)
- **Lesson:** Choosing module boundaries at the start is a one-way door. The v0.5.0 split required rewriting all tests because the boundary between domain/data/app was wrong. Had we run FUNDAMENTALS on the module decomposition, we would have caught this before writing 4K LOC.
- **Scope:** Any project with more than 3 modules. Does NOT apply to scripts under 500 lines.
- **Counterexample:** A single-purpose CLI tool with no domain separation (like a password generator) does not benefit from pre-modularization.
- **Evidence:** 4K LOC, 161 tests. The module split required significant test rewrites.
- **Status:** active

### [permanent] AI card quality is sufficient for standard CS curriculum

- **Project:** Oh-My-Learner (v2 to v3)
- **Lesson:** DeepSeek V4 Flash generates accurate flashcards for standard CS topics (OS, algorithms, automata, networking) at university level. 80+ cards generated, zero factual errors found.
- **Scope:** Standard CS curriculum topics that have not changed in 10+ years. Does NOT apply to bleeding-edge research or proprietary systems.
- **Counterexample:** A card about a specific professor's lecture notation not in any textbook (AI training data does not cover this).
- **Evidence:** 88 templates across 6 subjects, all from standard textbooks. Installed and reviewable.
- **Status:** active

### [permanent] Knowledge type determines optimal study strategy

- **Project:** Oh-My-Learner (learning science research)
- **Lesson:** Interleaving across subjects improves retention for PROCEDURAL knowledge (effect size g=0.42) but HARMS declarative fact retention (g=-0.39). The v1 design applied interleaving to everything uniformly, which was counterproductive for definitions.
- **Scope:** Any spaced repetition or learning system. Does NOT apply to project management or task tracking.
- **Counterexample:** For advanced learners (more than 2 months in a topic), even declarative content benefits from interleaving. Boundary conditions depend on learner stage.
- **Evidence:** Brunmair and Richter 2019 meta-analysis (59 studies). Implemented as knowledge_type field with selective interleaving.
- **Status:** active

### [permanent] Language must be clarified before any extraction

- **Project:** Development Protocol (self-apply, v2 to v3)
- **Lesson:** Before any extraction technique, the AI must restate what it heard in different words and probe multiple dimensions/scales/perspectives. Otherwise, the AI optimizes for the most likely interpretation rather than the correct one.
- **Scope:** Any human-AI interaction where intent matters. Does NOT apply to AI-AI communication or purely technical prompts.
- **Counterexample:** Asking what time it is requires no clarification. The problem domain is intent, not fact.
- **Evidence:** Added as Clarify the Language in EXTRACTION.md. Caught multiple misinterpretations during self-apply.
- **Status:** active

### [permanent] Real-world binary corpora are vendor dialects — parse adaptively, document skip classes with hard-asserted counts

- **Project:** Waybill (private EDI/ISO 8583 parsing library)
- **Lesson:** Wire formats in the wild are a zoo of vendor dialects (raw bytes, ASCII hex-text, length-prefixed, BCD MTI, EBCDIC). A spec table alone failed ~87% of real files. The fix was adaptive parsing (try ASCII framing, fall back to packed-BCD prefixes per field, dual-mode MTI, header strip) + hard-asserted skip classes with exact counts — never assert 'tested>0'.
- **Scope:** Any binary format parser fed from real-world collections (payments, emulation, forensics, legacy media). Does NOT apply to clean-room synthetic corpora.
- **Counterexample:** Asserting the gate as 'tested>0' hid a ~87% failure rate until an independent reviewer caught it — a loose assertion masked the real gap.
- **Evidence:** Adaptive-prefix parser + hard-asserted corpus counts (independent review FAIL on the loose gate).
- **Status:** active

---

## Process & Workflow

### [semi-permanent:2028] One-way doors need minimum prototypes

- **Project:** Development Protocol (FUNDAMENTALS research)
- **Lesson:** A one-way door decision should be validated with the MINIMUM prototype. Schema plus 3 Queries for data model, one end-to-end endpoint for tech stack. If 10,000 projects already validated a choice (PostgreSQL for web), zero validation needed.
- **Scope:** Any project with irreversible decisions. Does NOT apply to two-way doors (reversible under 1 team-week).
- **Counterexample:** A novel cryptography or consensus algorithm where no prior validation exists. The minimum prototype may need to be production-grade.
- **Evidence:** Blake Crosley 15x multiplier. Boehm Risk Exposure model. Implemented in FUNDAMENTALS.md.
- **Status:** active

### [semi-permanent:2028] Goalpost shifts are learning, not failures

- **Project:** Development Protocol (v3 reframe)
- **Lesson:** The protocol originally treated scope changes as failures (max 3 warps, forced into PERFECT). Research showed this was wrong. Changed to learning shifts with up to 5 documented shifts per project. Each shift logs what you learned, what changed, and what it cost.
- **Scope:** Any creative or novel project where discovery is expected. Does NOT apply to routine maintenance.
- **Counterexample:** A deploy-a-static-site task where scope change is a failure, not a learning shift.
- **Evidence:** Schon The Reflective Practitioner, Brooks No Silver Bullet, Polanyi Tacit Knowledge. Implemented as Learning Shifts in RULES.md.
- **Status:** active

### [semi-permanent:2027] The same AI cannot audit itself

- **Project:** Development Protocol (REVIEW.md design)
- **Lesson:** The Godel Gate requires a SEPARATE session with no prior context. In-session reviews find fewer issues than fresh-session reviews. The independence protocol is not optional.
- **Scope:** Any project. Always.
- **Counterexample:** None found. Every test case confirmed independence matters.
- **Evidence:** Meta-review of Dev Protocol: in-session review had to flag its own lack of independence as a limitation.
- **Status:** active

### [semi-permanent:2027] Size rules catch real structural issues

- **Project:** Oh-My-Learner (v3, Size Rule enforcement)
- **Lesson:** A 250 LOC per file / 40 lines per function limit caught storage.go (583 LOC) and review.go (269 LOC) as over-large. Splitting them improved maintainability without breaking anything.
- **Scope:** Any codebase with files exceeding 250 LOC. Does NOT apply to generated code or configuration files.
- **Counterexample:** A file with 300 LOC of pure data declarations (no logic) is fine at a higher limit. The rule targets logic density.
- **Evidence:** storage.go split into 4 files (max 194 LOC each). review.go split into 2 files (max 150 LOC each). Zero test changes needed.
- **Status:** active

### [permanent] Golden-corpus-first: the failure table is both CI gate and #1 marketing asset

- **Project:** Waybill (private EDI/ISO 8583 parsing library)
- **Lesson:** Assemble a real-message corpus with provenance BEFORE writing the engine, and build the prior-library failure table from it at M0. It doubles as the headline marketing asset (prior open-source libs failed most real-world files; prior-art precedent) and the CI gate (full corpus parses, zero panics). Publish it honestly — a falsified 'clean pass' claim is worse than no claim.
- **Scope:** Any open-core library play where prior fragmented impls exist. Does NOT apply where a strong incumbent exists — the slot is closed.
- **Counterexample:** The stale 'no clean pass' claim would have shipped at M7 if the reviewer hadn't flagged it — a falsified claim is worse than no claim.
- **Evidence:** Prior-library failure table + real-message corpus assembled at M0; M0→M8 pipeline.
- **Status:** active

---

### [permanent] Agent 'complete' is not delivery — verify with git

- **Project:** Waybill (all milestones)
- **Lesson:** 4 of ~15 subagents reported 'complete' with ZERO committed work (analysis-paralysis: full designs in reasoning, never a write call; plus no-commit completions). Git is the source of truth: after every agent completion, check `git log origin/main --oneline -3` + `git status` before accepting. The anti-paralysis contract (design already given → transcribe into files; first four tool calls must be write; ≤50 lines reasoning per borrow question) + mandatory checkpoint commits are the fixes.
- **Scope:** Delegating multi-file implementation to subagents. Does NOT apply to research/read-only agents.
- **Counterexample:** Two milestones each took multiple attempts because 'complete' was trusted over git state.
- **Evidence:** Milestone retries from trusting 'complete' over git; analysis-paralysis diagnosis transcripts.
- **Status:** active

### [semi-permanent:2027] State docs drift silently — update transition logs at the moment of transition

- **Project:** Waybill
- **Lesson:** The state doc said one state was current while a release was tagged and shipped (no transition row logged) — the REVIEW gate caught it. State-transition docs must be updated in the same commit as the transition, not at review time.
- **Scope:** Any project with a state machine / state-model doc. Does NOT apply to throwaway spikes.
- **Counterexample:** The valid-transitions table omitted a transition that had actually happened — the table and the log disagreed.
- **Evidence:** State-model doc drifted from the release state until the REVIEW gate caught it.
- **Status:** active

---

## Tooling & Dependencies

### [semi-permanent:2028] stdlib over external SDKs for AI integration

- **Project:** Oh-My-Learner (agent package)
- **Lesson:** The agent package uses Go's stdlib net/http instead of the OpenAI Go SDK. This eliminates a dependency, reduces binary size, and avoids SDK version lock. For a simple chat completion call, the SDK adds boilerplate without value.
- **Scope:** AI integrations where the API is OpenAI-compatible. Does NOT apply when SDK provides auth flows, streaming helpers, or retry logic that stdlib would need to reimplement.
- **Counterexample:** An application using multiple AI providers (OpenAI, Anthropic, Google) benefits from a unified SDK for provider switching.
- **Evidence:** Oh-My-Learner agent/agent.go uses stdlib net/http, works with DeepSeek API, zero dependency issues.
- **Status:** active

### [ephemeral:2027-07] DeepSeek API keys in OpenCode env are internal

- **Project:** Development Protocol (validation spike)
- **Lesson:** The DEEPSEEK_API_KEY visible in the environment is set by OpenCode for its own internal proxy routing. It is NOT a valid key for direct API calls to api.deepseek.com. Direct AI integration requires a user-provided key.
- **Scope:** OpenCode users setting up AI integrations. Does NOT apply to other AI harnesses.
- **Counterexample:** The OPENAI_API_KEY in OpenCode env was a valid direct key. Provider-specific behavior.
- **Evidence:** Tested both api.deepseek.com/chat/completions and /v1/chat/completions. Both returned 401 with the env key.
- **Status:** active

---

## Meta-Lessons (about this KB itself)

### [permanent] The KB stays under 500 lines or it will not be loaded

When it exceeds 500 lines, review and purge deprecated entries. Size discipline is signal quality.

### [permanent] Entries without counterexamples are suspect

If you cannot think of a scope condition where the opposite is true, you have not thought hard enough.

### [permanent] One entry per distinct lesson. Merge duplicates.

If two entries say the same thing with different words, pick the better one and delete the other.

## 2026-08-04 — Development Protocol run (Cluster AA, Personal Life OS)

### [permanent] Write ledger entries per phase immediately, mini-check at every transition.
The Gödel Gate (REVIEW) caught a missing INBOX ledger entry and systemic hygiene debt (shift-log absent, test artifact absent) only at the end. Fix: every phase transition runs a mini ledger fitness check — do the phase's methods have entries with file evidence? Prevents end-of-run hygiene debt.

### [permanent] Socratic questions must mine the INBOX dump first — never re-interview.
The user pushed back on §7: "I literally asked you that question at the very start of the session." Their opening thoughts already contained the answer. Re-asking wastes user energy and erodes trust. Rule: before any Socratic/probing question, cross-reference the original capture; only ask what's genuinely new.

### [permanent] Behavioral test artifacts are created during EXECUTOR, not discovered at REVIEW.
Spec §8 defines the test table; nothing created the runnable checklist file until the reviewer flagged its absence. EXECUTOR milestone checklists must include "create the test artifact (TESTS.md)" as a first-class deliverable.

### [permanent] Committed-self authority model (for AI-personal systems).
When a user asks "shouldn't your opinion override mine?", the answer is: the AI holds the user's OWN committed philosophy (written with momentum) steady against their momentary urges — it never substitutes its own values. Philosophy-grounded recommendation is the default that HOLDS; momentary urges don't override without a reasoned amendment; final authority remains the human. The user ratified this enthusiastically — it's what "objective strategist" means when the AI has no values of its own.

### [permanent] "Short answers = uncertainty" signal (human pattern).
User self-identified: when their answers get short/low-effort, it signals genuine uncertainty, not indifference. Slowing down to investigate uncertainty beats powering through.
