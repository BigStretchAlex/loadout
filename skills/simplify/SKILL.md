---
name: simplify
description: Refactor already-written code for clarity and reuse without changing its behavior, targeting named files or the git-changed set. Use only when the user asks to simplify, clean up, or tidy existing code; not while authoring new code, and not for bug fixes or behavior changes.
argument-hint: "[file1,file2,...] (defaults to git-changed files)"
allowed-tools: Read, Task, Glob, Bash
context: fork
---

# Simplify Skill

Simplify and refine code for clarity, consistency, and maintainability without changing behavior.

**Fork boundary:** this skill forks whole (`context: fork` above) — it has no interactive step, so nothing here needs the main session. No outer `agent:` shell: it already spawns the real role (`code-simplifier`) itself, so a second shell would only nest roles for no gain. No `background:`: `/simplify` is today's foreground user action.

## Instructions

### Step 1: Resolve target files

Parse `$ARGUMENTS` as a comma-separated list of file paths.

If no arguments provided:
1. Run `git diff --name-only HEAD` to find staged/unstaged changes
2. Run `git status --short` to include untracked modified files
3. Combine and deduplicate — these are the target files
4. If still no files found, display:
   ```
   No files to simplify. Usage:
     /simplify src/auth.ts,src/login.tsx   Simplify specific files
     /simplify                             Auto-detect git-changed files
   ```
   Then exit.

### Step 2: Spawn code-simplifier agent

Use the Task tool to spawn the **code-simplifier** agent, passing the resolved file path list.

### Step 3: Display summary

Print the agent's simplification summary to the console — this is this skill's final output, and since the whole skill runs forked, it is what the fork returns to the main session; nothing earlier in this run is visible outside this transcript.
