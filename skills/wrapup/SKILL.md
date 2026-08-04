---
name: wrapup
description: Promote insights to .ai-docs/ after work completed outside the loadout workflow, using git to detect changes since the last wrapup
disable-model-invocation: true
argument-hint: "git-ref-or-range"
allowed-tools: Bash(git:*), Bash(mkdir:*), Read, Grep, Glob, Task, Write
model: sonnet
---

# Wrapup Skill

Reconstruct reusable insights from git history — commit messages for rationale and decisions, diffs for patterns and gotchas — and promote them to the `.ai-docs/` knowledge base using the `document-writer` agent. Useful for work done without scratch memory: quick fixes, pre-existing history, or manual edits.

## Instructions

### Phase 1 – Discovery & Validation

**Check `.ai-docs/` exists:**
- If `.ai-docs/` does not exist or is empty → suggest running `/init-docs` first and stop.

**Capture current state:**
- Run `git rev-parse HEAD` → `current_head`. This is captured now and used for the state file at the end, regardless of any range resolved below.

**Resolve the change range:**

1. **Explicit argument** — if `$ARGUMENTS` is non-empty, use it as a literal git ref or range (e.g. `abc123..HEAD`, `main..HEAD`, a single ref meaning "since that ref").
2. **No argument, state file exists** — if `.dev/.wrapup` exists, read it (`{"last_commit", "last_run"}`).
   - If `last_commit == current_head` AND `git status --short` is clean → report "Nothing to promote — no changes since last wrapup." and stop.
   - Otherwise, `range = "<last_commit>..HEAD"`.
3. **No argument, no state file (first run)** — resolve a default branch:
   - Try `git symbolic-ref refs/remotes/origin/HEAD` (strip to branch name); if that fails, fall back to `main` then `master` (whichever exists via `git show-ref --verify --quiet refs/heads/<name>`).
   - If a default branch is found, run `git merge-base HEAD <default>`.
     - If the merge-base differs from `current_head`, `range = "<merge-base>..HEAD"`.
     - If it equals `current_head`, there's no divergence — `range` is empty.
   - If no default branch can be resolved (e.g. detached HEAD, no local/remote branches to compare against), `range` is unresolvable — treat as empty and rely on uncommitted changes only.

**Always check for uncommitted changes** — run `git status --short` regardless of which branch above was taken, and union it into scope. If `range` is empty **and** the working tree is clean → report "Nothing to wrap up — no new commits or uncommitted changes." and stop.

Proceed immediately to Phase 2 — no confirmation needed.

---

### Phase 2 – Content Analysis

**Size-aware survey** — run each as a separate tool call, not combined:
```bash
git log --oneline <range>
git diff --stat <range>
git diff --stat
git diff --staged --stat
git status --short
```
(Skip the `<range>` calls if range is empty.)

**Full commit messages** — read subjects and bodies together, since rationale for decisions lives in the body:
```bash
git log <range> --format='%H%n%s%n%n%b%n===END==='
```

**Enumerate and dedupe changed files** from `git diff --name-only <range>`, unstaged (`git diff --name-only`), staged (`git diff --staged --name-only`), and untracked entries from `git status --short`.

**Read diffs in batches** grouped by directory or concern (the same idiom as `skills/commit/SKILL.md`) — never one giant diff call across the whole range. For untracked files, `git diff` shows nothing — read the file directly instead.

**Synthesize insight candidates** across these categories:
- Domain concepts
- Technical patterns
- Integration points
- Gotchas
- Decisions with rationale (drawn from commit bodies)
- Assumptions
- Reusable solutions

If `range` is empty (uncommitted changes only, no commit history to draw from), don't fabricate rationale — report only what the diff itself evidences.

**Apply a medium quality threshold** — filter out incomplete, one-off, or noise items; retain both general (applicable across projects) and codebase-specific (conventions, decisions unique to this repo) insights.

**Report the count** before spawning the agent:
```
Found N promotable insights across M commits (<range>)[, plus uncommitted changes]. Spawning document-writer...
```

---

### Phase 3 – Knowledge Extraction & Document Update

1. Glob `.ai-docs/*.md` for the existing file list.
2. Compile findings into `## Document: [name]` blocks — the same shape `document-writer` already parses from codebase analysis input:
   - Decisions, gotchas, and integration points → **Patterns Found**, with rationale quoted or paraphrased from commit bodies
   - Naming/style observations → **Conventions**
   - Touched files → **Key Files**

3. Spawn the `document-writer` agent with this prompt (fill in the bracketed values):

   > You are writing `.ai-docs/` documents from codebase analysis findings.
   >
   > **Input type**: codebase analysis findings (not a scratch file)
   > **Source**: git history analysis, range `[range or "uncommitted changes only"]` ([N] commits[, plus uncommitted working-tree changes])
   > **Findings**: [compiled `## Document:` blocks]
   > **Existing `.ai-docs/` files**: [list]
   > **Mode**: Augment
   >
   > For each set of findings, decide whether to append to an existing file or create a new one — prefer merging when the topic matches. In Augment mode, only create new files or append new sections; do not modify or remove unrelated existing content. Write files directly using the two-pass line-number approach. Return a summary of what was promoted and skipped (with reasons).

---

### Phase 4 – Review Agent Output

Read the agent's returned summary and display it to the user:
```
Promoted N patterns, skipped M.

Promoted:
- [pattern name] → [target document]

Skipped:
- [insight]: [reason]
```

No manual confirmation loop — the agent has already applied changes.

---

### Phase 5 – Verify Written Line Ranges (self-check)

Run the shared check in `templates/line-range-verification.md` against every `.ai-docs/` file the agent reported as promoted-to or updated (from Phase 4's list). Do not write the `.dev/.wrapup` state file until it reports PASS — that file is a done-claim that gates the next no-arg run.

---

### Phase 6 – Report & Update State

Only after Phase 5 reports PASS:

1. Ensure `.dev/` exists (`mkdir -p .dev`). This is a lighter variant of `templates/work-item.md`'s setup: only that template's directory-creation step applies, scoped to the `.dev/` root rather than a `.dev/<slug>/` work item — wrapup analyzes git history rather than a scratch-memory work item, so there is no slug to derive and no `scratch.md` to initialize. The directory only needs to exist to hold wrapup's own state file, below.
2. Write `.dev/.wrapup`:
   ```json
   { "last_commit": "<current_head>", "last_run": "<today's date>" }
   ```
   Always use the HEAD SHA captured at the *start* of Phase 1 — even if an explicit range argument overrode the resolved range — so the next no-arg run resumes from here. This state file is wrapup's own idempotency marker: a separate file rather than an in-file comment, since there's no single source file in git history to annotate.

3. Print the final report using the skeleton in `references/completion-format.md`. If uncommitted changes were included, add a note recommending the user commit them (e.g. via `/commit`) to avoid re-analyzing the same diff on the next run.

**Wrapup never stages, commits, or pushes.** It is read-only with respect to git state — only `log`, `diff`, `status`, `rev-parse`, `merge-base`, `show-ref`, and `symbolic-ref` are used. Committing is a separate concern.

