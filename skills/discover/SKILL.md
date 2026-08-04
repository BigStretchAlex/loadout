---
name: discover
description: Explore a codebase and .ai-docs/ to build grounded discovery findings for a goal. Writes research.md with six sections ready for planning.
user-invocable: false
context: fork
---

# Discover Skill

Explore a problem space by combining documented patterns from `.ai-docs/` (via arbiter) with live codebase traversal (via code-explorer). Synthesize findings into `research.md` — the canonical input for `/plan`.

**Callers**: `/plan` invokes this skill (via the Skill tool) whenever a work item's `research.md` doesn't already exist, instead of reimplementing discovery inline. `/tdd-plan` inherits this transitively through `/plan`'s Phase 1. This skill is `user-invocable: false` (chain-invocable only, per its frontmatter) — it is not meant to be run directly from the `/` menu.

**Fork boundary:** this skill forks whole (`context: fork` above) — no interactive step survives in the design (see Step 3 and Fallback below), so nothing here needs the main session. No outer `agent:` shell: this skill already spawns the real roles (`arbiter`, `code-explorer`) itself, so a second shell would only nest roles for no gain. No `background:`: `/plan` (its only caller) blocks on this skill's `research.md` output before it can continue, so nothing is gained by parallelizing.

## Instructions

1. **Parse arguments**: "$ARGUMENTS" should contain either:
   - A work item slug (e.g., `feat-auth-flow`) — discover within that context
   - A free-form goal description — create a new work item for it
   - If empty, jump to the **Fallback** section at the bottom

2. **Set up the work item directory** — follow `templates/work-item.md` (slug parsing/derivation, `.dev/<slug>/` creation, `scratch.md` init).

3. **Check for existing research** — if `.dev/<slug>/research.md` already exists, reuse it as-is and skip to step 8. No prompt: `discover` is chain-invoked only, and its sole caller (`/plan`, `skills/plan/SKILL.md` step 4) already invokes `discover` only when `research.md` is absent — under that guard this branch is unreachable in normal operation. If it is ever reached anyway (e.g. a stale file from an interrupted run), reusing rather than silently deleting prior work is the safe default; a full restart is always available by deleting `research.md` before invoking `/plan`.

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

6. **Synthesize** findings into the six-section schema defined in `templates/research.md`: **Domain Concepts** and **Technical Patterns** from the arbiter (step 4), **Relevant Code**, **Dependencies**, and **Integration Points** verbatim from code-explorer (step 5), and **Constraints & Risks** synthesized from both (arbiter anti-patterns + code-explorer divergences + missing files + test coverage gaps).

7. **Write** the synthesized output to `.dev/<slug>/research.md`, ending with the handoff footer (schema in `templates/handoff-footer.md`, mirrored in `templates/research.md`):

   ```loadout-handoff
   schema: 1
   artifact: research
   produced_by: /discover
   work_item: .dev/<slug>
   lane: standard
   verification: none
   next_command: /plan
   next_arguments: .dev/<slug>
   ```

   Field semantics: `templates/handoff-footer.md`. `lane` is `standard` here — the lane distinction (`tdd`/`express`) is made later, at planning time (`/tdd-plan` augments `/plan`'s output; `/perform-task`'s express lane bypasses discovery entirely), so `research.md` is never itself tdd/express. This producer sets `verification: none`; note the schema check in step 8 below is a self-check on the artifact, not a verification result reported in this field. `next_command`/`next_arguments` are fixed — discover has no verdict-based routing to compute; every completed discovery leads to `/plan`.

8. **Verify the artifact (self-check)** — re-read `.dev/<slug>/research.md` as written:
   - Confirm all six `templates/research.md` headings are present — `### Domain Concepts`, `### Technical Patterns`, `### Relevant Code`, `### Dependencies`, `### Integration Points`, `### Constraints & Risks` — and each has non-empty content beneath it, not just a bare heading.
   - Confirm every file path cited under **Relevant Code** exists on disk (check each with a read or `test -f`).
   - Confirm the `loadout-handoff` footer is present with all eight keys (`schema`, `artifact`, `produced_by`, `work_item`, `lane`, `verification`, `next_command`, `next_arguments`), and that `artifact: research` and `next_command: /plan`.
   - **If any check fails**: fix the gap — re-synthesize a missing/empty section from the captured arbiter or code-explorer output (step 4/5), correct/remove a stale path, or rewrite the footer — then re-check. Do not proceed to step 9 until this passes.
   - Report explicitly: `Verification: PASS` or `Verification: FAIL — <reason>`. Carry this into step 10's report.

9. **Update scratch.md** — append key findings and open questions under the relevant sections

10. **Report** (this is the whole point of forking — the only thing that leaves this subagent):
   ```
   ## Discovery Complete: <slug>
   Files explored: N | Patterns found: N | Risks: N
   Key finding: [1 sentence]
   Verification: PASS
   Next step: `/plan <slug>`
   ```

## Fallback

If no arguments are provided, this skill cannot proceed without a goal or work-item slug — and since it is chain-invoked only (its sole caller, `/plan`, always supplies one), reaching this path at all means something outside the normal flow invoked it. No prompt (consistent with the fork boundary: a subagent cannot ask the user anything). Instead:

1. Check `.dev/` for work items that have `brainstorm.md` but no `research.md`.
2. Report and stop — no discovery is performed:
   ```
   No goal or work item slug provided to /discover. It is chain-invoked by /plan, which always
   supplies one. Candidates with a brainstorm but no research: [list, or "none found"]
   Invoke /plan <goal-or-slug> instead of /discover directly.
   ```
