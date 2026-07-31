---
name: release
description: Sync the version number across a Claude Code plugin's `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, then optionally tag and publish the release. Use whenever the user wants to release, publish, or cut a new version of a plugin — e.g. "bump the version", "cut a new release", "release 2.0.0", "prep this for release", or "the marketplace and plugin versions are out of sync". Trigger even if they only mention one of the two files, since this skill's whole job is keeping them in agreement.
arguments: "Optional target version, e.g. 2.0.0"
allowed-tools: AskUserQuestion, Bash(git:*), Bash(gh:*), Read, Edit
---

# Release: sync plugin version

Keep a plugin's version declarations in agreement across `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, then help the user tag and publish the release. Claude Code uses the `version` field for update caching, so a drift between the two files (or a release that never bumped either) causes stale installs for consumers — this skill exists to catch that before it ships.

The one rule that matters: **don't guess the version.** Don't infer a bump from commit messages, diff size, or conventional-commit types — that's a judgment call for the user, not something to reverse-engineer. The only exceptions are pure arithmetic (computing what "next patch/minor/major" would look like from the current version, to offer as convenient options) and an explicit version passed via `$ARGUMENTS`.

## Instructions

### Step 1: Locate the files and current versions

Find `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` relative to the project root (ask the user for the path if the layout is unfamiliar). Read both and extract:

- `plugin_version` — the top-level `version` field in `plugin.json`
- `marketplace_version` — the `version` field of the entry in `marketplace.json`'s `plugins` array whose `name` matches `plugin.json`'s `name`

If `marketplace.json` lists multiple plugins and none match `plugin.json`'s name, say so and ask the user which entry to treat as this plugin before continuing.

### Step 2: Check whether a bump is already staged

Run:
```bash
git diff -- <path-to-plugin.json> <path-to-marketplace.json>
```

This tells you whether the working tree already has pending edits to these files, and specifically whether the `"version"` line changed in either. Note the old and new values if so.

### Step 3: Decide whether you need to ask the user

Ask via `AskUserQuestion` when **either** of these is true — both are cases where you genuinely don't have enough signal to proceed safely:

- **Nothing changed yet**: `git diff` shows no pending edits to the version fields (this is a fresh release request, not a bump already in progress).
- **The two files disagree**: `plugin_version != marketplace_version`, regardless of what `git diff` shows.

If neither applies — a bump is already staged in the working tree and both files agree on the new value — skip straight to Step 5, there's nothing to resolve.

If `$ARGUMENTS` was passed and looks like an explicit version string (e.g. `2.0.0`), treat that as the answer and skip the question — the user already told you.

### Step 4: Ask

Frame the question around whichever case triggered it:

**Fresh release** (nothing changed yet) — compute the next patch/minor/major from the current version and offer them as concrete options, e.g. current is `1.1.0`:
- "1.1.1 (patch)"
- "1.2.0 (minor)"
- "2.0.0 (major)"

(the user can always type a different value via "Other")

**Mismatch** — offer the two conflicting values plus room for a fresh one:
- "Use 1.1.0 (plugin.json's version)"
- "Use 1.0.0 (marketplace.json's version)"
- "Something else"

Either way, the header should read something like "Version" and the question should state plainly why you're asking (nothing changed / they disagree) so the user isn't left guessing at your reasoning.

### Step 5: Apply the version

Update the `version` field in both files to match the resolved value, using `Edit` for precision so you don't disturb unrelated formatting. Both files must end up identical on this field — that's the entire point of the skill.

### Step 6: Report and offer next steps

Show a small before/after summary (old plugin_version → new, old marketplace_version → new), then end with a numbered menu and **wait** — don't tag, push, or run `gh` commands until the user picks one. Tags and releases are visible to anyone with repo access and awkward to undo, so this follows the same "propose, then wait" pattern as the `commit` skill:

1. **Tag and push** — `git tag -a v<version> -m "Release v<version>"` then `git push origin v<version>`
2. **Tag, push, and create a GitHub Release** — same as above, plus `gh release create v<version> --generate-notes` (skip gracefully with a note if `gh` isn't installed or authenticated)
3. **Just leave the version bump** — the user will commit and tag it themselves

**Before acting on 1 or 2**, check `git status` on the two files. A tag points at a commit, not the working tree — tagging while the version edit is still uncommitted would tag a commit that doesn't actually contain the bump. Handle whichever case applies:

- **The version edit is the only pending change to these files** (this is the common case, since Step 5 just made the edit): ask the user whether to commit it now (a small `chore: bump plugin version to v<version>` covering just `plugin.json`/`marketplace.json`) before tagging, or whether they'd rather fold it into a different commit themselves — then proceed accordingly.
- **Step 2 found the bump was already staged alongside other unrelated changes**: don't commit on the user's behalf. Point out that tagging now would tag whatever HEAD currently is (without the bump), and let them decide how to commit.

Close with a one-line reminder that consumers can now pin to this exact release with `claude plugin marketplace add <owner>/<repo>@v<version>`, or via a `ref`/`sha` in their own marketplace's `source` entry for this plugin — useful context, not an action to take here.
