---
name: update-rules
description: Distill new project rules from recent work evidence and maintain an existing .claude/rules/ directory.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Task, AskUserQuestion
argument-hint: '[explicit rules or focus...] (e.g., "never use default exports" or empty to distill from recent work)'
model: sonnet
---

# Update Rules Skill

Maintain `.claude/rules/` in the consuming project: distill candidate rules from recent work evidence — scratch memory, review findings, git history, and anything the user states directly — then apply only what the user approves.

Read `templates/rules-standard.md` from the plugin directory before drafting anything — it is the format contract every rule file must follow.

## Instructions

### Step 1 — Preflight

1. Check whether `.claude/rules/` exists and contains any `.md` files.
2. **If it doesn't exist or is empty**, stop and tell the user there are no rules to update yet — `/create-rules` is the bootstrap path.
3. Otherwise, proceed.

### Step 2 — Inventory Existing Rules

Read **every** file under `.claude/rules/` (Glob `**/*.md`, then Read each). Record for each file:

- its path (`common/testing.md`, `typescript/coding-style.md`, ...)
- its `##` section headings
- its rule bullets

This inventory is the dedupe baseline for Step 4 — a candidate is only new if no existing bullet already says it. Also note each file's line count for the ~100-line soft cap check in Step 6.

### Step 3 — Gather Candidates

Collect candidate rules from four evidence sources. Each candidate is **one imperative rule line** (ALWAYS/NEVER phrasing where it fits) paired with **its evidence** (source path or commit, plus the observation behind it).

1. **`$ARGUMENTS`** — if non-empty, treat each user-stated rule or focus as an explicit candidate. These still go through the verdict and approval steps; being user-stated is strong evidence, not a bypass.
2. **Scratch memory** — Glob `.dev/*/scratch.md` (and `.dev/scratch.md`), read the most recent files, and mine their **Gotchas** and **Decisions** sections for hard-won lessons that generalize.
3. **Review findings** — Glob `.dev/*/reviews/review-*.md` and look for **recurring** findings: the same class of issue flagged in more than one review is a rule waiting to be written.
4. **Git history** — run `git log --oneline -20` and look for recurring themes: repeated fix/revert subjects, the same subsystem patched again and again, convention churn. Read individual commit bodies only where a subject suggests rationale worth capturing.

Do not pad — a short candidate list from real evidence beats a long speculative one.

### Step 4 — Verdict per Candidate

Assign every candidate exactly one verdict:

| Verdict | Meaning |
|---------|---------|
| **Append** | Add the rule as a bullet under an existing `##` section |
| **Revise** | An existing rule is wrong or outdated — edit it in place |
| **New Section** | The rule fits an existing file but no existing section covers it — add a `##` section |
| **New File** | No existing file fits the topic, or the target file would exceed the ~100-line soft cap — create a new topic file |
| **Already Covered** | The Step 2 inventory already says this — reject |
| **Too Specific** | A one-off, not a rule — reject |

A candidate only qualifies for the first four verdicts if it passes **ALL four** criteria:

1. **Generalizes** — applies to 2+ distinct situations, not one incident
2. **Actionable** — a future session could follow it as written, no context needed
3. **Real risk** — without the rule, a violation is plausible, not hypothetical
4. **Not covered** — no existing bullet in the inventory already says it

A candidate failing criterion 4 is **Already Covered**; failing 1, 2, or 3 is **Too Specific** (note which criterion failed). For each qualifying candidate, record the target file and section, and check the standard's constraints now: `common/` targets take no code blocks, a New File in a language directory needs the `> This file extends ...` blockquote, and a new common topic file needs ≥3 substantive rules (fold a lone rule into a related existing topic instead).

### Step 5 — Approval Gate

Rules are never auto-modified. **This skill is explicitly exempt from the Confidence Policy in `templates/confidence-policy.md`** (which lets other loadout skills auto-apply objective fixes) — unlike that policy, this skill applies no auto-apply tier at any confidence level: **every rule change requires explicit user approval.**

Present the qualifying candidates as a table, then ask via `AskUserQuestion` with `multiSelect` so the user picks which to apply:

> ## Proposed Rule Changes
>
> | # | Candidate rule | Verdict | Target | Evidence |
> |---|----------------|---------|--------|----------|
> | 1 | NEVER ... | Append | common/testing.md → ## Test Organization | .dev/feat-x/scratch.md Gotcha |
> | 2 | ALWAYS ... | New Section | common/git-workflow.md | 3 recurring review findings |
>
> Rejected (not asked about): [each Already Covered / Too Specific candidate with its reason]
>
> Which changes should I apply? (select any, all, or none)

Show Revise verdicts with both the current wording and the proposed replacement. If the user selects none, stop after reporting the rejections.

### Step 6 — Apply & Report

1. Apply each approved change with Edit (Append, Revise, New Section) or Write (New File), conforming exactly to `templates/rules-standard.md`: plain markdown, no frontmatter, imperative bullets, concrete `##` headings, no code blocks in `common/`, language-file blockquote convention, ~100-line soft cap.
2. If applying an Append or New Section pushes a file past the soft cap, split it into narrower topic files rather than letting it grow — tell the user when this happens.
3. Report:

```
## Rules Updated

| Change | File | Section |
|--------|------|---------|
| Appended: [rule] | common/testing.md | ## Test Organization |
| New file: [topic] | typescript/patterns.md | — |

**Applied**: [N] | **Rejected**: [N]

### Rejected
- [candidate]: Already Covered by common/coding-style.md → ## Naming
- [candidate]: Too Specific — single incident, fails criterion 1
```

## Rules

1. NEVER modify a rule file without explicit user approval (Step 5) — this skill is exempt from the Confidence Policy in `templates/confidence-policy.md`; there is no confidence level at which a rule change is auto-applied
2. Never modify anything outside `.claude/rules/`

## Fallback

Degrade gracefully — an honest empty result beats an invented rule:

- **No `.dev/` directory or no scratch/review history**: distill from `$ARGUMENTS` only (plus git history if available); say so in the Step 5 presentation. If `$ARGUMENTS` is also empty and git shows no themes, report that there is no evidence to distill from.
- **Nothing qualifies** (every candidate lands on Already Covered or Too Specific): report "no rule-worthy candidates" with the rejection table — do not lower the bar to have something to show.
- **Git unavailable** (not a repo, or `git log` fails): skip that source and note it; the other sources stand alone.
