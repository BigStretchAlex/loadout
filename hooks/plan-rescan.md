# Plan Rescan Hook

## Purpose

Re-evaluates `.ai-docs/` topics after Explore or Plan agents complete during plan mode. Discovers new related topics based on what was already identified, then injects any newly matched documentation that wasn't surfaced on the initial prompt scan.

## Trigger

- **Event**: SubagentStop
- **Condition**: `.ai-docs/` directory exists, session state file exists, completed agent is an Explore or Plan type

## Behavior

1. Receives agent completion JSON via stdin (`session_id`, `subagent_type`, `cwd`)
2. Checks if the completed agent is an Explore or Plan type — exits silently for other agent types
3. Reads previously scanned topics from the session state file
4. Uses `claude --bare --model haiku --json-schema -p` to suggest 3-5 additional related topics based on the existing topic set
5. Diffs new topics against previously scanned topics
6. Scores new topics against cached `.ai-docs/` frontmatter
7. Outputs only NEW matches not already injected in this session
8. Updates session state with new topics and injected docs

## Registration

Add to the consumer project's `.claude/settings.json`:

```json
{
  "hooks": {
    "SubagentStop": [
      {
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

## Notes

- Only fires for Explore and Plan agent types — other agents are ignored
- Uses `claude --bare --model haiku -p` for topic discovery (existing Claude Code auth, no separate API key needed)
- Reuses the same session state and cache files as `prompt-doc-scan`
- Caps output at 5 docs / 10 sections
- Silent exit on: no `.ai-docs/`, no session file, non-Explore agent, no new matches
