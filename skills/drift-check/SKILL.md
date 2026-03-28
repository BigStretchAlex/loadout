---
description: Detect stale .ai-docs/ entries by comparing documented patterns against current code
allowed-tools: Bash(git:*), Bash(mkdir:*), Read, Write
---

# Drift Check Skill

Compare `.ai-docs/` documentation against the current codebase to find stale, drifted, or contradicted patterns.

## Instructions

1. **Verify `.ai-docs/` exists** — if not, tell the user to run `/init-docs` first.

2. **Check incremental state**:
   - Run `git rev-parse HEAD` to get the current HEAD SHA.
   - Check if `.dev/.drift-check` exists:
     - If it **exists**: read it and extract `last_commit`.
       - If `last_commit` equals HEAD SHA → tell the user "No new commits since last drift check. Skipping." and **stop**.
       - Otherwise: set `since_commit = last_commit` and continue with incremental mode.
     - If it **does not exist**: continue with full scan (no `since_commit`).

3. **Spawn the `drift-analyzer` agent** with the following prompt:
   - If incremental (`since_commit` is set):
     > Analyze the `.ai-docs/` knowledge base against the current codebase. Scope: $ARGUMENTS (or "all documents" if no arguments provided). since_commit: <since_commit SHA>. Only check documents affected by files changed since that commit. For each documented pattern in scope, verify it still exists and is accurate. Report drift with severity levels.
   - If full scan:
     > Analyze the `.ai-docs/` knowledge base against the current codebase. Scope: $ARGUMENTS (or "all documents" if no arguments provided). For each documented pattern, verify it still exists and is accurate. Report drift with severity levels.

4. **Present the drift report** to the user.

5. **Write state file** after the agent reports:
   - Ensure `.dev/` directory exists (run `mkdir -p .dev` if needed).
   - Write `.dev/.drift-check` with:
     ```json
     { "last_commit": "<HEAD SHA>", "last_run": "<today's date>" }
     ```

6. **For HIGH severity issues**, offer to fix them:
   - **Stale patterns**: offer to remove the section or the entire document
   - **Contradicted patterns**: offer to rewrite the section based on current code
   - **Wrong line ranges**: offer to recalculate line numbers

7. **For MEDIUM severity issues**, suggest updates but don't auto-apply.

8. **For undocumented patterns** (LOW), suggest running `/init-docs` with a focused scope to add them.

9. **Summary**:

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
