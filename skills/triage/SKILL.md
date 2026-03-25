---
description: Promote scratch memory insights to .ai-docs/ knowledge base
---

# Triage Skill

Review scratch memory from a completed work item and promote valuable insights to the `.ai-docs/` knowledge base using the `document-writer` agent.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain:
   - A work item slug (e.g., `feat-auth-flow`) — triage that item's scratch
   - Or `global` — triage `.dev/scratch.md`

2. **Read scratch memory**:
   - If slug: read `.dev/<slug>/scratch.md`
   - If global: read `.dev/scratch.md`
   - If the file doesn't exist or is empty, report nothing to triage

3. **Check `.ai-docs/` exists** — if not, suggest running `/init-docs` first to establish the knowledge base.

4. **Spawn the `document-writer` agent** with:
   > Scratch memory file: [path]
   > Quality threshold: medium
   > Existing .ai-docs context: [list of current .ai-docs/ files]
   > Read `templates/ai-docs-frontmatter-standard.md` for the frontmatter schema.
   > Extract reusable patterns and produce .ai-docs/ documents or updates.

5. **Review the agent's output** — for each promoted pattern:
   - If it targets an existing document: show the proposed addition and confirm with user
   - If it creates a new document: show the document and confirm

6. **Apply approved changes**:
   - Write new documents to `.ai-docs/`
   - Update existing documents with new sections
   - Recalculate line numbers in frontmatter after any modifications

7. **Report**:
```
## Triage Complete: [slug]

**Insights reviewed**: [N]
**Promoted to .ai-docs/**: [N]
**Skipped**: [N] (too specific / low value / incomplete)

### Promoted
- [pattern name] → [target document]

### Skipped
- [insight]: [reason]

The work item [slug] is now complete.
```

If no arguments are provided, check `.dev/` for work items with scratch files that haven't been triaged and suggest those.
