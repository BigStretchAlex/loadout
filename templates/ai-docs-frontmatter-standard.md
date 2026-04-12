# `.ai-docs/` Frontmatter Standard

Every file in `.ai-docs/` **must** begin with YAML frontmatter that follows this schema. The frontmatter enables fast, content-free discovery by `doc-scanner` — only frontmatter is read during scans.

All agents that create or update docs MUST read this file first.

## Schema

```yaml
---
title: "<Human-readable title>"
document_type: technical_guide        # or: reference (machine-read only, no LLM synthesis)
domain: "<general|backend|frontend|security|database|deployment|testing|architecture>"

# SCORING FIELDS — directly affect doc-scanner relevance score
patterns:
  - "<kebab-case-pattern-name>"      # 5+ entries recommended
  - "<variant-name>"                  # include synonyms and aliases
keywords:
  - "<lowercase-supplementary-term>"  # terms not covered by patterns
  - "<another-keyword>"
topics:
  - "<human-readable subject area>"   # MUST use arbiter vocabulary where applicable
  - "<another topic>"

# METADATA FIELDS — used by hooks and agent enhancements
load_frequency: high                  # high | medium | low | reference
content_size: small                   # small (<150 lines) | medium (150-300 lines) | large (>300 lines)
standalone: true                      # true = can be understood alone; false = load related_docs too
task_triggers:                        # REQUIRED — 1-3 generic trigger categories from the canonical list
  - create_feature                    # see Canonical task_triggers List below — never invent values
  - aggregate_change
related_docs:                         # sibling docs to co-load when standalone: false
  - add-new-aggregate.md

purpose: "One sentence describing what this document enables an agent to do"
updated: YYYY-MM-DD
sections:
  - name: "<Section Heading>"
    line_start: <int>
    line_end: <int>
    line_count: <int>
    summary: "<1-2 sentence description with searchable terms>"
  - name: "<Another Section>"
    line_start: <int>
    line_end: <int>
    line_count: <int>
    summary: "<description>"
---
```

## Field Reference

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `title` | Yes | string | Human-readable document title |
| `document_type` | Yes | enum | `technical_guide` or `reference` (reference = machine-read only, never synthesized) |
| `domain` | Yes | enum | One of: general, backend, frontend, security, database, deployment, testing, architecture |
| `patterns` | Yes | string[] | Kebab-case pattern names. Include all variations/synonyms. Exact match scores +5 in scanning. |
| `keywords` | Yes | string[] | Lowercase supplementary search terms. Exact match scores +3. |
| `topics` | Yes | string[] | Human-readable subject areas broader than patterns. MUST use arbiter vocabulary. Exact match scores +3. |
| `load_frequency` | Yes | enum | `high` \| `medium` \| `low` \| `reference` — controls scoring bonus and synthesis eligibility |
| `content_size` | Yes | enum | `small` (<150 lines) \| `medium` (150–300 lines) \| `large` (>300 lines) |
| `standalone` | Yes | bool | `true` = self-contained; `false` = always surface `related_docs` alongside it |
| `task_triggers` | Yes | string[] | 1-3 generic trigger categories from the canonical list. Exact match scores +4. Required for all docs — new and legacy. |
| `related_docs` | No | string[] | Sibling docs to co-load when `standalone: false` |
| `purpose` | Yes | string | One sentence describing what this document enables an agent to do |
| `updated` | Yes | date | Last updated date (YYYY-MM-DD) |
| `sections` | Yes | object[] | Array of section descriptors with line ranges |
| `sections[].name` | Yes | string | Section heading as it appears in the document |
| `sections[].line_start` | Yes | int | First line of the section (1-indexed) |
| `sections[].line_end` | Yes | int | Last line of the section (1-indexed) |
| `sections[].line_count` | Yes | int | Number of lines in the section |
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

For each topic:
  exact match with query:   score += 3
  contains query:           score += 1

For each section:
  name contains query:      score += 2
  summary contains query:   score += 2

For task_triggers:
  exact match with query:   score += 4
  contains query:           score += 1

load_frequency == "high":       score += 2 (bonus)
load_frequency == "reference":  score = 0  (never synthesize)

