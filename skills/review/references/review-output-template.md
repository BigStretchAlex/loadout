# Report Structure Template

Detail for Step 5 (Generate Report). Fill in this Markdown structure and write it to
`<dir>/reviews/review-[N].md` (or display inline if no `<dir>`).

```markdown
# Code Review — Round [N]: [dir]

**Reviewer:** [agent name returned by Step 2 — `code-reviewer` or `typescript-reviewer`]

## Review Status

> **[APPROVED ✓ | CHANGES REQUIRED ✗]**

## Executive Summary

- **Files reviewed**: [N]
- **Issues found**: CRITICAL: [N], HIGH: [N], MEDIUM: [N], LOW: [N], AI Slop: [N]
- **Issues included**: [N] (excluded: [N])
- **Domains**: [backend, frontend, test, ...]
- **Overall**: [1–2 sentence assessment]

## Excluded Issues

[If any exclusions]
The following issues were excluded from this review round:
- [SEVERITY] `file:line` — [title]

[If none]
No issues excluded.

## Findings

### Critical Issues
[List or "None"]

### High Issues
[List or "None"]

### Medium Issues
[List or "None"]

### Low Issues
[List or "None"]

### AI Slop Findings
[List or "None"]

## Security Analysis

[From agent output]

## Test Coverage

[From agent output]

## Best Practice Violations

[From agent output]

## Recommendations

### Must fix (Critical/High)
[List]

### Should fix (Medium / AI Slop)
[List]

### Nice to have (Low)
[List]
```

## Handoff footer

Append after the report body above, as the last thing in the file — schema defined in
`templates/handoff-footer.md`, mirrored in `templates/review-report.md`. Only written when `<dir>`
is present (Mode A); Mode B/C's inline display has no file to append to.

````markdown
```loadout-handoff
schema: 1
artifact: review-report
produced_by: /review
work_item: <dir>
lane: standard | tdd | express
verification: pass | fail
next_command: /review-fix | /triage | none
next_arguments: <dir>/reviews/review-[N].md | <dir>
```
````

- `lane` — copy forward from `<dir>/tasks.md`'s footer if it has one, else `<dir>/plan.md`'s, else `standard`.
- `verification` — `pass` if Step 4 computed APPROVED, `fail` if CHANGES REQUIRED.
- `next_command`/`next_arguments` — filled from Step 6's routing exactly as computed there (never a second copy of that mapping): `/review-fix` with the report path if CHANGES REQUIRED; `/triage` with `<dir>/` if APPROVED and `<dir>/scratch.md` exists; `none` (omit `next_arguments`) if APPROVED and `<dir>` is not a work item.
