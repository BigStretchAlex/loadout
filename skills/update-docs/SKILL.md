---
name: update-docs
description: 'Incorporate new user-provided knowledge into the .ai-docs/ knowledge base by updating existing sections, adding new sections, or creating new docs. Use whenever the user wants to record information into their docs. Trigger on: "update the docs about X", "add this to the knowledge base", "the docs on Y are missing Z", "document that we now do X", "correct the docs on Y".'
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion
model: sonnet
argument-hint: "<topic/doc to update> + <the new information>"
---

# Update Docs Skill

Take new information the user provides and fold it into `.ai-docs/` — updating existing sections, adding new sections, or creating new documents as appropriate.

## Phase 1 — Parse

1. Parse `$ARGUMENTS` into two parts:
   - **Target topic/doc**: which doc or subject area the user wants updated
   - **New information**: the knowledge to incorporate (facts, patterns, corrections, additions)

   If either part is unclear, ask the user via `AskUserQuestion` before proceeding.

2. Check if `.ai-docs/` exists. If not, tell the user to run `/init-docs` first and **stop**.

## Phase 2 — Locate

Spawn `doc-scanner` with the target topic:

> Scan .ai-docs/ frontmatter for documents and sections relevant to: [topic]. Return relevance scores and line ranges.

Interpret the results:

- **One clear HIGH-relevance target** → proceed with it.
- **Multiple plausible targets** → resolve via `AskUserQuestion`: list the candidate docs/sections (with their summaries) and let the user pick which to update.
- **No matches** → go to Fallback.

## Phase 3 — Classify

Split the new information into discrete pieces and classify each one:

- **(a) Update to an existing section** — the information corrects, extends, or supersedes content in a section the scanner found (use the section's line range and summary to judge).
- **(b) New section in an existing doc** — the information belongs in a located doc but no existing section covers it.
- **(c) New doc** — the information is a distinct topic no existing doc covers (or the user explicitly asked for a new doc).

If classification is ambiguous for a piece (e.g., it could extend a section or stand alone), resolve via `AskUserQuestion`.

## Phase 4 — Route

**(a) Existing-section updates** — spawn `doc-updater`, **one call per target doc** with all of that doc's findings batched together. Because the evidence here is the user's stated information (not code lines), use the inline-evidence input variant:

```
Document: .ai-docs/<filename>.md
Findings:
  1. Section: "<heading>", Lines: <start>-<end>, Evidence (inline): "<the user's new information for this section>", Actual: "<what should change>", Type: Drifted
  2. ...
```

Use `Type: Contradicted` when the user's information contradicts the section, `Type: Drifted` when it extends or refines it.

**(b) New sections and (c) new docs** — spawn `document-writer` with the relevant pieces of information:

> You are incorporating user-provided knowledge into `.ai-docs/`.
>
> **Input type**: user-provided knowledge (treat as pre-curated — skip quality filtering)
> **Information**: [the classified pieces, with their target: "new section in .ai-docs/<file>.md" or "new doc on <topic>"]
> **Existing `.ai-docs/` files**: [list from Phase 2 scan]
>
> For new sections: append to the named existing doc and refresh its frontmatter per `templates/ai-docs-frontmatter-standard.md` — add/update the `sections[]` entry (name, summary, line ranges via the two-pass approach) and revise `patterns`, `keywords`, `task_triggers` (canonical list only), and `domain` if the doc's scope broadened.
> For new docs: create the file with full frontmatter per `templates/ai-docs-frontmatter-standard.md`, including `task_triggers` (1-3 canonical values), accurate line ranges, and searchable section summaries.

## Phase 5 — Report

```
## Update Docs Complete

**Docs touched**: [N]

| Document | Sections updated | Sections added | Frontmatter refreshed |
|----------|-----------------|----------------|----------------------|
| [name.md] | [headings or —] | [headings or —] | [yes/no] |

[New docs created, if any]
```

## Fallback

If `doc-scanner` finds nothing relevant to the topic:

1. Tell the user no existing doc covers the topic.
2. Offer via `AskUserQuestion` to create a new doc from the provided information.
3. If accepted, route the full information set to `document-writer` as case (c) above. If declined, stop.

## Rules

1. Never edit `.ai-docs/` files directly — all writes go through `doc-updater` or `document-writer`.
2. Never fabricate `file:line` citations for knowledge that has no code location — use `Evidence (inline):` instead.

## Relationship to Other Skills

- **`/init-docs` (Augment mode)** is create-only — it bootstraps docs that are missing but never modifies existing ones. Before this skill, no update capability existed; `/update-docs` fills that gap.
- **`/drift-check`** fixes code-vs-doc drift by comparing docs against the codebase. `/update-docs` is different: it incorporates new knowledge the user provides directly, with no code comparison.
- **`/triage`** promotes scratch-memory insights; `/eval-docs` audits quality. `/update-docs` is for direct, user-stated additions and corrections.
