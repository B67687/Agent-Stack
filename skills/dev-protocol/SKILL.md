---
name: dev-protocol
description: "Run the Development Protocol on the current project. Reads the protocol dynamically from the Development-Protocol repo — whatever steps it currently defines, execute in order. Triggers: '/dev-protocol', 'run the dev protocol', 'start the development protocol', 'dev protocol', 'run development protocol'."
---

# /dev-protocol — Development Protocol Executor

## Quick Start

```
/dev-protocol [start-from-step]
```

Without arguments, starts from the beginning of the current protocol pipeline.
With a step name, resumes from that step (e.g., `/dev-protocol VALIDATION`).

## Protocol Definition

The Development Protocol is defined at:

- **Local:** `~/projects/dev/Development-Protocol/`
- **Remote:** https://github.com/B67687/Development-Protocol

This skill does NOT hardcode the pipeline steps. It reads the protocol repo dynamically.

## Agent Protocol — What to do when invoked

When invoked via `/dev-protocol`, execute this protocol:

### Phase 1: Understand the Current Protocol

1. **Read the README** from the Development Protocol repo (`PROTOCOL_DIR=~/projects/dev/Development-Protocol/`)
2. **Identify the current pipeline structure** — which steps exist and their ordering
3. **Read each step's Markdown file** to understand what it requires
4. **Determine where to start** — if the user specified a step name, start there; otherwise start from the first step

### Phase 2: Execute Each Step

For each step in the pipeline:

1. **Read the step's `.md` file** from the protocol repo fully
2. **Understand the methodology** — what techniques, tools, and outputs it requires
3. **Execute the step** in the current project context:
   - For dialogue-heavy steps (EXTRACTION, AMBITION): engage with the user
   - For research-heavy steps (LANDSCAPE): parallel agent research
   - For template-heavy steps (SPECIFICATION): scaffold the output files
   - For execution steps (EXECUTOR): implement the spec
4. **Save outputs** to `.omo/plans/` with descriptive names
5. **Progress to the next step** — inform the user and continue

**Response format during protocol execution:** Every response follows the 3-layer format from EXTRACTION.md § Protocol Output Format:
   - **Layer 1: Overview** — Pipeline progress checkmarks (completed/in-progress/pending)
   - **Layer 2: Verbose** — The step's conversation content
   - **Layer 3: Round Checkmarks** — What was accomplished this round
   The format activates when a protocol step is executing and pauses when conversation is outside-procol (meta discussion, planning, etc.).

### Phase 3: Phase Tracking

- After each step completes, record progress in `.omo/protocol-state.md`:
  ```markdown
  # Protocol State

  **Protocol repo:** Development-Protocol (main)
  **Project:** [project-name]
  **Started:** [date]
  **Completed:** [step1], [step2], ...
  **Current:** [step-name]
  **Next:** [next-step]
  ```
- If the project already has a `.omo/protocol-state.md`, resume from the `Current` step
- If protocol files change between sessions (git pull), re-read the step files

## Key Principles

1. **Dynamic, not hardcoded** — The pipeline comes from the repo, not this skill. If the protocol adds a step, this skill executes it. No updates needed.
2. **Context-aware** — Run in the current project directory. Save artifacts there (`.omo/`).
3. **User-paced** — Dialogue steps wait for user input. Research steps run in parallel. Implementation steps execute autonomously within specified autonomy level.
4. **Resumable** — State is saved after each step. Resume from any point.
5. **Any project type** — Works for code projects, docs, research, anything.
6. **Protocol Output Format** — During active protocol execution, use the 3-layer format from EXTRACTION.md § Protocol Output Format:
   **Overview** (pipeline checkmarks) → **Verbose** (step content) → **Round Checkmarks** (what was done this round).
   Outside protocol execution, normal free-form conversation.

## Protocol Reference (as of last read)

The protocol pipeline is defined in the Development Protocol repo's README. Common steps:

- `EXTRACTION` — Extract real problem from stated solution (7 techniques)
- `FUNDAMENTALS` — One-way door decisions, LLM bias detection
- `DECOMPOSITION` — Cynefin classify, MECE tree, KNOWN/RESEARCH/PROTOTYPE
- `AMBITION` — Research-interleaved tightening dialogue (6 rounds)
- `LANDSCAPE` — Structured research (Frame/Search/Evaluate/Synthesize)
- `VALIDATION` — Prototyping gate with KILL/PIVOT/COMMIT scoring
- `SPECIFICATION` — 14-section spec template
- `EXECUTOR` — Implementation with autonomy levels (incl. POLISH post-execution)
- `EXPLAINER` — Architecture doc (docs/EXPLAINER.md)
- `REVIEW` — Independent meta-review (incl. SPEC_SYNC fidelity check)
- `REVIEW` — Independent meta-review (27-check audit)

Read the actual files for current definitions — this list may be stale.

## States Directory

All protocol artifacts go in `.omo/plans/`:

- `extraction-output.md`
- `fundamentals-output.md`
- `decomposition-output.md`
- `ambition-output.md`
- `landscape-output.md`
- `validation-output.md`
- `specification.md`
- `review-findings.md`
- `protocol-state.md` (auto-generated, tracks progress)
