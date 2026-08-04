---
name: tdd-build
description: TDD-gated autonomous implementation based on a plan.md with TDD Gates.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite, AskUserQuestion, Edit, Write
argument-hint: "[<dir> [step <N>[-<M>]]]"
model: sonnet
---

# TDD Build Skill

This skill **composes on `/build`** (`skills/build/SKILL.md`): its Phases 1–4 and the non-gate parts of Phase 5 run exactly as build defines them — same argument parsing, same `build-executor` agent, same `tasks.md` tracking, same blocked handling, same simplify pass, same testing-rules loading (`templates/testing-rules.md`). Layered on top is the TDD gate delta below: every step's gate must be proven to fail before implementation and pass after, and Phase 5 re-runs every gate to prove the simplify pass introduced no regression.

Gates use the four canonical field names produced by `/tdd-plan` — **Test**, **Command**, **Fail-first**, **Pass condition** — plus the plan-level `## TDD Gate Summary` table (Step | Command | ACs covered). These names and the table are the parsing contract with `/tdd-plan`; do not rename or restructure them.

## Instructions

Run `/build`'s phases (`skills/build/SKILL.md`) in full, applying these deltas at the noted points.

### Delta — Phase 1: Validation & Context Loading

- **Prerequisite** (in addition to build's `plan.md` existence check): verify the plan is TDD-gated — every step must have a `**TDD Gate**:` block, and a `## TDD Gate Summary` section must exist. If either check fails, the plan is not TDD-ready — fire `AskUserQuestion`:
  1. **Run `/tdd-plan <slug>` first** (recommended) — augment the plan with gates, then re-run `/tdd-build`
  2. **Fall back to plain `/build <slug>`** — build without test gates
  3. **Abort**
- **Context loading**: in addition to build's context load, also extract each step's TDD Gate and the `## TDD Gate Summary` table.

### Delta — Phase 3: Confirm & Execute

- Confirmation prompt notes the plan is TDD-gated:
  ```
  ## TDD Build: [dir]

  Plan has [N] steps, all TDD-gated. [Step range if specified, e.g., "Running steps 3–5."]
  [Resume note if applicable, e.g., "2 of 6 steps complete, resuming from Step 3."]

  Acceptance criteria: [N]

  Proceed? (yes / review plan first / cancel)
  ```
- Spawn the `build-executor` agent (used unchanged — the TDD protocol lives entirely in this prompt) with build's base prompt, plus this binding TDD protocol section appended before any testing-rules block:
  > TDD protocol (binding — every step in `plan.md` carries a **TDD Gate** with fields **Test**, **Command**, **Fail-first**, **Pass condition**):
  > --- BEGIN TDD PROTOCOL ---
  > For each step, in this order:
  > 1. **Fail-first evidence** — BEFORE implementing, run the step's gate **Command**. It MUST fail, for the reason stated in the gate's **Fail-first** field. Record the observed failure in `scratch.md` (the command run + the key output line proving the failure).
  > 2. **Implement** the step as described in the plan.
  > 3. **Pass evidence** — re-run the gate **Command**. It MUST pass, meeting the gate's **Pass condition**, before the step's `tasks.md` line may be checked off. A step whose gate has not passed is not complete — never check it off.
  > 4. **If the gate cannot be made to fail first** (e.g., the behavior already exists, or the test cannot be written before a scaffold step lands), record the reason in `scratch.md` and proceed — but never skip fail-first silently. An unexplained gate that passes before implementation is a blocking condition: stop and report it.
  > A gate that never passes after implementation is also blocking: stop and report it rather than checking the step off.
  > --- END TDD PROTOCOL ---

### Delta — Phase 4: Handle Build Report

Build's Modify/Skip/Abort flow applies unchanged — no separate escalation path — but "blocked" additionally includes:
- A gate that **never failed first** and has no recorded reason in `scratch.md`.
- A gate that **never passed after implementation**.

### Delta — Phase 5: Simplify, Gate Re-verification & Summary

Build's scratch.md update and simplify pass run unchanged. Add:

1. **Gate re-verification**: after the simplify pass, re-run **every** gate Command from the `## TDD Gate Summary` table (skipped steps excluded). Every gate must still meet its Pass condition — this proves the simplify pass broke nothing. If any gate now fails, treat it as a regression: revert or fix the offending simplification until the gate passes again, and note it in `scratch.md`. A regression is fixed before reporting — never shipped.
2. **Report** (replaces build's Phase 5 report):
```
## TDD Build Complete: [dir]

**Steps completed**: [N] / [total]
**Acceptance criteria met**: [N] / [total]
**Simplify pass**: [N refinements applied | clean — no changes]
**Gate re-verification**: [N/N gates passing after simplify]

### Gate Results

| Step | Fail-first observed | Final pass |
|------|--------------------|-----------|
| 1 | yes — [key failure line] | yes |
| ... | ... | ... |

[Only if no testing rules were found in Phase 1:] No testing rules found — consider /create-rules.

Next step: `/review <dir>` to run a code review.
```

---

## Rules

1. The `build-executor` and `code-simplifier` agents are used **unchanged** — the entire TDD protocol is carried in the Phase 3 prompt, never in agent edits.
2. **Gates are the source of truth for step completion** — never check off a `tasks.md` step whose gate Command has not passed its Pass condition.
3. Fail-first is never skipped silently — either the failure is observed and recorded in `scratch.md`, or the reason it could not fail is recorded there; an unexplained pre-implementation pass is blocking.
4. The four canonical field names — **Test**, **Command**, **Fail-first**, **Pass condition** — and the `## TDD Gate Summary` table are the parsing contract with `/tdd-plan`; a plan missing them routes through the Phase 1 delta's `AskUserQuestion`, never a guess.

---

## Fallback

If no arguments are provided:
1. Check `.dev/` for work items that have a `plan.md` containing a `## TDD Gate Summary` but no `review.md` — suggest building those
2. Check `.dev/` for work items with a `plan.md` lacking TDD Gates — suggest `/tdd-plan` to augment them (or plain `/build`)
3. If none found, ask the user what they'd like to build via `AskUserQuestion`
