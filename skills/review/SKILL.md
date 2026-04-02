---
name: review
description: Perform comprehensive code review of recent changes, analyzing quality, security, and test coverage
argument-hint: "[dir | file1,file2,...] [--include-all] [--clear-exclusions]"
Allowed-tools: Read, Task, Glob, Bash, TodoWrite, Write
model: sonnet
---

# Review Skill

Perform a comprehensive code review with domain categorization, interactive issue selection, persistent exclusions, and round tracking.

## Instructions

### Step 1: Parse Arguments & Flags

Parse `$ARGUMENTS` for the following flags:
- `--include-all` → skip interactive issue selection, include all issues
- `--clear-exclusions` → delete `<dir>/.review-exclusions.json` before starting

After extracting flags, inspect the remaining argument:
- **Directory path** (e.g., `.dev/feat-auth-flow`, `src/`, `./my-feature`): treat as `<dir>` — the working directory for this review. Storage files (exclusions, reports) live inside it.
- **Comma-separated file paths** (e.g., `src/auth.ts,src/login.tsx`): treat as an explicit file list. No persistent storage; output goes to stdout only.
- **No argument**: auto-detect from git status.

### Step 2: Determine Review Mode & Discover Files

Three modes:

**Mode A — Directory provided:**
1. Verify the directory exists; if not, suggest alternatives:
   ```
   Directory <dir> not found. Did you mean one of:
     [list sibling directories]
   ```
2. Look for `<dir>/plan.md` — if found, extract file paths from its file list section
3. If no plan.md or no file list, fall back to `git diff --name-only origin/HEAD...HEAD` (branch diff) or `git diff --name-only` (unstaged)
4. If still no files, try `git status --short` to find modified/untracked files

**Mode B — Comma-separated file list:**
- Split the comma-separated file paths directly
- No `<dir>`; round is always 1 and output goes to stdout only

**Mode C — No args:**
- Run `git status --short` to find all modified/untracked files
- Run `git diff --name-only HEAD` to catch staged/unstaged changes
- Combine and deduplicate
- No `<dir>`; round is always 1 and output goes to stdout only

**Error handling:**
- No files found → display usage and exit:
  ```
  No files to review. Usage:
    /review <dir>                Review files in a directory (uses plan.md if present)
    /review file1.ts,file2.ts   Review specific files
    /review                     Auto-detect uncommitted changes
  ```

### Step 3: Categorize Files by Domain

Group files by path pattern:

| Domain | Pattern |
|--------|---------|
| **backend** | `src/`, `api/`, `server/`, `lib/`, `services/`, `models/`, `routes/`, `controllers/`, `middleware/` |
| **frontend** | `components/`, `pages/`, `views/`, `ui/`, `app/`, `public/`, `styles/`, `hooks/`, `stores/` |
| **test** | `__tests__/`, `.test.`, `.spec.`, `tests/`, `test/`, `e2e/`, `cypress/`, `jest/` |
| **config** | `*.config.*`, `.env`, `Dockerfile`, `docker-compose`, `*.yml`, `*.yaml`, `*.toml`, `*.json` (root level), `scripts/` |
| **general** | anything else |

Display the categorization before spawning the agent.

### Step 4: Handle `--clear-exclusions`

If `--clear-exclusions` was passed and `<dir>/.review-exclusions.json` exists, delete it. Notify: `Cleared previous exclusions.`

### Step 5: Set Up Reviews Directory & Determine Round

- If a `<dir>` is present, create `<dir>/reviews/` if it doesn't exist
- Count existing `review-*.md` files in that directory to determine round N (start at 1)
- If no `<dir>`, round is always 1 and output goes to stdout only

### Step 6: Spawn `code-reviewer` Agent

Use the Task tool to spawn the `code-reviewer` agent. Pass:
- The full file list
- The domain breakdown (backend/frontend/test/config/general)
- If this is round N > 1, include: `This is review round [N]. Prior reviews exist at <dir>/reviews/.`
- Explicit instruction to include the AI Slop Detection section in the report

Collect the full review output.

**Error handling:** If the agent returns an error or empty output, display:
```
Review agent failed. Check that the files exist and are readable.
Details: [error]
```

### Step 7: Interactive Issue Selection (skip if `--include-all`)

**If `--include-all` is set:** skip this step entirely — all issues are included.

**Otherwise:**

1. Parse all issues from the agent's output by severity: CRITICAL, HIGH, MEDIUM, LOW, AI SLOP
2. Load `<dir>/.review-exclusions.json` if it exists (structure: `{ "excluded": [{ "id": "...", "title": "...", "reason": "...", "round": N }] }`)
3. **CRITICAL issues**: always included, never shown for exclusion. Notify: `[N] CRITICAL issues are always included.`
4. For HIGH, MEDIUM, LOW, AI SLOP issues: use `AskUserQuestion` with `multiSelect: true` to let the user choose which ones to **exclude** from the report.
   - Show issues grouped by severity, highest first
   - Label each option clearly: `[HIGH] AuthService:42 — Missing input validation`
   - Pre-deselect any issues already in `.review-exclusions.json`
   - Prompt: `Select issues to EXCLUDE from this review (CRITICAL issues are always included):`
