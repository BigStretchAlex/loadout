# Review Report Contract

The shared output contract for `code-reviewer` and `typescript-reviewer`, and the report shape `skills/review/SKILL.md` writes to `<dir>/reviews/review-N.md` and `skills/review-fix/SKILL.md` parses back.

## Reviewer identity header

Every review report file begins with a header field naming the agent that produced it:

```markdown
**Reviewer:** [code-reviewer | typescript-reviewer]
```

`review-fix` reads this field back to re-spawn the **same** reviewer agent for re-review, falling back to `code-reviewer` only when the field is absent (a legacy review file predating this convention).

## Severity Levels

| Severity | Criteria | Action |
|----------|----------|--------|
| **CRITICAL** | Security vulnerabilities, data loss risks, breaking changes | Must fix before merge |
| **HIGH** | Bugs, missing error handling, no tests for critical paths | Should fix before merge |
| **MEDIUM** | Best practice violations, complexity, missing docs | Fix soon |
| **LOW** | Style, naming, minor optimizations | Nice to have |
| **AI SLOP** | Unnecessary comments, premature abstractions, over-engineering | Fix in cleanup pass |

## Verdict values

- **APPROVED** — no CRITICAL or HIGH issues remain (after any exclusions).
- **CHANGES REQUIRED** — at least one CRITICAL or HIGH issue remains.

## Output Format (agent body)

Both reviewer agents produce exactly this shape — this is what a reviewer agent returns; the consuming `review` skill wraps it with the reviewer-identity header, `## Review Status`, and its own Excluded Issues / Security Analysis / Test Coverage / Best Practice Violations sections.

```markdown
### Executive Summary
- Files reviewed: [count]
- Issues: [CRITICAL: N, HIGH: N, MEDIUM: N, LOW: N, AI Slop: N]
- Overall: [1-2 sentence assessment]

### Findings by File

**File**: `[path]`

1. **[SEVERITY]**: [Title]
   - **Line**: [number or range]
   - **Description**: [What's wrong and why it matters]
   - **Recommendation**: [How to fix]
   - **Reference**: [.ai-docs pattern if applicable]

#### AI Slop Findings

[List AI slop issues for this file, or omit section if none]

### Recommendations by Priority

**Must fix (Critical/High):**
- [List]

**Should fix (Medium / AI Slop):**
- [List]

**Nice to have (Low):**
- [List]
```

## Handoff footer

Schema defined in `templates/handoff-footer.md`. `skills/review/SKILL.md`'s report-writing step appends
this to the report file it writes at `<dir>/reviews/review-N.md` — after the reviewer-identity header and
every other section, never inside them. It does not belong to the reviewer *agent's* output shape above;
the wrapping skill adds it once, at write time.

`next_command`/`next_arguments` are filled in from the verdict→route mapping the approval-status and
routing steps already compute (the mapping appears exactly once in `skills/review/SKILL.md` — the footer
is a second representation of that decision, not a second copy of the mapping). When `<dir>` is not a
work item and the route is deliberately suppressed, `next_command: none` — never a fabricated suggestion.

```loadout-handoff
schema: 1
artifact: review-report
produced_by: /review
work_item: .dev/<slug>
lane: standard | tdd | express
verification: pass | fail
next_command: /review-fix | /triage | none
next_arguments: <dir>
```
