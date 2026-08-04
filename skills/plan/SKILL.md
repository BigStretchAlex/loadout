---
name: plan
description: Create a structured implementation plan with acceptance criteria, risks, and test strategy
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Task, Skill, TodoWrite, WebFetch, AskUserQuestion, Write, Bash
argument-hint: "[feature-description | slug | .dev/<slug>/] [@context-files...]"
model: sonnet
---

# Plan Skill

Produce a detailed implementation plan for a work item, grounded in codebase discovery, resolved ambiguities, and documented patterns.

**Dependency**: this skill depends on `loadout:discover` — step 4 invokes it rather than reimplementing discovery. Any change to discover's schema (`templates/research.md`) or its agent spawns is inherited automatically here.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain one of:
   - A `.dev/<slug>/` directory path or a bare work item slug (e.g., `.dev/feat-auth-flow/` or
     `feat-auth-flow`) — plan within that existing context. Strip any leading `.dev/` and any
     trailing `/` to recover the slug.
   - A free-form description — create a new work item for it
   - If empty, jump to the **Fallback** section at the bottom

2. **Set up the work item directory** — follow `templates/work-item.md` (slug parsing/derivation, `.dev/<slug>/` creation, `scratch.md` init).
   - Note the **type prefix** extracted from the slug (`feat`, `bug`, `refactor`, or `spike`) — this determines the type constraint injected in step 6.

3. **Check for existing plan** — if `.dev/<slug>/plan.md` already exists, ask the user via `AskUserQuestion`:
   - **Revise**: update the existing plan based on new information
   - **Replace**: start fresh
   - **Cancel**: abort

4. **Discovery** — ensure `research.md` exists:

   - **If `.dev/<slug>/research.md` already exists** (user ran `/discover` first):
     Use it directly. Write a summary to `scratch.md` and proceed to step 4b.

   - **If `research.md` does not exist**: invoke the `loadout:discover` skill via the **Skill tool**, passing the goal and work item slug through. `discover` owns the six-section schema (`templates/research.md`) and the arbiter/code-explorer spawns that produce it — do not reimplement that flow here. When it completes, `.dev/<slug>/research.md` exists.

     **Fallback**: if Skill invocation is unavailable in the current context, follow the steps in `skills/discover/SKILL.md` manually to the same result (same work-item directory, same `research.md` schema), then continue.

     Proceed to step 4b.

4b. **Architecture consult (conditional)** — applies only to `feat` and `refactor` slugs:

   - Review `research.md`: did discovery surface **multiple viable architectural approaches** to the goal (structurally different designs, each defensible given the constraints)?
   - **If yes**: spawn the `architect` agent:
     > **Design question**: [goal]
     > **Research context**: `.dev/<slug>/research.md`

     Record its **Recommendation** and paste its **Decision Record** block into `scratch.md` under **Decisions**. Carry the recommendation forward to step 6 as the `**Architecture guidance**` prompt field.
   - **If one approach is obviously right** (or the slug is `bug`/`spike`): skip this step silently — do not spawn the agent, do not mention the skip. This consult is the exception, not the default.

5. **Clarifying questions** — resolve genuine ambiguity before handing off to the plan-writer:
   - Review discoveries from step 4 and identify: ambiguities, unstated assumptions, design choices with multiple valid options, scope boundaries that aren't clear
   - **If ambiguities exist**: batch ALL questions into a single `AskUserQuestion` call. Format as a numbered list. Ask once, not one at a time.
   - **If requirements are clear**: skip this step entirely — do not ask questions for the sake of asking
   - Record answers in `scratch.md` under **Decisions** and **Assumptions**

   When to ask:
   - The goal mentions "auth" but doesn't specify the auth provider
   - Multiple valid architectural approaches exist, the choice has significant downstream impact, and step 4b did not already resolve it via the architect consult
   - Scope boundaries are ambiguous (e.g., "improve performance" — which endpoints? what target?)

   When to skip:
   - `research.md` and `brainstorm.md` already resolve the key decisions
   - The goal is specific and the codebase makes the approach obvious
   - The only "questions" would be implementation details the plan-writer can decide

6. **Spawn the `plan-writer` agent** with an enriched prompt constructed from all gathered context:
   > **Goal**: [goal from arguments or research.md]
   > **Work item**: `.dev/<slug>/`
   > **Discovery findings**: [full contents of `.dev/<slug>/research.md`]
   > **Clarification answers**: [numbered Q&A from step 5, or "N/A — requirements were clear"]
   > **Architecture guidance**: [recommendation summary from the architect consult in step 4b — omit this field entirely if step 4b was skipped]
   > **Constraints**: [any constraints from arguments or user answers]
   > **Type constraint**: [constraint text from `references/type-constraints.md` matching the slug type prefix — one of `feat`, `bug`, `refactor`, `spike`]
   >
   > Write the plan to `.dev/<slug>/plan.md` using the plan template structure.

7. **Write the plan** — the plan-writer agent writes to `.dev/<slug>/plan.md`. After it completes, read the plan to extract summary counts.

