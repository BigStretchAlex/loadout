---
name: review-fix
description: Address code review findings and re-review with an iteration limit
---

# Review Fix Skill

Address findings from a specific code review file and trigger a re-review. Enforces a maximum of 3 review iterations to prevent infinite loops. Objective fixes are auto-applied with re-verification; subjective fixes require explicit user approval (see Confidence Policy).

## Confidence Policy

Classify every finding or proposed fix before acting on it:

- **Objective (auto-apply)**: the fix is mechanically verifiable — a factual error, broken path, missing required field, failing command, or a direct contradiction of a rule, plan, or template. Apply it without asking, then re-run the relevant check once to confirm.
- **Subjective (ask)**: the fix is a judgment call — scope, naming, architecture, trade-offs. Surface it via AskUserQuestion; never apply it unprompted.

Never auto-apply a fix that deletes user-authored content, changes scope, or contradicts a decision recorded in `scratch.md`. When in doubt, treat the finding as subjective.

## Variables

Derived from `$ARGUMENTS` (path to a review file, e.g., `.dev/feat-auth-flow/reviews/review-2.md`):

- `REVIEW_FILE` — `$ARGUMENTS` (the review file path)
- `REVIEWS_DIR` — parent directory of `REVIEW_FILE` (e.g., `.dev/feat-auth-flow/reviews/`)
- `WORK_DIR` — parent of `REVIEWS_DIR` (e.g., `.dev/feat-auth-flow/`)
- `SCRATCH_FILE` — `WORK_DIR/scratch.md`

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

- Read `REVIEW_FILE` fully.
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

- Spawn the `code-reviewer` agent on all files modified during Phase 5.
- Determine the next iteration number (N+1) from the count of files currently in `REVIEWS_DIR`.
- Save the agent output as `REVIEWS_DIR/review-N+1.md`.

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

## Examples

### Example 1 — Standard single-pass fix

**Invocation:**
```
/review-fix .dev/feat-checkout-flow/reviews/review-1.md
```

**Phase 3 output (internal):**
Parsed 8 findings: 3 CRITICAL, 2 HIGH, 2 MEDIUM, 1 LOW.

**Phase 4, Step 1 (objective fixes auto-applied, in severity order):**
All 3 CRITICAL findings and MEDIUM #2 are objective — each is mechanically verifiable (failing security/lint checks, unhandled exception covered by tests). Applied immediately without asking, each re-verified once, SCRATCH_FILE updated after each fix.

**Phase 4, Step 2 (AskUserQuestion for subjective fixes):**
```
## Fix Plan: .dev/feat-checkout-flow/reviews/review-1.md

### Auto-applied (objective — already done, re-verified)
1. src/checkout/payment.ts:42 — Removed hardcoded API key, now loaded from env — checkout test suite re-run: pass
2. src/checkout/cart.ts:118 — Added input validation before DB query — checkout test suite re-run: pass
3. src/checkout/order.ts:87 — Wrapped DB write in try/catch with rollback — order tests re-run: pass
4. src/checkout/payment.ts:9 — Sorted imports alphabetically — lint re-run: pass

### HIGH — subjective (2 issues)
1. src/checkout/payment.ts:71 — Extract magic number 0.15 to named constant TAX_RATE — naming judgment call
2. src/checkout/cart.ts:203 — Remove duplicate items-fetch logic, reuse existing getCartItems() — refactor judgment call

### MEDIUM — subjective (1 issue — fix only if straightforward)
1. src/checkout/order.ts:14 — Add JSDoc to createOrder() — documentation

### LOW (1 issue — skipping)
1. src/checkout/cart.ts:55 — Consider renaming `d` to `discount` — readability

Proceed with subjective fixes? (yes / adjust / cancel)
```

**User responds:** `yes to both HIGH fixes; skip the JSDoc`

**Phase 5:** Both HIGH subjective fixes applied. MEDIUM #1 skipped per user. SCRATCH_FILE updated after each fix.

**Phase 6:** `code-reviewer` agent spawned on 3 modified files. Output saved as `.dev/feat-checkout-flow/reviews/review-2.md`.

**Phase 7 report:**
```
## Review Fix: .dev/feat-checkout-flow/ (Iteration 1)

**Issues addressed**: 6 / 8
- CRITICAL fixed: 3
- HIGH fixed: 2
- MEDIUM fixed: 1
- LOW skipped: 1

**Re-review result**: APPROVED — no remaining issues

**Next step**: /triage .dev/feat-checkout-flow/
```

---

### Example 2 — Iteration limit escape hatch

**Invocation:**
```
/review-fix .dev/feat-auth-flow/reviews/review-3.md
```

**Phase 2:** `.dev/feat-auth-flow/reviews/` already contains `review-1.md`, `review-2.md`, `review-3.md` — 3 files, limit reached.

**Output shown to user:**
```
## Review Limit Reached

3 review iterations completed for .dev/feat-auth-flow/.

Remaining issues from .dev/feat-auth-flow/reviews/review-3.md:

CRITICAL (1)
- src/auth/token.ts:34 — JWT secret falls back to hardcoded string when env var is missing

HIGH (2)
- src/auth/session.ts:102 — Session not invalidated on password change
- src/auth/login.ts:67 — Brute-force protection missing on /login endpoint

MEDIUM (1)
- src/auth/middleware.ts:88 — Error message leaks internal stack trace to client

Options:
- **continue** — run one more review cycle (override limit)
- **skip** — accept remaining issues and mark complete
- **escalate** — keep issues documented for manual review
```

Skill pauses and waits for user input before taking any further action.
