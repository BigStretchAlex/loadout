# Scratch Capture Hook

## Purpose

Reminds the assistant to capture insights in scratch memory when working within a `.dev/` work item context. Fires after command execution to prompt reflection on what was learned.

## Trigger

- **Event**: PostToolUse
- **Tools**: Bash
- **Condition**: Currently working in a `.dev/<type>-<slug>/` context

## Behavior

1. The shell script `hooks/scripts/scratch-reminder.sh` checks if recent tool activity involves files within a `.dev/` work item
2. If a work item context is detected and scratch.md exists, it outputs a brief reminder
3. The reminder only fires once per work item per session to avoid noise

## Registration

Add to the consumer project's `.claude/settings.json`:

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

## Notes

- Lightweight shell check — no LLM call
- Only fires once per work item per session (tracks in `.dev/.scratch-reminded`)
- Does not fire if no `.dev/` work item exists
