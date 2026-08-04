# Type Constraints

Injected into the `plan-writer` prompt (step 6 of `skills/plan/SKILL.md`) based on the slug type prefix noted in step 2. Apply only the entry matching the work item type.

| Type | Constraint |
|------|------------|
| `feat` | **Simplicity discipline** — Solve the stated requirement only. Prefer the simplest design that satisfies the acceptance criteria. Use clear, intention-revealing names. Define explicit boundaries — what this feature does and does not own. Do not add extensibility hooks, abstraction layers, or optional configurability unless the goal explicitly calls for them. |
| `bug` | **Minimal footprint** — Change only what is necessary to fix the defect. Do not refactor surrounding code, rename symbols, or improve unrelated logic. Every step should trace directly to reproducing or preventing the bug. |
| `refactor` | **Scope discipline** — Restructure only what the goal names. Do not introduce new behaviour, fix unrelated bugs, rename symbols outside the stated scope, or add new capabilities. If you notice something worth improving, record it in Risks/Notes as a follow-on item — do not fold it into this plan. |
| `spike` | **Timebox and question focus** — The output is findings, not production code. Structure steps around answering the spike's stated questions. Include an explicit step to document conclusions and a recommended next action. Do not plan implementation work. |
