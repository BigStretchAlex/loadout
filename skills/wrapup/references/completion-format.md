# Wrapup completion message skeleton

Used by Phase 6 to print the message after `.dev/.wrapup` has been written.

```
## Wrapup Complete: [range description]

**Commits analyzed**: N
**Uncommitted changes included**: yes|no
**Insights reviewed**: N
**Promoted to .ai-docs/**: N
**Skipped**: N
**Line-range verification**: PASS

### Promoted
- [pattern name] → [target document]

### Skipped
- [insight]: [reason]

State updated: .dev/.wrapup (last_commit: <short SHA>)
```
