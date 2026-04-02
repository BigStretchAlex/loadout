# Installing Loadout Hooks

Loadout hooks run as shell scripts triggered by Claude Code events. They are optional but significantly improve the workflow — especially `prompt-doc-scan`, which makes the `.ai-docs/` knowledge base active.

## How Doc Scanning and Reading Works

The doc-scan hooks implement a two-stage pipeline: **scan** (find relevant docs) then **read** (load the specific sections).

### Stage 1: Scan — hook injects references on every prompt

When you submit a prompt, `prompt-scan-docs.sh` fires automatically:

1. Extracts 3–8 search topics from your prompt using `claude --bare --model haiku`
2. Scores topics against cached `.ai-docs/` frontmatter (patterns, keywords, section names)
3. Injects matched sections as `HIGH` or `MEDIUM` relevance with exact line ranges

The hook writes its output directly into Claude's context:

```
[loadout] Relevant .ai-docs/ for this prompt:

HIGH: .ai-docs/auth-patterns.md
  - "JWT Token Flow" (lines 25-80): JWT creation, validation, and refresh flow
  - "Session Management" (lines 82-130): Server-side session storage patterns

MEDIUM: .ai-docs/error-handling.md
  - "API Error Responses" (lines 40-75): Standardized error response format

Read sections with: Read .ai-docs/<file>.md lines <start>-<end>
```

### Stage 2: Read — Claude loads the referenced sections

With the injected references in context, Claude reads only the specific line ranges that are relevant — not entire files. For example:

```
Read .ai-docs/auth-patterns.md lines 25-80
Read .ai-docs/error-handling.md lines 40-75
```

This keeps context focused. A 500-line doc with 5 sections might contribute only 55 lines if only one section is relevant.

### Stage 3: Rescan — after exploration agents complete

When `/plan` runs an Explore or Plan agent, `plan-rescan-docs.sh` fires on `SubagentStop`. It suggests new related topics based on what was already found, then injects any newly matched sections that weren't surfaced on the initial prompt. This catches docs that only become relevant once the codebase has been explored.

### Prerequisite: `.ai-docs/` with frontmatter

The scan hooks only activate when `.ai-docs/` exists and contains files with valid frontmatter. Run `/loadout:init-docs` to bootstrap the knowledge base from your codebase, or see `templates/ai-docs-frontmatter-standard.md` for the schema.

---

## Quick Install (Recommended)

From within any project that has loadout loaded as a plugin:

```
/loadout:install-hooks
```

This skill lists the available hooks, asks which ones you want, and edits `.claude/settings.json` for you.

## Manual Install

If you prefer to configure hooks directly, add them to your project's `.claude/settings.json`.

### Core Hooks

These are the hooks most projects should use:

#### `prompt-doc-scan` — UserPromptSubmit

Scans `.ai-docs/` on every prompt. Extracts topics from the prompt using `claude --bare --model haiku`, scores them against cached frontmatter, and injects matched doc sections (with line ranges) into context.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/loadout/hooks/scripts/prompt-scan-docs.sh"
          }
        ]
      }
    ]
  }
}
```

Requires a `.ai-docs/` directory with frontmatter-annotated docs. Silent exit if `.ai-docs/` doesn't exist.

#### `plan-rescan` — SubagentStop

After an Explore or Plan agent completes, discovers additional `.ai-docs/` topics that weren't surfaced on the initial prompt scan. Best used together with `prompt-doc-scan`.

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/loadout/hooks/scripts/plan-rescan-docs.sh"
          }
        ]
      }
    ]
  }
}
```

Silent exit for non-Explore/Plan agents and when no new matches are found.

#### `scratch-capture` — PostToolUse (Bash)

After Bash commands, reminds the assistant to capture insights into the active work item's `scratch.md`. Fires once per work item per session.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/loadout/hooks/scripts/scratch-reminder.sh"
          }
        ]
      }
    ]
  }
}
```

### All Three Core Hooks Together

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/loadout/hooks/scripts/prompt-scan-docs.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/loadout/hooks/scripts/plan-rescan-docs.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/loadout/hooks/scripts/scratch-reminder.sh"
          }
        ]
      }
    ]
  }
}
```

Replace `/path/to/loadout` with the actual path to your loadout plugin directory.

## Observability Hooks

These hooks log workflow activity to `.dev/loadout-test.log`. Useful for verifying the plugin is working or debugging the workflow. The `log-doc-scan`, `log-plan-rescan`, and `log-scratch-reminder` hooks are **tee wrappers** — they run the corresponding core hook and log the output, so they replace (not supplement) their core counterparts.

| Hook | Replaces | What it logs |
|------|----------|-------------|
| `log-agent-spawn` | — | Subagent spawns: type, description, background flag |
| `log-agent-stop` | — | Subagent completions: type, session ID |
| `log-skill-invoke` | — | Skill invocations: name, args |
| `log-doc-scan` | `prompt-doc-scan` | Doc-scan matches (or "no matches") |
| `log-plan-rescan` | `plan-rescan` | Rescan output after explore agents |
| `log-scratch-reminder` | `scratch-capture` | When the scratch reminder fires |

Install via `/loadout:install-hooks` and select the observability group, or use `install-hooks.py` directly:

```bash
python3 /path/to/loadout/skills/install-hooks/scripts/install-hooks.py \
  --plugin-dir /path/to/loadout \
  --project-dir . \
  --hooks log-agent-spawn log-agent-stop log-skill-invoke \
          log-doc-scan log-plan-rescan log-scratch-reminder
```

Monitor in a second terminal while running the workflow:

```bash
tail -f .dev/loadout-test.log
```

## Using `install-hooks.py` Directly

The install script can be run from the command line for scripted setup or CI:

```bash
python3 /path/to/loadout/skills/install-hooks/scripts/install-hooks.py \
  --plugin-dir /path/to/loadout \
  --project-dir /path/to/your/project \
  --hooks prompt-doc-scan plan-rescan scratch-capture
```

Options:
- `--dry-run` — preview changes without writing to disk
- `--hooks` — space-separated list of hook names to install

The script merges hooks into the existing `.claude/settings.json` without clobbering other configuration. Running it twice is safe — already-installed hooks are skipped.

Available hook names: `prompt-doc-scan`, `plan-rescan`, `scratch-capture`, `log-agent-spawn`, `log-agent-stop`, `log-skill-invoke`, `log-doc-scan`, `log-plan-rescan`, `log-scratch-reminder`

## Notes

- **Authentication**: The doc-scan hooks use `claude --bare --model haiku -p` for topic extraction, which reuses your existing Claude Code authentication. No separate `ANTHROPIC_API_KEY` is needed.
- **Performance**: `scratch-capture` is a pure shell check with no LLM call. `prompt-doc-scan` and `plan-rescan` each make one fast Haiku call.
- **Silent exit**: All hooks exit silently when their conditions aren't met (no `.ai-docs/`, no active work item, etc.). They won't interfere with unrelated work.
- **Settings file location**: Hooks go in the project-level `.claude/settings.json`, not `~/.claude/settings.json`. This keeps hook configuration per-project.
