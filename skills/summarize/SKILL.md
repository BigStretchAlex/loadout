---
name: summarize
description: Summarize a whole repository or one named file — its purpose, structure, and stack. Use only when the user asks for a standalone summary of a project or file they name; not for summarizing conversations, diffs, command output, or the assistant's own work in progress.
---

# Summarize Skill

Provide a concise summary based on the user's request.

If "$ARGUMENTS" specifies a file path, read that file and provide a clear summary of its purpose, key functions, and notable patterns.

If no arguments are provided, look at the current project structure and give a high-level overview including:
- What the project does
- Key directories and files
- Tech stack and dependencies
- How to get started
