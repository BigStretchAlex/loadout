---
name: build
description: Autonomous implementation based on plan.md
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite, AskUserQuestion, Edit, Write
argument-hint: "[<dir> [step <N>[-<M>]]]"
model: sonnet
---

# Build Skill

Execute the implementation plan for a work item autonomously, working through each step and capturing insights.

`/tdd-build` (`skills/tdd-build/SKILL.md`) composes on this skill — it runs these same phases and layers a TDD gate delta on top (fail-first proof per step, gate re-verification after the simplify pass). A change to any phase below is a change tdd-build inherits; check it when editing.

## Instructions

### Phase 1: Validation & Context Loading

1. **Parse arguments**: "$ARGUMENTS" should contain:
   - A directory path where the plan lives (e.g., `.dev/feat-auth-flow`) — required
   - Optional step range override (e.g., `step 3` or `step 3-5`)
   - If empty, jump to the **Fallback** section at the bottom

2. **Validate prerequisites**:
   - `<dir>/plan.md` must exist — if not, suggest running `/plan` first and stop

3. **Load full context**:
   - Read `<dir>/plan.md` — extract step count, acceptance criteria, and any step range override
   - Read `<dir>/scratch.md` if it exists (prior decisions and insights)
   - Read `<dir>/research.md` if it exists (domain and technical context)

4. **Generate or load `<dir>/tasks.md`**:
   - If it does not exist: generate it from the plan's steps using `templates/tasks.md` — one line per step in the template's exact format: `- [ ] Step N: <title> — <ACTION> — <file> — Validation: pending` (ACTION = the plan's CREATE/UPDATE/ADD/DELETE keyword where available; every step starts `Validation: pending` — the executor updates it to `pass`/`fail` per step)
   - When generating fresh, also append the `loadout-handoff` footer (schema in `templates/handoff-footer.md`) below the step list — never inside it:
     ```loadout-handoff
     schema: 1
     artifact: tasks
     produced_by: /build
     work_item: <dir>
     lane: standard
     verification: none
     next_command: /build
     next_arguments: <dir>
     ```
     Field semantics: `templates/handoff-footer.md`. Set `lane` by reading `<dir>/plan.md`'s own `loadout-handoff` footer, if it has one, and copying its `lane` value unchanged (`standard`/`tdd`/`express`); if `plan.md` has no footer, default to `standard`. This skill writes `verification: none` and `next_command: /build` once, at generation, and never touches the footer again on resume — `agents/build-executor.md` has exclusive ownership of updating those two fields (plus `next_arguments` when it changes) as the build progresses.
   - If it exists and has checked items, this is a **resume**: report "N of M steps complete, resuming from Step X" and instruct the executor to skip the checked steps
   - An explicit `step <N>-<M>` argument always wins over tasks.md-derived resume state

5. **Load testing rules**: follow `templates/testing-rules.md` — its Discovery steps, then its "Inject verbatim into an executor prompt" consumption mode. Hold the found contents for injection into the executor prompt (Phase 3); if none were found, note it for the final report per that template's Discovery step 3.

6. **Create initial `TodoWrite` list** from the plan steps (filtered to step range if specified)

---

### Phase 2: Gap Analysis

7. **Review plan for ambiguities** before writing any code:
   - Look for: missing file paths, unclear API contracts, ambiguous behaviors, unstated assumptions that would block implementation
   - **If genuine gaps exist**: batch ALL critical questions into a single `AskUserQuestion` call — up to 4 questions, numbered list
   - **If plan is clear**: skip this phase entirely — do not ask questions for the sake of asking
   - Record any resolutions in `scratch.md` under **Decisions**

---

### Phase 3: Confirm & Execute

8. **Confirm with the user** before starting:
   ```
   ## Build: [dir]

   Plan has [N] steps. [Step range if specified, e.g., "Running steps 3–5."]
   [Resume note if applicable, e.g., "2 of 6 steps complete, resuming from Step 3."]

   Acceptance criteria: [N]

   Proceed? (yes / review plan first / cancel)
   ```

9. **Spawn the `build-executor` agent** with the following prompt:
   > Work item: `<dir>/`
   > Execute the plan in `plan.md`. [Step override if specified, e.g., "Run only steps 3–5."]
   > Task list: `tasks.md` — skip steps already checked; after each step's verification passes, check off its line.
   > Capture insights in `scratch.md` as you work.
   > Stop and report if any step fails or requires plan changes.

   If testing rules were found in Phase 1, append their contents as a clearly delimited section:
   > Testing rules (binding):
   > --- BEGIN TESTING RULES ---
   > [contents of each file found, labeled with its path]
   > --- END TESTING RULES ---

---

### Phase 4: Handle Build Report

10. **Evaluate build report**:
    - If all steps completed: proceed to Phase 5
    - If blocked: present the issue via `AskUserQuestion` and let the user choose:
      - **Modify plan**: update `plan.md` and re-spawn build-executor for the remaining steps
      - **Skip step**: continue with the remaining steps
      - **Abort**: stop the build

---

### Phase 5: Simplify, Acceptance Criteria & Summary

11. **Update `<dir>/scratch.md`** with any insights, decisions, or surprises that emerged during the build.

12. **Simplify pass**: spawn the `code-simplifier` agent on the files the build modified (listed in the build report). Count the refinements it applied for the final report.

13. **Acceptance criteria check (final phase)** — walk the plan's `## Acceptance Criteria` list and compute, per criterion, from the evidence the build report already provides (each step's `Validation:` pass/fail/pending and its Check, plus the build report's own `### Acceptance Criteria Status` section):
    - **Met** — a specific step's Validation Check (or TDD Gate, under `/tdd-build`) passed and demonstrates this criterion. Name the step and the check.
    - **Unverified** — no step's validation covers this criterion, or the covering step's validation is `fail` or `pending`. State which, explicitly — do not omit it from the report.
    - Never mark a criterion **Met** without naming the check that proved it — a criterion is not counted just because its step was implemented.
    - If the simplify pass in step 12 touched a file backing a `pass` validation, re-check that criterion's Validation Check before finalizing the count — the simplify pass must not silently invalidate a previously-passing check.
    - This per-criterion walk is what populates the `[N] / [total]` line below — it is computed here, not asserted.

14. **Report**:
```
## Build Complete: [dir]

**Steps completed**: [N] / [total]
**Acceptance criteria met**: [N] / [total]
**Simplify pass**: [N refinements applied | clean — no changes]

### Acceptance Criteria Status
- [x] [criterion] — met — [step + Validation Check / TDD Gate that verified it]
- [ ] [criterion] — unverified — [reason: no covering step / covering step's validation is fail or pending]

[Only if no testing rules were found in Phase 1:] No testing rules found — consider /create-rules.

Next step: `/review <dir>` to run a code review.
```

---

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have a `plan.md` but no `review.md` — suggest building those
2. If none found, ask the user what they'd like to build via `AskUserQuestion`
