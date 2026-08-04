# Discovery Output Schema

The canonical six-section shape for a work item's `research.md`, produced by synthesizing the **arbiter** and **code-explorer** agents' outputs.

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

## Handoff footer

Schema defined in `templates/handoff-footer.md`. Append after the six sections above — always the last
thing in `research.md`:

````markdown
```loadout-handoff
schema: 1
artifact: research
produced_by: /discover
work_item: .dev/<slug>
lane: standard | tdd | express
verification: none
next_command: /plan
next_arguments: .dev/<slug>
```
````

## Producing it

1. Spawn the **arbiter** agent: `Find patterns, conventions, and anti-patterns in .ai-docs/ relevant to: [goal]`. Capture **Domain Concepts** and **Technical Patterns** from its summary/recommendations.
2. Spawn the **code-explorer** agent with the goal, the Technical Patterns from step 1 (as navigation hints only), and the work item path. Capture **Relevant Code**, **Dependencies**, and **Integration Points** verbatim.
3. Synthesize both into the schema above and write to `.dev/<slug>/research.md`, ending with the handoff footer.

`skills/discover/SKILL.md` is the canonical producer of this schema. Any skill that needs discovery findings should invoke `discover` rather than re-running steps 1–3 inline.
