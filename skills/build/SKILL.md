---
name: build
description: Autonomous implementation based on plan.md
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite, AskUserQuestion, Edit, Write
argument-hint: [<dir> [step <N>[-<M>]]]
model: sonnet
---

# Build Skill

Execute the implementation plan for a work item autonomously, working through each step and capturing insights.

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
   > [contents of `.claude/rules/common/testing.md` and each `<language>/testing.md`, labeled with its path]
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

### Phase 5: Simplify & Summary

11. **Update `<dir>/scratch.md`** with any insights, decisions, or surprises that emerged during the build.

12. **Simplify pass**: spawn the `code-simplifier` agent on the files the build modified (listed in the build report). Count the refinements it applied for the final report.

13. **Report**:
```
## Build Complete: [dir]

**Steps completed**: [N] / [total]
**Acceptance criteria met**: [N] / [total]
**Simplify pass**: [N refinements applied | clean — no changes]

[Only if no testing rules were found in Phase 1:] No testing rules found — consider /create-rules.

Next step: `/review <dir>` to run a code review.
```

---

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have a `plan.md` but no `review.md` — suggest building those
2. If none found, ask the user what they'd like to build via `AskUserQuestion`

---

## Examples

### Example 1 — Full build, no step override

**Invocation**: `/build .dev/feat-auth-flow`

**Phase 1 — Validation & Context Loading**:
- Directory parsed: `.dev/feat-auth-flow`
- No step range specified — full plan
- `.dev/feat-auth-flow/plan.md` found
- Read `plan.md`: 6 steps, 5 acceptance criteria
- Read `scratch.md`: prior decision to use JWT with 15-min expiry recorded
- `research.md` found and loaded
- `tasks.md` not found — generated from the plan's 6 steps per `templates/tasks.md`:
  ```
  - [ ] Step 1: Token helpers — CREATE — `src/lib/token.ts`
  - [ ] Step 2: Auth middleware — CREATE — `src/middleware/auth.ts`
  ...
  ```
  (No checked items, so this is a fresh build — a `tasks.md` with checked items would trigger a resume: "2 of 6 steps complete, resuming from Step 3.")
- Testing rules: `.claude/rules/common/testing.md` found; project is TypeScript, so `.claude/rules/typescript/testing.md` also read — contents held for the executor prompt. (If neither existed, the build would proceed anyway and the final report would add: "No testing rules found — consider /create-rules.")
- `TodoWrite` created with all 6 steps

**Phase 2 — Gap Analysis**:
Plan is specific: file paths, API contracts, and token strategy are all defined in `plan.md` and `scratch.md`. **Skip — no questions needed.**

**Phase 3 — Confirm & Execute**:

Confirmation prompt fires:
```
## Build: .dev/feat-auth-flow

Plan has 6 steps.

Acceptance criteria: 5

Proceed? (yes / review plan first / cancel)
```

User replies **yes**. `build-executor` agent spawned:
> Work item: `.dev/feat-auth-flow/`
> Execute the plan in `plan.md`.
> Task list: `tasks.md` — skip steps already checked; after each step's verification passes, check off its line.
> Capture insights in `scratch.md` as you work.
> Stop and report if any step fails or requires plan changes.
> Testing rules (binding):
> --- BEGIN TESTING RULES ---
> [contents of `.claude/rules/common/testing.md`, then `.claude/rules/typescript/testing.md`, each labeled with its path]
> --- END TESTING RULES ---

**Phase 4 — Handle Build Report**:
All 6 steps completed; all 6 lines in `tasks.md` now checked. Proceed to Phase 5.

**Phase 5 — Simplify & Summary**:

`scratch.md` updated with note: "refresh token rotation implemented in step 4 using httpOnly cookie pattern from existing session middleware."

`code-simplifier` spawned on the files the build modified — 2 refinements applied (guard clause flattening in `src/middleware/auth.ts`, redundant import removed in `src/lib/token.ts`).

```
## Build Complete: .dev/feat-auth-flow

**Steps completed**: 6 / 6
**Acceptance criteria met**: 5 / 5
**Simplify pass**: 2 refinements applied

Next step: `/review .dev/feat-auth-flow` to run a code review.
```

---

### Example 2 — Step range override, blocked step with user resolution

**Invocation**: `/build .dev/feat-auth-flow step 3-5`

**Phase 1 — Validation & Context Loading**:
- Directory parsed: `.dev/feat-auth-flow`, step range: 3–5
- `.dev/feat-auth-flow/plan.md` found
- Read `plan.md`: 6 steps total, 5 acceptance criteria
- Read `scratch.md`: prior context loaded
- `TodoWrite` created for steps 3, 4, 5 only

**Phase 2 — Gap Analysis**:
Step 4 references `src/lib/token.ts` which is listed in `plan.md`. All contracts are clear. **Skip — no questions needed.**

**Phase 3 — Confirm & Execute**:

Confirmation prompt fires:
```
## Build: .dev/feat-auth-flow

Plan has 6 steps. Running steps 3–5.

Acceptance criteria: 5

Proceed? (yes / review plan first / cancel)
```

User replies **yes**. `build-executor` agent spawned:
> Work item: `.dev/feat-auth-flow/`
> Execute the plan in `plan.md`. Run only steps 3–5.
> Capture insights in `scratch.md` as you work.
> Stop and report if any step fails or requires plan changes.

**Phase 4 — Handle Build Report**:

Executor completes steps 3 and 4, then stops on step 5:

> **Blocked on step 5**: `src/middleware/auth.ts` imports `verifyToken` from `src/lib/token.ts`, but `token.ts` was not created in steps 3–4. It exists in the plan as step 2 (outside the run range).

`AskUserQuestion` fires:

> **Build blocked on step 5 of .dev/feat-auth-flow**
>
> `src/lib/token.ts` is missing — it was scheduled in step 2, which was outside the step range 3–5.
>
> How would you like to proceed?
> 1. **Modify plan** — I'll update `plan.md` to note the dependency and you can re-run `/build .dev/feat-auth-flow step 2` first
> 2. **Skip step 5** — continue without it (step 5's acceptance criterion will remain unmet)
> 3. **Abort** — stop here

User selects **Modify plan**. `plan.md` updated to add a note under step 5: "Depends on step 2 (`src/lib/token.ts`)." `scratch.md` updated with decision. Build stopped; user advised to run `/build feat-auth-flow step 2` then retry.

**Phase 5 — Summary**:

```
## Build Complete: .dev/feat-auth-flow

**Steps completed**: 2 / 3 (steps 3–5)
**Acceptance criteria met**: 3 / 5

Next step: `/build .dev/feat-auth-flow step 2` to resolve the dependency, then retry step 5.
```
