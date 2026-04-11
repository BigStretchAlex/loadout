---
name: init-docs
description: Bootstrap .ai-docs/ knowledge base from a codebase by extracting patterns and conventions
allowed-tools: Read, Grep, Glob, Task, AskUserQuestion, Write, Bash
argument-hint: [focus-areas...] (e.g., "backend security" or empty for all)
model: opus
---

# Init Docs Skill

Analyze the current codebase and generate an `.ai-docs/` knowledge base containing documented patterns, conventions, and architectural decisions.

## Instructions

### Phase 1 — Setup & Existing Docs Check

1. **If `.ai-docs/` exists and has documents**, ask the user via `AskUserQuestion`:
   - **Augment**: add new documents without modifying existing ones
   - **Rebuild**: remove existing docs and start fresh
   - **Cancel**: abort

   If user selects Rebuild, delete existing `.ai-docs/` contents.
   If user selects Augment, read all existing `.ai-docs/` files to know what's already covered.

2. **Create `.ai-docs/`** if it doesn't exist.

---

### Phase 2 — Codebase Survey

Run a structured survey using Glob + Read. No subagent needed — the model is capable of deep analysis.

**Step 1 — Project structure**: Glob for top-level dirs and read package files (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `pom.xml`, etc.)

**Step 2 — Existing documentation**: Read `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `docs/` if they exist.

**Step 3 — Discovery checklist**: For each signal found, note the evidence (specific files/dirs). If `$ARGUMENTS` specifies focus areas, filter to matching domains.

| Signal | What to Check | Proposed Document |
|--------|---------------|-------------------|
| Layered dirs (`domain/`, `service/`, `repository/`, `controller/`, `handler/`) | Dir structure, module boundaries, dependency direction | architecture-patterns |
| Lambda/serverless config (SAM, Serverless Framework, `handler.ts` patterns) | Handler structure, event sources, middleware | serverless-patterns |
| CI/CD config (`.github/workflows/`, `Jenkinsfile`, `buildspec.yml`, `.gitlab-ci.yml`) | Pipeline stages, deploy strategies, env promotion | cicd-patterns |
| Migration dirs/config (Flyway, Alembic, Prisma, Knex, TypeORM migrations) | Schema evolution, rollback strategy, naming | migration-patterns |
| Test directories with structure (`__tests__/`, `test/`, `spec/`, pytest, jest) | Organization, fixtures, mocking, naming conventions | testing-strategy |
| IaC files (CDK, Terraform, CloudFormation, Pulumi) | Resource organization, naming, environments | infrastructure-patterns |
| API route/endpoint files with consistent patterns | Route structure, middleware, request/response | api-patterns |
| Feature slices showing end-to-end implementation | How to add a new feature across layers | building-features |
| Error handling (custom error classes, error boundaries, catch patterns) | Error hierarchy, user-facing errors, logging | error-handling |
| Auth/security modules (auth middleware, guards, policies, token handling) | Auth flow, authorization, validation | security-patterns |
| State management (Redux, Zustand, Context, stores) | State patterns, data flow, side effects | frontend-patterns |
| Shared libraries/packages (monorepo packages, internal libs) | Code sharing conventions, package boundaries | codebase-organization |

---

### Phase 3 — Propose Document Plan

Present findings to the user via `AskUserQuestion`:

```
## Proposed .ai-docs/ Documents

Based on codebase analysis, I recommend creating these documents:

1. [x] **architecture-patterns** — Hexagonal architecture with domain/service/repository layering
   Evidence: `src/domain/`, `src/services/`, `src/repositories/`

2. [x] **testing-strategy** — Jest with integration test fixtures and factory pattern
   Evidence: `test/`, `test/fixtures/`, `jest.config.ts`

3. [x] **cicd-patterns** — GitHub Actions with staging → production promotion
   Evidence: `.github/workflows/deploy.yml`, `.github/workflows/test.yml`

Deselect any you don't want, or describe additional topics to include.
```

Use `multiSelect` so the user can toggle individual documents on/off and add custom ones.

In **Augment mode**, indicate which topics are already covered by existing docs so the user can see what's new.

---

### Phase 4 — Extract & Write

For each approved document:

1. **Read 3–5 representative code files** for the domain. The skill does this directly — it needs to understand the patterns deeply before compiling findings.

2. **Compile findings** into a structured analysis per document:

   ```
   ## Document: [name]

   ### Patterns Found
   - [pattern]: [description + rationale + code evidence]

   ### Conventions
   - [convention]: [description + examples]

   ### Key Files
   - [file]: [role in the pattern]
   ```

3. **After analyzing all approved documents**, spawn `document-writer` with the compiled findings:

   > You are writing `.ai-docs/` documents from codebase analysis findings.
   >
   > **Input type**: codebase analysis findings (not a scratch file)
   > **Findings**:
   > [all compiled analyses from step 2]
   >
   > **Existing `.ai-docs/` files**: [list, or "none" for fresh mode]
   > **Mode**: [Augment | Fresh]
   >
   > For each set of findings, create a new `.ai-docs/` document. In Augment mode, do not modify existing files — only create new ones.
   > Write files directly. Use the two-pass line number approach.

---

### Phase 5 — Report

```
## .ai-docs/ Initialized

