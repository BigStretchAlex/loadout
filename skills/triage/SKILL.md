---
name: triage
description: Promote scratch memory insights to .ai-docs/ knowledge base
disable-model-invocation: true
argument-hint: "<scratch-dir>"
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

This skill does not perform the setup flow in `templates/work-item.md` — it derives no slug, creates no `.dev/<slug>/` directory, and initializes no `scratch.md`. It operates only on an existing work item's `scratch.md`, produced earlier by another skill; if that file or directory is missing, triage stops (above) rather than creating it.

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

### Phase 5 – Verify Written Line Ranges (self-check)

Run the shared check in `templates/line-range-verification.md` against every `.ai-docs/` file the agent reported as promoted-to or updated (from Phase 4's list). Do not write the `<!-- triaged: -->` marker until it reports PASS.

---

### Phase 6 – Report & Mark Triaged

Only after Phase 5 reports PASS:

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
   **Line-range verification**: PASS

   ### Promoted
   - [pattern name] → [target document]

   ### Skipped
   - [insight]: [reason]

   Scratch file marked as triaged.
   ```