8. **Adversarial review** — determine the output filename, then spawn the `plan-reviewer` agent:

   - Count existing `plan-review*.md` files in `.dev/<slug>/` to determine the review round N (first review = round 1, second = round 2, etc.)
   - Construct the output filename: round 1 → `plan-review.md`, round N → `plan-review-N.md` (e.g., `plan-review-2.md`)

   Spawn the `plan-reviewer` agent:
   > **Goal**: [goal]
   > **Work item**: `.dev/<slug>/`
   > **Plan to review**: [full contents of `.dev/<slug>/plan.md`]
   > **Research context**: [full contents of `.dev/<slug>/research.md` if it exists]
   > **Output file**: `plan-review.md` (or `plan-review-N.md` for round N)
   >
   > Produce numbered findings with severity. Write output to `.dev/<slug>/[output file]`.

   After the agent completes, read `.dev/<slug>/[output file]` and partition the **blocking** findings per the **Confidence Policy** (see section below): objective vs. subjective.

   **a. Objective blocking findings — auto-Revise (maximum 2 auto-rounds):**
   - If any blocking findings are objective AND fewer than 2 auto-rounds have already run during this planning session: re-spawn the `plan-writer` agent with the original enriched prompt PLUS the reviewer findings, instructing it to fix **exactly those objective findings and nothing else**. Do not ask the user first.
   - Then re-run step 8 (adversarial review) on the updated plan. Each auto-Revise consumes a normal review round — the `plan-review-*` counting and filename increment above apply unchanged.
   - After 2 auto-rounds, stop auto-revising: everything still open goes to the user in b, even if objective.

   **b. Subjective and any remaining findings — ask the user** via `AskUserQuestion`:

   > ## Plan Review: \<slug\>
   > [full findings from the latest review round]
   >
   > [If any auto-rounds ran: "Already auto-applied and re-reviewed (objective fixes): <finding numbers + one-line summaries>."]
   >
   > How would you like to proceed with the remaining findings?
   > 1. **Accept** — proceed to build as-is
   > 2. **Revise** — re-run plan-writer targeting specific findings (specify which numbers)
   > 3. **Skip** — ignore review and proceed

   If user selects **Revise**: re-spawn the `plan-writer` agent with the original enriched prompt PLUS the reviewer findings and the user's selected finding numbers. Then re-run step 8 (adversarial review) on the updated plan — the filename will automatically increment to the next round.

   If user selects **Accept** or **Skip**: proceed to step 9.

9. **Update scratch.md** — append any new insights, decisions, or open questions that emerged during planning.

### Step 10 — Verification (self-check before reporting)

Before printing `## Plan Ready`, re-read `.dev/<slug>/plan.md` and run every check below. This is the **only** verification phase in this skill — it carries both the per-step validation condition and the schema/artifact condition in one pass; do not add a second phase. Plan **must not report** `## Plan Ready` while any check fails.

**a. Per-step validation loop (every `### Step N` block):**
- A `**Validation**:` block is present under the step — not missing, not omitted.
- All four fields are present: **Type** (`deterministic` or `agent-evaluable`), **Check**, **Expect**, **On fail**.
- None of the four fields are a template placeholder (`<...>`, `TBD`, `...`) or unfalsifiable prose ("works correctly", "behaves as expected", "verify it's fine").
- If **Type: deterministic**, the **Check** names an actual runnable command (a real script/binary/test target), not a placeholder.
- If **Type: agent-evaluable**, the **Check** is phrased as a yes/no question an agent can judge unambiguously.

**b. Plan schema completeness (`templates/plan.md`):** the plan contains every required section — `## Goal`, `## Acceptance Criteria`, `## Approach`, `## File-Action Index`, at least one `### Step N` block, `## Risks & Mitigations`, `## Test Strategy`, `## Out of Scope`.

**c. File-path integrity:** for every step, the **File**: path either exists on disk (verify with a read or `test -f`), or the step's **Action** is `CREATE` (a non-existent path is then expected, not a failure).

**d. Index/step parity:** the number of rows in **File-Action Index** equals the number of `### Step N` blocks in the plan.

**e. Handoff footer** (`templates/handoff-footer.md`): the file ends with a fenced ` ```loadout-handoff ` block as the last content in the file; every key (`schema`, `artifact`, `produced_by`, `work_item`, `lane`, `verification`, `next_command`, `next_arguments`) is present, non-blank, and not a template placeholder; `next_command` is either the literal `none` or names a real skill under `skills/`; when `next_command` is not `none`, `next_arguments` is present and parses under that skill's `argument-hint`.

**On any failure**: do not report success. Re-spawn the `plan-writer` agent with the original enriched prompt plus the specific list of failed checks, instructing it to fix exactly those and nothing else, then re-run this Step 10 check on the result. This is capped at 2 retries (shares the auto-Revise budget with step 8a — do not exceed 2 combined auto-rounds across review and verification). If checks still fail after the retry budget, stop: set the footer's `verification` field to `fail`, then surface the surviving failures to the user via `AskUserQuestion` instead of printing `## Plan Ready`.

**Once checks a–e all pass**, set the footer's `verification` field from `none` (as `plan-writer` wrote it) to `pass` — this is the only footer field this step edits, and only after every other check in this pass has genuinely passed; never set it to `pass` speculatively.

Report explicitly, and carry the result into step 11's report: `Verification: PASS` or `Verification: FAIL — <check> — <reason>` (one line per failure).

11. **Report** — only after Step 10 reports PASS:
```
## Plan Ready: [slug]

**Steps**: [N] | **Acceptance criteria**: [N] | **Risks identified**: [N]
**Review**: [N blocking, N advisory findings] / accepted / skipped
**Verification**: PASS (per-step validation + schema checks)

### File-Action Index
1. [Step 1 title] — ACTION — `path/to/file`
2. [Step 2 title] — ACTION — `path/to/file`
...

Next step: `/build .dev/<slug>` to start implementation.
```

---

## Confidence Policy

See `templates/confidence-policy.md`. Applied in step 8 to partition adversarial-review findings into auto-Revise (objective) vs. ask-the-user (subjective).

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have `research.md` or `brainstorm.md` but no `plan.md` — suggest planning those
2. If none found, ask the user what they'd like to plan via `AskUserQuestion`
