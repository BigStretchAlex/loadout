---
description: Run a code review on changes for a work item
---

# Review Skill

Run a thorough code review on the changes made for a work item using the `code-reviewer` agent.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain:
   - A work item slug (e.g., `feat-auth-flow`) — review changes in that context
   - Or no arguments — review all uncommitted changes

2. **Determine what to review**:
   - If a slug is provided: identify files changed as part of this work item (use git diff if on a branch, or check plan.md for the file list)
   - If no slug: use `git diff` to find all modified files

3. **Create reviews directory** — if a slug is provided, create `.dev/<slug>/reviews/` if it doesn't exist.

4. **Determine iteration number** — count existing review files in `.dev/<slug>/reviews/` to determine the current iteration (e.g., `review-1.md`, `review-2.md`).

5. **Spawn the `code-reviewer` agent** with the changed files and context from the work item.

6. **Save the review** to `.dev/<slug>/reviews/review-[N].md` (or display inline if no slug).

7. **Evaluate results**:
   - If **no CRITICAL or HIGH issues**: report clean review
   - If **issues found**: summarize and suggest `/review-fix <slug>`

8. **Report**:
```
## Review [N]: [slug]

**Files reviewed**: [N]
**Issues**: CRITICAL: [N], HIGH: [N], MEDIUM: [N], LOW: [N]

[If clean]
No blocking issues found. Feature is ready.
Next step: `/triage <slug>` to promote insights to .ai-docs/

[If issues]
[N] issues need attention.
Next step: `/review-fix <slug>` to address findings.
```
