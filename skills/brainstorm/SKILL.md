---
name: brainstorm
description: Interactive adversarial exploration of a vague idea before planning
disable-model-invocation: true
---

# Brainstorm Skill

Explore an idea through adversarial brainstorming — challenge assumptions, surface alternatives, and produce a structured brainstorm document.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain either:
   - A work item slug (e.g., `feat-auth-flow`) — research within that context
   - A free-form idea description — create a new work item for it

2. **Set up the work item** — follow `templates/work-item.md`: use `.dev/<slug>/` if a slug was provided, otherwise derive one; create the directory and initialize `scratch.md` if they don't already exist.

3. **Check for existing brainstorm** — if `.dev/<slug>/brainstorm.md` already exists, ask the user:
   - **Continue**: add to existing brainstorm
   - **Restart**: replace with fresh brainstorm
   - **Cancel**: abort

4. **Spawn the `brainstorm-challenger` agent** with the following prompt:
   > Brainstorm topic: [idea/problem from arguments]
   > Work item: .dev/<slug>/
   > Context: [any existing scratch.md or brainstorm.md content]
   > Challenge assumptions, propose alternatives, and check .ai-docs/ for precedents.

5. **Capture the output** — write the brainstorm-challenger's findings to `.dev/<slug>/brainstorm.md` using the structure from `templates/brainstorm.md`, including its trailing `loadout-handoff` footer (schema in `templates/handoff-footer.md`) as the last thing in the file:
   ```loadout-handoff
   schema: 1
   artifact: brainstorm
   produced_by: /brainstorm
   work_item: .dev/<slug>
   lane: standard
   verification: none
   next_command: /plan
   next_arguments: .dev/<slug>
   ```
   Field semantics: `templates/handoff-footer.md`. This producer sets `verification: none` (brainstorm has no self-check of its own) and `lane: standard` (brainstorm precedes lane selection, so `standard` is the default path out of it). `next_command`/`next_arguments` are filled from this skill's own routing in step 7 below (`/plan <slug>`) — never a second copy of that decision.

6. **Update scratch.md** — append any key insights or open questions.

7. **Report**:
```
## Brainstorm Complete: [slug]

**Assumptions challenged**: [N]
**Alternatives identified**: [N]
**Risks surfaced**: [N]

Key finding: [1-sentence summary]

Next step: `/plan <slug>` to create an implementation plan.
```

If no arguments are provided, ask the user what they'd like to brainstorm.
