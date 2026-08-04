---
paths:
  - "skills/**"
---

# Skill Authoring Rules

Applies to `SKILL.md` files and bundled `references/`/`assets/`. Rationale: `docs/agent-authoring-best-practices.md` §2–§6, §11.

## Structure & frontmatter

- `name` matches the parent directory exactly: lowercase `a-z`, `0-9`, hyphens; no leading/trailing/consecutive hyphens.
- `description` (≤1024 chars) states what the skill does AND when to use it, phrased against user intent ("Use when…"), with explicit boundaries for near-miss cases. It never restates body instructions and never lobbies for invocation.
- Body budget: ≤500 lines / ~5k tokens. Keep in the body: workflow skeleton, gotchas, output contract, pointers with load conditions. Move out: format specs, per-error tables, rare edge-case procedures, long templates. Split by workflow phase, not by topic.
- Reference bundled files by relative path from the skill root; keep references one level deep (a reference never points at further references).
- State *when* to load each reference ("read `references/api-errors.md` if the API returns non-200"), never "see `references/` for details".
- Before shipping: `skills-ref validate` passes; every referenced path exists; every command in the body is runnable as written; no instruction block is duplicated from another skill.

## Body content

- Encode project-specific knowledge: mid-task corrections, real input/output shapes, conventions the agent had to be told. A skill derivable from generic public material about its domain is a candidate for deletion.
- One skill = one coherent unit of work, scoped like a function.
- Gotchas live in the body, never in `references/` — the agent can't recognize the trigger for a non-obvious issue. Every correction made to an agent mid-task gets added to the gotchas section.
- Calibrate control to fragility: prescriptive exact commands only where operations are fragile or sequence is load-bearing; goal + reason everywhere else. Prefer "do X, because Y causes Z" over ALWAYS/NEVER.
- Provide a default tool with escape hatches, not a menu of equals.
- Teach the approach to a class of problems, not the answer to one instance.

## Invocation class

- Every skill declares its class: **Command** (`disable-model-invocation: true`), **Chain** (`user-invocable: false`), or **Open** (neither — a deliberate choice, not a default).
- Side effects the user didn't just ask for (git operations, deletions, bulk writes, expensive scans) ⇒ always Command.
- A Chain skill cannot set `disable-model-invocation: true` (it would block the Skill tool that chains it); its only guard against spurious triggering is a narrowly scoped description.

## Composition & handoffs

- Pick the lightest execution mode that satisfies the context constraint: inline → `context: fork` → spawned agent → skill chain.
- A forked skill receives only its `SKILL.md` as prompt: everything it needs arrives via `$ARGUMENTS` or files it reads itself.
- Every handoff = an artifact conforming to a `templates/` schema **plus** the exact next command, valid in the target's own argument grammar. One argument convention across a workflow, stated in `argument-hint`.
- State the skill always needs at startup is injected via `` !`command` `` preprocessing, not gathered by tool calls in phase 1.
- A same-context skill-to-skill dependency is stated in *both* skills' bodies.

## Verification & pause points

- Every producing phase ends with a self-check of its artifact — required sections present, referenced files exist, line ranges in bounds, validation commands runnable — as a distinct final phase with a pass/fail report.
- Build-class skills execute the plan's per-step validation commands after each step and its acceptance criteria at the end.
- Chain routing must differ by verdict; a verdict that always routes to the same next step is decorative.
- Re-verification after a fix uses the same checker that produced the findings.
- Anything an exit code can decide belongs in a hook, not prose (see `hooks.md` rules).
- Name the workflow's sanctioned pause points; never pause mid-phase for something objectively determinable, and never end a phase with "shall I continue?" when the workflow defines what's next. At each pause present: artifact path, verification result, exact next command.
