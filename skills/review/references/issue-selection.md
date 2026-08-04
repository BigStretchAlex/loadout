# Interactive Issue Selection Mechanics

Detail for Step 3 (Interactive Issue Selection). Only relevant when `--include-all` was not
passed.

1. Parse all issues from Step 2's returned result by severity: CRITICAL, HIGH, MEDIUM, LOW, AI SLOP
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
