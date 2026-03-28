---
description: Promote scratch memory insights to .ai-docs/ knowledge base
argument-hint: <scratch-dir>
allowed-tools: Read, Grep, Glob, Task, TodoWrite, Write, Bash
model: sonnet
---

# Triage Skill

Review scratch memory from a work item directory and promote valuable insights to the `.ai-docs/` knowledge base using the `document-writer` agent.

## Instructions

### No-arg fallback

If "$ARGUMENTS" is empty or blank:
1. Scan `.dev/` for all `scratch.md` files (e.g., `.dev/*/scratch.md` and `.dev/scratch.md`)
2. For each file, check whether it contains `<!-- triaged:` — if yes, skip it
3. Report the un-triaged files with line counts, numbered:
   ```
   Found N un-triaged scratch files:
   1. .dev/feat-payments/scratch.md (62 lines)
   2. .dev/scratch.md (11 lines)

   Which would you like to triage? (Reply with a number or a path)
   ```
4. Wait for user reply, then treat their answer as the directory path and proceed through Phases 1–5

---

### Phase 1 – Discovery & Validation

**Resolve scratch file:**
- Argument is a directory path (e.g., `.dev/feat-auth-flow/`)
- Scratch file = `<dir>/scratch.md`
- If the file doesn't exist or is empty → report error and stop

**Check for prior triage:**
- If scratch file contains `<!-- triaged:` → warn the user and ask to confirm before re-triaging

**Check `.ai-docs/` exists:**
- If `.ai-docs/` directory does not exist → suggest running `/init-docs` first and stop

Proceed immediately to Phase 2 — no confirmation needed.

---

### Phase 2 – Content Analysis

1. Read the scratch file
2. Scan for distinct patterns, decisions, heuristics, and reusable insights — including both general patterns (applicable across projects) and codebase-specific patterns (conventions, architectural decisions, or domain knowledge unique to this repo)
3. Apply quality threshold (default: **medium**) — filter out items that are incomplete, one-off hacks, or noise; retain both general and codebase-specific insights
4. Report the estimated count before spawning the agent:
   ```
   Found N promotable insights. Spawning document-writer...
   ```

---

### Phase 3 – Knowledge Extraction & Document Update

Spawn the `document-writer` agent with this prompt (fill in the bracketed values):

> You are extracting reusable knowledge from a scratch memory file and writing it to the `.ai-docs/` knowledge base.
>
> **Scratch file:** `[path to scratch.md]`
> **Quality threshold:** medium
> **Existing `.ai-docs/` files:** [list each file path, one per line]
>
> Instructions:
> 1. Read the scratch file and identify all reusable patterns, decisions, and heuristics that meet the quality threshold — including both general patterns (applicable across projects) and codebase-specific patterns (conventions, architectural choices, or domain knowledge specific to this repo). Do not discard an insight solely because it is codebase-specific; document it under the appropriate `.ai-docs/` file so future work in this repo can benefit.
> 2. For each insight, decide whether to append to an existing `.ai-docs/` file or create a new one — prefer merging into existing files when the topic matches.
> 3. Write or update `.ai-docs/` files directly. Use a two-pass approach:
>    - First pass: write content with `-1` as placeholder line numbers in frontmatter section references
>    - Second pass: re-read each written file, compute the actual line numbers, and replace `-1` placeholders
> 4. Return a summary of what was promoted and what was skipped (with reasons).

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

### Phase 5 – Report & Mark Triaged

1. Append the triage marker to the scratch file:
   ```
   <!-- triaged: YYYY-MM-DD -->
   ```
   Use today's actual date.

2. Print the final report:
   ```
   ## Triage Complete: [dir]

   **Insights reviewed**: N
   **Promoted to .ai-docs/**: N
   **Skipped**: N

   ### Promoted
   - [pattern name] → [target document]

   ### Skipped
   - [insight]: [reason]

   Scratch file marked as triaged.
   ```

---

## Examples

### Example 1: Triage a feature work item

**User invokes:**
```
/triage .dev/feat-auth-flow/
```

**Phase 1 – Discovery & Validation**

Skill resolves `.dev/feat-auth-flow/scratch.md`. File exists (48 lines), no prior-triage marker. `.ai-docs/` exists with 3 files (`auth.md`, `api-patterns.md`, `testing.md`). Proceeds immediately to Phase 2.

