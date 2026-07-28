---
name: tdd-build
description: TDD-gated autonomous implementation based on a plan.md with TDD Gates. Use when the user says "tdd build", "build with test gates", "run the tdd plan", or wants every step proven by a failing-then-passing test.
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite, AskUserQuestion, Edit, Write
argument-hint: [<dir> [step <N>[-<M>]]]
model: sonnet
---

# TDD Build Skill

Execute a TDD-augmented implementation plan autonomously. A phase-for-phase variant of `/build`: same executor, same task tracking, same blocked handling and simplify pass — but every step is gated by its **TDD Gate**: the gate's test must fail before implementation and pass after, and Phase 5 re-runs all gates as quantifiable proof of completion.

Gates use the four canonical field names produced by `/tdd-plan` — **Test**, **Command**, **Fail-first**, **Pass condition** — plus the plan-level `## TDD Gate Summary` table (Step | Command | ACs covered).

## Instructions

### Phase 1: Validation & Context Loading

1. **Parse arguments**: "$ARGUMENTS" should contain:
   - A directory path where the plan lives (e.g., `.dev/feat-auth-flow`) — required
   - Optional step range override (e.g., `step 3` or `step 3-5`)
   - If empty, jump to the **Fallback** section at the bottom

2. **Validate prerequisites**:
   - `<dir>/plan.md` must exist — if not, suggest running `/tdd-plan` first and stop
   - **Verify the plan is TDD-gated**: every step must have a `**TDD Gate**:` block, and a `## TDD Gate Summary` section must exist. If either check fails, the plan is not TDD-ready — fire `AskUserQuestion`:
     1. **Run `/tdd-plan <slug>` first** (recommended) — augment the plan with gates, then re-run `/tdd-build`
     2. **Fall back to plain `/build <slug>`** — build without test gates
     3. **Abort**

3. **Load full context**:
   - Read `<dir>/plan.md` — extract step count, acceptance criteria, each step's TDD Gate, the `## TDD Gate Summary` table, and any step range override
   - Read `<dir>/scratch.md` if it exists (prior decisions and insights)
   - Read `<dir>/research.md` if it exists (domain and technical context)

4. **Generate or load `<dir>/tasks.md`**:
   - If it does not exist: generate it from the plan's steps using `templates/tasks.md` — one line per step: `- [ ] Step N: <title> — <ACTION> — <file>` (ACTION = the plan's CREATE/UPDATE/ADD/DELETE keyword where available)
   - If it exists and has checked items, this is a **resume**: report "N of M steps complete, resuming from Step X" and instruct the executor to skip the checked steps
   - An explicit `step <N>-<M>` argument always wins over tasks.md-derived resume state

5. **Load testing rules** (never block on this):
   - Read `.claude/rules/common/testing.md` if it exists
   - Detect the project's language(s) and read `.claude/rules/<language>/testing.md` for each, if present
   - If any were found, hold their contents for injection into the executor prompt (Phase 3)
   - If none were found, note it — the final report gains one line: "No testing rules found — consider /create-rules"

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
   ## TDD Build: [dir]

   Plan has [N] steps, all TDD-gated. [Step range if specified, e.g., "Running steps 3–5."]
   [Resume note if applicable, e.g., "2 of 6 steps complete, resuming from Step 3."]

   Acceptance criteria: [N]

   Proceed? (yes / review plan first / cancel)
   ```

9. **Spawn the `build-executor` agent** (used unchanged — the TDD protocol lives entirely in this prompt) with the following prompt:
   > Work item: `<dir>/`
   > Execute the plan in `plan.md`. [Step override if specified, e.g., "Run only steps 3–5."]
   > Task list: `tasks.md` — skip steps already checked; after each step's verification passes, check off its line.
   > Capture insights in `scratch.md` as you work.
   > Stop and report if any step fails or requires plan changes.
   >
   > TDD protocol (binding — every step in `plan.md` carries a **TDD Gate** with fields **Test**, **Command**, **Fail-first**, **Pass condition**):
   > --- BEGIN TDD PROTOCOL ---
   > For each step, in this order:
   > 1. **Fail-first evidence** — BEFORE implementing, run the step's gate **Command**. It MUST fail, for the reason stated in the gate's **Fail-first** field. Record the observed failure in `scratch.md` (the command run + the key output line proving the failure).
   > 2. **Implement** the step as described in the plan.
   > 3. **Pass evidence** — re-run the gate **Command**. It MUST pass, meeting the gate's **Pass condition**, before the step's `tasks.md` line may be checked off. A step whose gate has not passed is not complete — never check it off.
   > 4. **If the gate cannot be made to fail first** (e.g., the behavior already exists, or the test cannot be written before a scaffold step lands), record the reason in `scratch.md` and proceed — but never skip fail-first silently. An unexplained gate that passes before implementation is a blocking condition: stop and report it.
   > A gate that never passes after implementation is also blocking: stop and report it rather than checking the step off.
   > --- END TDD PROTOCOL ---

   If testing rules were found in Phase 1, append their contents as a clearly delimited section:
   > Testing rules (binding):
   > --- BEGIN TESTING RULES ---
   > [contents of `.claude/rules/common/testing.md` and each `<language>/testing.md`, labeled with its path]
   > --- END TESTING RULES ---

---

### Phase 4: Handle Build Report

10. **Evaluate build report**:
    - If all steps completed with fail-first and pass evidence recorded: proceed to Phase 5
    - If blocked — including the gate-specific blocking conditions: a gate that **never failed first** and has no recorded reason in `scratch.md`, or a gate that **never passed after implementation** — present the issue via `AskUserQuestion` and let the user choose:
      - **Modify plan**: update `plan.md` (step and/or its gate) and re-spawn build-executor for the remaining steps
      - **Skip step**: continue with the remaining steps (the step's gate — and its ACs — remain unmet; record the decision in `scratch.md`)
      - **Abort**: stop the build

---

### Phase 5: Simplify, Gate Re-verification & Summary

11. **Update `<dir>/scratch.md`** with any insights, decisions, or surprises that emerged during the build.

12. **Simplify pass**: spawn the `code-simplifier` agent (used unchanged) on the files the build modified (listed in the build report). Count the refinements it applied for the final report.

13. **Gate re-verification**: after the simplify pass, re-run **every** gate Command from the `## TDD Gate Summary` table (skipped steps excluded). Every gate must still meet its Pass condition — this proves the simplify pass broke nothing. If any gate now fails, treat it as a regression: revert or fix the offending simplification until the gate passes again, and note it in `scratch.md`.

