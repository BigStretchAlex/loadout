---
description: Address code review findings and re-review with an iteration limit
---

# Review Fix Skill

Address findings from the most recent code review and trigger a re-review. Enforces a maximum of 3 review iterations to prevent infinite loops.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain a work item slug (e.g., `feat-auth-flow`).

2. **Validate prerequisites**:
   - `.dev/<slug>/reviews/` must exist with at least one review file
   - If not, suggest running `/review <slug>` first

3. **Check iteration count**:
   - Count review files in `.dev/<slug>/reviews/`
   - If **3 or more reviews already exist**, trigger the escape hatch:
     ```
     ## Review Limit Reached: [slug]

     3 review iterations completed. Remaining issues:

     [List remaining CRITICAL/HIGH/MEDIUM issues from latest review]

     Options:
     - **continue**: run one more review cycle (override limit)
     - **skip**: accept remaining issues and mark complete
     - **escalate**: keep issues documented for manual review
     ```
   - Wait for user decision before proceeding

4. **Read the latest review** — parse `.dev/<slug>/reviews/review-[latest].md` to identify:
   - CRITICAL and HIGH issues (must fix)
   - MEDIUM issues (should fix)
   - LOW issues (skip unless trivial)

5. **Fix issues** — for each CRITICAL and HIGH issue:
   - Read the referenced file and line
   - Apply the recommended fix
   - Note the fix in scratch.md

6. **Fix MEDIUM issues** if they're straightforward (< 5 minutes of work each).

7. **Re-run review** — after fixes are applied, spawn the `code-reviewer` agent again on the modified files. Save as the next review iteration.

8. **Report**:
```
## Review Fix: [slug] (Iteration [N])

**Issues addressed**: [N] / [total from previous review]
- CRITICAL fixed: [N]
- HIGH fixed: [N]
- MEDIUM fixed: [N]
- LOW skipped: [N]

**Re-review result**: [clean / N remaining issues]

[If clean] Next step: `/triage <slug>`
[If issues remain and under limit] Next step: `/review-fix <slug>`
[If at limit] Review limit reached — see options above.
```

If no arguments are provided, check `.dev/` for work items with reviews that have unresolved issues and suggest fixing those.
