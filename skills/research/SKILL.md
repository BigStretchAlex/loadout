---
description: Interactive adversarial exploration of a vague idea before planning
---

# Research Skill

Explore an idea through adversarial research — challenge assumptions, surface alternatives, and produce a structured research document.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain either:
   - A work item slug (e.g., `feat-auth-flow`) — research within that context
   - A free-form idea description — create a new work item for it

2. **Set up the work item directory**:
   - If a slug is provided, use `.dev/<slug>/`
   - If a new idea, derive a slug: `<type>-<descriptive-slug>` where type is one of: `feat`, `bug`, `refactor`, `spike`
   - Create the `.dev/<slug>/` directory if it doesn't exist
   - Initialize `scratch.md` from the template if it doesn't exist

3. **Check for existing research** — if `.dev/<slug>/research.md` already exists, ask the user:
   - **Continue**: add to existing research
   - **Restart**: replace with fresh research
   - **Cancel**: abort

4. **Spawn the `research-challenger` agent** with the following prompt:
   > Research topic: [idea/problem from arguments]
   > Work item: .dev/<slug>/
   > Context: [any existing scratch.md or research.md content]
   > Challenge assumptions, propose alternatives, and check .ai-docs/ for precedents.

5. **Capture the output** — write the research-challenger's findings to `.dev/<slug>/research.md` using the research template structure.

6. **Update scratch.md** — append any key insights or open questions.

7. **Report**:
```
## Research Complete: [slug]

**Assumptions challenged**: [N]
**Alternatives identified**: [N]
**Risks surfaced**: [N]

Key finding: [1-sentence summary]

Next step: `/plan <slug>` to create an implementation plan.
```

If no arguments are provided, ask the user what they'd like to research.
