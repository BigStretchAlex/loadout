# Plugin Authoring Principles

Core rules for developing this plugin (skills, agents, hooks, templates, scripts). Path-scoped companion files in this directory load component-specific rules when you work on matching files. Rationale, examples, and platform details: `docs/agent-authoring-best-practices.md`.

- **Judgement over rules.** A body states the goal, the genuinely non-obvious constraints, and the output contract — nothing else. Cut any instruction a competent engineer would infer from the goal ("do not skip steps", "be thorough").
- **Interfaces over examples.** Communicate output shape by pointing at a schema/template file in `templates/`, never by embedding a filled-in sample run. Load-bearing syntax examples go in `references/`, loaded on demand.
- **Progressive disclosure.** Always-loaded content is a shared budget: descriptions ≤ what triggering needs, bodies ≤ ~500 lines / ~5k tokens, detail in `references/`/`scripts/`/`assets/` with explicit load conditions.
- **Single source of truth.** An instruction block used by two or more skills/agents lives in exactly one file, referenced from both. Every copy is a divergence waiting to happen.
- **Schemas over prose specs.** Every artifact produced or consumed has a named schema file in `templates/`, referenced by path — including machine-readable frontmatter that hooks parse.
- **Verify, don't trust.** Every producing step checks its own artifact before reporting success; every executing step runs the plan's own validation commands. A "done" claim without an executed check is a defect.
- **Add what the agent lacks; omit what it knows.** For each sentence ask: would the agent get this wrong without it? If no, cut it. If unsure, measure it.
- **Skills first; agents only for a named pressure.** Start every new capability as a skill — cheaper, visible, user-invocable. Introduce an agent only when you can name which pressure it relieves: context isolation (the work reads far more than it returns), tool restriction (the role must be denied tools), model tiering, or parallelism. When an existing skill grows a phase that reads far more than it returns, that phase is the next agent — carve it out with a schema for its return value.
