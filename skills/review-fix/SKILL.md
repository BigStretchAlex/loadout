---
name: review-fix
description: Address code review findings and re-review with an iteration limit
---

# Review Fix Skill

Address findings from a specific code review file and trigger a re-review. Enforces a maximum of 3 review iterations to prevent infinite loops. Requires explicit user approval before applying any fixes.

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

### Phase 4 – Fix Planning (USER APPROVAL REQUIRED)

Organize all actionable fixes by priority: CRITICAL → HIGH → MEDIUM → LOW.

Display the following fix plan and **wait for explicit user approval before implementing anything**:

```
## Fix Plan: [REVIEW_FILE]

### CRITICAL ([N] issues)
1. [file:line] — [action] — [rationale]
...

### HIGH ([N] issues)
1. [file:line] — [action] — [rationale]
...

### MEDIUM ([N] issues — fix only if straightforward)
1. [file:line] — [action] — [rationale]
...

### LOW ([N] issues — skipping)
1. [file:line] — [description]
...

Proceed with implementation? (yes / adjust / cancel)
```

Do not continue to Phase 5 until the user responds with approval.

### Phase 5 – Implementation

- Apply fixes in priority order: CRITICAL first, then HIGH, then MEDIUM.
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

1. **User approval required** after Phase 4 before any code is modified.
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

**Phase 4 output (shown to user, awaiting approval):**
```
## Fix Plan: .dev/feat-checkout-flow/reviews/review-1.md

### CRITICAL (3 issues)
1. src/checkout/payment.ts:42 — Remove hardcoded API key, load from env — security: credential exposure
2. src/checkout/cart.ts:118 — Add input validation before passing to DB query — security: SQL injection risk
3. src/checkout/order.ts:87 — Wrap DB write in try/catch and rollback on failure — reliability: unhandled exception

### HIGH (2 issues)
1. src/checkout/payment.ts:71 — Extract magic number 0.15 to named constant TAX_RATE — maintainability
2. src/checkout/cart.ts:203 — Remove duplicate items-fetch logic, reuse existing getCartItems() — duplication

### MEDIUM (2 issues — fix only if straightforward)
1. src/checkout/order.ts:14 — Add JSDoc to createOrder() — documentation
2. src/checkout/payment.ts:9 — Sort imports alphabetically — style

### LOW (1 issue — skipping)
1. src/checkout/cart.ts:55 — Consider renaming `d` to `discount` — readability

Proceed with implementation? (yes / adjust / cancel)
```

**User responds:** `yes`

**Phase 5:** All 3 CRITICAL and 2 HIGH fixes applied. MEDIUM #1 applied (trivial). MEDIUM #2 skipped (style-only, borderline). SCRATCH_FILE updated after each fix.

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