5. Save excluded issues back to `<dir>/.review-exclusions.json`:
   ```json
   {
     "excluded": [
       { "id": "<hash-or-title>", "title": "...", "severity": "HIGH", "round": N, "file": "..." }
     ]
   }
   ```

### Step 8: Calculate Approval Status

Based on the **included** issues (after exclusions):
- Any CRITICAL or HIGH issue → **CHANGES REQUIRED**
- Only MEDIUM, LOW, or AI SLOP issues (or none) → **APPROVED**

### Step 9: Generate Report

Write the report to `<dir>/reviews/review-[N].md` (or display inline if no `<dir>`).

Report structure:

```markdown
# Code Review — Round [N]: [dir]

## Review Status

> **[APPROVED ✓ | CHANGES REQUIRED ✗]**

## Executive Summary

- **Files reviewed**: [N]
- **Issues found**: CRITICAL: [N], HIGH: [N], MEDIUM: [N], LOW: [N], AI Slop: [N]
- **Issues included**: [N] (excluded: [N])
- **Domains**: [backend, frontend, test, ...]
- **Overall**: [1–2 sentence assessment]

## Excluded Issues

[If any exclusions]
The following issues were excluded from this review round:
- [SEVERITY] `file:line` — [title]

[If none]
No issues excluded.

## Findings

### Critical Issues
[List or "None"]

### High Issues
[List or "None"]

### Medium Issues
[List or "None"]

### Low Issues
[List or "None"]

### AI Slop Findings
[List or "None"]

## Security Analysis

[From agent output]

## Test Coverage

[From agent output]

## Best Practice Violations

[From agent output]

## Recommendations

### Must fix (Critical/High)
[List]

### Should fix (Medium / AI Slop)
[List]

### Nice to have (Low)
[List]
```

### Step 10: Display Summary

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

Then suggest next steps:
- If CHANGES REQUIRED: `Next step: /review-fix <dir>`
- If APPROVED: `Next step: /review-fix <dir>`

---

## Examples

### Example 1: Review a work item directory

**Input:** `/review .dev/feat-auth-flow`

**Execution:**

```
Files discovered from .dev/feat-auth-flow/plan.md:
  src/auth/AuthService.ts
  src/auth/middleware/jwtGuard.ts
  src/auth/routes/login.ts
  src/auth/__tests__/AuthService.test.ts
  frontend/src/pages/Login.tsx

Domain breakdown:
  backend  → src/auth/AuthService.ts, src/auth/middleware/jwtGuard.ts, src/auth/routes/login.ts
  test     → src/auth/__tests__/AuthService.test.ts
  frontend → frontend/src/pages/Login.tsx

Spawning code-reviewer agent...
```

> [Interactive multiselect prompt]
> `2 CRITICAL issues are always included.`
> Select issues to EXCLUDE from this review (CRITICAL issues are always included):
> - [HIGH] src/auth/routes/login.ts:34 — No rate limiting on login endpoint
> - [HIGH] src/auth/middleware/jwtGuard.ts:18 — JWT secret falls back to hardcoded string
> - [MEDIUM] frontend/src/pages/Login.tsx:61 — Missing loading state on submit button
> - [LOW] src/auth/AuthService.ts:102 — Unused import `bcryptjs`

_(User excludes the LOW issue)_

```
Saved exclusions to .dev/feat-auth-flow/.review-exclusions.json

## Review Round 1 Complete

Status: CHANGES REQUIRED ✗

Issues:
  CRITICAL : 2
  HIGH     : 2
  MEDIUM   : 1
  LOW      : 0
  AI SLOP  : 0
  Excluded : 1

Report saved: .dev/feat-auth-flow/reviews/review-1.md

Next step: /review-fix .dev/feat-auth-flow
```

---

### Example 2: Auto-detect uncommitted changes

**Input:** `/review --include-all`

**Execution:**

```
Detecting uncommitted changes...
  M  src/payments/stripe.ts
  M  src/payments/webhook.ts
  ?? src/payments/__tests__/stripe.test.ts

Domain breakdown:
  backend → src/payments/stripe.ts, src/payments/webhook.ts
  test    → src/payments/__tests__/stripe.test.ts

Spawning code-reviewer agent...
--include-all set: skipping interactive issue selection.

## Review Round 1 Complete

Status: APPROVED ✓

Issues:
  CRITICAL : 0
  HIGH     : 0
  MEDIUM   : 2
  LOW      : 3
  AI SLOP  : 1
  Excluded : 0

(No <dir> provided — report displayed inline above)

Next step: /review-fix
```
