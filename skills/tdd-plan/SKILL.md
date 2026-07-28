---
name: tdd-plan
description: TDD-augmented planning — create a structured implementation plan, then attach a test-first TDD Gate to every step. Use when the user says "tdd plan", "plan with test gates", "test-first plan", or wants every plan step backed by a failing-then-passing test.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Task, Skill, AskUserQuestion
argument-hint: [feature-description | slug] [@context-files...]
model: sonnet
---

# TDD Plan Skill

Produce a standard implementation plan via the existing `loadout:plan` flow, then augment it so every step carries a verifiable, test-first **TDD Gate**. The result is a plan that `/tdd-build` can execute gate-by-gate: write the test, watch it fail, implement, watch it pass.

## Canonical TDD Gate Format

Every gate — in the plan, in reviews, and in `/tdd-build` — uses these exact four field names:

```markdown
**TDD Gate**:
- **Test**: `<path>` — <behavior verified, tied to acceptance criterion N>
- **Command**: `<exact runnable command>`
- **Fail-first**: <what must fail before implementation, and why>
- **Pass condition**: <deterministic, quantifiable outcome>
```

And the plan-level summary section:

```markdown
## TDD Gate Summary

| Step | Command | ACs covered |
|------|---------|-------------|
```

## Instructions

### Phase 1 — Base plan

Invoke the `loadout:plan` skill via the **Skill tool**, passing "$ARGUMENTS" through unchanged. This reuses the entire existing planning flow — work-item setup, discovery, clarifying questions, plan-writer, and adversarial plan review — with zero duplication.

**Fallback**: if Skill invocation is unavailable in the current context, follow the steps in `skills/plan/SKILL.md` manually to the same result (same work-item directory, same `plan.md`, same review flow), then continue with Phase 2.

When the base plan flow completes, note the work item slug — everything below operates on `.dev/<slug>/plan.md`.

### Phase 2 — Gate augmentation

1. Read `.dev/<slug>/plan.md` in full — steps, acceptance criteria, validation commands, test strategy.
2. Read the consuming project's testing rules if present:
   - `.claude/rules/common/testing.md` — especially the **What Constitutes a Valuable Test** section
   - Any `.claude/rules/<language>/testing.md` matching languages in play
   Gates must comply with these rules (behavior over implementation, deterministic, one reason to fail, no tautologies).
3. Append a **TDD Gate** block (canonical format above) to **every** step in the plan. For each gate:
   - **Test**: real path following the project's test location/naming conventions; state the behavior verified and which acceptance criterion it ties to
   - **Command**: exact and runnable in this project (correct test binary, real paths, no placeholders) — verify the binary exists (e.g., check `package.json` scripts, `pyproject.toml`, `Makefile`) before writing it
   - **Fail-first**: the test must fail because the behavior does not exist yet — not because of an import error or typo
   - **Pass condition**: deterministic and evaluable by an autonomous agent (exit code, specific assertion, exact output) — never "works correctly"