**Documents created**: [N]
**Patterns extracted**: [N]

| Document | Domain | Patterns | Sections |
|----------|--------|----------|----------|
| [name] | [domain] | [count] | [count] |

Next steps:
- `/drift-check` — periodically verify docs match code
- `/status` — see knowledge base state
- `/triage` — promote future scratch insights to .ai-docs/
```

---

## Examples

### Example 1: Fresh init on a Node.js API

**User invokes:** `/init-docs`

**Phase 1 — Setup**: No `.ai-docs/` directory exists. Created.

**Phase 2 — Codebase Survey**: Survey finds:
- `src/domain/`, `src/services/`, `src/repositories/` → architecture-patterns
- `.github/workflows/deploy.yml`, `.github/workflows/test.yml` → cicd-patterns
- `prisma/migrations/` → migration-patterns
- `test/`, `test/fixtures/`, `jest.config.ts` → testing-strategy
- `src/routes/`, `src/middleware/` → api-patterns

**Phase 3 — Propose Document Plan**: Proposes 5 documents. User deselects `cicd-patterns` ("CI is about to change, skip for now"). 4 documents approved.

**Phase 4 — Extract & Write**: Skill reads representative files for each domain:
- For architecture-patterns: reads `src/domain/user.ts`, `src/services/user-service.ts`, `src/repositories/user-repository.ts`
- For testing-strategy: reads `jest.config.ts`, `test/fixtures/user.fixture.ts`, `test/services/user-service.test.ts`
- For migration-patterns: reads `prisma/schema.prisma`, latest migration file
- For api-patterns: reads `src/routes/users.ts`, `src/middleware/auth.ts`, `src/middleware/validate.ts`

Compiles structured findings for all 4 domains. Spawns `document-writer` with the compiled analysis. Agent writes 4 `.ai-docs/` files with proper frontmatter and line numbers.

**Phase 5 — Report**:
```
## .ai-docs/ Initialized

**Documents created**: 4
**Patterns extracted**: 18

| Document | Domain | Patterns | Sections |
|----------|--------|----------|----------|
| architecture-patterns | architecture | 5 | 3 |
| testing-strategy | testing | 4 | 3 |
| migration-patterns | database | 4 | 2 |
| api-patterns | backend | 5 | 3 |

Next steps:
- `/drift-check` — periodically verify docs match code
- `/status` — see knowledge base state
- `/triage` — promote future scratch insights to .ai-docs/
```

---

### Example 2: Augment mode with focus area

**User invokes:** `/init-docs backend security`

**Phase 1 — Setup**: `.ai-docs/` exists with 3 files (`architecture-patterns.md`, `testing-strategy.md`, `api-patterns.md`). User selects **Augment**. Skill reads all existing docs to know what's covered.

**Phase 2 — Codebase Survey**: Survey is filtered to backend + security domains. Finds auth middleware at `src/middleware/auth.ts`, input validation at `src/validators/`, rate limiting config. Notes that existing docs already cover architecture and API patterns.

**Phase 3 — Propose Document Plan**: Proposes 1 new document:

```
## Proposed .ai-docs/ Documents

Already covered by existing docs:
- architecture-patterns.md (architecture)
- api-patterns.md (backend)

New documents recommended:

1. [x] **security-patterns** — Auth flow, input validation, rate limiting
   Evidence: `src/middleware/auth.ts`, `src/validators/`, `src/config/rate-limit.ts`

Deselect any you don't want, or describe additional topics to include.
```

User approves.

**Phase 4 — Extract & Write**: Skill reads `src/middleware/auth.ts`, `src/validators/user.validator.ts`, `src/config/rate-limit.ts` in depth. Compiles findings. Spawns `document-writer` with analysis + existing file list (Augment mode). Agent creates `security-patterns.md`.

**Phase 5 — Report**:
```
## .ai-docs/ Initialized

**Documents created**: 1
**Patterns extracted**: 6

| Document | Domain | Patterns | Sections |
|----------|--------|----------|----------|
| security-patterns | security | 6 | 3 |

Next steps:
- `/drift-check` — periodically verify docs match code
- `/status` — see knowledge base state
- `/triage` — promote future scratch insights to .ai-docs/
```