14. **Report**:
```
## TDD Build Complete: [dir]

**Steps completed**: [N] / [total]
**Acceptance criteria met**: [N] / [total]
**Simplify pass**: [N refinements applied | clean — no changes]
**Gate re-verification**: [N/N gates passing after simplify]

### Gate Results

| Step | Fail-first observed | Final pass |
|------|--------------------|-----------|
| 1 | yes — [key failure line] | yes |
| ... | ... | ... |

[Only if no testing rules were found in Phase 1:] No testing rules found — consider /create-rules.

Next step: `/review <dir>` to run a code review.
```

---

## Rules

1. The `build-executor` and `code-simplifier` agents are used **unchanged** — the entire TDD protocol is carried in the Phase 3 prompt, never in agent edits
2. **Gates are the source of truth for step completion** — never check off a `tasks.md` step whose gate Command has not passed its Pass condition
3. Fail-first is never skipped silently — either the failure is observed and recorded in `scratch.md`, or the reason it could not fail is recorded there; an unexplained pre-implementation pass is blocking
4. Gate blocking goes through the same Modify/Skip/Abort flow as any other block — no separate escalation path
5. Phase 5 re-runs **all** gate Commands after the simplify pass — a simplify regression is fixed before reporting, never shipped
6. The four canonical field names — **Test**, **Command**, **Fail-first**, **Pass condition** — and the `## TDD Gate Summary` table are the parsing contract with `/tdd-plan`; a plan missing them routes through the Phase 1 AskUserQuestion, never a guess

---

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have a `plan.md` containing a `## TDD Gate Summary` but no `review.md` — suggest building those
2. Check `.dev/` for work items with a `plan.md` lacking TDD Gates — suggest `/tdd-plan` to augment them (or plain `/build`)
3. If none found, ask the user what they'd like to build via `AskUserQuestion`

---

## Examples

### Example 1 — Clean TDD run, fail-first → pass per step

**Invocation**: `/tdd-build .dev/feat-api-rate-limiting`

**Phase 1 — Validation & Context Loading**:
- Directory parsed: `.dev/feat-api-rate-limiting`
- No step range specified — full plan
- `.dev/feat-api-rate-limiting/plan.md` found
- TDD verification: all 6 steps carry a `**TDD Gate**:` block and `## TDD Gate Summary` exists — plan is TDD-ready
- Read `plan.md`: 6 steps, 6 acceptance criteria, gate summary table loaded
- Read `scratch.md`: prior decision to use `rate-limiter-flexible` recorded
- `tasks.md` not found — generated from the plan's 6 steps per `templates/tasks.md` (no checked items — fresh build)
- Testing rules: `.claude/rules/common/testing.md` and `.claude/rules/typescript/testing.md` found — contents held for the executor prompt
- `TodoWrite` created with all 6 steps

**Phase 2 — Gap Analysis**:
Plan is specific: file paths, gate commands, and pass conditions are all defined. **Skip — no questions needed.**

**Phase 3 — Confirm & Execute**:

Confirmation prompt fires:
```
## TDD Build: .dev/feat-api-rate-limiting

Plan has 6 steps, all TDD-gated.

Acceptance criteria: 6

Proceed? (yes / review plan first / cancel)
```

