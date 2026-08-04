# loadout

An AI-assisted development lifecycle framework for Claude Code. Provides adversarial research, structured planning, autonomous building, code review with iteration limits, and progressive knowledge management.

Loadout solves a core problem with AI-assisted development: context evaporates between sessions, decisions go unrecorded, and every feature starts from scratch. It imposes a repeatable lifecycle where context accumulates, insights get written down, and the knowledge Claude gains from one feature is available the next time something related comes up.

Everything lives in three places:
- `.dev/<slug>/` — per-feature working memory (scratch notes, brainstorm, plan, tasks, reviews)
- `.ai-docs/` — permanent knowledge base of patterns, conventions, and decisions extracted from your codebase
- `.claude/rules/` — short, binding project coding rules (see [Rules](#rules))

## Installation

### Local development

```bash
claude --plugin-dir ./path/to/loadout
```

### From marketplace

```
/plugin install loadout
```

## Quick Start

```bash
# 1. Bootstrap knowledge base from your codebase (run once)
/loadout:init-docs

# 2. Adversarially explore an idea — challenge assumptions
/loadout:brainstorm feat-auth-flow "Add OAuth2 login flow"

# 3. Ground the idea in your codebase + knowledge base
/loadout:discover feat-auth-flow

# 4. Create an implementation plan
/loadout:plan feat-auth-flow

# 5. Build it
/loadout:build .dev/feat-auth-flow

# 6. Review the code
/loadout:review .dev/feat-auth-flow

# 7. Fix review issues (max 3 iterations, then escape hatch)
/loadout:review-fix .dev/feat-auth-flow/reviews/review-1.md

# 8. Promote insights to knowledge base
/loadout:triage .dev/feat-auth-flow

# Check status at any point
/loadout:status
```

---

## Lifecycle

Loadout organises work into two tracks. The **Feature Lifecycle** is a linear sequence — each step feeds the next. **Knowledge Base Maintenance** runs periodically to keep `.ai-docs/` accurate.

### Step 0 — Bootstrap: `/loadout:init-docs`

Run once when you first add Loadout to a project. Surveys the codebase structure, identifies patterns (architecture layers, API conventions, test strategy, CI/CD, migrations, auth, etc.), proposes a set of `.ai-docs/` documents, and asks you to approve them before writing anything.

Without this, every feature starts from zero context. With it, Claude knows your repo's conventions before writing a line of code — and every subsequent skill benefits.

You can re-run it with focus areas (`/init-docs backend security`) to add new documents without touching existing ones (Augment mode), or rebuild from scratch. Augment mode is create-only — to fold new information into existing docs, use `/loadout:update-docs` instead.

---

### Step 1 — Explore: `/loadout:brainstorm`

Before committing to an approach, challenge the idea adversarially. The `brainstorm-challenger` agent stress-tests your idea: it challenges assumptions, proposes alternatives, and checks `.ai-docs/` for relevant precedents.

**Output**: `.dev/<slug>/brainstorm.md`

This step is intentionally confrontational — its job is to find holes before you've invested in a plan. It's easy to plan the wrong solution, or miss a simpler approach. Brainstorm first.

---

### Step 2 — Discover: `/loadout:discover`

Grounds the idea in your actual codebase and documented conventions. Two agents run:

- `arbiter` reads `.ai-docs/` to surface relevant patterns and anti-patterns
- `code-explorer` traverses the live codebase to find relevant files, dependencies, and integration points

The outputs are synthesised into `research.md` with six sections: Domain Concepts, Technical Patterns, Relevant Code, Dependencies, Integration Points, Constraints & Risks.

**Output**: `.dev/<slug>/research.md`

If you run `/discover` before `/plan`, the plan step uses `research.md` directly and skips its own discovery — giving the plan-writer better inputs and reducing clarifying questions.

---

### Step 3 — Plan: `/loadout:plan`

Produces a detailed `plan.md` grounded in discovery findings. If `research.md` doesn't exist yet, the plan step runs inline discovery first. It then asks any genuine clarifying questions (batched into one prompt, only when truly needed), and spawns the `plan-writer` agent.

The plan includes: numbered steps with file-action mappings, acceptance criteria, risks, and test strategy.

**Architecture consult (optional)**: for `feat` and `refactor` slugs, if discovery surfaced multiple viable architectural approaches, the plan step consults the read-only `architect` agent (opus) — it compares the options, commits to a single recommendation, and records an ADR-style decision in `scratch.md`. If one approach is obvious, the consult is skipped silently.

After writing the plan, the `plan-reviewer` agent critiques it adversarially — checking for flawed assumptions, missing risks, untestable criteria, and scope creep. Blocking findings are partitioned per the **Confidence Policy**: objective findings (mechanically verifiable defects — broken paths, contradictions with discovery) are auto-revised without asking, up to 2 revision rounds; subjective findings (scope, naming, architecture trade-offs) are surfaced via `AskUserQuestion` and never applied unprompted.

**TDD variant — `/loadout:tdd-plan`**: runs the same plan flow, then attaches a test-first **TDD Gate** to every step (Test, Command, Fail-first, Pass condition) plus a plan-level TDD Gate Summary table. The `code-quality` agent then verifies gate completeness, acceptance-criterion coverage, runnable commands, and deterministic pass conditions before any implementation begins. Use it when you want every step backed by a failing-then-passing test.

**Type discipline**: the plan enforces constraints based on your slug prefix:
- `feat-*` — simplicity; solve only what's stated, no speculative abstractions
- `bug-*` — minimal footprint; change only what fixes the defect
- `refactor-*` — scope discipline; restructure only what the goal names
- `spike-*` — timebox; output is findings and a recommended next action, not implementation steps

**Output**: `.dev/<slug>/plan.md` + `.dev/<slug>/plan-review.md`

---

### Step 4 — Build: `/loadout:build`

Confirms the plan with you, then spawns `build-executor` to work through each step. The executor has the full plan, research, and scratch context. It writes code, runs commands, and captures insights in `scratch.md` as it goes.

The build generates `<dir>/tasks.md` from the plan's steps (one checkbox line per step, from `templates/tasks.md`) and checks each line off as its verification passes. If `tasks.md` already exists with checked items, the build **resumes** from the first unchecked step. If `.claude/rules/` exists, testing rules (`common/testing.md` plus any language testing rules) are injected into the executor prompt as binding constraints; if none are found the build proceeds and the final report suggests `/create-rules`.

If a step fails or hits an ambiguity, it stops and presents options (modify plan, skip step, abort) rather than pushing through silently.

After all steps complete, a **simplify pass** spawns `code-simplifier` on the files the build modified, so over-engineering is caught before review.

You can run a subset of steps: `/loadout:build .dev/<slug> step 3-5` — useful for re-running a specific section after fixing a blocker.

**TDD variant — `/loadout:tdd-build`**: phase-for-phase variant of `/build` for plans produced by `/tdd-plan` — same executor, task tracking, blocked handling, and simplify pass, but every step is gated by its TDD Gate: the gate's test must fail before implementation and pass after, and a final phase re-runs all gates as quantifiable proof of completion. If the plan isn't TDD-gated, it offers to run `/tdd-plan` first or fall back to plain `/build`.

**Output**: implemented code, `tasks.md`, updated `scratch.md`

---

### Step 5 — Review: `/loadout:review`

Spawns `code-reviewer` on the files listed in `plan.md` (or auto-detects from git diff). **Language-based routing**: if all non-config source files under review are TS/JS (`.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`), the `typescript-reviewer` agent is spawned instead — a drop-in alternative with the same input contract and output format, adding compiler/linter runs and a TS-specific severity checklist. Issues are categorised as CRITICAL / HIGH / MEDIUM / LOW / AI SLOP.

CRITICAL issues are always included. For everything else, you get an interactive multiselect to exclude noise (e.g. a stylistic LOW you've consciously decided not to fix) before the report is written to `reviews/review-N.md`. Exclusions are persisted to `.review-exclusions.json` so they carry forward to future rounds.

The AI Slop Detection section explicitly calls out generated code patterns that look correct but are generic or cargo-culted — patterns that pass review but don't fit the codebase.

Running `/review` again increments the round number automatically, so you get a history.

**Output**: `.dev/<slug>/reviews/review-1.md`

---

### Step 6 — Fix: `/loadout:review-fix`

Reads the review file, plans fixes in priority order (CRITICAL → HIGH → MEDIUM, skip LOW), shows you the fix plan before touching any code, then applies fixes and automatically spawns another review round. Fixes are partitioned per the **Confidence Policy**: objective fixes (mechanically verifiable) are auto-applied with re-verification; subjective fixes (judgment calls on scope, naming, architecture) require explicit approval before any code changes.

Hard limit of 3 iterations. At 3, it shows you remaining unresolved issues and presents an escape hatch: continue, skip, or escalate for manual review.

**Output**: fixed code, `reviews/review-2.md`

---

### Step 7 — Triage: `/loadout:triage`

Reads `scratch.md` from the work item and extracts reusable patterns — both general ones (applicable anywhere) and codebase-specific ones (conventions unique to this repo). The `document-writer` agent decides whether to append to existing `.ai-docs/` files or create new ones. It runs a two-pass line-number update to keep frontmatter section references accurate, then marks `scratch.md` as triaged.

**Output**: updated `.ai-docs/` files

This is what makes the system compound. The insights from implementing a feature — the Redis TTL heuristic you discovered, the middleware ordering that works, the naming convention the team settled on — get written into the knowledge base so they're available the next time something related comes up.

---

### At any time — `/loadout:status`

Scans `.dev/` and reports where each work item is in the lifecycle, what files exist, and what the suggested next step is. Pass a slug for detailed status on one item.

---

### Express path — `/loadout:perform-task`

For small, well-scoped tasks, the full brainstorm → discover → plan → build cycle is overkill. `/loadout:perform-task "fix the login typo"` compresses plan → build → review into one command: **the prompt is the plan**. It still scaffolds a `.dev/<slug>/` work item with scratch memory, still reuses `build-executor` and `code-reviewer` unchanged, and still reviews the result — it just skips the planning ceremony. If the task turns out to span many files or need design decisions, it refuses the express path and points you at the full lifecycle.

---

## Knowledge Base Maintenance

These skills run periodically to keep `.ai-docs/` accurate and useful.

### `/loadout:drift-check`

Detects when documented patterns no longer match the live codebase. Runs incrementally — tracks the last-checked commit and skips if nothing has changed since. Spawns `drift-analyzer` to compare documented patterns against current code, then `doc-reviewer` to flag oversized or bloated docs.

For HIGH-severity drift (contradicted or deleted patterns), offers to remove or update the section. For MEDIUM drift (partially outdated), lets you pick which items to fix. Fixes are batched per file to avoid re-reading the same document multiple times.

Run after significant refactors, dependency upgrades, or periodically as a maintenance habit.

### `/loadout:eval-docs`

Audits `.ai-docs/` quality in two parallel passes:
- `doc-reviewer` checks structure: file size, topic bloat, split proposals (target 50–100 lines per file, max 5 sections)
- `doc-content-reviewer` checks content: frontmatter accuracy, keyword/domain mismatches, missing examples, invalid or missing `task_triggers`, content gaps

Findings are presented together and partitioned per the **Confidence Policy** — objective fixes (mechanically verifiable frontmatter defects) are applied directly, subjective ones (splits, restructuring) are offered for approval. Can split oversized files, fix frontmatter, or enrich sections with missing examples and rationale.

Run after running `/triage` several times, or when discovery isn't surfacing the right docs.

### `/loadout:update-docs`

Folds new user-provided knowledge into `.ai-docs/` — updating existing sections, adding new sections, or creating new documents as appropriate. Uses `doc-scanner` to locate the right doc, then applies the change surgically (the `doc-updater` agent accepts inline evidence supplied directly by the caller, so user-stated facts don't need a code location). Use it whenever you want to record something: "document that we now do X", "the docs on Y are missing Z".

---

## Rules

Rules are short, binding coding rules that live in the **consuming project** at `.claude/rules/` — plain markdown, no frontmatter (rule files are read whole and matched by heading, not scanned by metadata).

```
.claude/rules/
├── common/              # language-agnostic rules — ALWAYS included by consumers
│   ├── coding-style.md
│   └── testing.md
└── typescript/          # language-specific — included when the language applies
    └── testing.md
```

**Creating and maintaining them**:
- `/loadout:create-rules` — bootstraps the directory, grounded in `.ai-docs/` and the actual code (detects languages from manifest files, drafts per-language directories, asks for approval before writing)
- `/loadout:update-rules` — distills new candidate rules from recent work evidence (scratch memory, review findings, git history, or rules you state directly) and applies only what you approve

**Who consumes them**:
- `doc-scanner` / `arbiter` — surface matching rules as an `### Applicable Rules` section (paths + headings only) during discovery
- the `explore-ai-docs` hook — tells Explore agents to read `common/` plus the matching language directory
- `/build` and `/tdd-build` — inject testing rules into the executor prompt as binding constraints
- `typescript-reviewer` and `architect` — treat rules as binding review criteria / design constraints
- the `post-edit-lint` / `post-edit-simplify` agent hooks — check edits against documented rules

The format contract is `templates/rules-standard.md`.

---

## Skills

Loadout ships 22 skills.

### Feature Lifecycle

| Skill | Description |
|-------|-------------|
| `/loadout:brainstorm` | Adversarial exploration of a vague idea — challenges assumptions, surfaces alternatives before planning |
| `/loadout:discover` | Explores codebase and `.ai-docs/` to build grounded discovery findings; writes `research.md` with six sections ready for planning |
| `/loadout:plan` | Structured implementation plan with acceptance criteria, risks, and test strategy; includes adversarial plan review with Confidence Policy partitioning and an optional architect consult |
| `/loadout:tdd-plan` | TDD-augmented planning — runs the plan flow, then attaches a test-first TDD Gate to every step, verified by the `code-quality` agent |
| `/loadout:build` | Autonomous step-by-step implementation based on `plan.md`; generates/resumes `tasks.md`, injects testing rules, ends with a simplify pass; stops and surfaces blockers rather than pushing through |
| `/loadout:tdd-build` | TDD-gated variant of `/build` — every step's gate test must fail before implementation and pass after, with a final re-run of all gates as proof of completion |
| `/loadout:perform-task` | Express path for small, well-scoped tasks — the prompt is the plan; compresses plan → build → review into one command, still with scratch memory and review |
| `/loadout:review` | Code review with severity categorisation, interactive issue exclusion, round tracking, and AI slop detection; routes all-TS/JS changesets to `typescript-reviewer` |
| `/loadout:review-fix` | Address review findings with fix-plan approval, re-review loop, and 3-iteration hard limit; objective fixes auto-applied, subjective fixes need approval |
| `/loadout:triage` | Promote scratch insights to `.ai-docs/` knowledge base |
| `/loadout:wrapup` | Promote git-detected insights to `.ai-docs/` for work done outside the loadout workflow |
| `/loadout:status` | Show work item state and suggest next steps |

### Knowledge Base

| Skill | Description |
|-------|-------------|
| `/loadout:init-docs` | Bootstrap `.ai-docs/` from a codebase by extracting patterns and conventions |
| `/loadout:update-docs` | Incorporate new user-provided knowledge into `.ai-docs/` — update existing sections, add new sections, or create new docs |
| `/loadout:drift-check` | Detect stale `.ai-docs/` entries vs. current code; incremental by default |
| `/loadout:eval-docs` | Audit `.ai-docs/` for structural quality, content quality, and frontmatter accuracy; offers to implement improvements |
| `/loadout:install-hooks` | Stub — reports that loadout hooks were removed pending the Phase 1 redesign |

### Rules

| Skill | Description |
|-------|-------------|
| `/loadout:create-rules` | Bootstrap a `.claude/rules/` directory of project coding rules grounded in the codebase and `.ai-docs/` |
| `/loadout:update-rules` | Distill new project rules from recent work evidence and maintain an existing `.claude/rules/` directory |

### Utility

| Skill | Description |
|-------|-------------|
| `/loadout:commit` | Analyse staged/unstaged changes and create a well-formed git commit message |
| `/loadout:simplify` | Review recently changed code for reuse, quality, and efficiency — then fix issues found; checks `.ai-docs/` for project-specific patterns before making changes |
| `/loadout:summarize` | Summarise the current project or a specific file |

---

## Agents

Loadout ships 19 agents.

| Agent | Model | Purpose |
|-------|-------|---------|
| **arbiter** | sonnet | Orchestrates research by delegating to doc-scanner and content-retriever; synthesises findings into actionable recommendations |
| **architect** | opus | System-design consultant — analyses current code, generates distinct design options, compares trade-offs, and commits to a single recommendation with an ADR-style record; strictly read-only |
| **brainstorm-challenger** | sonnet | Adversarial brainstorm partner — challenges assumptions, proposes alternatives, and stress-tests ideas before they become plans |
| **build-executor** | sonnet | Reads `plan.md` and autonomously implements changes step by step; updates scratch memory with insights |
| **code-explorer** | sonnet | Traverses the live codebase to map relevant files, trace dependencies, and identify integration points |
| **code-quality** | sonnet | Review-only gate reviewer for TDD-augmented plans — verifies gate completeness, acceptance-criterion coverage, runnable commands, and deterministic pass conditions; never edits |
| **code-reviewer** | sonnet | Reviews code for security vulnerabilities, quality issues, testing gaps, and best practice violations |
| **code-simplifier** | sonnet | Simplifies and refines recently modified code for clarity and consistency without changing behaviour; checks `.ai-docs/` for project patterns before acting |
| **content-retriever** | haiku | Reads targeted line ranges from docs identified by doc-scanner; returns synthesised section content |
| **doc-content-reviewer** | sonnet | Evaluates `.ai-docs/` files for content quality and frontmatter accuracy — never modifies, reports only |
| **doc-reviewer** | haiku | Identifies `.ai-docs/` files that are too long or too broad and recommends splits |
| **doc-scanner** | haiku | Lightweight scanner that reads only document frontmatter to find relevant sections by topic and relevance score |
| **doc-updater** | haiku | Applies surgical updates to `.ai-docs/` sections flagged as drifted by drift-analyzer; accepts inline evidence supplied directly by the caller (used by `/update-docs`) |
| **document-writer** | haiku | Extracts reusable patterns from scratch memory and transforms them into well-structured `.ai-docs/` entries with accurate frontmatter |
| **drift-analyzer** | haiku | Compares `.ai-docs/` entries against current code; reports drift with severity and recommended actions |
| **mermaid** | sonnet | Creates and interprets Mermaid diagrams from descriptions, code, or architecture; can explain existing syntax |
| **plan-reviewer** | sonnet | Adversarial reviewer that critiques a completed `plan.md` for flawed assumptions, missing risks, and scope issues |
| **plan-writer** | sonnet | Produces structured plans with acceptance criteria, risks, test strategy, and step-by-step approach |
| **typescript-reviewer** | sonnet | TypeScript/JavaScript-specialised code reviewer — drop-in alternative to code-reviewer with the same input contract and output format, adding compiler/linter runs and a TS-specific severity checklist |

### Agent Architecture

```
Feature Lifecycle:
  brainstorm-challenger (sonnet)
  └── arbiter → doc-scanner + content-retriever

  discover:
  ├── code-explorer (sonnet)     → maps files, deps, integration points
  └── arbiter (sonnet)           → doc-scanner + content-retriever

  plan-writer (sonnet)
  ├── arbiter → doc-scanner + content-retriever
  ├── architect (opus)           → optional design consult, ADR-style decision (feat/refactor)
  └── plan-reviewer (sonnet)     → adversarial plan critique

  tdd-plan:
  └── code-quality (sonnet)      → verifies TDD Gates before implementation

  build-executor (sonnet)
  └── reads plan.md + tasks.md + testing rules, writes scratch.md

  code-reviewer (sonnet) | typescript-reviewer (sonnet, all-TS/JS changesets)
  └── arbiter → doc-scanner + content-retriever

  code-simplifier (sonnet)
  └── reads .ai-docs/ for project patterns before simplifying

Knowledge Base:
  drift-analyzer (haiku)
  └── compares .ai-docs/ vs. code → doc-updater (haiku) applies fixes

  document-writer (haiku)
  └── reads scratch → produces .ai-docs/ entries

  doc-reviewer (haiku) + doc-content-reviewer (sonnet)
  └── audit .ai-docs/ for size, topic bloat, content gaps

Research Pipeline:
  arbiter (sonnet)
  ├── doc-scanner (haiku)        → relevance scores + line ranges
  └── content-retriever (haiku)  → synthesised section content
```

---

## Hooks

Loadout's hook code was removed in Phase 0 (`docs/modernization-roadmap.md` §0.5) — none of it
was wired into a consuming project by default, so the dead and half-installed tree was deleted
rather than patched in place. See [`hooks/README.md`](hooks/README.md) for the full inventory of
what existed and why, and the modernization roadmap's Phase 1 section for the `hooks.json`
auto-registration design that will replace it. `/loadout:install-hooks` currently reports that
there is nothing to install.

---

## Context Loading

The discovery pipeline uses a two-tier classification system to surface the right docs at the right time.

### How it works

**Tier 1 — task_triggers (broad intent)**: Every `.ai-docs/` document is tagged with 1-3 generic trigger categories (e.g., `create_feature`, `ui_component`, `auth_change`). When the arbiter receives a request, it maps the request type to matching triggers and passes them as scan queries. Doc-scanner awards +4 for an exact trigger match — enough to hit HIGH relevance before any keyword matching.

**Tier 2 — domain + keywords + patterns (fine discrimination)**: When two docs share the same trigger (e.g., both tagged `create_feature`), secondary fields distinguish them: `domain: frontend` + `keywords: react, tsx` vs `domain: backend` + `keywords: lambda, repository`.

### Worked example

> User: "add a new React form component"

1. Arbiter maps request → `ui_component` + `create_feature` task triggers
2. Doc-scanner runs queries for `ui_component`, `create_feature`, plus fine-grained topics
3. A doc tagged `task_triggers: [create_feature, ui_component]` + `domain: frontend` scores +8 (two trigger matches) before keyword scoring
4. A doc tagged `task_triggers: [create_feature, aggregate_change]` + `domain: backend` scores +4 but ranks lower — its keywords don't match the React context

### Canonical task_triggers

| Generic Trigger | Description |
|---|---|
| `create_feature` | New feature, entity, endpoint, service, lambda |
| `aggregate_change` | Extend aggregates, mappers, repositories |
| `api_design` | API changes, schemas, validation, result types |
| `database_change` | Migrations, queries, RLS, tenant-scoped data |
| `auth_change` | Auth context, authorizers, IAM, permissions |
| `error_handling` | Error classes, handling strategies |
| `architecture_question` | DI wiring, file placement, factory functions |
| `testing` | Write/fix unit, integration, e2e tests |
| `test_strategy` | Coverage decisions, what/how much to test |
| `infrastructure_change` | IaC, CI/CD, deployment |
| `dev_ops` | Builds, bootstrapping, onboarding |
| `ui_component` | UI components, styling, layouts |
| `state_management` | State stores, context, reducers |
| `data_fetching` | Client-side queries, caching, mutations |
| `code_review` | Review standards, checklists |
| `workflow` | Business processes, state machines, event flows |
| `performance` | Optimisation, caching, bundle size |
| `observability` | Logging, monitoring, tracing, alerting |

See `templates/ai-docs-frontmatter-standard.md` for full descriptions and examples.

### Rules surfacing

Alongside `.ai-docs/` scanning, `doc-scanner` globs `.claude/rules/**/*.md`. Rules have no frontmatter and are **not scored** — matching rule files are surfaced in a `### Applicable Rules` section as file paths plus their `#` headings only. The arbiter passes this section through unchanged (deduplicated by path) and never spawns a content-retriever for rule files: rules are small, so consumers read them directly. If `.claude/rules/` doesn't exist, the section is omitted entirely.

---

## Work Item Structure

Work items live in `.dev/<type>-<slug>/` where type is one of: `feat`, `bug`, `refactor`, `spike`.

```
.dev/
├── scratch.md                    # Global scratch (optional)
└── feat-auth-flow/               # Example work item
    ├── brainstorm.md             # From /brainstorm
    ├── research.md               # From /discover
    ├── plan.md                   # From /plan
    ├── plan-review.md            # From /plan (adversarial critique)
    ├── tdd-gate-review-1.md      # From /tdd-plan (code-quality gate review)
    ├── tasks.md                  # From /build or /tdd-build (progress + resume)
    ├── scratch.md                # Per-feature scratch
    └── reviews/                  # Review iteration outputs
        ├── review-1.md
        ├── review-2.md
        └── .review-exclusions.json
```

---

## Knowledge Base

The `.ai-docs/` directory stores reusable patterns extracted from scratch memory and codebase analysis. Documents follow a frontmatter standard that enables fast, content-free discovery.

See `templates/ai-docs-frontmatter-standard.md` for the schema.

---

## Plugin Structure

```
loadout/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
│   ├── arbiter.md
│   ├── architect.md
│   ├── brainstorm-challenger.md
│   ├── build-executor.md
│   ├── code-explorer.md
│   ├── code-quality.md
│   ├── code-reviewer.md
│   ├── code-simplifier.md
│   ├── content-retriever.md
│   ├── doc-content-reviewer.md
│   ├── doc-reviewer.md
│   ├── doc-scanner.md
│   ├── doc-updater.md
│   ├── document-writer.md
│   ├── drift-analyzer.md
│   ├── mermaid.md
│   ├── plan-reviewer.md
│   ├── plan-writer.md
│   └── typescript-reviewer.md
├── skills/
│   ├── brainstorm/SKILL.md
│   ├── build/SKILL.md
│   ├── commit/SKILL.md
│   ├── create-rules/SKILL.md
│   ├── discover/SKILL.md
│   ├── drift-check/SKILL.md
│   ├── eval-docs/SKILL.md
│   ├── init-docs/SKILL.md
│   ├── install-hooks/
│   │   └── SKILL.md              # Stub — hooks removed pending Phase 1 redesign
│   ├── perform-task/SKILL.md
│   ├── plan/SKILL.md
│   ├── review/SKILL.md
│   ├── review-fix/SKILL.md
│   ├── simplify/SKILL.md
│   ├── status/SKILL.md
│   ├── summarize/SKILL.md
│   ├── tdd-build/SKILL.md
│   ├── tdd-plan/SKILL.md
│   ├── triage/SKILL.md
│   ├── update-docs/SKILL.md
│   ├── update-rules/SKILL.md
│   └── wrapup/SKILL.md
├── hooks/
│   └── README.md          # Hook code removed in Phase 0 (0.5) — inventory + rationale
├── templates/
│   ├── ai-docs-frontmatter-standard.md
│   ├── brainstorm.md
│   ├── plan.md
│   ├── rules-standard.md
│   ├── scratch.md
│   └── tasks.md
├── .gitignore
└── README.md
```

---

## Development

To test changes locally:

```bash
claude --plugin-dir ./loadout
```

Reload after making changes:

```
/reload-plugins
```

## License

MIT
