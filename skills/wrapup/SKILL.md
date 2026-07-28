---
name: wrapup
description: Promote insights to .ai-docs/ after work completed outside the loadout workflow, using git to detect changes since the last wrapup
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

### Phase 5 – Report & Update State

1. Ensure `.dev/` exists (`mkdir -p .dev`).
2. Write `.dev/.wrapup`:
   ```json
   { "last_commit": "<current_head>", "last_run": "<today's date>" }
   ```
   Always use the HEAD SHA captured at the *start* of Phase 1 — even if an explicit range argument overrode the resolved range — so the next no-arg run resumes from here. This state file is wrapup's own idempotency marker: a separate file rather than an in-file comment, since there's no single source file in git history to annotate.

3. Print the final report:
   ```
   ## Wrapup Complete: [range description]

   **Commits analyzed**: N
   **Uncommitted changes included**: yes|no
   **Insights reviewed**: N
   **Promoted to .ai-docs/**: N
   **Skipped**: N

   ### Promoted
   - [pattern name] → [target document]

   ### Skipped
   - [insight]: [reason]

   State updated: .dev/.wrapup (last_commit: <short SHA>)
   ```
   If uncommitted changes were included, add a note recommending the user commit them (e.g. via `/commit`) to avoid re-analyzing the same diff on the next run.

**Wrapup never stages, commits, or pushes.** It is read-only with respect to git state — only `log`, `diff`, `status`, `rev-parse`, `merge-base`, `show-ref`, and `symbolic-ref` are used. Committing is a separate concern.

---

## Examples

### Example 1: Incremental run using existing state

**User invokes:**
```
/wrapup
```

**Phase 1**: `.ai-docs/` exists with 4 files. `git rev-parse HEAD` → `9f3a1c2`. `.dev/.wrapup` exists with `{"last_commit": "7b2e001", "last_run": "2026-06-20"}`. `7b2e001 != 9f3a1c2`, so `range = "7b2e001..HEAD"`. `git status --short` is clean. Proceeds to Phase 2.

**Phase 2**: `git log --oneline 7b2e001..HEAD` shows 4 commits. Diff stat shows changes across `src/billing/` and `src/webhooks/`. Full commit log reveals a body explaining a switch to idempotency keys for webhook retries. Reads diffs in two batches (billing, webhooks). Synthesizes 3 candidates: idempotency key pattern (general), webhook retry backoff (general), and this repo's webhook signature header convention (codebase-specific). All 3 pass the medium threshold.

Output:
```
Found 3 promotable insights across 4 commits (7b2e001..HEAD). Spawning document-writer...
```

**Phase 3**: Compiles one `## Document: webhooks` block with the 3 findings, rationale quoted from commit bodies. Existing files: `auth.md`, `api-patterns.md`, `testing.md`, `billing.md`. Spawns `document-writer` in Augment mode.

Agent creates `.ai-docs/webhooks.md` with all 3 patterns and runs two-pass line number resolution.

**Phase 4**: Displays:
```
Promoted 3 patterns, skipped 0.

Promoted:
- Idempotency key pattern for webhook delivery → .ai-docs/webhooks.md (new)
- Webhook retry backoff strategy → .ai-docs/webhooks.md (new)
- Webhook signature header convention (codebase-specific) → .ai-docs/webhooks.md (new)
```

**Phase 5**: Writes `.dev/.wrapup` with `{"last_commit": "9f3a1c2", "last_run": "2026-07-03"}` and prints:
```
## Wrapup Complete: 7b2e001..HEAD

**Commits analyzed**: 4
**Uncommitted changes included**: no
**Insights reviewed**: 3
**Promoted to .ai-docs/**: 3
**Skipped**: 0

### Promoted
- Idempotency key pattern for webhook delivery → .ai-docs/webhooks.md (new)
- Webhook retry backoff strategy → .ai-docs/webhooks.md (new)
- Webhook signature header convention (codebase-specific) → .ai-docs/webhooks.md (new)

State updated: .dev/.wrapup (last_commit: 9f3a1c2)
```

---

### Example 2: First run — no state file, falls back to merge-base plus uncommitted changes

**User invokes:**
```
/wrapup
```

**Phase 1**: `.ai-docs/` exists. `git rev-parse HEAD` → `c4d8e91`. No `.dev/.wrapup` file. Resolves default branch: `origin/HEAD` isn't set, `main` exists locally. `git merge-base HEAD main` → `a01f223`, which differs from `c4d8e91`, so `range = "a01f223..HEAD"`. `git status --short` shows one modified file (`src/cache/redis.ts`, uncommitted). Both are in scope.

**Phase 2**: `git log --oneline a01f223..HEAD` shows 6 commits. Diff stats span `src/cache/`, `src/queue/`. Reads full commit log for rationale — one body explains why a 15-minute TTL was chosen for session cache. Reads batched diffs plus the uncommitted `redis.ts` change directly. Synthesizes 4 candidates: Redis TTL heuristic (codebase-specific, from commit body rationale), queue backpressure pattern (general), a gotcha about connection pool exhaustion under load (from the uncommitted diff, evidenced directly since it has no commit body), and one one-off logging tweak that gets filtered out as noise.

Output:
```
Found 3 promotable insights across 6 commits (a01f223..HEAD), plus uncommitted changes. Spawning document-writer...
```

**Phase 3**: Compiles `## Document: caching` and `## Document: queueing` blocks. Existing `.ai-docs/` files: `auth.md`, `api-patterns.md`. Spawns `document-writer` in Augment mode.

Agent creates `.ai-docs/caching.md` and `.ai-docs/queueing.md`.

**Phase 4**: Displays:
```
Promoted 3 patterns, skipped 0.

Promoted:
- Redis TTL heuristic for session caching (codebase-specific) → .ai-docs/caching.md (new)
- Connection pool exhaustion under load → .ai-docs/caching.md (new)
- Queue backpressure pattern → .ai-docs/queueing.md (new)
```

**Phase 5**: Writes `.dev/.wrapup` with `{"last_commit": "c4d8e91", "last_run": "2026-07-03"}` and prints:
```
## Wrapup Complete: a01f223..HEAD, plus uncommitted changes

**Commits analyzed**: 6
**Uncommitted changes included**: yes
**Insights reviewed**: 4
**Promoted to .ai-docs/**: 3
**Skipped**: 1

### Promoted
- Redis TTL heuristic for session caching (codebase-specific) → .ai-docs/caching.md (new)
- Connection pool exhaustion under load → .ai-docs/caching.md (new)
- Queue backpressure pattern → .ai-docs/queueing.md (new)

### Skipped
- Logging tweak in worker loop: one-off, no reusable insight

State updated: .dev/.wrapup (last_commit: c4d8e91)

Note: uncommitted changes were included in this analysis. Commit them (e.g. via /commit) to avoid re-analyzing the same diff next run.
```

---

### Example 3: Immediate re-run short-circuits

**User invokes:**
```
/wrapup
```

**Phase 1**: `git rev-parse HEAD` → `c4d8e91`, same as `.dev/.wrapup`'s `last_commit` from Example 2. `git status --short` is now clean (the uncommitted change was committed separately since the last run).

Output:
```
Nothing to promote — no changes since last wrapup.
```

Skill stops immediately. No agent spawned, no state file update.
