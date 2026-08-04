---
name: review
description: Perform comprehensive code review of recent changes, analyzing quality, security, and test coverage
disable-model-invocation: true
argument-hint: "[dir | file1,file2,...] [--include-all] [--clear-exclusions]"
allowed-tools: Read, Task, Glob, Bash, TodoWrite, Write, AskUserQuestion
model: sonnet
---

# Review Skill

Perform a comprehensive code review with domain categorization, interactive issue selection, persistent exclusions, and round tracking.

**Fork boundary:** this skill's frontmatter carries no `context: fork` — it stays inline overall because Step 3 (interactive issue selection) needs `AskUserQuestion`, which cannot run inside a subagent, and Steps 4–6 (approval status, report write, routing) need the exclusion set Step 3 produces. Instead, the context-bloating half — file discovery, domain categorization, and the reviewer agent's full transcript — is delegated to a single `Task`-tool call to a `general-purpose` agent in Step 2, so none of that work enters this transcript; only Step 2's returned structured result does. This gives the same isolation `context: fork` would give a whole skill, without deleting the Step 3 pause point. No outer `agent:` shell: the delegate spawns the real reviewer role (`code-reviewer`/`typescript-reviewer`) itself, so a second shell would only nest roles for no gain. No `background:`: `/review` is today's foreground user action and Step 3 cannot proceed until Step 2 returns.

## Instructions

### Step 1: Parse Arguments & Flags

Parse `$ARGUMENTS` for the following flags:
- `--include-all` → skip interactive issue selection, include all issues
- `--clear-exclusions` → delete `<dir>/.review-exclusions.json` before starting

After extracting flags, inspect the remaining argument:
- **Directory path** (e.g., `.dev/feat-auth-flow`, `src/`, `./my-feature`): treat as `<dir>` — the working directory for this review. Storage files (exclusions, reports) live inside it.
- **Comma-separated file paths** (e.g., `src/auth.ts,src/login.tsx`): treat as an explicit file list. No persistent storage; no `<dir>`, so Step 5 displays the report inline instead of writing a file.
- **No argument**: auto-detect from git status.

### Step 2: Discover & Review (delegated)

Use the `Task` tool to spawn a **general-purpose** agent that runs everything from file discovery through the reviewer agent's pass. This is where the context bloat lives (git output, file categorization, the full reviewer transcript), and none of it enters this transcript — only the structured result below does.

Pass the agent, self-contained (it has no access to this conversation — only what's listed below):
- The mode / `<dir>` / file-list / flags resolved in Step 1
- Instruction to determine the review mode and discover files per `references/review-modes.md` (read it itself) — three modes: **Mode A** (directory provided) discovers from `<dir>/plan.md`, falling back to a branch/unstaged git diff, then `git status --short`; **Mode B** (comma-separated file list) splits the paths directly, round is always 1; **Mode C** (no args) combines `git status --short` and `git diff --name-only HEAD`, round is always 1.
- Instruction to categorize files by domain per `references/domain-categorization.md` (read it itself)
- If `--clear-exclusions` was set: delete `<dir>/.review-exclusions.json` before anything else; note that it was cleared
- If `<dir>` is present: create `<dir>/reviews/` if missing, count existing `review-*.md` files to determine round N (start at 1); if no `<dir>`, round is always 1
- **Language-based routing:** if ALL non-config source files under review have extensions `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, or `.cjs`, spawn the `typescript-reviewer` agent instead of `code-reviewer`; otherwise spawn `code-reviewer`. Config files (e.g. `*.config.js`, `.eslintrc.cjs`) and non-source files don't count against this test — a changeset of TS source plus a JSON/YAML/Markdown file still routes to `typescript-reviewer` based on its source files.
- Instruction to pass the reviewer agent the full file list, the domain breakdown, `This is review round [N]. Prior reviews exist at <dir>/reviews/.` when N > 1, and an explicit instruction to include the AI Slop Detection section

Require the agent to **return**, as its final result (never printed mid-run, since a delegate's transcript is discarded and only the return value survives):
- Resolved `<dir>` (or none), mode (A/B/C), round N
- The domain breakdown
- Which reviewer agent it spawned — `code-reviewer` or `typescript-reviewer` — this fills the `Reviewer:` field in Step 5
- The reviewer agent's full output, conforming to `templates/review-report.md`'s agent output shape
- If the reviewer agent failed or returned empty output: the error, so Step 3 can display `Review agent failed. Check that the files exist and are readable. Details: [error]` instead of proceeding

### Step 3: Interactive Issue Selection (skip if `--include-all`)

**If `--include-all` is set:** skip this step entirely — all issues are included.

**Otherwise:** parse issues from Step 2's returned result by severity, load any prior exclusions, and let the user choose which non-CRITICAL issues to exclude via `AskUserQuestion`. Save the updated exclusion set back to `<dir>/.review-exclusions.json`.

See `references/issue-selection.md` for the exclusions file schema, the CRITICAL-always-included rule, and the exact `AskUserQuestion` prompt/labeling format.

### Step 4: Calculate Approval Status

Based on the **included** issues (after Step 3's exclusions):
- Any CRITICAL or HIGH issue → **CHANGES REQUIRED**
- Only MEDIUM, LOW, or AI SLOP issues (or none) → **APPROVED**

Kept inline rather than delegated into Step 2: this depends on Step 3's exclusion set, which only exists once the interactive step runs — Step 2's delegate would have to guess exclusions it cannot know.

### Step 5: Generate Report

Write the report to `<dir>/reviews/review-[N].md` (or, if no `<dir>`, display it in this transcript) — built from Step 2's returned result, never from something a discarded delegate transcript already printed.

The severity vocabulary, verdict values, and reviewer-identity header follow `templates/review-report.md`; this report wraps that shared contract with the skill's own `Review Status` / `Excluded Issues` / `Security Analysis` / `Test Coverage` / `Best Practice Violations` sections.

See `references/review-output-template.md` for the full report Markdown structure to fill in and write, including the `loadout-handoff` footer appended when `<dir>` is present (schema in `templates/handoff-footer.md`).

### Step 6: Display Summary

Print to console:

```
## Review Round [N] Complete

Status: [APPROVED ✓ | CHANGES REQUIRED ✗]

Issues:
  CRITICAL : [N]
  HIGH     : [N]
  MEDIUM   : [N]
  LOW      : [N]
  AI SLOP  : [N]
  Excluded : [N]

Report saved: <dir>/reviews/review-[N].md
```

Then suggest next steps (using the exact report path written in Step 5, or omitted if no `<dir>` was provided):
- If CHANGES REQUIRED: `Next step: /review-fix <dir>/reviews/review-[N].md`
- If APPROVED and `<dir>` is a work item (i.e. `<dir>/scratch.md` exists): `Next step: /triage <dir>/`
- If APPROVED and `<dir>` is not a work item (no `scratch.md`), or no `<dir>` was provided (Modes B/C): print the verdict with no next-step line — `/triage` requires an existing `<dir>/scratch.md` and errors otherwise, so no suggestion is safe to emit. The handoff footer (Step 5) represents this same suppression as `next_command: none` — never a fabricated suggestion.
