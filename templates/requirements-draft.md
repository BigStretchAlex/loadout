# Requirements Draft Contract

The shared output contract for the requirements lens agents — `requirements-product`,
`requirements-backend`, `requirements-frontend`. All three emit this shape so `/plan`'s
requirements gate merges them without lens-specific parsing, and a fourth lens can be added
without touching the consumer.

## Lens identity header

Every draft begins with these two fields, mirroring the `**Reviewer:**` convention in
`templates/review-report.md`:

```markdown
**Lens:** [requirements-product | requirements-backend | requirements-frontend]
**Round:** [1 | 2 | 3]
```

The gate uses `Lens` to prefix requirement IDs on merge and to decide which lenses to re-spawn
in the next round; `Round` distinguishes a fresh draft from a revision built on user answers.

## Budgets

- **≤6 Confirmed Requirements** per lens.
- **≤4 Open Questions** per lens per round.

Three lenses merge into a single `AskUserQuestion` prompt; without caps that prompt is unusable.
Cutting to budget is part of the job, not a failure of it: rank by **what most changes the plan**,
keep those, and fold the rest into Assumptions where they are still visible but not blocking.

## Sections

```markdown
**Lens:** <lens name>
**Round:** <N>

## Confirmed Requirements

1. **[R1]** [One testable, observable statement of what must be true when the work is done]
   - **Basis**: [`research.md` § section | `path/to/file.ts:42` | goal text | user answer, round N]

## Non-Goals

- [Something a reader could reasonably expect to be in scope, explicitly excluded — and why]

## Open Questions

1. **[Q1]** [The question, phrased so the user can answer it without reading the codebase]
   - **Options**: [Option A] | [Option B] | [Option C]
   - **Default**: [which option applies if the user does not answer]
   - **Impact**: [what changes in the plan depending on the answer]

## Assumptions

- [Something taken as true without confirmation, including questions cut to fit the budget]

## Coverage Boundary

[What this lens deliberately left to another lens, named explicitly — so the merge can tell a real
gap from a hand-off]
```

### Requirement rules

- **Testable and observable.** A requirement whose satisfaction cannot be checked by running
  something or looking at something is an Assumption, not a requirement.
- **Every requirement carries a Basis.** Cite the `research.md` section, a `file:line`, the goal
  text, or `user answer, round N`. A requirement with no basis is invention — the exact failure
  this gate exists to prevent.
- **No implementation steps.** "Done means X" belongs here; "edit file Y" belongs in `plan.md`.

### Open Question rules

- **`Options` are 2–4, mutually exclusive, and user-presentable verbatim.** They are passed
  straight through as `AskUserQuestion` options — the gate does not rewrite them, so write them
  for the user, not for the agent.
- **`Default` is mandatory.** It is what the gate's *Continue with what we have* choice and the
  round-3 cap resolve the question to, and it is recorded under **Assumptions** in `scratch.md`.
  A question with no default stalls the flow.
- **Ask only what changes the plan.** If both answers lead to the same steps, it is an Assumption.

## Platform constraint

Lens agents **draft** questions; they never ask them. `AskUserQuestion` is stripped from every
subagent by a filter that runs after the `tools` allowlist — "even when listed in the `tools`
field" (https://code.claude.com/docs/en/sub-agents#available-tools). Do not add it to a lens
agent's `tools`; it will not appear, and the `Options`/`Default` fields above exist precisely
because the skill body has to ask on the agent's behalf.
