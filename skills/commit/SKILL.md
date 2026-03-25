---
description: Analyze changes and create a smart git commit. Use when the user wants to commit, stage, or save their work to git, even if they don't say "commit" explicitly (e.g., "save my changes", "I'm done with this feature", "wrap this up").
arguments: "Additional instructions for the commit"
model: haiku
---

# Smart Git Commit

Create well-structured conventional commits by analyzing changes, suggesting the right commit type, and confirming with the user before committing.

## Instructions

additional instructions = "$ARGUMENTS"

### Step 1: Analyze the current state

Run these in parallel to understand what changed:

```bash
git status
git diff --staged
```

If nothing is staged, also run:

```bash
git diff
git status -s
```

### Step 2: Help stage files if needed

If no files are staged, show the user what's changed and help them decide what to stage. Group related changes together and suggest logical staging — don't just `git add .` unless everything belongs in one commit.

If the changes are complex and span multiple concerns, suggest breaking them into separate commits and explain the grouping.

### Step 3: Suggest a commit message

Pick the appropriate conventional commit type based on what actually changed:

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

### Step 4: Confirm with the user

Present the suggested commit message and ask if they want to:
- Use it as-is
- Modify it
- Add more details to the body
- Stage different files

### Step 5: Commit

Once approved, create the commit and show the result.

### Step 6: Offer next steps

Ask if they want to:
- Push to remote
- Create a PR
- Continue working
