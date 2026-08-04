---
paths:
  - "skills/*/evals/**"
---

# Skill Eval Rules

Applies when building or running skill evals. Full methodology: `docs/agent-authoring-best-practices.md` §4.4, §10.

## Triggering evals (does the description fire?)

- ~20 realistic queries, roughly half `should_trigger: true`, half `false`. Vary positives by phrasing, explicitness, detail, and complexity; the best positives are ones where the skill helps but the connection isn't obvious.
- Negatives are **near-misses** sharing keywords but needing something else — unrelated queries test nothing.
- Run each query ~3× and score a trigger rate (positive passes above ~0.5); a single run is an anecdote.
- Fixed ~60/40 train/validation split: iterate on train failures, select the final description by validation pass rate.
- Never paste keywords from failed queries into the description — identify the general category instead. If five iterations don't move the numbers, suspect the queries.

## Output evals (does the skill help?)

- Run every case twice — with the skill and without (or against the snapshotted previous version) — each from a clean context. Record tokens and duration. Without a baseline you can't tell whether the skill contributed anything.
- Write assertions *after* the first round of outputs; make them verifiable and specific ("output is valid JSON", "≥3 recommendations"), script the mechanical ones, and require quoted evidence for a PASS.
- Decide on the **delta** between configurations, not the with-skill score. Remove assertions that pass in both configurations; investigate ones that fail in both.
- Read execution traces, not just outputs. Wasted effort means: instructions too vague, instructions followed that don't apply, or a menu with no default.
- Generalize every fix — a patch aimed at one failed case is technical debt. If pass rates plateau while rules accumulate, cut instructions and re-measure.
