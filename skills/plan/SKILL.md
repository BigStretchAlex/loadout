---
name: plan
description: Create a structured implementation plan with acceptance criteria, risks, and test strategy
allowed-tools: Read, Grep, Glob, Task, TodoWrite, WebFetch, AskUserQuestion, Write, Bash
argument-hint: [feature-description] [@context-files...]
model: sonnet
---

# Plan Skill

Produce a detailed implementation plan for a work item, grounded in codebase discovery, resolved ambiguities, and documented patterns.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain either:
   - A work item slug (e.g., `feat-auth-flow`) — plan within that context
   - A free-form description — create a new work item for it
   - If empty, jump to the **Fallback** section at the bottom

2. **Set up the work item directory**:
   - If a slug is provided, use `.dev/<slug>/`
   - If new, derive a slug: `<type>-<descriptive-slug>` where type is one of: `feat`, `bug`, `refactor`, `spike`
   - Note the **type prefix** extracted from the slug (`feat`, `bug`, `refactor`, or `spike`) — this determines the type constraint injected in step 6
   - Create the `.dev/<slug>/` directory if it doesn't exist
   - Initialize `scratch.md` from `templates/scratch.md` if it doesn't exist

3. **Check for existing plan** — if `.dev/<slug>/plan.md` already exists, ask the user via `AskUserQuestion`:
   - **Revise**: update the existing plan based on new information
   - **Replace**: start fresh
   - **Cancel**: abort

