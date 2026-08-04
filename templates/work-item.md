# Work Item Setup

Standard steps for establishing (or resuming) a `.dev/<slug>/` work item at the start of a skill.

1. **Parse arguments** for either:
   - A `.dev/<slug>/` directory path or a bare slug (e.g., `.dev/feat-auth-flow/` or `feat-auth-flow`) — strip any leading `.dev/` and trailing `/` to recover the slug, then operate within that existing context.
   - A free-form description — create a new work item for it.
   - If empty, fall through to the invoking skill's own Fallback section.

2. **Derive the slug** (only when none was provided): `<type>-<descriptive-slug>`, where `<type>` is one of `feat`, `bug`, `refactor`, `spike`. Note the type prefix — some skills (e.g. `plan`) inject a type-specific constraint keyed off it.

3. **Create `.dev/<slug>/`** if it doesn't already exist.

4. **Initialize `scratch.md`** from `templates/scratch.md` if it doesn't already exist in that directory.

5. **Existing-artifact check** — if the artifact this skill is about to produce already exists (e.g. `research.md`, `plan.md`), ask the user via `AskUserQuestion` before overwriting it. The exact choices are the invoking skill's call (e.g. Continue/Restart/Cancel, or Revise/Replace/Cancel) — this template fixes the setup steps above, not that decision's wording.
