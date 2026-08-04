# Loadout Plugin

This is the **Loadout** Claude Code plugin. It provides skills, agents, and hooks for structured software development workflows.

## Templates

Reusable file templates are stored in the `templates/` directory of this plugin. When any skill or agent instructs you to initialize or create a file from a template, read the corresponding file from `templates/`:

**Path resolution.** Every `templates/…`, `docs/…`, or other in-plugin path referenced from a skill or agent body is relative to the plugin root, not the consuming project's working directory (an installed plugin's CWD is the consuming project). Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` inline anywhere it appears in skill and agent content, resolving it to the plugin's absolute install path — that is the one resolution mechanism for these paths; never climb out with `../../`.

| Template | File | Used for |
|----------|------|----------|
| Scratch memory | `templates/scratch.md` | Per-work-item working notebook |
| Brainstorm | `templates/brainstorm.md` | Adversarial exploration output |
| Plan | `templates/plan.md` | Implementation plan structure |
| AI docs frontmatter | `templates/ai-docs-frontmatter-standard.md` | `.ai-docs/` knowledge base files |
| Rules standard | `templates/rules-standard.md` | `.claude/rules/` coding rule files |
| Tasks | `templates/tasks.md` | Per-work-item task/progress tracking |
| Confidence Policy | `templates/confidence-policy.md` | Objective/subjective auto-apply classification |
| Work item | `templates/work-item.md` | Work item slug derivation and `.dev/<slug>/` setup |
| Research schema | `templates/research.md` | Discovery output six-section schema |
| Testing rules loading | `templates/testing-rules.md` | Locating and consuming `.claude/rules/` testing rules |
| Review report | `templates/review-report.md` | Reviewer agent output contract and identity header |
| Handoff footer | `templates/handoff-footer.md` | Machine-readable `loadout-handoff` schema appended to every lifecycle artifact |
| Line-range verification | `templates/line-range-verification.md` | Self-check for `document-writer`-written `sections[]` line ranges before a done-claim artifact is written |
