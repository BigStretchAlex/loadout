---
description: Create a structured implementation plan with acceptance criteria, risks, and test strategy
---

# Plan Skill

Produce a detailed implementation plan for a work item, grounded in research findings and aligned with documented patterns.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain either:
   - A work item slug (e.g., `feat-auth-flow`) — plan within that context
   - A detailed description — create a new work item for it

2. **Set up the work item directory**:
   - If a slug is provided, use `.dev/<slug>/`
   - If new, derive a slug: `<type>-<descriptive-slug>` (feat/bug/refactor/spike)
   - Create the `.dev/<slug>/` directory if it doesn't exist
   - Initialize `scratch.md` from the template if it doesn't exist

3. **Check for existing plan** — if `.dev/<slug>/plan.md` already exists, ask the user:
   - **Revise**: update the existing plan based on new information
   - **Replace**: start fresh
   - **Cancel**: abort

4. **Gather context**:
   - Read `.dev/<slug>/research.md` if it exists
   - Read `.dev/<slug>/scratch.md` if it exists
   - Scan the codebase for files relevant to the goal

5. **Spawn the `plan-writer` agent** with the following prompt:
   > Goal: [goal from arguments or research.md]
   > Work item: .dev/<slug>/
   > Research: [summary of research.md findings if it exists]
   > Constraints: [any constraints from arguments]
   > Check .ai-docs/ for relevant patterns and conventions.

6. **Write the plan** to `.dev/<slug>/plan.md` using the plan template structure.

7. **Update scratch.md** — append any new insights or decisions.

8. **Report**:
```
## Plan Ready: [slug]

**Steps**: [N]
**Acceptance criteria**: [N]
**Risks identified**: [N]

Next step: `/build <slug>` to start implementation.
```

If no arguments are provided, check `.dev/` for work items with research but no plan and suggest planning those. If none found, ask the user what they'd like to plan.
