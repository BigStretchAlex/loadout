# Load Relevant Docs Hook

## Purpose

Automatically scans `.ai-docs/` frontmatter when files are read or searched, injecting relevant documentation paths into the context. Uses session-level caching to avoid repeated scans.

## Trigger

- **Event**: PreToolUse
- **Tools**: Read, Glob
- **Condition**: `.ai-docs/` directory exists in the project root

## Behavior

1. The shell script `hooks/scripts/scan-ai-docs.sh` runs on each qualifying tool call
2. It checks a session cache file (`.dev/.ai-docs-cache`) to avoid rescanning directories already processed this session
3. For new directories, it reads `.ai-docs/` frontmatter and outputs relevant doc paths as context
4. Results are cached per directory for the session lifetime

## Registration

Add to the consumer project's `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Glob",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/loadout/hooks/scripts/scan-ai-docs.sh \"$TOOL_INPUT\""
          }
        ]
      }
    ]
  }
}
```

## Notes

- Uses haiku-weight processing (shell script, no LLM call)
- Cache invalidated when `.ai-docs/` files are modified (checks mtime)
- Only fires when `.ai-docs/` exists — zero overhead on projects without a knowledge base
