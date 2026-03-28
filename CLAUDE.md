# Loadout Plugin

This is the **Loadout** Claude Code plugin. It provides skills, agents, and hooks for structured software development workflows.

## Templates

Reusable file templates are stored in the `templates/` directory of this plugin. When any skill or agent instructs you to initialize or create a file from a template, read the corresponding file from `templates/`:

| Template | File | Used for |
|----------|------|----------|
| Scratch memory | `templates/scratch.md` | Per-work-item working notebook |
| Brainstorm | `templates/brainstorm.md` | Adversarial exploration output |
| Plan | `templates/plan.md` | Implementation plan structure |
| AI docs frontmatter | `templates/ai-docs-frontmatter-standard.md` | `.ai-docs/` knowledge base files |
