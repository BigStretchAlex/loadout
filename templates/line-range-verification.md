# Line-Range Verification

Self-check for any skill that has `document-writer` write `sections[]` line-range metadata into
`.ai-docs/` frontmatter. Run this after the write phase, before any done-claim artifact is written.

For every `.ai-docs/` file the agent reported as promoted-to or updated, re-read the file and check its frontmatter:

1. Determine the file's total line count and the frontmatter block's line range (between the opening `---` on line 1 and the matching closing `---`).
2. For each entry in `sections[]`, check:
   - `line_start` ≥ 1
   - `line_end` ≤ the file's total line count
   - `line_start` ≤ `line_end`
   - `line_count` is consistent (`line_end - line_start + 1`)
   - the `[line_start, line_end]` range does **not** overlap the frontmatter block's line range
   - neither `line_start` nor `line_end` is `-1` — any surviving `-1` placeholder from the two-pass approach is a failure, not a value to tolerate

**If any check fails**: re-spawn `document-writer` with the specific file(s) and section(s) that failed, instructing it to recompute the exact line numbers from a direct re-read of the current file (not the two-pass placeholder trick) and rewrite only those `sections[]` entries. Re-run this check on the result. Do **not** write the done-claim artifact until every check passes.

Report explicitly: `Line-range verification: PASS` or `Line-range verification: FAIL — <file>: <section> — <reason>` (one line per failure). Carry this into the final report.
