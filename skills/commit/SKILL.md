---
name: commit
description: Analyze the working tree and create a well-formed git commit.
disable-model-invocation: true
argument-hint: "Additional instructions for the commit"
model: haiku
allowed-tools: Bash(git:*)
---

# Smart Git Commit

Create well-structured conventional commits by analyzing changes, suggesting the right commit type, and confirming with the user before committing.

## Instructions

additional instructions = "$ARGUMENTS"

### Step 1: Survey all changes

Here's the high-level view of everything that changed — staged, unstaged, and untracked:

- Unstaged diff stat: !`git diff --stat`
- Staged diff stat: !`git diff --staged --stat`
- Status: !`git status -s`

Do NOT stage or add any files yet. The goal is to understand the full picture first.

### Step 2: Read the actual diffs

Group changed files by area (e.g., backend, frontend, docs, config) and read the diffs in batches. For large changesets, split into multiple `git diff` calls by directory or concern:

```bash
git diff -- src/api/ src/models/
git diff -- docs/ .ai-docs/
git diff --staged -- <paths>
```

Read enough to understand **what** changed and **why**, not just which files were touched.

### Step 3: Summarize and propose a commit

Present your analysis as a **changes summary table** grouping related changes by category, then propose a commit message. Use this shape:

````
**Changes summary:**

| Category | What changed |
|----------|-------------|
| ... | ... |

**Suggested commit:**

```
type(scope): concise description

[optional body]
```
````

Pick the appropriate conventional commit type:

| Type       | When to use                                      |
|------------|--------------------------------------------------|
| `feat`     | New functionality for the user                   |
| `fix`      | Bug fix                                          |
| `docs`     | Documentation only                               |
| `style`    | Formatting, whitespace, semicolons — no logic    |
| `refactor` | Code restructuring without behavior change       |
| `perf`     | Performance improvement                          |
| `test`     | Adding or updating tests                         |
| `chore`    | Build, tooling, config, dependencies             |

Format:
- Simple: `type: concise description`
- With scope: `type(scope): concise description`
- Complex changes: include a body explaining **what** and **why** (not how — the diff shows how)

If the user provided additional instructions via $ARGUMENTS, factor those into the message (e.g., they might specify the type or mention a ticket number).

### Step 4: Offer actions and WAIT

After presenting the summary and suggested message, ALWAYS end with numbered actions. The base actions are always present:

1. **Commit and push** — stage, commit, and push to remote
2. **Commit only** — stage and commit, don't push
3. **Edit message** — let me modify the commit message first

Then, conditionally add these only when relevant:

4. **Split commits** — only show this when the changeset spans multiple unrelated concerns. Don't show it for focused changes that naturally belong together.
5. **Split commits and push** — same as Split commits, but push each commit to remote after creating it. Show alongside option 4 when split is relevant.
6. **Stage different files** — change what's included before committing

If "Split commits" isn't shown, "Stage different files" becomes option 4.

**Do NOT stage or commit anything until the user picks an option.** This is the critical handoff — you've done the analysis, now the user decides.

Render the final options as a plain numbered list, e.g.:

```
**Next steps:**
1. **Commit and push**
2. **Commit only**
3. **Edit message**
[4./5./6. conditional options per the rules above, if applicable]
```