HIGH:   score >= 5
MEDIUM: score >= 2
LOW:    score >= 1
```

## Canonical task_triggers List

This is the single source of truth for valid `task_triggers` values. **Never invent new trigger names** — always pick 1-3 from this list. Use `domain` + `keywords` + `patterns` as secondary discriminators when multiple docs share the same trigger.

| Group | Generic Trigger | Description | Example Specific Triggers |
|---|---|---|---|
| Feature / Component | `create_feature` | New feature, domain entity, endpoint, service, lambda | new_component, new_endpoint, add_service, sqs_handler |
| Aggregate Operations | `aggregate_change` | Extend aggregates, add methods, write mappers/repos | add_method, write_mapper, write_repository |
| API & Schema | `api_design` | API changes, schemas, Zod, validation, result types | api_change, schema_change, zod_schema, result_type |
| Database | `database_change` | Migrations, queries, RLS, tenant-scoped data | database_migration, add_column, rls_query, tenant_scoped_query |
| Auth & Security | `auth_change` | Auth context, authorizers, IAM, multi-tenant, permissions | lambda_authorizer, cognito_trigger, iam_setup, tenant_isolation |
| Error Handling | `error_handling` | Error classes, handling strategies | custom_error_class |
| Architecture | `architecture_question` | DI wiring, file placement, data access, factory functions | composition_root, wire_dependencies, data_access_layer |
| Testing | `testing` | Write/fix unit, integration, e2e tests, mocks, test data | write_unit_test, mock_dependency, database_test, jest_config |
| Test Strategy | `test_strategy` | Coverage decisions, what/how much to test | test_coverage_decision, how_much_to_test |
| Infra & Deployment | `infrastructure_change` | IaC, CI/CD, deployment, new environments | iac, cicd_change, deployment_change |
| Dev Operations | `dev_ops` | Builds, bootstrapping, commands, onboarding | run_build, bootstrap, artifact_promotion |
| UI Components | `ui_component` | New/extending UI components, styling, layouts | new_component, design_system, layout_change |
| State Management | `state_management` | State stores, context, reducers, derived state | context_provider, zustand_store, reducer |
| Data Fetching | `data_fetching` | Client-side queries, caching, mutations | react_query, swr, fetch_hook |
| Code Review | `code_review` | Review standards, checklists | review_checklist |
| Business Workflow | `workflow` | Business processes, state machines, event flows | state_machine, event_flow, orchestration |
| Performance | `performance` | Optimization, caching strategies, bundle size, profiling | cache_strategy, bundle_optimization |
| Observability | `observability` | Logging, monitoring, tracing, alerting | structured_logging, error_tracking, alerting |

### task_triggers Guidance

**Primary classification**: `task_triggers` is the broadest signal — it tells the arbiter which docs are relevant to a request type before any keyword matching happens. A doc tagged `create_feature` scores +4 when the arbiter is researching a feature-creation task.

**Secondary discrimination**: When two docs share the same trigger, `domain` + `keywords` + `patterns` distinguish them:

```yaml
# Backend feature doc
task_triggers: [create_feature, aggregate_change]
domain: backend
keywords: [lambda, sqs, repository, mapper]

