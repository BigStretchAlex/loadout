---
name: eval-docs
description: Evaluate .ai-docs/ files for structural quality, content quality, and frontmatter accuracy, then offer to implement improvements.
disable-model-invocation: true
allowed-tools: Bash(ls:*), Task
model: sonnet
argument-hint: "[doc-name or domain to scope, or leave blank for all]"
---

# Eval Docs Skill

Audit `.ai-docs/` for structural and content quality, then auto-apply objective fixes and interactively apply approved subjective improvements.

## Confidence Policy

Follow the Confidence Policy in `templates/confidence-policy.md` — classify every finding or proposed fix as objective (auto-apply) or subjective (ask) before acting on it.

For this skill the split is concrete:

- **Objective**: missing required frontmatter fields (`task_triggers`, `domain`, `patterns`, `keywords`), invalid `task_triggers` values, wrong line ranges in section references, inaccurate section summaries → auto-fix by routing to `document-writer`, then re-check that finding once.
- **Subjective**: doc splits, content enrichment (missing examples, rationale gaps), restructuring → existing user-approval flow.
- **Keyword coverage** (missing abbreviations/synonyms in an *existing* `keywords[]` field, per `templates/ai-docs-frontmatter-standard.md:200`) is **subjective**, not objective. A *missing field* is unambiguous (objective); *insufficient coverage of a field the author already curated* is a judgement call about which synonyms matter — auto-appending speculative terms would degrade the author-curated closed vocabulary that makes exact matching work (§5.3). Present the suggested terms and route through the existing user-approval flow, listed individually so the user can accept or reject term by term.

## Phase 1 — Preflight

1. Check if `.ai-docs/` exists. If not, tell the user to run `/init-docs` first and stop.
2. If `$ARGUMENTS` is set, note the scope (specific doc name or domain). Otherwise scope is all files.

## Phase 2 & 3 — Parallel Audit

Spawn both agents **in the same turn** (parallel):

**Agent: `doc-reviewer`**
> Review all .ai-docs/ files for size and topic bloat. Flag files over 300 lines or with more than 5 sections or patterns spanning unrelated domains. Propose concrete splits.

**Agent: `doc-content-reviewer`**
> Evaluate all .ai-docs/ files for content quality and frontmatter accuracy. For each file: check if patterns/keywords match the actual content, identify missing patterns, flag incorrect domain assignments, note content gaps (patterns without examples or rationale), check section summary accuracy, and verify that all `task_triggers` values are from the canonical list in `templates/ai-docs-frontmatter-standard.md` — flag missing `task_triggers`, `domain`, `patterns`, and `keywords` fields as **required additions** (not optional), and flag any unknown trigger values as frontmatter issues. Also check **keyword coverage**: for every pattern and every significant body term, confirm the abbreviation and the common synonym are present in `keywords[]` per `templates/ai-docs-frontmatter-standard.md:200`. Name concrete missing terms (e.g. pattern "oauth-integration" present but keyword "oauth" absent) — not a generic "add more keywords" note.

If `$ARGUMENTS` is set, pass it as scope context to both agents.

## Phase 4 — Present Consolidated Findings

Merge both reports and present to the user in this structure:

```
## Eval Docs Findings

### Structural Issues (from doc-reviewer)
[size/topic findings and split proposals, or "None"]

### Content & Frontmatter Issues (from doc-content-reviewer)
[frontmatter gaps, domain mismatches, content gaps, invalid/missing task_trigger values, or "None"]

### Keyword Coverage (from doc-content-reviewer)
[concrete missing abbreviations/synonyms — each naming the term and the pattern/body concept it would make findable — or "None"]

### Clean Files
[files that passed both reviews]
```

Partition the findings per the Confidence Policy: frontmatter and accuracy issues (missing required fields, invalid `task_triggers`, wrong line ranges, inaccurate section summaries) are **objective** and will be auto-fixed; splits, content enrichment, restructuring, and **keyword coverage** (missing abbreviations/synonyms in an existing `keywords[]` field) are **subjective**. When presenting the findings, mark which changes will be auto-applied. Then ask the user which of the **subjective** improvements they want to apply — list each proposed subjective change clearly and ask for approval before proceeding, and for keyword-coverage findings list each suggested term individually so the user can accept or reject term by term. Do not ask about objective fixes.

## Phase 5 — Remediation

**Objective fixes first — apply without asking.**

**Frontmatter fixes** (missing patterns, wrong domain, wrong line ranges, inaccurate summaries, invalid/missing task_triggers) — spawn `document-writer` immediately, no approval needed:
> Fix the frontmatter of `.ai-docs/<filename>.md`. Read the file and edit only the frontmatter block (between the `---` delimiters). Apply these specific fixes: [list the frontmatter issues identified by doc-content-reviewer]. Rules:
> - Add missing patterns/keywords, correct the domain field, correct wrong section line ranges, rewrite inaccurate section summaries
> - For invalid `task_triggers`: replace unknown values with the nearest canonical trigger from `templates/ai-docs-frontmatter-standard.md`
> - For missing `task_triggers`: **required** — add the field with 1-3 appropriate values from the canonical list
> - For missing `domain`: **required** — add the field with the most appropriate domain value
> - For missing `patterns` or `keywords`: **required** — add the fields with values that accurately reflect the file's content
> - Do not touch the body content

After `document-writer` returns for an objective fix, re-check that finding once: re-read the file's frontmatter and confirm the required fields are present, all `task_triggers` values are canonical, line ranges match the file, and section summaries are accurate. If the re-check fails, surface it to the user instead of retrying silently.

**Subjective fixes — only those the user approved in Phase 4.**

**Approved splits** — spawn `document-writer`:
> The file `.ai-docs/<filename>.md` needs to be split. Here is the split strategy from the structural review: [paste split proposal]. Read the file, create the focused child files with correct frontmatter, then delete the original.

**Approved content improvements** (missing examples, rationale gaps) — spawn `document-writer`:
> Enrich the file `.ai-docs/<filename>.md`. Specific instructions: [list the content gaps identified by doc-content-reviewer — e.g., "add a code example for pattern X in section Y", "add rationale for the Z approach"]. Read the existing file and edit only the sections that need improvement.

**Approved keyword-coverage additions** (missing abbreviations/synonyms, user-approved term by term) — spawn `document-writer`:
> Add keywords to `.ai-docs/<filename>.md`. Read the file and edit only the `keywords[]` array in the frontmatter block. Add exactly these user-approved terms, and no others: [list only the specific terms the user accepted, each with the pattern/concept it makes findable — e.g., "oauth" (bare abbreviation for pattern "oauth-integration"), "jwt" (bare abbreviation for pattern "jwt-authentication")]. Do not add any term the user did not approve. Do not touch `patterns[]`, `topics[]`, or body content.

Apply subjective changes one at a time and confirm each with the user before proceeding to the next if the user has not given blanket approval.

## Phase 6 — Summary

After all approved changes are applied:

```
## Eval Docs Complete

**Docs reviewed**: N
**Structural issues found**: N
**Content/frontmatter issues found**: N
**Changes applied**: N
**Fixes auto-applied (objective)**: N
**Fixes user-approved (subjective)**: N

**Modified**:
- [filename.md] — [what changed]

**Unchanged**:
- [filename.md]
```
