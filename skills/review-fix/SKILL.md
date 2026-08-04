---
name: review-fix
description: Address code review findings and re-review with an iteration limit
disable-model-invocation: true
---

# Review Fix Skill

Address findings from a specific code review file and trigger a re-review. Enforces a maximum of 3 review iterations to prevent infinite loops. Objective fixes are auto-applied with re-verification; subjective fixes require explicit user approval (see Confidence Policy).

## Confidence Policy

Classify every finding or proposed fix per `templates/confidence-policy.md` before acting on it (objective fixes auto-apply with re-verification; subjective fixes require `AskUserQuestion` approval).

## Variables

Derived from `$ARGUMENTS` (path to a review file, e.g., `.dev/feat-auth-flow/reviews/review-2.md`):

- `REVIEW_FILE` — `$ARGUMENTS` (the review file path)
- `REVIEWS_DIR` — parent directory of `REVIEW_FILE` (e.g., `.dev/feat-auth-flow/reviews/`)
- `WORK_DIR` — parent of `REVIEWS_DIR` (e.g., `.dev/feat-auth-flow/`)
- `SCRATCH_FILE` — `WORK_DIR/scratch.md`
- `REVIEWER_AGENT` — the agent name from `REVIEW_FILE`'s `Reviewer:` header field (e.g., `typescript-reviewer`); falls back to `code-reviewer` if the field is absent (legacy review file written before this field existed)

## Workflow

### Phase 1 – Validation & Setup

- If `REVIEW_FILE` is not provided: scan `.dev/` for work items that have unresolved review issues and suggest the appropriate invocation paths, then stop.
- Verify `REVIEW_FILE` exists on disk; if not, report the missing path and stop.
- Derive `WORK_DIR`, `REVIEWS_DIR`, and `SCRATCH_FILE` from the path.
- Read `SCRATCH_FILE` if it exists; initialize it if not.

### Phase 2 – Iteration Guard

- Count all review files in `REVIEWS_DIR`.
- If **3 or more review files already exist**, display the escape hatch and wait for user input before proceeding:

```
## Review Limit Reached

3 review iterations completed for [WORK_DIR].

Remaining issues from [REVIEW_FILE]:
[List all unresolved CRITICAL / HIGH / MEDIUM issues with file and line references]

Options:
- **continue** — run one more review cycle (override limit)
- **skip** — accept remaining issues and mark complete
- **escalate** — keep issues documented for manual review
```

### Phase 3 – Analyze Review (ULTRATHINK)

- Read `REVIEW_FILE` fully. Parse it against the schema in `templates/review-report.md` (reviewer-identity header, severity vocabulary, section ordering) — both reviewer agents produce reports conforming to that same template, so this parsing works unchanged regardless of which agent wrote the file.
- Parse the `Reviewer:` field from the report header to set `REVIEWER_AGENT`. If the field is absent (a legacy review file predating this field), fall back to `code-reviewer` and note the fallback in `SCRATCH_FILE`.
- Parse all findings by severity: CRITICAL / HIGH / MEDIUM / LOW.
- For each finding extract: file path, line reference, description, recommended fix.
- Identify dependencies between fixes (e.g., fix A must land before fix B).
- Note complexity assessment and fix order in `SCRATCH_FILE`.

### Phase 4 – Fix Partitioning (CONFIDENCE POLICY)

Organize all actionable fixes by priority: CRITICAL → HIGH → MEDIUM → LOW. Within that order, classify each fix as **objective** or **subjective** per the Confidence Policy.

**Step 1 — Apply objective fixes immediately:**

- Apply each objective fix in severity order without asking.
- After each objective fix, re-run the relevant check once (test, lint, build, or type check) to confirm it passes.
- Record each applied fix in `SCRATCH_FILE` with the file, line, and a one-line description.

**Step 2 — Ask about subjective fixes:**

Surface the remaining subjective fixes via AskUserQuestion and **wait for explicit user approval before implementing any of them**. The question must note which objective fixes were already auto-applied:

```
## Fix Plan: [REVIEW_FILE]

### Auto-applied (objective — already done, re-verified)
1. [file:line] — [action taken] — [check re-run: pass]
...

### CRITICAL — subjective ([N] issues)
1. [file:line] — [action] — [rationale]
...

### HIGH — subjective ([N] issues)
1. [file:line] — [action] — [rationale]
...

### MEDIUM — subjective ([N] issues — fix only if straightforward)
1. [file:line] — [action] — [rationale]
...

### LOW ([N] issues — skipping)
1. [file:line] — [description]
...

Proceed with subjective fixes? (yes / adjust / cancel)
```

Do not continue to Phase 5 until the user responds with approval. If there are no subjective fixes, skip the question and continue directly to Phase 6.

### Phase 5 – Implementation

- Apply approved subjective fixes in priority order: CRITICAL first, then HIGH, then MEDIUM.
- After each fix is applied, record it in `SCRATCH_FILE` with the file, line, and a one-line description.
- MEDIUM issues: fix only if the change is straightforward (< 5 min effort); skip otherwise.
- LOW issues: skip entirely.
- If an implementation error occurs, stop immediately and surface the error clearly to the user before continuing.

### Phase 6 – Re-Review

- Spawn `REVIEWER_AGENT` (the same agent recorded in `REVIEW_FILE`'s header — falls back to `code-reviewer` only when that header was absent) on all files modified during Phase 5. Findings are re-checked by the same agent that raised them, not a different one.
- Determine the next iteration number (N+1) from the count of files currently in `REVIEWS_DIR`.
- Save the agent output as `REVIEWS_DIR/review-N+1.md`, preserving the `Reviewer: REVIEWER_AGENT` header field so a subsequent `/review-fix` cycle can read it back.

### Phase 7 – Report

Display a structured summary:

```
## Review Fix: [WORK_DIR] (Iteration [N])

**Issues addressed**: [fixed] / [total]
- CRITICAL fixed: [N]
- HIGH fixed: [N]
- MEDIUM fixed: [N]
- LOW skipped: [N]

**Re-review result**: [APPROVED / N remaining issues]

**Next step**:
[If re-review clean]       → /triage [WORK_DIR]
[If issues remain, under limit] → /review-fix [REVIEWS_DIR]/review-N+1.md
[If at iteration limit]    → Review limit reached — see escape hatch options above.
```

## Critical Rules

1. **User approval required for subjective fixes** — objective fixes are auto-applied with re-verification per the Confidence Policy; no subjective fix may be implemented before the user approves it in Phase 4.
2. **Fix order**: CRITICAL → HIGH → MEDIUM → LOW — never reorder.
3. **Never exceed 3 iterations** without explicit user override via the escape hatch.
4. **Update `SCRATCH_FILE`** after each individual fix is applied.
5. **Stop on implementation errors** — surface them clearly rather than skipping silently.
6. **Preserve existing code formatting and indentation** when applying fixes.
