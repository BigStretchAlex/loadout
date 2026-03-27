# Context Loading: How .ai-docs/ Gets Injected

## Overview

Loadout automatically loads relevant `.ai-docs/` documentation into Claude Code's context via two hook scripts. Both use `claude --bare --model haiku -p` for topic extraction against the user's existing Claude Code authentication — no separate API key is needed.

## Hook Pipeline

### 1. UserPromptSubmit → `prompt-scan-docs.sh`

Fires on every user prompt when `.ai-docs/` exists.

```
User prompt
  → claude --bare --model haiku --json-schema -p  (extract 3-8 kebab-case topics)
  → filter out topics already scanned this session
  → score new topics against frontmatter cache (deterministic bash matching)
  → inject matched docs as HIGH/MEDIUM with section line ranges
  → update session state
```

### 2. SubagentStop → `plan-rescan-docs.sh`

Fires when an Explore or Plan agent completes.

```
Previously scanned topics from session file
  → claude --bare --model haiku --json-schema -p  (suggest 3-5 related NEW topics)
  → filter out already-scanned topics
  → score against frontmatter cache
  → inject only NEW matches not already injected
  → update session state
```

## Separation of Concerns

| Layer | Responsibility | Implementation |
|-------|---------------|----------------|
| **Topic extraction** | Understand natural language → kebab-case topics | `claude --bare --model haiku` via CLI |
| **Scoring** | Match topics against frontmatter | Deterministic bash: exact match (5pts), contains (2pts patterns, 1pt keywords), section name/summary (2pts each) |
| **Session tracking** | Avoid duplicate injections | `.dev/.ai-docs-session-{id}` file with `# topics` and `# injected` sections |
| **Caching** | Avoid re-parsing frontmatter | `.dev/.ai-docs-cache` (tab-delimited, rebuilt when any `.ai-docs/*.md` is newer) |

## Claude CLI Flags

```bash
claude --bare --model haiku \
  --system-prompt "..." \   # ~50 token prompt (replaces ~5000 token default)
  --tools "" \              # no tools — pure text-in text-out
  --json-schema "$SCHEMA" \ # validated structured output, guarantees JSON shape
  -p "..." \                # print mode — run and exit
  < /dev/null               # prevent stdin inheritance from hook pipeline
```

- `--bare`: Skips hooks/plugins/MCP/CLAUDE.md discovery (fast start, no recursive hooks)
- `--model haiku`: Cheapest/fastest model — sufficient for topic extraction
- `--json-schema`: Returns `{"topics": ["auth-flow", "error-handling", ...]}` with guaranteed shape
- `< /dev/null`: Required because the hook script consumes stdin for JSON parsing; without this, claude may block waiting on the depleted pipe

## Frontmatter Cache Format

Tab-delimited, one line per doc:

```
.ai-docs/auth-patterns.md\tsecurity\tauthentication,auth-flow,...\tlogin,logout,...\tJWT Token Flow|25|80|summary;Session Management|82|130|summary
```

Fields: `path \t domain \t patterns_csv \t keywords_csv \t sections_csv`

Sections are `;`-separated, each as `name|line_start|line_end|summary`.

## Session File Format

```
# topics
authentication
oauth-integration
database-queries
# injected
auth-patterns.md|JWT Token Flow|25-80
database-patterns.md|Query Optimization|30-65
```

Parsed with `awk '/^# topics$/{f=1; next} /^#/{f=0} f'` to extract topics between section headers.

## Scoring Thresholds

- **HIGH relevance**: score >= 5 (at least one exact pattern match)
- **MEDIUM relevance**: score >= 2
- **Max output**: 5 docs, 10 sections total (prevents context bloat)

## Output Format

```
[loadout] Relevant .ai-docs/ for this prompt:

HIGH: .ai-docs/auth-patterns.md
  - "JWT Token Flow" (lines 25-80): JWT creation, validation, and refresh flow
  - "Session Management" (lines 82-130): Server-side session storage patterns

MEDIUM: .ai-docs/error-handling.md
  - "API Error Responses" (lines 40-75): Standardized error response format

Read sections with: Read .ai-docs/<file>.md lines <start>-<end>
```

## Testing

Tests use a stub `claude` script on PATH that returns canned topic JSON based on the user prompt content. Run:

```bash
bash tests/test-prompt-scan.sh
```

The stub extracts the user prompt after `Prompt: ` in the `-p` argument and pattern-matches to return appropriate topics. Test 8 verifies graceful degradation when the claude CLI fails.
