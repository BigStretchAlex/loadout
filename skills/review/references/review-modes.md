# Review Modes — Full Discovery & Error Handling

Detail for Step 2's delegated discovery phase (Determine Review Mode & Discover Files). Consulted
by the `general-purpose` agent Step 2 spawns, not by the main skill directly — read this file
yourself once spawned; nothing here assumes anything from the parent conversation.

## Mode A — Directory provided

1. Verify the directory exists; if not, suggest alternatives:
   ```
   Directory <dir> not found. Did you mean one of:
     [list sibling directories]
   ```
2. Look for `<dir>/plan.md` — if found, extract file paths from its file list section
3. If no plan.md or no file list, fall back to `git diff --name-only origin/HEAD...HEAD` (branch diff) or `git diff --name-only` (unstaged)
4. If still no files, try `git status --short` to find modified/untracked files

## Mode B — Comma-separated file list

- Split the comma-separated file paths directly
- No `<dir>`; round is always 1. Return the file list as part of Step 2's result — the review skill displays the report inline in Step 5 since there's no file to write it to.

## Mode C — No args

- Run `git status --short` to find all modified/untracked files
- Run `git diff --name-only HEAD` to catch staged/unstaged changes
- Combine and deduplicate
- No `<dir>`; round is always 1. Same as Mode B: return the result, the report is displayed inline in Step 5.

## Error handling

- No files found → return this usage text as part of Step 2's result (the main skill displays it and exits):
  ```
  No files to review. Usage:
    /review <dir>                Review files in a directory (uses plan.md if present)
    /review file1.ts,file2.ts   Review specific files
    /review                     Auto-detect uncommitted changes
  ```
