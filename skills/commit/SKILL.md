---
name: commit
description: Analyze changes and create a smart git commit. Use when the user wants to commit, stage, or save their work to git, even if they don't say "commit" explicitly (e.g., "save my changes", "I'm done with this feature", "wrap this up").
arguments: "Additional instructions for the commit"
model: haiku
allowed-tools: Bash(git:*)
---

# Smart Git Commit

Create well-structured conventional commits by analyzing changes, suggesting the right commit type, and confirming with the user before committing.

## Instructions

additional instructions = "$ARGUMENTS"

### Step 1: Survey all changes

Get a high-level view of everything that changed — staged, unstaged, and untracked. Run each of these as a separate tool call (do not combine with shell operators):

```bash
git diff --stat
```
```bash
git diff --staged --stat
```
```bash
git status -s
```

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

Present your analysis as a **changes summary table** grouping related changes by category, then propose a commit message.

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

## Examples

### Example 1: Focused change (no split option)

All changes relate to the same feature, so "Split commits" is not offered.

---

**Changes summary:**

| Category | What changed |
|----------|-------------|
| Auth | Added session refresh logic in `src/auth/session.ts` |
| Auth | Updated login flow to use new refresh in `src/auth/login.ts` |
| Tests | New test for session expiry in `tests/auth.test.ts` |

**Suggested commit:**

```
feat(auth): add session refresh on token expiry

Automatically refreshes the user session when the JWT expires
instead of forcing a re-login.
```

**Next steps:**
1. **Commit and push**
2. **Commit only**
3. **Edit message**
4. **Stage different files**

---

### Example 2: Multi-concern changeset (split option shown)

Changes span unrelated areas — a new API feature, a docs update, and a config bump — so "Split commits" is offered.

---

**Changes summary:**

| Category | What changed |
|----------|-------------|
| API | New `/webhooks` endpoint in `src/api/webhooks.ts` |
| API | Added webhook payload validation in `src/api/validators.ts` |
| Docs | Updated API reference in `docs/api.md` |
| Config | Bumped Node version in `.nvmrc` |

**Suggested commit:**

```
feat(api): add webhook delivery endpoint

Accepts incoming webhooks, validates payload signatures,
and queues events for async processing.
```

**Next steps:**
1. **Commit and push**
2. **Commit only**
3. **Edit message**
4. **Split commits** — could separate API feature, docs update, and config change
5. **Split commits and push**
6. **Stage different files**

---

### Example 3: Simple single-file fix

Minimal change, no need for split or stage options.

---

**Changes summary:**

| Category | What changed |
|----------|-------------|
| Billing | Fixed off-by-one in proration calc (`src/billing/prorate.ts`) |

**Suggested commit:**

```
fix(billing): correct off-by-one in proration calculation
```

**Next steps:**
1. **Commit and push**
2. **Commit only**
3. **Edit message**
