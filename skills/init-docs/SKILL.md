---
description: Bootstrap .ai-docs/ knowledge base from a codebase by extracting patterns and conventions
---

# Init Docs Skill

Analyze the current codebase and generate an `.ai-docs/` knowledge base containing documented patterns, conventions, and architectural decisions.

## Instructions

1. **Check for existing `.ai-docs/`** — if it already exists and has documents, warn the user and ask whether to:
   - **Augment**: add new documents without modifying existing ones
   - **Rebuild**: remove existing docs and start fresh
   - **Cancel**: abort

2. **Create `.ai-docs/` directory** if it doesn't exist.

3. **Spawn the `doc-extractor` agent** with the following prompt:
   > Analyze the codebase at the current working directory. Extract patterns, conventions, and architectural decisions. Focus areas: $ARGUMENTS (or "all domains" if no arguments provided). Read `templates/ai-docs-frontmatter-standard.md` from the loadout plugin directory for the frontmatter schema. Produce complete .ai-docs/ documents ready to be written.

4. **Review the agent's output** — for each document produced:
   - Validate frontmatter follows the standard
   - Ensure patterns are generalized (not overly project-specific)
   - Write the file to `.ai-docs/`

5. **Calculate line numbers** — after writing each file, read it back and update the frontmatter `line_start` and `line_end` values for each section to reflect actual line positions.

6. **Report results**:

```
## .ai-docs/ Initialized

**Documents created**: [N]

| Document | Domain | Patterns | Sections |
|----------|--------|----------|----------|
| [name] | [domain] | [count] | [count] |

Run `/drift-check` periodically to keep these docs current.
Run `/status` to see knowledge base state.
```

If "$ARGUMENTS" specifies focus areas (e.g., "backend security"), pass them to the doc-extractor to narrow the analysis. Otherwise, analyze all domains.
