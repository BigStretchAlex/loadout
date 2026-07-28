---
name: install-hooks
description: Install loadout hooks into a consuming project's .claude/settings.json. Use this skill whenever the user wants to set up, add, enable, or configure loadout hooks in their project — including explore agent doc injection, scratch memory reminders, or observability/logging hooks. Trigger even if the user just says "set up hooks", "add the explore-ai-docs hook", "enable scratch capture", or "I want to use loadout hooks".
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit
---

# Install Hooks Skill

Guide the user through selecting and installing loadout hooks into their project's `.claude/settings.json`.

## Hook Catalog

Present these hooks to the user grouped by category. For each hook show: name, event, and what it does.

### Core Hooks

| Name | Event | What it does |
|------|-------|-------------|
| `scratch-capture` | PostToolUse (Bash) | After Bash commands, reminds the assistant to capture insights in the active work item's `scratch.md`. Fires once per work item per session. |
| `explore-ai-docs` | PreToolUse (Agent) | Before every Explore agent invocation, injects an instruction to check `.ai-docs/` frontmatter first — read frontmatter to assess relevance, then use line ranges to read only relevant sections. Requires `.ai-docs/` directory to exist. |

### Quality Hooks

| Name | Event | What it does |
|------|-------|-------------|
| `post-edit-simplify` | PostToolUse (Edit\|Write) | After a file is edited or created, spawns an agent that reads the file, checks `.ai-docs/` patterns, and reports simplification opportunities using the same analysis as `/simplify`. Does not modify the file. |
| `post-edit-lint` | PostToolUse (Edit\|Write) | After a file is edited or created, spawns an agent that discovers the lint command from `.ai-docs/` (or common config files like `package.json`, `.eslintrc*`, `pyproject.toml`) and runs it on the file. Reports errors/warnings with file:line references. |
| `ts-lint` | PostToolUse (Edit\|Write) | Deterministic command hook (no agent): after a JS/TS file (`.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`) is edited or created, runs ESLint on it via `npx` and prints the results. Report-only — never blocks the edit. Skips silently if the file isn't JS/TS or the project has no ESLint config. |
| `jest-test` | PostToolUse (Edit\|Write) | Deterministic command hook (no agent): after a JS/TS file is edited or created, runs `jest --findRelatedTests` on it and prints the results. Report-only — never blocks the edit. Skips silently if the file isn't JS/TS or Jest isn't present in the project. |

**Note**: `post-edit-simplify` and `post-edit-lint` use agent sub-processes; `ts-lint` and `jest-test` are plain shell commands. They all fire on both `Edit` and `Write` tool use. The agent hooks work best with a `.ai-docs/` directory but fall back to config file inspection when not present.

**TypeScript/JavaScript projects**: prefer `ts-lint` over `post-edit-lint`; don't install both (guidance — the installer won't stop you, but they'd duplicate lint feedback on every edit).

### Observability Hooks (for testing/debugging the workflow)

| Name | Event | What it does |
|------|-------|-------------|
| `log-agent-spawn` | PreToolUse (Agent) | Logs every subagent spawn (type, description, background flag) to `.dev/loadout-test.log` |
| `log-agent-stop` | SubagentStop | Logs every subagent completion (type, session ID) to `.dev/loadout-test.log` |
| `log-skill-invoke` | PreToolUse (Skill) | Logs every skill invocation (name, args) to `.dev/loadout-test.log` |
| `log-scratch-reminder` | PostToolUse (Bash) | **Replaces** `scratch-capture` — same behavior but also logs when the reminder fires |

**Note**: Do not combine `log-scratch-reminder` with `scratch-capture` — the log variant already includes the core behavior.

## Instructions

1. **Determine the plugin directory** — the script at `skills/install-hooks/scripts/install-hooks.py` is relative to the loadout plugin. Resolve the absolute path:
   ```bash
   # The skill file is at: <plugin_dir>/skills/install-hooks/SKILL.md
   # Derive PLUGIN_DIR by finding where loadout is installed.
   # In Claude Code the plugin dir is available via the skill path, or ask the user.
   ```
   If you're unsure of the plugin dir, use `AskUserQuestion` to ask the user for the path to the loadout plugin directory before proceeding.

2. **Present the catalog** — use `AskUserQuestion` to show the hook catalog table above and ask:
   - Which hooks do they want to install?
   - Are they setting up for normal use (core hooks) or testing/debugging (observability hooks)?
   - Where is their project's `.claude/settings.json` (or CWD if it's the current directory)?

   Format the question clearly with the full catalog so they can choose by name.

3. **Run the install script** — once you have the selections:
   ```bash
   python3 <plugin_dir>/skills/install-hooks/scripts/install-hooks.py \
     --plugin-dir <plugin_dir> \
     --project-dir <project_dir> \
     --hooks <hook1> <hook2> ...
   ```
   The script:
   - Copies the required hook scripts and data files from the plugin into `<project_dir>/.claude/hooks/` (so the project is self-contained and `settings.json` is portable across machines)
   - Reads the existing `.claude/settings.json` (or creates it), merges in the selected hooks without clobbering existing configuration, and writes the result
   - Hook commands reference `.claude/hooks/scripts/<script>.sh` (relative paths), not absolute plugin paths

4. **Report** — show the user:
   - Which scripts were copied to `.claude/hooks/scripts/`
   - Which hooks were added
   - The updated hook block in `settings.json`
   - A reminder that observability hooks log to `.dev/loadout-test.log` (run `tail -f .dev/loadout-test.log` in a second terminal)
   - If `prompt-doc-scan` was installed: remind them they need a `.ai-docs/` directory with frontmatter files for it to activate

## Common Setups

**Typical project (doc-aware workflow)**:
- `scratch-capture` + `explore-ai-docs`

**With automatic quality feedback**:
- `scratch-capture` + `explore-ai-docs` + `post-edit-simplify` + `post-edit-lint`

**TypeScript/JavaScript project**:
- `scratch-capture` + `explore-ai-docs` + `ts-lint` + `jest-test` (use `ts-lint` instead of `post-edit-lint`)

**Testing the loadout workflow**:
- `log-agent-spawn` + `log-agent-stop` + `log-skill-invoke` + `log-scratch-reminder`
