---
name: simplify
description: Review changed code for reuse, quality, and efficiency, then fix any issues found.
argument-hint: "[file1,file2,...] (defaults to git-changed files)"
allowed-tools: Read, Task, Glob, Bash
---

# Simplify Skill

Simplify and refine code for clarity, consistency, and maintainability without changing behavior.

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

Use the Task tool to spawn the **code-simplifier** agent. Pass:
- The resolved file path list
- Instruction to check `.ai-docs/` for project-specific patterns and anti-patterns before making changes

### Step 3: Display summary

Print the agent's simplification summary to the console.
