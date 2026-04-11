---
name: drift-check
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

5. **Doc size review** — spawn the `doc-reviewer` agent with the prompt:
   > Review all .ai-docs/ files for size and topic bloat. Flag files over 300 lines (ideal target: 50–100 lines) or with more than 5 sections. Propose splits.

   Present the doc review report to the user.

6. **Write state file** after the agent reports:
   - Ensure `.dev/` directory exists (run `mkdir -p .dev` if needed).
   - Write `.dev/.drift-check` with:
     ```json
     { "last_commit": "<HEAD SHA>", "last_run": "<today's date>" }
     ```

7. **For HIGH severity issues**, offer to fix them per finding:
   - **Stale patterns**: offer to (a) remove the section or (b) remove the entire document
   - **Contradicted patterns**: offer three options — (a) remove the section, (b) update the section using the cited code evidence, (c) skip
   - **Wrong line ranges**: offer to recalculate line numbers

   For any "update" choices selected, collect those findings and proceed to the batching step below.

8. **For MEDIUM severity issues (Drifted)**, present an interactive offer:
   - List all Drifted items with their index, document, and section heading
   - Ask the user: "Which would you like to update? Enter indices (e.g. 1,3), 'all', or 'none'."
   - Collect the selected findings.

   **Batching rule**: Before spawning `doc-updater`, group all selected findings (from both Step 7 and Step 8) by their target `.ai-docs/` document. Spawn **one `doc-updater` agent call per document**, passing all findings for that document together. This prevents re-reading the same file multiple times.

   **`doc-updater` input construction**: Build the input block from the drift report fields:
   ```
   Document: .ai-docs/<filename>.md
   Findings:
     1. Section: "<Section heading>", Lines: <line_start>-<line_end>, Evidence: <file>:<line>, Actual: "<Actual summary>", Type: Contradicted|Drifted
     2. ...
   ```

9. **For undocumented patterns** (LOW), suggest running `/init-docs` with a focused scope to add them.

10. **Summary**:

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
