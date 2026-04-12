---
name: status
description: Show current work item state and suggest next steps
---

# Status Skill

Inspect the `.dev/` directory to show the current state of all work items and suggest the next logical step.

## Instructions

1. **Check for `.dev/` directory** — if it doesn't exist, report that no work items are active and suggest starting with `/brainstorm` or `/plan`.

2. **Scan work items** — for each subdirectory in `.dev/` (excluding `scratch.md`):
   - Read the directory name to determine type and slug (e.g., `feat-auth-flow` → type: feat, slug: auth-flow)
   - Check which files exist: `research.md`, `plan.md`, `scratch.md`, `reviews/`
   - Determine the current phase based on what exists

3. **Determine phase** for each work item:

   | Files Present | Phase | Suggested Next Step |
   |--------------|-------|-------------------|
   | Nothing | Initialized | `/brainstorm <slug>` or `/plan <slug>` |
   | `research.md` only | Researched | `/plan <slug>` |
   | `plan.md` (no review) | Planned | `/build <slug>` |
   | `plan.md` + active changes | Building | Continue building or `/review <slug>` |
   | `reviews/` exists | In Review | `/review-fix <slug>` or complete |
   | Review with no issues | Complete | `/triage <slug>` to promote insights |

4. **Check for global scratch** — if `.dev/scratch.md` exists, note it has cross-cutting observations.

5. **Check `.ai-docs/`** — report if the knowledge base exists and how many documents it contains.

6. **Format output**:

```
## Loadout Status

### Knowledge Base
- `.ai-docs/`: [N documents | not initialized — run /init-docs]

### Active Work Items

#### [type]-[slug] — [Phase]
- Research: [exists/missing]
- Plan: [exists/missing]
- Scratch: [N entries / empty / missing]
- Reviews: [N iterations / none]
- **Next step**: [suggestion]

### Global Scratch
- [exists with N entries / not present]

### Suggested Actions
- [Most impactful next action based on current state]
```

If "$ARGUMENTS" specifies a slug, show detailed status for just that work item (including file summaries). Otherwise show the overview for all work items.