**Phase 2 – Content Analysis**

Skill reads scratch file, identifies 3 candidate patterns:
- JWT refresh token rotation strategy
- Redis TTL heuristic for session caching
- Middleware ordering for auth + rate-limit

Quality threshold: medium. All 3 pass — the JWT and middleware patterns are general; the Redis TTL heuristic is codebase-specific (this repo uses a 15-minute session window) but valuable for future work here.

Output:
```
Found 3 promotable insights. Spawning document-writer...
```

**Phase 3 – Knowledge Extraction & Document Update**

Skill spawns `document-writer` with the scratch path, threshold `medium`, and the list of existing `.ai-docs/` files.

Agent actions:
- Detects JWT refresh and middleware patterns belong in existing `auth.md` — appends two new sections
- Creates `.ai-docs/caching.md` for the Redis TTL heuristic
- Runs two-pass line number update on both modified files
- Returns summary: promoted 3 patterns across 2 documents

**Phase 4 – Review Agent Output**

Skill displays:
```
Promoted 3 patterns, skipped 0.

Promoted:
- JWT refresh token rotation → .ai-docs/auth.md
- Auth + rate-limit middleware ordering → .ai-docs/auth.md
- Redis TTL heuristic for sessions → .ai-docs/caching.md (new)
```

**Phase 5 – Report & Mark Triaged**

Skill appends `<!-- triaged: 2026-03-28 -->` to the scratch file and prints:
```
## Triage Complete: .dev/feat-auth-flow/

**Insights reviewed**: 3
**Promoted to .ai-docs/**: 3
**Skipped**: 0

### Promoted
- JWT refresh token rotation → .ai-docs/auth.md
- Auth + rate-limit middleware ordering → .ai-docs/auth.md
- Redis TTL heuristic for sessions → .ai-docs/caching.md (new)

Scratch file marked as triaged.
```

---

### Example 2: No arguments — discover un-triaged scratch files

**User invokes:**
```
/triage
```

**No-arg fallback**

Skill scans `.dev/` for `scratch.md` files. Finds three:
- `.dev/feat-auth-flow/scratch.md` — contains `<!-- triaged: 2026-03-28 -->`, skip
- `.dev/feat-payments/scratch.md` — no marker, 62 lines
- `.dev/scratch.md` — no marker, 11 lines

Output:
```
Found 2 un-triaged scratch files:
1. .dev/feat-payments/scratch.md (62 lines)
2. .dev/scratch.md (11 lines)

Which would you like to triage? (Reply with a number or a path)
```

User replies `1`. Skill sets dir to `.dev/feat-payments/` and proceeds through Phases 1–5.

**Phase 1**: Resolves `.dev/feat-payments/scratch.md`. 62 lines, no prior-triage marker. `.ai-docs/` exists. Proceeds immediately.

**Phase 2**: Scans content. Identifies 3 promotable insights (Stripe idempotency key pattern, webhook retry backoff strategy, and this repo's Stripe customer-ID naming convention). 0 skipped — all pass medium threshold. Reports: "Found 3 promotable insights. Spawning document-writer..."

**Phase 3**: Spawns `document-writer`. Agent creates `.ai-docs/payments.md` with all three patterns and runs two-pass line number resolution.

**Phase 4**: Displays:
```
Promoted 3 patterns, skipped 0.

Promoted:
- Stripe idempotency key usage → .ai-docs/payments.md (new)
- Webhook retry backoff strategy → .ai-docs/payments.md (new)
- Stripe customer-ID naming convention (codebase-specific) → .ai-docs/payments.md (new)
```

**Phase 5**: Appends `<!-- triaged: 2026-03-28 -->` to `.dev/feat-payments/scratch.md` and prints:
```
## Triage Complete: .dev/feat-payments/

**Insights reviewed**: 3
**Promoted to .ai-docs/**: 3
**Skipped**: 0

### Promoted
- Stripe idempotency key usage → .ai-docs/payments.md (new)
- Webhook retry backoff strategy → .ai-docs/payments.md (new)
- Stripe customer-ID naming convention (codebase-specific) → .ai-docs/payments.md (new)

Scratch file marked as triaged.
```
