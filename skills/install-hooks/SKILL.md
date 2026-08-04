---
name: install-hooks
description: Reports that loadout hooks have been removed pending a redesign.
disable-model-invocation: true
allowed-tools: Read
---

# Install Hooks Skill

Loadout's hook code was removed — none of it was wired into a
consuming project by default, and rather than patch dead or half-built code in place, the whole
`hooks/` tree was deleted. See [`hooks/README.md`](${CLAUDE_PLUGIN_ROOT}/hooks/README.md) for the full inventory
of what existed and why, and [`docs/modernization-roadmap.md`](${CLAUDE_PLUGIN_ROOT}/docs/modernization-roadmap.md)
for the `hooks.json` auto-registration design that will replace it.

There is currently nothing to install. If invoked, tell the user hooks are removed pending a
redesign and point them at `hooks/README.md` for context.
