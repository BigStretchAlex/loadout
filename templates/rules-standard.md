# `.claude/rules/` Project Rules Standard

Every file under `.claude/rules/` **must** follow this format. Rules live in the consuming project (not this plugin) and are plain markdown with **no frontmatter**. Downstream consumers (doc-scanner, build, hooks) include rules by heading match — `common/` rules are always included, language directories are included when their language is in play.

All skills and agents that create or update rule files MUST read this file first.

## Directory Layout

```
.claude/rules/
├── common/              # language-agnostic rules — ALWAYS included by consumers
│   ├── coding-style.md
│   ├── testing.md
│   └── git-workflow.md
├── typescript/          # language-specific rules — included when the language applies
│   └── testing.md
└── python/
    └── coding-style.md
```

- `common/` holds rules that apply regardless of language.
- Each `<language>/` directory (e.g. `typescript/`, `python/`, `go/`) holds rules that only apply to that language.
- Files are plain markdown. **NO frontmatter** — rule files are read whole and matched by heading, not scanned by metadata.

## Canonical Common Topics

| File | Covers |
|------|--------|
| `common/coding-style.md` | Naming, structure, comments, formatting expectations |
| `common/testing.md` | Test value criteria, organization, coverage expectations |
| `common/git-workflow.md` | Branching, commit messages, PR conventions |
| `common/security.md` | Secrets handling, input validation, auth expectations |
| `common/patterns.md` | Architectural patterns to follow and anti-patterns to avoid |
| `common/code-review.md` | Review standards and checklists |

**Creation threshold**: create a topic file only when there are **at least 3 substantive rules** for it. A file with one or two rules is noise — fold those rules into a related topic or omit them until more accumulate.

## File Format

- **H1 = topic name** (e.g. `# Testing`). Exactly one H1 per file, first line of the file.
- **`##` sections group related rules.** Section headings are the inclusion surface — name them for what they govern (e.g. `## Commit Messages`), not generically (`## Guidelines`).
- **Rules are imperative bullets.** Use **ALWAYS** / **NEVER** phrasing where it fits: "ALWAYS validate input at system boundaries", "NEVER commit secrets".
- **State what, not how.** A rule declares the required outcome; it is not an implementation walkthrough or tutorial.
- **No code blocks in `common/` files.** Language-agnostic rules must be expressible in prose. Language directories MAY include short idiomatic snippets when a rule is meaningless without one — keep snippets to a few lines.
- **Soft cap ~100 lines per file.** When a file exceeds it, split it into narrower topic files rather than letting it grow.

## Language Files

Every file in a `<language>/` directory starts with a blockquote linking its common counterpart:

> This file extends [../common/testing.md](../common/testing.md) with typescript-specific rules.

(Substitute the topic and language.) Language files contain **only rules that genuinely differ per language** — a rule that holds for every language belongs in `common/`, not duplicated per directory. A language file with the same topic name as a common file supplements it; it never replaces it.

## Inclusion Model

Consumers include rules by heading match against the task at hand:

- `common/` files are **always** candidates — every consumer includes them regardless of language.
- `<language>/` files are candidates only when that language is detected in the task or project.
- Within a file, `##` headings are the match surface — write headings that name concrete concerns so consumers can select relevant sections.

## Canonical Seed Outline: `common/testing.md`

Skills that bootstrap rules ALWAYS create `common/testing.md`, seeded from this outline. The **What Constitutes a Valuable Test** section is REQUIRED and must be present in every generated `common/testing.md`; the remaining sections are drafted from project evidence and included only when the ≥3 substantive rules threshold is met.

```markdown
# Testing

## What Constitutes a Valuable Test

- ALWAYS test observable behavior, not implementation details — a refactor that preserves behavior must not break tests
- ALWAYS make tests deterministic — no dependence on wall-clock time, network access, or test execution order
- Each test has exactly one reason to fail — one behavior under test per test case
- Every acceptance criterion is covered by at least one test
- NEVER write tautological tests — asserting that a mock returns what you stubbed it to return proves nothing
- NEVER snapshot-everything — broad snapshots assert incidental structure, not intended behavior

## Test Organization

- [Where tests live, how they are named, how fixtures are shared — drafted from project evidence]

## Coverage Expectations

- [What must be tested before merge, what may be skipped — drafted from project evidence]
```

## Anti-Patterns

- ❌ Frontmatter in a rule file — rule files are plain markdown, always
- ❌ A `common/` rule with a code snippet — if it needs code, it is language-specific; move it
- ❌ "Consider using descriptive names" — hedged phrasing; write "ALWAYS use intention-revealing names"
- ❌ A rule that explains step-by-step how to implement something — that is documentation, not a rule
- ❌ Duplicating a common rule into every language directory — it belongs in `common/` once
- ❌ `typescript/style.md` with different topic naming than `common/coding-style.md` — language files mirror common topic names
- ❌ A 2-rule `common/security.md` — below the ≥3 substantive rules threshold; hold until more accumulate
