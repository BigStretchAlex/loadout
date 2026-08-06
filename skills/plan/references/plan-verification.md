# Plan Verification Checks

Loaded by `skills/plan/SKILL.md` step 10. Re-read `.dev/<slug>/plan.md` and run every check below before printing `## Plan Ready`. The on-failure protocol, the footer `verification` edit, and the report line stay in the skill body.

**a. Per-step validation loop (every `### Step N` block):**
- A `**Validation**:` block is present under the step — not missing, not omitted.
- All four fields are present: **Type** (`deterministic` or `agent-evaluable`), **Check**, **Expect**, **On fail**.
- None of the four fields are a template placeholder (`<...>`, `TBD`, `...`) or unfalsifiable prose ("works correctly", "behaves as expected", "verify it's fine").
- If **Type: deterministic**, the **Check** names an actual runnable command (a real script/binary/test target), not a placeholder.
- If **Type: agent-evaluable**, the **Check** is phrased as a yes/no question an agent can judge unambiguously.

**b. Plan schema completeness (`templates/plan.md`):** the plan contains every required section — `## Goal`, `## Acceptance Criteria`, `## Approach`, `## File-Action Index`, at least one `### Step N` block, `## Risks & Mitigations`, `## Test Strategy`, `## Out of Scope`.

**c. File-path integrity:** for every step, the **File**: path either exists on disk (verify with a read or `test -f`), or the step's **Action** is `CREATE` (a non-existent path is then expected, not a failure).

**d. Index/step parity:** the number of rows in **File-Action Index** equals the number of `### Step N` blocks in the plan.

**e. Handoff footer** (`templates/handoff-footer.md`): the file ends with a fenced ` ```loadout-handoff ` block as the last content in the file; every key (`schema`, `artifact`, `produced_by`, `work_item`, `lane`, `verification`, `next_command`, `next_arguments`) is present, non-blank, and not a template placeholder; `next_command` is either the literal `none` or names a real skill under `skills/`; when `next_command` is not `none`, `next_arguments` is present and parses under that skill's `argument-hint`.
