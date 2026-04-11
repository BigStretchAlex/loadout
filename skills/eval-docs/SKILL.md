---
name: eval-docs
description: Evaluate .ai-docs/ files for structural quality, content quality, and frontmatter accuracy, then offer to implement improvements. Use whenever the user wants to audit their knowledge base, check if docs are too large or too broad, verify patterns match content, improve frontmatter discoverability, or identify content gaps. Trigger on: "evaluate my docs", "check doc quality", "review ai-docs", "improve my docs", "are my docs good", "check if my frontmatter is right", "clean up my knowledge base", "review knowledge base".
allowed-tools: Read, Write, Bash(wc:*), Bash(rm:*)
model: sonnet
argument-hint: "[doc-name or domain to scope, or leave blank for all]"
---

# Eval Docs Skill

Audit `.ai-docs/` for structural and content quality, then interactively apply approved improvements.

## Phase 1 — Preflight

1. Check if `.ai-docs/` exists. If not, tell the user to run `/init-docs` first and stop.
2. If `$ARGUMENTS` is set, note the scope (specific doc name or domain). Otherwise scope is all files.

## Phase 2 & 3 — Parallel Audit

Spawn both agents **in the same turn** (parallel):

**Agent: `doc-reviewer`**
> Review all .ai-docs/ files for size and topic bloat. Flag files over 300 lines or with more than 5 sections or patterns spanning unrelated domains. Propose concrete splits.

**Agent: `doc-content-reviewer`**
> Evaluate all .ai-docs/ files for content quality and frontmatter accuracy. For each file: check if patterns/keywords match the actual content, identify missing patterns, flag incorrect domain assignments, note content gaps (patterns without examples or rationale), and check section summary accuracy.

If `$ARGUMENTS` is set, pass it as scope context to both agents.

## Phase 4 — Present Consolidated Findings

Merge both reports and present to the user in this structure:

```
## Eval Docs Findings

### Structural Issues (from doc-reviewer)
[size/topic findings and split proposals, or "None"]

### Content & Frontmatter Issues (from doc-content-reviewer)
[frontmatter gaps, domain mismatches, content gaps, or "None"]

### Clean Files
[files that passed both reviews]
```

Ask the user which improvements they want to apply. Present the options clearly — list each proposed change and ask for approval before proceeding.

## Phase 5 — Interactive Remediation

For each change the user approves, apply it:

**Approved splits** — spawn `document-writer`:
> The file `.ai-docs/<filename>.md` needs to be split. Here is the split strategy from the structural review: [paste split proposal]. Read the file, create the focused child files with correct frontmatter, then delete the original.

**Frontmatter fixes** (missing patterns, wrong domain, inaccurate summaries) — apply directly using Read + Write:
1. Read the file
2. Edit only the frontmatter block (between the `---` delimiters)
3. Add missing patterns/keywords, correct the domain field, rewrite inaccurate section summaries
4. Write the file back — do not touch the body content

**Content improvements** (missing examples, rationale gaps) — spawn `document-writer`:
> Enrich the file `.ai-docs/<filename>.md`. Specific instructions: [list the content gaps identified by doc-content-reviewer — e.g., "add a code example for pattern X in section Y", "add rationale for the Z approach"]. Read the existing file and edit only the sections that need improvement.

Apply changes one at a time and confirm each with the user before proceeding to the next if the user has not given blanket approval.

## Phase 6 — Summary

After all approved changes are applied:

```
## Eval Docs Complete

**Docs reviewed**: N
**Structural issues found**: N
**Content/frontmatter issues found**: N
**Changes applied**: N

**Modified**:
- [filename.md] — [what changed]

**Unchanged**:
- [filename.md]
```
