# hooks/ — removed (Phase 0, task 0.5)

This directory used to hold loadout's hook code: a deprecated `.ai-docs/` scan pipeline plus a
handful of "live" hooks that were never installed by default. None of it was wired into a
consuming project's `.claude/settings.json` without a manual `install-hooks.py` run that nobody
did, so [`docs/modernization-roadmap.md`](../docs/modernization-roadmap.md) §0.5 deleted the
whole tree rather than patch dead or half-built code in place. This README is the only thing
left, so Phase 1's `hooks.json` auto-registration design (roadmap §1.1) can rebuild deliberately
instead of inheriting these fossilized decisions.

See [`../ai-docs-hook-investigation.md`](../ai-docs-hook-investigation.md) for the investigation
that informs the rebuild, and [`../docs/modernization-roadmap.md`](../docs/modernization-roadmap.md)
for the phased plan this deletion is part of.

## Root cause: the `--bare` flag, not the hook environment

The deprecated hooks (`prompt-doc-scan.md`, `plan-rescan.md`) were originally taken offline with
a documented diagnosis that command hooks run in a clean environment without the session's
`ANTHROPIC_API_KEY`, making `claude --bare -p` topic extraction impossible. That diagnosis was
**wrong**, per `ai-docs-hook-investigation.md` Finding 1/2:

- **Finding 1:** the actual blocker is the `--bare` flag itself. Per `claude --help`, `--bare`
  mandates `ANTHROPIC_API_KEY` or `apiKeyHelper` and *never* reads OAuth/keychain credentials —
  it is the one mode that requires an explicit API key. `claude --bare -p` fails with
  "Not logged in" while plain `claude -p` succeeds, using the same session's existing
  authentication.
- **Finding 2:** hooks otherwise inherit the **full** environment (`HOME`, `PATH`, `CLAUDECODE=1`,
  etc.) — not a stripped-down sandbox. A command hook calling `claude -p` (without `--bare`)
  works end-to-end, using the session's OAuth credentials, in about 5 seconds.

In short: the failure was self-inflicted by the flag choice made in `cef4a6c`, not a platform
limitation. Whoever rebuilds prompt-time injection should drop `--bare` — or better, skip the LLM
call entirely, since the investigation's Finding 4 shows deterministic exact-match scoring against
`.ai-docs/` frontmatter hits 10/10 with no model call at all. See the investigation's "Recommended
Design" section for the full proposal.

## Files removed

### Hook definitions (top level)

| File | Original intent |
|------|------------------|
| `explore-ai-docs-context.json` | `PreToolUse` (Agent) hook. Injected an instruction telling Explore agents to check `.ai-docs/` frontmatter before reading files, and to use section line ranges instead of reading whole files. One of the only "live" hooks, but required a manual `install-hooks.py` run to activate. |
| `scratch-capture.md` | `PostToolUse` (Bash) hook doc. Described reminding the assistant to capture insights into the active work item's `scratch.md`, once per work item per session, driven by `scripts/scratch-reminder.sh`. |
| `prompt-doc-scan.md` | `UserPromptSubmit` hook doc (deprecated). Described extracting 3-8 search topics from every user prompt via `claude --bare --model haiku -p`, matching them against cached `.ai-docs/` frontmatter, and injecting relevant doc sections. Deprecated with an incorrect root-cause note — see above. |
| `plan-rescan.md` | `SubagentStop` hook doc (deprecated). Described re-evaluating `.ai-docs/` topics after an Explore/Plan agent completed, using the same `claude --bare -p` approach as `prompt-doc-scan.md`, to catch docs that only become relevant once the codebase has been explored. Deprecated for the same (incorrect) reason. |

### Scripts (`scripts/`)

| File | Original intent |
|------|------------------|
| `prompt-scan-docs.sh` | ~370 lines. The implementation behind `prompt-doc-scan.md`: built/refreshed a tab-delimited `.ai-docs/` frontmatter cache, extracted topics via `claude --bare -p`, scored them against the cache, and emitted matched sections as `additionalContext`. Dead code — never reachable without `--bare` working, and never installed by default. |
| `plan-rescan-docs.sh` | ~260 lines. The implementation behind `plan-rescan.md`: read previously-scanned topics from session state, suggested new related topics via `claude --bare -p`, and injected any newly matched `.ai-docs/` sections. Same dead-code status as `prompt-scan-docs.sh`. |
| `scratch-reminder.sh` | Implementation behind `scratch-capture.md`. Checked whether recent Bash activity touched a `.dev/<type>-<slug>/` work item and, if so, printed a one-time-per-session reminder to update `scratch.md`. |
| `ts-lint.sh` | `PostToolUse` (Edit\|Write) hook. Report-only: ran ESLint on edited `.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs` files via `npx` and printed results. Never blocked the edit; never installed by default. |
| `jest-related.sh` | `PostToolUse` (Edit\|Write) hook. Report-only: ran `jest --findRelatedTests` on edited JS/TS files and printed results. Never blocked the edit; never installed by default. |
| `log-agent-spawn.sh` | `PreToolUse` (Agent) observability hook. Logged every subagent spawn (type, description, background flag) to `.dev/loadout-test.log`, for debugging the loadout workflow itself. |
| `log-agent-stop.sh` | `SubagentStop` observability hook. Logged every subagent completion (type, session ID) to `.dev/loadout-test.log`. |
| `log-skill-invoke.sh` | `PreToolUse` (Skill) observability hook. Logged every skill invocation (name, args) to `.dev/loadout-test.log`. |
| `log-doc-scan.sh` | `UserPromptSubmit` observability hook. Tee wrapper around `prompt-scan-docs.sh` — logged its output to `.dev/loadout-test.log` while also passing it through to Claude. Inherited the same dead-code status as the hook it wrapped. |
| `log-plan-rescan.sh` | `SubagentStop` observability hook. Tee wrapper around `plan-rescan-docs.sh`, same purpose and same dead-code status. |
| `log-scratch-reminder.sh` | `PostToolUse` (Bash) observability hook. Tee wrapper around `scratch-reminder.sh` — logged when the scratch reminder fired, in addition to the reminder itself. |
| `settings-snippet.json` | Example `.claude/settings.json` `hooks` block wiring up `explore-ai-docs-context.json` and other hooks, for copy-paste reference during manual install. |

### Installer

| File | Original intent |
|------|------------------|
| `skills/install-hooks/scripts/install-hooks.py` | ~438-line Python script. Copied selected hook scripts from the plugin into a consuming project's `.claude/hooks/scripts/` and merged the corresponding entries into that project's `.claude/settings.json`, so the project stayed self-contained and portable. Required a manual, opt-in run; nobody ran it, so every hook above shipped installed-nowhere. `skills/install-hooks/SKILL.md` is now a stub pending the Phase 1 `hooks.json` auto-registration redesign (roadmap §1.1) — see `docs/modernization-roadmap.md` §5.1 for the intended replacement (hooks that ship with the plugin auto-register via `${CLAUDE_PLUGIN_ROOT}`, no installer, no manual step).

## What replaces this

Phase 1 (`docs/modernization-roadmap.md` §1.1-1.4, §3.4-3.6) plans a `hooks/hooks.json`
auto-registering design, scripts addressed via `${CLAUDE_PLUGIN_ROOT}`, and a deterministic
(non-LLM) `.ai-docs/` injection hook built on the investigation's Finding 4-6 design. Until that
lands, `skills/install-hooks/SKILL.md` is a stub noting hooks are removed, and there is nothing
to install.
