---
paths:
  - "agents/**"
---

# Agent Authoring Rules

Applies to agent definition files. Rationale: `docs/agent-authoring-best-practices.md` §7, §8.5.

- Every agent file records which pressure justified its existence — context isolation, tool restriction, model tiering, or parallelism (the skills-first heuristic in `principles.md`) — so the choice survives review.
- An agent definition specifies a **role, a tool allowlist, and an output contract**. The allowlist is a safety boundary, not documentation — a review-only agent with `Write`/`Edit` will eventually write.
- Assign the model tier deliberately — expensive models for architecture/review/synthesis, cheap fast models for mechanical roles — and record the reason in the agent file so the choice survives review.
- An agent receives everything through its prompt and the files it reads; it cannot see the parent conversation. A step that depends on ambient session context is not agent-ready.
- Two agents that must produce interchangeable output reference one shared schema file in `templates/`. A prose promise to "maintain an identical format" is a divergence that has already happened.
- Fan out to parallel agents only when subtasks are independent AND each returns a small result — fan-out is context management, not throughput.
- `hooks`, `mcpServers`, and `permissionMode` in agent frontmatter are **silently ignored** for plugin-distributed agents. Verification for agent work attaches at plugin level (`hooks/hooks.json`, matcher-scoped to the agent) or skill level (`hooks:` in `SKILL.md`).
