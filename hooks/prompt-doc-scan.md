# Prompt Doc Scan Hook

## Purpose

Intelligently scans `.ai-docs/` on prompt submission by extracting search topics from the user's prompt using `claude --bare --model haiku -p`, then matching against cached frontmatter to inject relevant documentation paths with section line ranges.

## Trigger

- **Event**: UserPromptSubmit
- **Condition**: `.ai-docs/` directory exists in the project root

## Behavior

1. Receives prompt JSON via stdin (`prompt`, `session_id`, `cwd`)
2. Extracts 3-8 search topics using `claude --bare --model haiku --json-schema` (uses existing Claude Code authentication — no separate API key needed)
3. Filters out topics already scanned in this session (tracked in `.dev/.ai-docs-session-{id}`)
4. Scores new topics against cached `.ai-docs/` frontmatter using the doc-scanner scoring algorithm
5. Outputs matched docs with HIGH/MEDIUM relevance tiers and section line ranges
6. Updates session state to avoid re-injecting the same docs

## Registration

Add to the consumer project's `.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
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

## Topic Extraction

Uses `claude --bare --model haiku -p` with `--json-schema` for validated structured output. The CLI call uses:
- `--bare`: Fast start, no recursive hooks/plugins/MCP
- `--model haiku`: Cheapest/fastest model, sufficient for topic extraction
- `--system-prompt`: Minimal ~50 token prompt
- `--tools ""`: No tools, pure text-in text-out
- `--json-schema`: Guarantees exact JSON shape with topic array

This uses the existing Claude Code authentication — no separate `ANTHROPIC_API_KEY` needed.

## Session Tracking

State file: `.dev/.ai-docs-session-{session_id}`

Tracks which topics have been scanned and which docs/sections have been injected, so subsequent prompts in the same session only surface NEW matches.

## Notes

- Caps output at 5 docs / 10 sections to avoid context bloat
- Cache invalidated when any `.ai-docs/*.md` file is newer than the cache
- Silent exit on: no `.ai-docs/`, empty prompt, no matches, all topics already scanned