4. **Discovery** — ensure `research.md` exists:

   - **If `.dev/<slug>/research.md` already exists** (user ran `/discover` first):
     Use it directly. Write a summary to `scratch.md` and proceed to step 4b.

   - **If `research.md` does not exist**: run the discover workflow inline —

     a. Spawn the **arbiter** agent:
        > Find patterns, conventions, and anti-patterns in `.ai-docs/` relevant to: [goal]

        Capture: Domain Concepts (from arbiter summary) + Technical Patterns (from arbiter recommendations/anti-patterns)

     b. Spawn the **code-explorer** agent:
        > **Goal**: [goal]
        > **Technical Patterns from .ai-docs/**: [Technical Patterns from step a — navigation hints only]
        > **Work item path**: `.dev/<slug>/`

        Capture verbatim: Relevant Code + Dependencies + Integration Points sections

     c. Synthesize both outputs into the six-section schema and write to `.dev/<slug>/research.md`:
        ```markdown
        ## Discovery: [goal summary]

        ### Domain Concepts
        ### Technical Patterns
        ### Relevant Code
        ### Dependencies
        ### Integration Points
        ### Constraints & Risks
        ```

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
   > **Type constraint**: [constraint text from the Type Constraints section below matching the slug type prefix]
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

10. **Report**:
```
## Plan Ready: [slug]

**Steps**: [N] | **Acceptance criteria**: [N] | **Risks identified**: [N]
**Review**: [N blocking, N advisory findings] / accepted / skipped

### File-Action Index
1. [Step 1 title] — ACTION — `path/to/file`
2. [Step 2 title] — ACTION — `path/to/file`
...

Next step: `/build <slug>` to start implementation.
```

---

## Type Constraints

Injected into the `plan-writer` prompt based on the slug type prefix. Apply only the entry matching the work item type.

| Type | Constraint |
|------|------------|
| `feat` | **Simplicity discipline** — Solve the stated requirement only. Prefer the simplest design that satisfies the acceptance criteria. Use clear, intention-revealing names. Define explicit boundaries — what this feature does and does not own. Do not add extensibility hooks, abstraction layers, or optional configurability unless the goal explicitly calls for them. |
| `bug` | **Minimal footprint** — Change only what is necessary to fix the defect. Do not refactor surrounding code, rename symbols, or improve unrelated logic. Every step should trace directly to reproducing or preventing the bug. |
| `refactor` | **Scope discipline** — Restructure only what the goal names. Do not introduce new behaviour, fix unrelated bugs, rename symbols outside the stated scope, or add new capabilities. If you notice something worth improving, record it in Risks/Notes as a follow-on item — do not fold it into this plan. |
| `spike` | **Timebox and question focus** — The output is findings, not production code. Structure steps around answering the spike's stated questions. Include an explicit step to document conclusions and a recommended next action. Do not plan implementation work. |

## Confidence Policy

Classify every finding or proposed fix before acting on it:

- **Objective (auto-apply)**: the fix is mechanically verifiable — a factual error, broken path, missing required field, failing command, or a direct contradiction of a rule, plan, or template. Apply it without asking, then re-run the relevant check once to confirm.
- **Subjective (ask)**: the fix is a judgment call — scope, naming, architecture, trade-offs. Surface it via AskUserQuestion; never apply it unprompted.

Never auto-apply a fix that deletes user-authored content, changes scope, or contradicts a decision recorded in `scratch.md`. When in doubt, treat the finding as subjective.

## Examples

### Example 1 — Free-form description, clarifications needed

**Invocation**: `/plan add rate limiting to the API gateway`

**Step 1 — Parse arguments**: Free-form description. No slug provided.

**Step 2 — Set up work item**:
- Derived slug: `feat-api-rate-limiting`
- Created `.dev/feat-api-rate-limiting/`
- Initialized `scratch.md` from template

**Step 3 — Check for existing plan**: No `plan.md` found. Proceed.

**Step 4 — Discovery** (no `research.md` exists, run inline):

Arbiter finds: middleware registration pattern in `.ai-docs/middleware.md`, Redis client convention.

Code-explorer returns:
- **Relevant Code**: `src/gateway/middleware/auth.ts` (reference), `src/gateway/middleware/index.ts` (registration), `src/config/gateway.ts`
- **Dependencies**: middleware depends on `src/lib/redis.ts`; `index.ts` imports all middleware
- **Integration Points**: Redis client at `src/lib/redis.ts`, config schema at `src/config/schema.ts`

Synthesized `research.md` written to `.dev/feat-api-rate-limiting/research.md` with all six sections including **Constraints & Risks**: no rate-limiting library installed; Redis may not be available in all environments.

**Step 4b — Architecture consult**: `feat` slug, but discovery surfaced one obvious approach (Redis-backed middleware following the existing middleware registration pattern) — no competing architectures. Skipped silently; no agent spawned.

**Step 5 — Clarifying questions**:
Ambiguities found → batch into single `AskUserQuestion`:

> 1. Should rate limits be per-IP, per-API-key, or both?
> 2. What are the target limits (e.g., 100 req/min per IP)?
> 3. Should blocked requests return 429 with a Retry-After header, or a custom error format?
> 4. Is Redis guaranteed to be available, or does the implementation need a fallback (e.g., in-memory)?

User answers recorded in `scratch.md` under **Decisions**:
> 1. Per-IP only for now
> 2. 100 req/min, configurable via env var
> 3. 429 with Retry-After header, standard format
> 4. Redis required; no fallback needed for v1

**Step 6 — Spawn plan-writer** with enriched prompt including discovery findings and Q&A.

**Step 7 — Plan written** to `.dev/feat-api-rate-limiting/plan.md`.

**Step 8 — Adversarial review**:

`plan-reviewer` spawned (round 1 → output file `plan-review.md`). Finds 3 issues, writes `.dev/feat-api-rate-limiting/plan-review.md`:

> 1. **blocking** Step 2 / Validation — Validation command references a file the plan never creates
>    - **Issue**: Step 2 creates `src/gateway/middleware/rate-limit.ts` but its validation command tests `src/gateway/middleware/ratelimit.ts` — the command can never pass.
>    - **Suggestion**: Correct the path in Step 2's validation command.
>
> 2. **blocking** Acceptance Criteria — No criterion covers Redis unavailability
>    - **Issue**: The plan states "Redis required; no fallback needed for v1" but is silent on behavior when Redis is down. Deciding whether to add degradation behavior is a scope call.
>    - **Suggestion**: Either add an AC for graceful degradation or explicitly record Redis-down behavior as out of scope.
>
> 3. **advisory** Risk Table — Sliding window memory growth not mentioned
>    - **Issue**: Redis sorted-set sliding window accumulates keys; high-traffic IPs could grow the key set significantly.
>    - **Suggestion**: Add risk: "High-cardinality IP set growth" with mitigation: TTL already set by rate-limiter-flexible — confirm it's configured.

**Confidence Policy partition**: Finding 1 is **objective** — a broken path, mechanically verifiable. Finding 2 is **subjective** — a scope call that touches a decision recorded in `scratch.md` ("Redis required; no fallback needed for v1"), so it must never be auto-applied.

**Auto-Revise (auto-round 1 of 2)**: `plan-writer` re-spawned with the original enriched prompt plus finding 1, instructed to fix exactly finding 1 and nothing else. `plan-reviewer` re-run (round 2 → output file `plan-review-2.md`) — finding 1 confirmed resolved; findings 2 and 3 remain.

`AskUserQuestion` fires with the round-2 findings:

> ## Plan Review: feat-api-rate-limiting
> [round-2 findings: finding 2 (blocking, subjective) and finding 3 (advisory)]
>
> Already auto-applied and re-reviewed (objective fixes): finding 1 — corrected the validation command path in Step 2.
>
> How would you like to proceed with the remaining findings?
> 1. **Accept** — proceed to build as-is
> 2. **Revise** — re-run plan-writer targeting specific findings (specify which numbers)
> 3. **Skip** — ignore review and proceed

User selects **Revise**, targeting finding 2 with the direction "add the graceful-degradation AC". `plan-writer` re-spawned with original context plus finding 2 and the user's direction; the decision update is recorded in `scratch.md`. `plan-reviewer` re-spawned (round 3 → output file `plan-review-3.md`) — 0 blocking findings. User selects **Accept**.

**Step 9 — scratch.md updated** with decision to use `rate-limiter-flexible` library (noted by plan-writer as idiomatic match for Redis sliding window).

**Step 10 — Report**:
```
## Plan Ready: feat-api-rate-limiting

**Steps**: 6 | **Acceptance criteria**: 7 | **Risks identified**: 3
**Review**: 0 blocking, 1 advisory findings / accepted (1 objective fix auto-applied)

### File-Action Index
1. Install rate-limiter-flexible — ADD — `package.json`
2. Create rate limiter middleware — CREATE — `src/gateway/middleware/rate-limit.ts`
3. Register middleware — MODIFY — `src/gateway/middleware/index.ts`
4. Add config env vars — MODIFY — `src/config/schema.ts`
5. Wire Redis client — MODIFY — `src/lib/redis.ts`
6. Add 429 + Retry-After response — MODIFY — `src/gateway/middleware/rate-limit.ts`

Next step: `/build feat-api-rate-limiting` to start implementation.
```

---

### Example 2 — Slug provided, plan exists, revise flow, no clarifications

**Invocation**: `/plan feat-api-rate-limiting`

**Step 1 — Parse arguments**: Slug `feat-api-rate-limiting` provided.

**Step 2 — Set up work item**: `.dev/feat-api-rate-limiting/` already exists with `scratch.md` and `plan.md`.

**Step 3 — Check for existing plan**: `plan.md` found → `AskUserQuestion`:
> A plan already exists for `feat-api-rate-limiting`. What would you like to do?
> 1. Revise — update based on new information
> 2. Replace — start fresh
> 3. Cancel

User selects **Revise**. New context: "also need to add rate-limit headers (X-RateLimit-Remaining) to every response, not just blocked ones."

**Step 4 — Discovery** (`research.md` already exists from prior `/discover` run — use it directly):

Read `.dev/feat-api-rate-limiting/research.md`. Write summary to `scratch.md`. Proceed.

**Step 4b — Architecture consult**: One obvious approach — extend the existing rate-limit middleware. Skipped silently.

**Step 5 — Clarifying questions**: Requirements are specific and the codebase makes the approach obvious. **Skip.**

**Step 6 — Spawn plan-writer** with full context including the existing `plan.md` content, new discovery findings, and the revision instruction.

**Step 7 — Plan updated** — plan-writer adds one new step to the existing plan: "7. Attach X-RateLimit-Remaining and X-RateLimit-Limit headers to all passing responses using the limiter result object."

**Step 8 — Adversarial review**: `plan-reviewer` spawned (round 1 → `plan-review.md`). Produces 3 advisory findings (no blocking, so nothing qualifies for auto-Revise). All three go to the `AskUserQuestion`; user selects **Accept**.

**Step 9 — scratch.md updated** with note: "headers middleware pattern reused from headers.ts".

**Step 10 — Report**:
```
## Plan Ready: feat-api-rate-limiting

**Steps**: 7 | **Acceptance criteria**: 7 | **Risks identified**: 2
**Review**: 0 blocking, 3 advisory findings / accepted

### File-Action Index
1. Install rate-limiter-flexible — ADD — `package.json`
2. Create rate limiter middleware — CREATE — `src/gateway/middleware/rate-limit.ts`
3. Register middleware — MODIFY — `src/gateway/middleware/index.ts`
4. Add config env vars — MODIFY — `src/config/schema.ts`
5. Wire Redis client — MODIFY — `src/lib/redis.ts`
6. Add 429 + Retry-After response — MODIFY — `src/gateway/middleware/rate-limit.ts`
7. Attach X-RateLimit headers to passing responses — MODIFY — `src/gateway/middleware/rate-limit.ts`

Next step: `/build feat-api-rate-limiting` to start implementation.
```

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have `research.md` or `brainstorm.md` but no `plan.md` — suggest planning those
2. If none found, ask the user what they'd like to plan via `AskUserQuestion`
