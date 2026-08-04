---
name: drift-check
description: Detect stale .ai-docs/ entries by comparing documented patterns against current code
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(mkdir:*), Read, Write, Task, AskUserQuestion
---

# Drift Check Skill

Compare `.ai-docs/` documentation against the current codebase to find stale, drifted, or contradicted patterns.

**Fork boundary:** this skill's frontmatter carries no `context: fork` — it stays inline overall because Steps 6–7 (HIGH/MEDIUM fix offers) need `AskUserQuestion`, which cannot run inside a subagent, and those offers work off the reports Step 3 produces. Instead, the context-bloating half — the `drift-analyzer` and `doc-reviewer` agents' full transcripts over the whole `.ai-docs/` tree — is delegated to a single `Task`-tool call to a `general-purpose` agent in Step 3, so none of that enters this transcript; only its returned reports do. No outer `agent:` shell: the delegate spawns the real analyzer roles itself, so a second shell would only nest roles for no gain. No `background:`: `/drift-check` is today's foreground user action.

## Instructions

1. **Verify `.ai-docs/` exists** — if not, tell the user to run `/init-docs` first.

2. **Check incremental state**:
   - Run `git rev-parse HEAD` to get the current HEAD SHA.
   - Check if `.dev/.drift-check` exists:
     - If it **exists**: read it and extract `last_commit`.
       - If `last_commit` equals HEAD SHA → tell the user "No new commits since last drift check. Skipping." and **stop**.
       - Otherwise: set `since_commit = last_commit` and continue with incremental mode.
     - If it **does not exist**: continue with full scan (no `since_commit`).

3. **Run analysis (delegated)** — use the `Task` tool to spawn a **general-purpose** agent, self-contained: pass it everything below explicitly, since it has no access to this conversation.
   - `$ARGUMENTS` (or "all documents" if empty) as the scope
   - Whether this is incremental (`since_commit` from step 2) or a full scan
   - Instruction to spawn the `drift-analyzer` agent with:
     - If incremental: `Analyze the .ai-docs/ knowledge base against the current codebase. Scope: [scope]. since_commit: [since_commit SHA]. Only check documents affected by files changed since that commit. For each documented pattern in scope, verify it still exists and is accurate. Report drift with severity levels.`
     - If full scan: `Analyze the .ai-docs/ knowledge base against the current codebase. Scope: [scope]. For each documented pattern, verify it still exists and is accurate. Report drift with severity levels.`
   - Instruction to also spawn the `doc-reviewer` agent with: `Review all .ai-docs/ files for size and topic bloat. Flag files over 300 lines (ideal target: 50–100 lines) or with more than 5 sections. Propose splits.`
   - Require it to **return** both reports verbatim as its final result — never printed mid-run, since a delegate's transcript is discarded and only the return value survives.

4. **Present the reports** to the user — the drift report and the doc review report, both taken from step 3's returned result.

5. **Write state file**:
   - Ensure `.dev/` exists (run `mkdir -p .dev` if needed) — this is the lighter variant of the directory-creation step in `templates/work-item.md`. Drift-check has no per-work-item slug, so that template's slug-derivation and `scratch.md`-initialization steps don't apply here; only the bare `.dev/` directory is needed, to hold the state file below.
   - Write `.dev/.drift-check` with:
     ```json
     { "last_commit": "<HEAD SHA from step 2>", "last_run": "<today's date>" }
     ```

6. **For HIGH severity issues**, offer to fix them per finding via `AskUserQuestion`:
   - **Stale patterns**: offer to (a) remove the section or (b) remove the entire document
   - **Contradicted patterns**: offer three options — (a) remove the section, (b) update the section using the cited code evidence, (c) skip
   - **Wrong line ranges**: offer to recalculate line numbers

   For any "update" choices selected, collect those findings and proceed to the batching step below.

7. **For MEDIUM severity issues (Drifted)**, present an interactive offer via `AskUserQuestion`:
   - List all Drifted items with their index, document, and section heading
   - Ask the user: "Which would you like to update? Enter indices (e.g. 1,3), 'all', or 'none'."
   - Collect the selected findings.

   **Batching rule**: Before spawning `doc-updater`, group all selected findings (from both Step 6 and Step 7) by their target `.ai-docs/` document. Spawn **one `doc-updater` agent call per document**, passing all findings for that document together. This prevents re-reading the same file multiple times.

   **`doc-updater` input construction**: Build the input block from the drift report fields:
   ```
   Document: .ai-docs/<filename>.md
   Findings:
     1. Section: "<Section heading>", Lines: <line_start>-<line_end>, Evidence: <file>:<line>, Actual: "<Actual summary>", Type: Contradicted|Drifted
     2. ...
   ```

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
