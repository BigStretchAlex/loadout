# `.ai-docs/` Frontmatter Standard

Every file in `.ai-docs/` **must** begin with YAML frontmatter that follows this schema. The frontmatter enables fast, content-free discovery by `doc-scanner` — only frontmatter is read during scans.

## Schema

```yaml
---
title: "<Human-readable title>"
domain: "<general|backend|frontend|security|database|deployment|testing|architecture>"
patterns:
  - "<kebab-case-pattern-name>"      # 5+ entries recommended
  - "<variant-name>"                  # include synonyms and aliases
keywords:
  - "<lowercase-supplementary-term>"  # terms not covered by patterns
  - "<another-keyword>"
sections:
  - name: "<Section Heading>"
    line_start: <int>
    line_end: <int>
    summary: "<1-2 sentence description with searchable terms>"
  - name: "<Another Section>"
    line_start: <int>
    line_end: <int>
    summary: "<description>"
---
```

## Field Reference

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `title` | Yes | string | Human-readable document title |
| `domain` | Yes | enum | One of: general, backend, frontend, security, database, deployment, testing, architecture |
| `patterns` | Yes | string[] | Kebab-case pattern names. Include all variations/synonyms. Exact match scores +5 in scanning. |
| `keywords` | Yes | string[] | Lowercase supplementary search terms. Exact match scores +3. |
| `sections` | Yes | object[] | Array of section descriptors with line ranges |
| `sections[].name` | Yes | string | Section heading as it appears in the document |
| `sections[].line_start` | Yes | int | First line of the section (1-indexed) |
| `sections[].line_end` | Yes | int | Last line of the section (1-indexed) |
| `sections[].summary` | Yes | string | 1-2 sentence summary with searchable terms |

## Scoring Algorithm (used by `doc-scanner`)

```
score = 0

For each pattern:
  exact match with query:   score += 5
  contains query:           score += 2

For each keyword:
  exact match with query:   score += 3
  contains query:           score += 1

For each section:
  name contains query:      score += 2
  summary contains query:   score += 2

HIGH:   score >= 5
MEDIUM: score >= 2
LOW:    score >= 1
```

## Guidelines

1. **Patterns are primary** — make them comprehensive (5+ per document). Include exact names, abbreviations, and common synonyms.
2. **Keywords supplement** — use for terms that don't fit as pattern names (verbs, adjectives, technologies).
3. **Section summaries matter** — they're scored during scans. Use specific, searchable terms.
4. **Line numbers must be accurate** — `document-writer` calculates these in a second pass. Use `-1` as placeholder during drafting.
5. **One domain per file** — if content spans domains, split into multiple files.

## Example

```yaml
---
title: "Authentication Patterns"
domain: "security"
patterns:
  - "authentication"
  - "auth-flow"
  - "jwt-authentication"
  - "session-management"
  - "oauth-integration"
  - "token-refresh"
keywords:
  - "login"
  - "logout"
  - "middleware"
  - "bearer token"
  - "cookie"
  - "csrf"
sections:
  - name: "JWT Token Flow"
    line_start: 25
    line_end: 80
    summary: "JWT creation, validation, and refresh flow with middleware integration"
  - name: "Session Management"
    line_start: 82
    line_end: 130
    summary: "Server-side session storage patterns with Redis and cookie configuration"
---
```
