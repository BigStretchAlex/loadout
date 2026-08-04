---
name: tdd-plan
description: TDD-augmented planning — create a structured implementation plan, then attach a test-first TDD Gate to every step.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Task, Skill, AskUserQuestion
argument-hint: "[feature-description | slug] [@context-files...]"
model: sonnet
---

# TDD Plan Skill

Produce a standard implementation plan via the existing `loadout:plan` flow, then augment it so every step carries a verifiable, test-first **TDD Gate**. The result is a plan that `/tdd-build` can execute gate-by-gate: write the test, watch it fail, implement, watch it pass.

## Canonical TDD Gate Format

Every gate — in the plan, in reviews, and in `/tdd-build` — uses these exact four field names (exact names matter: `/tdd-build` parses them):

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

1. Read `.dev/<slug>/plan.md` in full — steps, acceptance criteria, each step's `**Validation**:` block, test strategy.
2. Load the project's testing rules per `templates/testing-rules.md` (**Discovery** section). Gates must **comply** with what's found — behavior over implementation, deterministic, one reason to fail, no tautologies — per that template's "constrain authored gates" consumption mode (as opposed to injecting the rules verbatim into an executor prompt, which is `build`/`tdd-build`'s mode instead).
3. **Keep, never replace, each step's `**Validation**:` block** — it is a separate loop from the TDD Gate, not a duplicate of it. Append a **TDD Gate** block (canonical format above) *in addition to* it, to **every** step in the plan. A step with nothing testable is a sign the step itself is misdrawn — flag it rather than skipping the gate. For each gate:
   - **Test**: real path following the project's test location/naming conventions; state the behavior verified and which acceptance criterion it ties to
   - **Command**: exact and runnable in this project (correct test binary, real paths, no placeholders) — verify the binary exists (e.g., check `package.json` scripts, `pyproject.toml`, `Makefile`) before writing it
   - **Fail-first**: the test must fail because the behavior does not exist yet — not because of an import error or typo
   - **Pass condition**: deterministic and evaluable by an autonomous agent (exit code, specific assertion, exact output) — never "works correctly"
4. Append the `## TDD Gate Summary` table (canonical format above) to `plan.md` directly after `## Test Strategy` — one row per step. `plan-writer` already appended a trailing `loadout-handoff` footer (`templates/handoff-footer.md`) as the last thing in the file: insert the summary table (and every per-step gate edit above) **before** that footer, never after it and never over it — do not delete or reorder it. Update only the footer's `lane` field, from `standard` to `tdd` (the one field this phase touches, so `/status` reads the augmented lane directly instead of re-inferring it from `**TDD Gate**:` block presence); leave `verification`, `next_command`, `next_arguments`, and every other field exactly as `plan-writer`/`skills/plan/SKILL.md` last set them.
5. Cross-check coverage: **every acceptance criterion must be covered by at least one gate.** If an AC has no gate, add one (extend an existing step's gate or flag the uncovered AC to the user if no step plausibly covers it).
6. **Validation-loop equivalence rule:** a step's TDD Gate satisfies that step's validation loop *only when* the gate's **Command** and **Pass condition** independently meet the same adequacy bar as a `Validation:` block (a runnable command or agent-evaluable yes/no check — never blank, a placeholder like `<...>`/`TBD`/`...`, or unfalsifiable prose like "works correctly"). This never licenses dropping the `Validation:` block — per step 3 above, both blocks always stand on every step, regardless of gate quality. The rule instead governs what `code-quality` treats as adequate coverage when reviewing the pair.

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

See `templates/confidence-policy.md` for the objective/subjective classification. Applied here to the gate review findings:

- **Objective gate defects** — a step missing its TDD Gate or one of the four fields, a non-runnable command (wrong binary, fake path, placeholder), an acceptance criterion covered by no gate: fix them directly in `plan.md`, then re-spawn `code-quality` **once** (writing `tdd-gate-review-N+1.md`) to confirm. One re-spawn maximum — if blocking findings remain after the re-check, surface them to the user instead of looping.
- **Subjective findings** — gate design choices, test granularity, unit-vs-integration trade-offs: batch into a single AskUserQuestion (apply / skip per finding); apply only what the user selects.

### Phase 5 — Report

```
## TDD Plan Ready: [slug]

**Steps**: [N] | **Gates added**: [N] | **ACs covered**: [N]/[N]
**Gate review**: [N blocking, N advisory] — [resolved / user-accepted / findings remain]

### TDD Gate Summary
[the summary table from plan.md]

Next step: `/tdd-build .dev/<slug>` to start test-first implementation.
```

## Rules

1. **NEVER name review artifacts `plan-review-*`** — gate reviews are always `tdd-gate-review-N.md`; the `plan` skill counts its own review rounds by globbing `plan-review*.md` in `.dev/<slug>/`, and a colliding filename would corrupt that count.
2. Gate augmentation is additive: never rewrite, reorder, or delete the plan-writer's steps, ACs, or risks — and never delete or replace a step's `**Validation**:` block. The TDD Gate is appended alongside it; a strong gate is never a reason to drop the block.

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items with a `plan.md` that has no TDD Gates — offer to augment those (skip Phase 1, start at Phase 2)
2. Check `.dev/` for work items with `research.md` or `brainstorm.md` but no `plan.md` — suggest running the full flow on those
3. If none found, ask the user what they'd like to plan via `AskUserQuestion`