# Frontend feature doc
task_triggers: [create_feature, ui_component]
domain: frontend
keywords: [react, tsx, props, component]
```

Both score +4 for `create_feature`, but a query for "React component" will score the frontend doc higher via keyword matching.

**Scoring note**: +4 for exact trigger match, +1 for partial. A single trigger match pushes a doc above the HIGH threshold (≥5) before patterns/keywords are even considered.

## Arbiter Topic Vocabulary

The arbiter generates these exact strings as search topics. Use them verbatim in your `topics[]`. Every document MUST include at least one verbatim match.

**Backend tasks**: `backend patterns`, `coding best practices`, `api design`, `data storage`, `testing patterns`
**Architecture tasks**: `architecture patterns`, `design patterns`, `technology decisions`
**Troubleshooting**: `error handling`, `debugging patterns`, `logging`
**Deployment tasks**: `deployment`, `ci-cd`, `infrastructure`
**Security tasks**: `authentication`, `authorization`, `security`
**Database tasks**: `database`, `schema-evolution`, `data storage`

Always include `coding best practices` for implementation guides. Always include `testing patterns` for test-related docs.

## Document Size Rules

- **Ideal**: 50–100 lines of content
- **Maximum**: 300 lines
- **If over 300 lines**: split into focused child files by section group
- Each child file gets its own frontmatter with `related_docs` pointing to siblings

## Section Naming Rules

Section names and summaries are scored. Write them to match natural search queries:
- ✅ "Factory Function Pattern" — matches "factory function" query (+4)
- ✅ "Row Level Security (RLS) Session Management" — matches "row level security", "RLS" (+4 each)
- ❌ "Overview" — matches nothing useful
- ❌ "Key Patterns" — too generic

## Domain Values

| Domain | Use for |
|--------|---------|
| `backend` | TypeScript services, repositories, API handlers, domain models |
| `frontend` | UI components, client-side logic, framework patterns |
| `testing` | Test strategies, Jest config, test patterns |
| `deployment` | CI/CD, Atmos, GitHub Actions, infrastructure pipelines |
| `security` | Auth, JWT, Cognito, authorizers, token handling |
| `database` | Flyway, SQL migrations, schema design |
| `architecture` | Cross-cutting structural patterns (use sparingly — prefer specific domain) |
| `general` | Commands, tooling, project setup |

## Field Guidance

### patterns[]
Ask "what exact term would someone search to find this?" — that's a pattern entry. Use hyphenated, specific identifiers (5+ per document). Include exact names, abbreviations, and common synonyms. These score highest (+5 exact match).

### keywords[]
Specific library names, TypeScript types, config keys, tool names. NOT generic nouns. Remove `typescript` from all files — it's in nearly every file and provides zero discrimination.

### topics[]
Pick from the arbiter vocabulary table above. Always include `coding best practices` for implementation guides. Match the arbiter's exact strings to ensure scoring. Use 3–7 human-readable subject areas per document. Do not repeat pattern names here; topics describe what the document is *about* at a conceptual level.

### sections[].summary
Write to win scoring, not to describe. Include key terms in plain prose. "Zod schema definition and type inference for domain models" beats "How Zod schemas work" because it hits `schema`, `type inference`, `domain`. Use `-1` as placeholder for line numbers during drafting.

### load_frequency
- `high`: patterns used in almost every coding task (hexagonal overview, core patterns, testing basics)
- `medium`: task-category specific (migration guides, aggregate creation, auth docs)
- `low`: niche/operational (environment setup, CI/CD specifics, Cognito triggers)
- `reference`: machine-read only, never synthesized by LLM (project-commands)

### standalone
- `true`: document is self-contained and can be understood without related docs
- `false`: document is part of a cluster — always surface `related_docs` alongside it

### task_triggers[]
**Required for all docs** (new and legacy). Select 1-3 values from the Canonical task_triggers List. Never invent new trigger names. Use `domain` + `keywords` + `patterns` to differentiate docs that share the same trigger. If a legacy doc is missing this field, add it immediately — do not leave it unset.

## Anti-Patterns

- ❌ `keywords: [typescript]` — generic, in every file, scores on every query, pollutes results
- ❌ `topics: [backend]` — use `backend patterns` to match arbiter vocabulary
- ❌ `topics: [testing]` — use `testing patterns` to match arbiter vocabulary
- ❌ Section summary: "How Flyway works" — add specifics: "Flyway directory structure, forward-only migrations, checksum immutability, versioned naming"
- ❌ One massive section covering 300+ lines — split into granular sections (each section = scoring surface)
- ❌ `load_frequency: high` on every doc — defeats the purpose; be honest about usage frequency
- ❌ `domain: backend` for auth/security docs — use `domain: security`
- ❌ `domain: deployment` for database migration docs — use `domain: database`

## Example

```yaml
---
title: "Authentication Patterns"
document_type: technical_guide
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
topics:
  - "authentication"
  - "authorization"
  - "security"
  - "coding best practices"
load_frequency: medium
content_size: small
standalone: true
task_triggers:
  - auth_change
  - create_feature
purpose: "Enables agents to implement JWT authentication flows and session management patterns"
updated: 2026-04-10
sections:
  - name: "JWT Token Flow"
    line_start: 25
    line_end: 80
    line_count: 56
    summary: "JWT creation, validation, and refresh flow with middleware integration"
  - name: "Session Management"
    line_start: 82
    line_end: 130
    line_count: 49
    summary: "Server-side session storage patterns with Redis and cookie configuration"
---
```
