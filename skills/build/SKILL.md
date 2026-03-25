---
description: Autonomous implementation based on plan.md
---

# Build Skill

Execute the implementation plan for a work item autonomously, working through each step and capturing insights.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain:
   - A work item slug (e.g., `feat-auth-flow`)
   - Optional: specific step number(s) to execute (e.g., `feat-auth-flow step 2-3`)

2. **Validate prerequisites**:
   - `.dev/<slug>/plan.md` must exist — if not, suggest running `/plan <slug>` first
   - Read the plan to understand the full scope

3. **Confirm with the user** before starting:
   ```
   ## Build: [slug]

   Plan has [N] steps. [Step override if specified]

   Acceptance criteria:
   - [list from plan]

   Proceed? (yes / review plan first / cancel)
   ```

4. **Spawn the `build-executor` agent** with the following prompt:
   > Work item: .dev/<slug>/
   > Execute the plan in plan.md. [Step override if specified]
   > Capture insights in scratch.md as you work.
   > Stop and report if any step fails or requires plan changes.

5. **Handle the build report**:
   - If all steps completed: proceed to report
   - If blocked: present the issue and ask the user how to proceed:
     - **Modify plan**: update plan.md and re-run
     - **Skip step**: continue with remaining steps
     - **Abort**: stop the build

6. **Report**:
```
## Build Complete: [slug]

**Steps completed**: [N] / [total]
**Acceptance criteria met**: [N] / [total]

Next step: `/review <slug>` to run a code review.
```

If no arguments are provided, check `.dev/` for work items with a plan but no review and suggest building those. If none found, ask the user what they'd like to build.
