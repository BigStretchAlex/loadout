---
name: discover
description: Explore a codebase and .ai-docs/ to build grounded discovery findings for a goal. Writes research.md with six sections ready for planning.
---

# Discover Skill

Explore a problem space by combining documented patterns from `.ai-docs/` (via arbiter) with live codebase traversal (via code-explorer). Synthesize findings into `research.md` — the canonical input for `/plan`.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain either:
   - A work item slug (e.g., `feat-auth-flow`) — discover within that context
   - A free-form goal description — create a new work item for it
   - If empty, jump to the **Fallback** section at the bottom

2. **Set up the work item directory**:
   - If a slug is provided, use `.dev/<slug>/`
   - If new, derive a slug: `<type>-<descriptive-slug>` where type is one of: `feat`, `bug`, `refactor`, `spike`
   - Create the `.dev/<slug>/` directory if it doesn't exist
   - Initialize `scratch.md` from `templates/scratch.md` if it doesn't exist

3. **Check for existing research** — if `.dev/<slug>/research.md` already exists, ask the user via `AskUserQuestion`:
   - **Continue**: use existing `research.md` as-is, skip to step 8
   - **Restart**: delete existing `research.md` and run full discovery
   - **Cancel**: abort

4. **Spawn the `arbiter` agent**:
   > Find patterns, conventions, and anti-patterns in `.ai-docs/` relevant to: [goal]

   Capture from the arbiter's output:
   - **Domain Concepts**: key terms, relationships, invariants from the arbiter summary
   - **Technical Patterns**: patterns that apply, anti-patterns to avoid, from arbiter recommendations

5. **Spawn the `code-explorer` agent**:
   > **Goal**: [goal]
   > **Technical Patterns from .ai-docs/**: [Technical Patterns section from step 4 — navigation hints only]
   > **Work item path**: `.dev/<slug>/`

   Capture verbatim from the code-explorer's output:
   - **Relevant Code** section
   - **Dependencies** section
   - **Integration Points** section

6. **Synthesize** findings into the six-section schema:
   ```markdown
   ## Discovery: [goal summary]

   ### Domain Concepts
   [from arbiter — key terms, relationships, invariants]

   ### Technical Patterns
   [from arbiter — patterns that apply, anti-patterns to avoid, plus any divergences noted by code-explorer]

   ### Relevant Code
   [verbatim from code-explorer]

   ### Dependencies
   [verbatim from code-explorer]

   ### Integration Points
   [verbatim from code-explorer]

   ### Constraints & Risks
   [synthesized from both: arbiter anti-patterns + code-explorer divergences + missing files + test coverage gaps]
   ```

7. **Write** the synthesized output to `.dev/<slug>/research.md`

8. **Update scratch.md** — append key findings and open questions under the relevant sections

9. **Report**:
   ```
   ## Discovery Complete: <slug>
   Files explored: N | Patterns found: N | Risks: N
   Key finding: [1 sentence]
   Next step: `/plan <slug>`
   ```

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have `brainstorm.md` but no `research.md` — suggest running discovery on those
2. If none found, ask the user what they'd like to discover via `AskUserQuestion`
