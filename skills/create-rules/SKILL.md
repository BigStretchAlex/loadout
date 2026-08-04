---
name: create-rules
description: Bootstrap a .claude/rules/ directory of project coding rules grounded in the codebase and .ai-docs/.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Task, Write, AskUserQuestion
argument-hint: '[focus-topics...] (e.g., "testing security" or empty for all)'
model: sonnet
---

# Create Rules Skill

Bootstrap `.claude/rules/` in the consuming project: language-agnostic rules in `common/` plus per-language directories, grounded in documented conventions (`.ai-docs/`) and the actual code.

Read `templates/rules-standard.md` from the plugin directory before drafting anything — it is the format contract every rule file must follow.

## Instructions

### Step 1 — Preflight

1. Check whether `.claude/rules/` exists and contains any `.md` files.
2. **If it has content**, tell the user rules already exist and that `/update-rules` is the maintenance path. Then ask via `AskUserQuestion`:
   - **Regenerate**: continue anyway and rebuild from scratch (existing files will be replaced by whatever the user approves in Step 4)
   - **Stop**: abort and suggest `/update-rules`
3. If it doesn't exist or is empty, proceed.

### Step 2 — Detect Languages & Gather Evidence

1. **Detect languages** from manifest files via Glob: `package.json` / `tsconfig.json` (TypeScript/JavaScript), `pyproject.toml` / `setup.py` / `requirements.txt` (Python), `go.mod` (Go), `Cargo.toml` (Rust), `pom.xml` / `build.gradle` (Java/Kotlin), `Gemfile` (Ruby), `*.csproj` (C#). Note each detected language — it becomes a candidate `<language>/` directory.

2. **In parallel**, spawn both evidence-gathering agents:

   Spawn the **arbiter** agent:
   > Find documented conventions, patterns, and anti-patterns in `.ai-docs/` relevant to: coding style, testing strategy, git workflow, security practices, architectural patterns, and code review standards. Return concrete, citable conventions — not general advice.

   Spawn the **code-explorer** agent:
   > **Goal**: Survey the actual conventions in this codebase to ground project rules — naming conventions, file organization, test structure and style, error handling, security-sensitive patterns.
   > **Technical Patterns from .ai-docs/**: [none yet — survey independently]
   > **Work item path**: N/A — this is a repo-wide convention survey, not a work item.

3. Capture from the arbiter: documented conventions with sources. Capture from code-explorer: observed conventions with file evidence. Where the two disagree, prefer what the code actually does and note the tension for the user in Step 4.

### Step 3 — Draft Rule Files

Read `templates/rules-standard.md` from the plugin directory and draft rule files that conform to it exactly:

1. **Always draft `common/testing.md`**, seeded from the standard's canonical seed outline — the **What Constitutes a Valuable Test** section is included verbatim; the remaining sections are filled from Step 2 evidence and kept only if they clear the threshold below.
2. For each other canonical common topic (`coding-style.md`, `git-workflow.md`, `security.md`, `patterns.md`, `code-review.md`): draft it **only if Step 2 produced at least 3 substantive, grounded rules** for that topic. Do not pad thin topics to reach three.
3. For each detected language: draft `<language>/<topic>.md` files only for rules that genuinely differ per language, each opening with the standard's `> This file extends ...` blockquote.
4. If `$ARGUMENTS` names focus topics, restrict drafting to those topics (plus the always-required `common/testing.md`).
5. Every rule must trace to evidence from Step 2 — a documented convention or an observed code pattern. Do not invent rules from general best practice alone.

### Step 4 — Approval Gate

Rules are always subjective — **NEVER write a rule file the user has not approved.**

Present the **full draft of every file** (complete contents, not summaries) to the user via `AskUserQuestion`:

> ## Proposed .claude/rules/
>
> [full contents of each drafted file, clearly separated by path]
>
> How would you like to proceed?
> 1. **Approve all** — write every file as drafted
> 2. **Exclude files** — write all except the ones you name
> 3. **Revise** — describe changes; I'll redraft and re-present
> 4. **Cancel** — write nothing

If the user selects **Revise**, apply the requested changes and re-run this step on the updated drafts. If **Cancel**, write nothing and stop.

### Step 5 — Write & Report

1. Write each approved file to `.claude/rules/` with the Write tool.
2. Report:

```
## Project Rules Created

.claude/rules/
├── common/
│   ├── testing.md        (N rules)
│   └── coding-style.md   (N rules)
└── typescript/
    └── testing.md        (N rules)

**Files**: [N] | **Rules**: [N] | **Languages**: [list]

Rules evolve with the codebase — run /update-rules to keep them current.
```

## Rules

1. Never modify anything outside `.claude/rules/`

## Fallback

Degrade gracefully — a smaller, grounded rule set beats a padded one:

- **No `.ai-docs/` directory**: skip the arbiter; draft from the code-explorer survey only, and say so in the Step 4 presentation.
- **No detectable language** (no manifest files): draft `common/` files only; note that language directories can be added later via `/update-rules`.
- **Agents unavailable** (Task tool fails or agents error): run a direct survey yourself with Glob/Grep/Read — sample 3–5 representative source files and test files per language — and draft from that.
- **Evidence too thin for any topic beyond testing**: present only `common/testing.md` (its required section needs no project evidence) and tell the user why the other topics were withheld.