User replies **yes**. `build-executor` agent spawned with the base build prompt plus the delimited TDD protocol section and testing rules. The executor works gate-by-gate — e.g., Step 2:
1. Runs `npx vitest run src/gateway/middleware/rate-limit.test.ts` before implementing — fails: `Error: Cannot find module './rate-limit'`. Records in `scratch.md`: "Step 2 fail-first: `npx vitest run src/gateway/middleware/rate-limit.test.ts` → Cannot find module './rate-limit'"
2. Implements `src/gateway/middleware/rate-limit.ts`
3. Re-runs the Command — exit 0, test "returns 429 after limit exceeded" passes → checks off Step 2 in `tasks.md`

**Phase 4 — Handle Build Report**:
All 6 steps completed; every gate has fail-first evidence in `scratch.md` and a final pass. Proceed to Phase 5.

**Phase 5 — Simplify, Gate Re-verification & Summary**:

`scratch.md` updated with note: "sliding-window counter reused the Redis client singleton from `src/lib/redis.ts`."

`code-simplifier` spawned on the modified files — 1 refinement applied (extracted duplicated window-key builder in `rate-limit.ts`).

All 6 gate Commands from the `## TDD Gate Summary` re-run: 6/6 still pass — the simplify pass broke nothing.

```
## TDD Build Complete: .dev/feat-api-rate-limiting

**Steps completed**: 6 / 6
**Acceptance criteria met**: 6 / 6
**Simplify pass**: 1 refinement applied
**Gate re-verification**: 6/6 gates passing after simplify

### Gate Results

| Step | Fail-first observed | Final pass |
|------|--------------------|-----------|
| 1 | yes — `npm ls rate-limiter-flexible` → missing dependency | yes |
| 2 | yes — Cannot find module './rate-limit' | yes |
| 3 | yes — middleware chain lacks rate-limit entry | yes |
| 4 | yes — schema rejects `rateLimit` key | yes |
| 5 | yes — redis helper `slidingWindow` undefined | yes |
| 6 | yes — Retry-After header absent from 429 | yes |

Next step: `/review .dev/feat-api-rate-limiting` to run a code review.
```

---

### Example 2 — Gate blocks: pre-implementation pass, user chooses Skip

**Invocation**: `/tdd-build .dev/feat-config-validation`

**Phase 1 — Validation & Context Loading**:
- Directory parsed: `.dev/feat-config-validation`
- `plan.md` found; TDD verification passes: 4 steps, all gated, `## TDD Gate Summary` present
- 4 acceptance criteria; `tasks.md` generated fresh; testing rules found and held; `TodoWrite` created

**Phase 2 — Gap Analysis**: plan is clear. **Skip.**

**Phase 3 — Confirm & Execute**:

User confirms. `build-executor` spawned with the base prompt plus the TDD protocol section.

**Phase 4 — Handle Build Report**:

Executor completes steps 1–2 with fail-first evidence, then stops on step 3:

> **Blocked on step 3**: gate Command `npx vitest run src/config/env.test.ts` **passes before implementation** — the test "rejects empty DATABASE_URL" already succeeds because `src/config/schema.ts` (step 2) added a global non-empty-string refinement covering it. No fail-first reason was pre-recorded in the plan, so per the TDD protocol this is blocking.

The behavior already existing is recorded in `scratch.md`; the block surfaces through the standard flow. `AskUserQuestion` fires:

> **TDD build blocked on step 3 of .dev/feat-config-validation**
>
> Step 3's gate passed before implementation: the empty-`DATABASE_URL` rejection already exists via step 2's schema refinement, so no failing test can be observed for this step.
>
> How would you like to proceed?
> 1. **Modify plan** — rewrite step 3 (and its gate) to target behavior not yet covered, then re-spawn for the remaining steps
> 2. **Skip step 3** — the behavior already exists and its gate passes; continue with step 4
> 3. **Abort** — stop here

User selects **Skip step 3**. Decision recorded in `scratch.md` ("Step 3 skipped: behavior delivered by step 2's refinement; gate green pre-implementation"). Executor re-spawned for step 4, which fails first, then passes, normally.

**Phase 5 — Simplify, Gate Re-verification & Summary**:

`code-simplifier` runs — clean, no changes. All gate Commands re-run (step 3's included, since its behavior ships regardless): 4/4 pass.

```
## TDD Build Complete: .dev/feat-config-validation

**Steps completed**: 3 / 4 (step 3 skipped — behavior pre-existing)
**Acceptance criteria met**: 4 / 4
**Simplify pass**: clean — no changes
**Gate re-verification**: 4/4 gates passing after simplify

### Gate Results

| Step | Fail-first observed | Final pass |
|------|--------------------|-----------|
| 1 | yes — zod schema module missing | yes |
| 2 | yes — schema accepts malformed config | yes |
| 3 | no — passed pre-implementation (covered by step 2; skipped by user) | yes |
| 4 | yes — startup does not exit on invalid config | yes |

Next step: `/review .dev/feat-config-validation` to run a code review.
```
