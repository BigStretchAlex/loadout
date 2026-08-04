---
paths:
  - "skills/*/scripts/**"
  - "hooks/scripts/**"
---

# Bundled Script Rules

Applies to executable scripts shipped with skills or hooks. Rationale: `docs/agent-authoring-best-practices.md` §9.

- Never prompt interactively — agents run in non-interactive shells and a TTY prompt hangs forever. Take input via flags, env vars, or stdin; fail with a message naming the missing flag and its valid values.
- Document the interface in `--help` (description, flags, usage examples) — that output is how the agent learns the script. Keep it short; it lands in the context window.
- Write errors that shape the next attempt: what went wrong, what was expected, what to try (`--format must be one of: json, csv. Received: "xml"`).
- Structured data (JSON/CSV/TSV) on stdout, diagnostics on stderr, distinct documented exit codes per failure type.
- Idempotent ("create if not exists" — agents retry); `--dry-run` for destructive operations.
- Bound output (~10K chars before harness truncation): default to a summary with `--offset`/`--limit`, or require `--output <file>` for large results.
- Prefer self-contained dependency declarations (PEP 723 under `uv run`, `npm:`/`jsr:` for Deno) or pinned package runners (`uvx`, `npx`) — no separate install step.
- List every script in the owning `SKILL.md` with a one-line purpose; show the exact invocation at the step that uses it.
