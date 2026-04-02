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
   - Create the `.dev/<slug>/` directory if it doesn't exist
   - Initialize `scratch.md` from `templates/scratch.md` if it doesn't exist

3. **Check for existing plan** — if `.dev/<slug>/plan.md` already exists, ask the user via `AskUserQuestion`:
   - **Revise**: update the existing plan based on new information
   - **Replace**: start fresh
   - **Cancel**: abort

4. **Discovery** — ensure `research.md` exists:

   - **If `.dev/<slug>/research.md` already exists** (user ran `/discover` first):
     Use it directly. Write a summary to `scratch.md` and proceed to step 5.

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

     Proceed to step 5.

5. **Clarifying questions** — resolve genuine ambiguity before handing off to the plan-writer:
   - Review discoveries from step 4 and identify: ambiguities, unstated assumptions, design choices with multiple valid options, scope boundaries that aren't clear
   - **If ambiguities exist**: batch ALL questions into a single `AskUserQuestion` call. Format as a numbered list. Ask once, not one at a time.
   - **If requirements are clear**: skip this step entirely — do not ask questions for the sake of asking
   - Record answers in `scratch.md` under **Decisions** and **Assumptions**

   When to ask:
   - The goal mentions "auth" but doesn't specify the auth provider
   - Multiple valid architectural approaches exist and the choice has significant downstream impact
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
   > **Constraints**: [any constraints from arguments or user answers]
   >
   > Write the plan to `.dev/<slug>/plan.md` using the plan template structure.

7. **Write the plan** — the plan-writer agent writes to `.dev/<slug>/plan.md`. After it completes, read the plan to extract summary counts.

8. **Adversarial review** — spawn the `plan-reviewer` agent:
   > **Goal**: [goal]
   > **Work item**: `.dev/<slug>/`
   > **Plan to review**: [full contents of `.dev/<slug>/plan.md`]
   > **Research context**: [full contents of `.dev/<slug>/research.md` if it exists]
   >
   > Produce numbered findings with severity. Write output to `.dev/<slug>/review.md`.

   After the agent completes, read `.dev/<slug>/plan-review.md` and present findings to the user via `AskUserQuestion`:

   > ## Plan Review: \<slug\>
   > [full review findings]
   >
   > How would you like to proceed?
   > 1. **Accept** — proceed to build as-is
   > 2. **Revise** — re-run plan-writer targeting specific findings (specify which numbers)
   > 3. **Skip** — ignore review and proceed

   If user selects **Revise**: re-spawn the `plan-writer` agent with the original enriched prompt PLUS the reviewer findings and the user's selected finding numbers. Then re-run step 8 (adversarial review) on the updated plan.

   If user selects **Accept** or **Skip**: proceed to step 9.

9. **Update scratch.md** — append any new insights, decisions, or open questions that emerged during planning.

10. **Report**:
```
## Plan Ready: [slug]

**Steps**: [N]
**Acceptance criteria**: [N]
**Risks identified**: [N]
**Review**: [N blocking, N advisory findings] / accepted / skipped

Next step: `/build <slug>` to start implementation.
```

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

`plan-reviewer` spawned. Finds 3 issues, writes `.dev/feat-api-rate-limiting/review.md`. `AskUserQuestion` fires:

> ## Plan Review: feat-api-rate-limiting
>
> ### Findings
>
> 1. **blocking** Step 4 / Acceptance Criteria — No test covers Redis unavailability path
>    - **Issue**: The plan states "Redis required; no fallback needed for v1" but no acceptance criterion verifies graceful error handling when Redis is down.
>    - **Suggestion**: Add AC: "When Redis is unreachable, requests pass through and an error is logged — rate limiting silently degrades."
>
> 2. **advisory** Risk Table — Sliding window memory growth not mentioned
>    - **Issue**: Redis sorted-set sliding window accumulates keys; high-traffic IPs could grow the key set significantly.
>    - **Suggestion**: Add risk: "High-cardinality IP set growth" with mitigation: TTL already set by rate-limiter-flexible — confirm it's configured.
>
> 3. **advisory** Step 2 — Config schema change not listed as a step dependency
>    - **Issue**: Step 2 adds an env var but Step 1 (middleware skeleton) references it before the schema update is done.
>    - **Suggestion**: Reorder: config schema update → middleware skeleton.
>
> ### Verdict
> Needs minor revision. One blocking finding around error-path acceptance criteria; two advisory items that are low effort to address.
>
> How would you like to proceed?
> 1. **Accept** — proceed to build as-is
> 2. **Revise** — re-run plan-writer targeting specific findings (specify which numbers)
> 3. **Skip** — ignore review and proceed

User selects **Revise**, targeting findings 1 and 3. `plan-writer` re-spawned with original context plus findings 1 and 3. Updated plan adds the missing AC and reorders steps. `plan-reviewer` re-spawned — new review has 0 blocking findings. User selects **Accept**.

**Step 9 — scratch.md updated** with decision to use `rate-limiter-flexible` library (noted by plan-writer as idiomatic match for Redis sliding window).

**Step 10 — Report**:
```
## Plan Ready: feat-api-rate-limiting

**Steps**: 6
**Acceptance criteria**: 6
**Risks identified**: 3
**Review**: 0 blocking, 2 advisory findings / accepted

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

**Step 5 — Clarifying questions**: Requirements are specific and the codebase makes the approach obvious. **Skip.**

**Step 6 — Spawn plan-writer** with full context including the existing `plan.md` content, new discovery findings, and the revision instruction.

**Step 7 — Plan updated** — plan-writer adds one new step to the existing plan: "7. Attach X-RateLimit-Remaining and X-RateLimit-Limit headers to all passing responses using the limiter result object."

**Step 8 — Adversarial review**: `plan-reviewer` spawned. Produces 3 advisory findings (no blocking). User selects **Accept**.

**Step 9 — scratch.md updated** with note: "headers middleware pattern reused from headers.ts".

**Step 10 — Report**:
```
## Plan Ready: feat-api-rate-limiting

**Steps**: 7
**Acceptance criteria**: 7
**Risks identified**: 2
**Review**: 0 blocking, 3 advisory findings / accepted

Next step: `/build feat-api-rate-limiting` to start implementation.
```

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have `research.md` or `brainstorm.md` but no `plan.md` — suggest planning those
2. If none found, ask the user what they'd like to plan via `AskUserQuestion`
