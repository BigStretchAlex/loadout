# loadout

An AI-assisted development lifecycle framework for Claude Code. Provides adversarial research, structured planning, autonomous building, code review with iteration limits, and progressive knowledge management.

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
# 1. Bootstrap knowledge base from your codebase
/loadout:init-docs

# 2. Research an idea (adversarial exploration)
/loadout:research feat-auth-flow "Add OAuth2 login flow"

# 3. Create an implementation plan
/loadout:plan feat-auth-flow

# 4. Build it
/loadout:build feat-auth-flow

# 5. Review the code
/loadout:review feat-auth-flow

# 6. Fix review issues (max 3 iterations, then escape hatch)
/loadout:review-fix feat-auth-flow

# 7. Promote insights to knowledge base
/loadout:triage feat-auth-flow

# Check status at any point
/loadout:status
```

## Skills

### Feature Lifecycle

| Skill | Description |
|-------|-------------|
| `/loadout:research` | Adversarial exploration of a vague idea — challenges assumptions, surfaces alternatives |
| `/loadout:plan` | Structured implementation plan with acceptance criteria, risks, and test strategy |
| `/loadout:build` | Autonomous implementation based on plan.md |
| `/loadout:review` | Code review on changes using the code-reviewer agent |
| `/loadout:review-fix` | Address review findings with re-review loop (max 3 iterations) |
| `/loadout:triage` | Promote scratch insights to .ai-docs/ knowledge base |
| `/loadout:status` | Show work item state and suggest next steps |

### Knowledge Base

| Skill | Description |
|-------|-------------|
| `/loadout:init-docs` | Bootstrap .ai-docs/ from a codebase by extracting patterns |
| `/loadout:drift-check` | Detect stale .ai-docs/ entries vs. current code |

### Utility

| Skill | Description |
|-------|-------------|
| `/loadout:hello` | Greet the user with a personalized message |
| `/loadout:summarize` | Summarize the current project or a specific file |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| **arbiter** | sonnet | Orchestrates research by delegating to doc-scanner and content-retriever |
| **code-reviewer** | sonnet | Reviews code for security, quality, testing, and best practices |
| **doc-scanner** | haiku | Scans document frontmatter to find relevant sections by topic |
| **content-retriever** | haiku | Reads specific doc sections and returns synthesized content |
| **document-writer** | haiku | Extracts reusable patterns from scratch memory into .ai-docs |
| **mermaid** | sonnet | Creates and explains Mermaid diagrams from code or descriptions |
| **doc-extractor** | sonnet | Analyzes codebase to extract patterns/conventions for .ai-docs |
| **drift-analyzer** | haiku | Compares .ai-docs/ against current code for staleness |
| **research-challenger** | sonnet | Adversarial research partner — challenges assumptions, proposes alternatives |
| **plan-writer** | sonnet | Produces structured plans with acceptance criteria and risks |
| **build-executor** | sonnet | Reads plan.md and autonomously implements changes |

### Agent Architecture

```
Feature Lifecycle:
  research-challenger (sonnet)
  └── arbiter → doc-scanner + content-retriever

  plan-writer (sonnet)
  └── arbiter → doc-scanner + content-retriever

  build-executor (sonnet)
  └── reads plan.md, writes scratch.md

  code-reviewer (sonnet)
  └── arbiter → best practice lookups

Knowledge Base:
  doc-extractor (sonnet)
  └── analyzes codebase → produces .ai-docs/

  drift-analyzer (haiku)
  └── compares .ai-docs/ vs. code

  document-writer (haiku)
  └── reads scratch → produces .ai-docs/ entries

Research Pipeline:
  arbiter (sonnet)
  ├── doc-scanner (haiku) → relevance scores + line ranges
  └── content-retriever (haiku) → synthesized section content
```

## Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `load-relevant-docs` | PreToolUse (Read/Glob) | Scans .ai-docs/ frontmatter and injects relevant doc paths |
| `scratch-capture` | PostToolUse (Bash) | Reminds to capture insights when working in a .dev/ context |

Hook scripts live in `hooks/scripts/`. See the hook documentation in `hooks/` for registration instructions.

## Work Item Structure

Work items live in `.dev/<type>-<slug>/` where type is one of: `feat`, `bug`, `refactor`, `spike`.

```
.dev/
├── scratch.md                    # Global scratch (optional)
└── feat-auth-flow/               # Example work item
    ├── research.md               # From /research
    ├── plan.md                   # From /plan
    ├── scratch.md                # Per-feature scratch
    └── reviews/                  # Review iteration outputs
        ├── review-1.md
        └── review-2.md
```

## Knowledge Base

The `.ai-docs/` directory stores reusable patterns extracted from scratch memory and codebase analysis. Documents follow a frontmatter standard that enables fast, content-free discovery.

See `templates/ai-docs-frontmatter-standard.md` for the schema.

## Plugin Structure

```
loadout/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
│   ├── arbiter.md
│   ├── build-executor.md
│   ├── code-reviewer.md
│   ├── content-retriever.md
│   ├── doc-extractor.md
│   ├── doc-scanner.md
│   ├── document-writer.md
│   ├── drift-analyzer.md
│   ├── mermaid.md
│   ├── plan-writer.md
│   └── research-challenger.md
├── skills/
│   ├── build/SKILL.md
│   ├── drift-check/SKILL.md
│   ├── hello/SKILL.md
│   ├── init-docs/SKILL.md
│   ├── plan/SKILL.md
│   ├── research/SKILL.md
│   ├── review/SKILL.md
│   ├── review-fix/SKILL.md
│   ├── status/SKILL.md
│   ├── summarize/SKILL.md
│   └── triage/SKILL.md
├── hooks/
│   ├── load-relevant-docs.md
│   ├── scratch-capture.md
│   └── scripts/
│       ├── scan-ai-docs.sh
│       └── scratch-reminder.sh
├── templates/
│   ├── ai-docs-frontmatter-standard.md
│   ├── plan.md
│   ├── research.md
│   └── scratch.md
├── .gitignore
└── README.md
```

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