4. Append the `## TDD Gate Summary` table (canonical format above) to the end of `plan.md`, one row per step.
5. Cross-check coverage: **every acceptance criterion must be covered by at least one gate.** If an AC has no gate, add one (extend an existing step's gate or flag the uncovered AC to the user if no step plausibly covers it).

### Phase 3 — Gate review

Determine the review round N by counting existing `tdd-gate-review-*.md` files in `.dev/<slug>/` (first review → `tdd-gate-review-1.md`).

Spawn the `code-quality` agent:
> **Plan to review**: `.dev/<slug>/plan.md` (TDD-augmented)
> **Testing rules**: `.claude/rules/common/testing.md` [plus language testing rules if present, or "none found"]
> **Output file**: `.dev/<slug>/tdd-gate-review-N.md`
>
> Verify every step's TDD Gate and acceptance-criterion coverage. Produce numbered findings with blocking/advisory severity and a per-step gate verdict table.

**NEVER name review artifacts `plan-review-*`** — the `plan` skill counts its review rounds by globbing `plan-review*.md` in `.dev/<slug>/`, and a matching filename would corrupt that count. Gate reviews are always `tdd-gate-review-N.md`.

### Phase 4 — Confidence Policy loop

## Confidence Policy

Classify every finding or proposed fix before acting on it:

- **Objective (auto-apply)**: the fix is mechanically verifiable — a factual error, broken path, missing required field, failing command, or a direct contradiction of a rule, plan, or template. Apply it without asking, then re-run the relevant check once to confirm.
- **Subjective (ask)**: the fix is a judgment call — scope, naming, architecture, trade-offs. Surface it via AskUserQuestion; never apply it unprompted.

Never auto-apply a fix that deletes user-authored content, changes scope, or contradicts a decision recorded in `scratch.md`. When in doubt, treat the finding as subjective.

Apply the policy to the gate review findings:

- **Objective gate defects** — a step missing its TDD Gate or one of the four fields, a non-runnable command (wrong binary, fake path, placeholder), an acceptance criterion covered by no gate: fix them directly in `plan.md`, then re-spawn `code-quality` **once** (writing `tdd-gate-review-N+1.md`) to confirm. One re-spawn maximum — if blocking findings remain after the re-check, surface them to the user instead of looping.
- **Subjective findings** — gate design choices, test granularity, unit-vs-integration trade-offs: batch into a single AskUserQuestion (apply / skip per finding); apply only what the user selects.

### Phase 5 — Report

```
## TDD Plan Ready: [slug]

**Steps**: [N] | **Gates added**: [N] | **ACs covered**: [N]/[N]
**Gate review**: [N blocking, N advisory] — [resolved / user-accepted / findings remain]

### TDD Gate Summary
[the summary table from plan.md]

Next step: `/tdd-build <slug>` to start test-first implementation.
```

## Rules

1. **Maximum reuse** — Phase 1 always goes through the `loadout:plan` skill (or its documented steps as fallback); never reimplement discovery, clarification, or plan-writing here
2. Every step gets a gate — no exceptions; a step with nothing testable is a sign the step is misdrawn, so flag it
3. Every acceptance criterion is covered by at least one gate, and the Summary table proves it
4. Use the four canonical field names exactly: **Test**, **Command**, **Fail-first**, **Pass condition** — `/tdd-build` parses them
5. Review artifacts are `tdd-gate-review-N.md` — never `plan-review-*`
6. Gate augmentation is additive: never rewrite, reorder, or delete the plan-writer's steps, ACs, or risks
7. At most one corrective re-spawn of `code-quality` per run
8. Honor the Confidence Policy — objective defects are fixed silently; subjective ones are asked, never assumed

## Example

**Invocation**: `/tdd-plan add rate limiting to the API gateway`

**Phase 1 — Base plan**: Skill tool invokes `loadout:plan` with the arguments. The plan flow runs end-to-end (discovery, clarifications, plan-writer, plan-reviewer) and produces `.dev/feat-api-rate-limiting/plan.md` with 6 steps and 6 acceptance criteria. User accepts the plan review.

**Phase 2 — Gate augmentation**: Read `plan.md` and `.claude/rules/common/testing.md`. `package.json` shows `"test": "vitest run"`. Append a gate to each step, e.g. Step 2 (Create rate limiter middleware):

```markdown
**TDD Gate**:
- **Test**: `src/gateway/middleware/rate-limit.test.ts` — 101st request within a minute from one IP receives 429 (AC 2)
- **Command**: `npx vitest run src/gateway/middleware/rate-limit.test.ts`
- **Fail-first**: fails before implementation because `rate-limit.ts` does not exist, so the middleware never returns 429
- **Pass condition**: exit code 0; test "returns 429 after limit exceeded" passes with response status asserted equal to 429
```

Append the summary table:

```markdown
## TDD Gate Summary

| Step | Command | ACs covered |
|------|---------|-------------|
| 1 | `npm ls rate-limiter-flexible` | AC 1 |
| 2 | `npx vitest run src/gateway/middleware/rate-limit.test.ts` | AC 2, AC 3 |
| 3 | `npx vitest run src/gateway/middleware/index.test.ts` | AC 4 |
| 4 | `npx vitest run src/config/schema.test.ts` | AC 5 |
| 5 | `npx vitest run src/lib/redis.test.ts` | AC 6 |
| 6 | `npx vitest run src/gateway/middleware/rate-limit.test.ts` | AC 3 |
```

Coverage check: all 6 ACs appear in the table.

**Phase 3 — Gate review**: no `tdd-gate-review-*.md` files exist → round 1. Spawn `code-quality`; it writes `.dev/feat-api-rate-limiting/tdd-gate-review-1.md` with 2 findings: (1) **blocking** — Step 4's command references `src/config/schema.spec.ts` but the gate's Test field says `schema.test.ts` (broken path); (2) **advisory** — Step 2's gate could split the 429 assertion and the Retry-After header assertion into separate tests.

**Phase 4 — Confidence Policy loop**: Finding 1 is objective (broken path) → fix the command in `plan.md`, re-spawn `code-quality` once → `tdd-gate-review-2.md` reports 0 blocking. Finding 2 is subjective (test granularity) → AskUserQuestion; user chooses to keep a single test.

**Phase 5 — Report**:

```
## TDD Plan Ready: feat-api-rate-limiting

**Steps**: 6 | **Gates added**: 6 | **ACs covered**: 6/6
**Gate review**: 1 blocking, 1 advisory — resolved

### TDD Gate Summary
[table above]

Next step: `/tdd-build feat-api-rate-limiting` to start test-first implementation.
```

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items with a `plan.md` that has no TDD Gates — offer to augment those (skip Phase 1, start at Phase 2)
2. Check `.dev/` for work items with `research.md` or `brainstorm.md` but no `plan.md` — suggest running the full flow on those
3. If none found, ask the user what they'd like to plan via `AskUserQuestion`
