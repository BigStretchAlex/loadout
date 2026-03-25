---
description: Detect stale .ai-docs/ entries by comparing documented patterns against current code
---

# Drift Check Skill

Compare `.ai-docs/` documentation against the current codebase to find stale, drifted, or contradicted patterns.

## Instructions

1. **Verify `.ai-docs/` exists** — if not, tell the user to run `/init-docs` first.

2. **Spawn the `drift-analyzer` agent** with the following prompt:
   > Analyze the `.ai-docs/` knowledge base against the current codebase. Scope: $ARGUMENTS (or "all documents" if no arguments provided). For each documented pattern, verify it still exists and is accurate. Report drift with severity levels.

3. **Present the drift report** to the user.

4. **For HIGH severity issues**, offer to fix them:
   - **Stale patterns**: offer to remove the section or the entire document
   - **Contradicted patterns**: offer to rewrite the section based on current code
   - **Wrong line ranges**: offer to recalculate line numbers

5. **For MEDIUM severity issues**, suggest updates but don't auto-apply.

6. **For undocumented patterns** (LOW), suggest running `/init-docs` with a focused scope to add them.

7. **Summary**:

```
## Drift Check Complete

**Health**: [Good / Needs Attention / Stale]
- Current: [N] patterns
- Drifted: [N] patterns
- Stale: [N] patterns
- Undocumented: [N] patterns

[Actions taken or recommended]
```

If "$ARGUMENTS" specifies a document or domain, check only that scope. Otherwise check everything.
