# Handoff Footer

The machine-readable contract every lifecycle artifact ends with. It upgrades the console `Next step:`
suggestion from prose into a fenced, schema'd block a driver agent
or script can parse without reading English.

Defined once, here. `templates/plan.md`, `research.md`, `tasks.md`, `review-report.md`, and
`brainstorm.md` reference this file rather than repeating the schema — the same discipline
`templates/confidence-policy.md` established for the objective/subjective policy.

## Schema

Append this fenced block as the **last thing** in the artifact — after every other section, never
inside a list or table another parser walks line-by-line (`templates/tasks.md`'s one-line-per-step
layout, the `plan.md` marker line `perform-task` requires at line 1). The info string is always
`loadout-handoff`, so a reader locates it with `grep -n '^```loadout-handoff$'` and never has to
understand the surrounding prose.

````markdown
```loadout-handoff
schema: 1
artifact: plan | research | tasks | review-report | brainstorm
produced_by: /plan
work_item: .dev/feat-auth-flow
lane: standard | tdd | express
verification: pass | fail | none
next_command: /build            # or: none
next_arguments: .dev/feat-auth-flow
```
````

## Keys

| Key | Values | Meaning |
|---|---|---|
| `schema` | `1` | Format version. Bump only on a breaking key change; readers may ignore unknown future keys. |
| `artifact` | `plan` \| `research` \| `tasks` \| `review-report` \| `brainstorm` | Which template this file conforms to — lets `status` identify the artifact without opening it. |
| `produced_by` | the skill invocation that wrote this file, e.g. `/plan`, `/perform-task`, `/build` | Traceability — which command to blame/credit for this artifact's shape. |
| `work_item` | `.dev/<slug>` | The work item this artifact belongs to. Redundant with the containing directory, but makes the block self-sufficient if extracted on its own. |
| `lane` | `standard` \| `tdd` \| `express` | **Replaces `status`'s content-sniffing** (the express first-line marker, the `**TDD Gate**:` presence check) as the authoritative lane signal when present. See `skills/status/SKILL.md`'s legacy fallback for footer-less artifacts. |
| `verification` | `pass` \| `fail` \| `none` | The pass/fail result of the producing skill's own artifact self-check, computed before the pause point where it's presented to the human. `none` means the artifact carries no verification step of its own (e.g. `brainstorm.md`). |
| `next_command` | a `/`-prefixed skill name naming a real skill under `skills/`, or the literal `none` | The exact next step, in the grammar that command validates. **`none` is the defined representation of a legitimately suppressed route** (e.g. `review`'s no-work-item-directory case) — never fabricate a suggestion to avoid emitting `none`. |
| `next_arguments` | the literal argument string `next_command` expects, or omitted when `next_command: none` | What to pass the next command. |

## Rule: fill from the routing, never restate it

`next_command`/`next_arguments` must be **filled in from** the verdict→route mapping each skill already
computes (that mapping appears exactly once, in `skills/review/SKILL.md`). The
footer is a second *representation* of that decision, never a second *copy* of the mapping logic itself.

## Producers and the consumer

Every lifecycle skill/agent that writes one of the five artifacts above emits this block at the point it
writes the file — a template reference alone changes nothing about actual output. `tasks.md`'s footer is the one mutable case: `agents/build-executor.md` updates `verification`
and `next_command` alongside its per-step checkbox edits as the build progresses, so the footer never
goes stale mid-build.

`skills/status/SKILL.md` reads the footer first when present. For work items that predate this schema,
it falls back to the existing lane-inference tables — labeled explicitly as the legacy path, never
silently.
