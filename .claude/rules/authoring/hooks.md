---
paths:
  - "hooks/**"
---

# Hook Authoring Rules

Applies to hook configs and hook scripts. Rationale: `docs/agent-authoring-best-practices.md` §8.

## Registration & scope

- Distribute via `hooks/hooks.json` (or the manifest `hooks` key) with script paths resolved through `${CLAUDE_PLUGIN_ROOT}`. Never a copy-into-project installer — copied scripts fossilize — except for genuinely project-local opt-ins.
- A hook's matcher is as narrow as its purpose; a hook must not fire where it contradicts the target's own contract.
- Per-session behavior keys on session ID, never on a once-ever flag file.
- Agent-frontmatter hooks are silently ignored for plugin agents; attach at plugin or skill level only.

## Output channels — write against the event's real channel, and document in-file which one and why

| Event | How output reaches the model |
|---|---|
| `UserPromptSubmit`, `SessionStart` | plain stdout on exit 0 **is** injected as context |
| `PostToolUse` | plain stdout is transcript-only (model-invisible); use JSON `{"hookSpecificOutput": {"additionalContext": "..."}}`, ≤10,000 chars |
| `PreToolUse` | exit 2 blocks the tool call; stderr goes to the model |
| `SubagentStop` | exit 2 blocks completion; stderr goes back to the agent |

- A `PostToolUse` linter printing plain stdout is a placebo — the model never sees its findings.
- Deterministic completion gates (`SubagentStop` + exit 2 running real tests) are the enforcement layer the model cannot talk its way past; prefer them over prose verification for anything an exit code can decide.

## Context-injection hooks

- Deterministic only: no LLM calls, exact-match against author-curated frontmatter vocabulary, silent when unsure. Fuzzy matching fails toward *wrong* context; exact matching fails toward silence, which is auditable.
- Validate line ranges at index-build time — never extract from inside frontmatter, never past current file length.
- Hard character cap, ranked cutoff, session-level dedupe.

## Project commands

- Resolve "the project's test/lint/build" through one contract used by every hook and gate: named env vars (`PROJECT_TEST_CMD`-style) if set → documented project-config fallback → exit 0 silently. Never hardcode a package manager, test runner, or linter.
