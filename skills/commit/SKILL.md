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

### Step 4: Present the commit and offer actions

Present the suggested commit message, then ALWAYS end your response with exactly these numbered actions for the user to choose from:

1. **Commit and push** — commit with this message and push to remote
2. **Commit only** — commit with this message, don't push
3. **Edit message** — let me modify the commit message first
4. **Stage different files** — change what's included before committing

Wait for the user to pick a number, then execute accordingly. After committing, do not offer further follow-up actions — the numbered list above is the final output.

## Example output

Here's what a typical response looks like after analyzing changes and staging files:

---

Staged 2 files: `src/auth/login.ts`, `src/auth/session.ts`

**Suggested commit:**

```
feat(auth): add session refresh on token expiry

Automatically refreshes the user session when the JWT expires
instead of forcing a re-login.
```

**Actions:**
1. **Commit and push**
2. **Commit only**
3. **Edit message**
4. **Stage different files**

---
