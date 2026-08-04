# Testing Rules Loading

Shared pattern for locating and using the consuming project's testing rules under `.claude/rules/`.

## Discovery (never block on this)

1. Read `.claude/rules/common/testing.md` if it exists.
2. Detect the project's language(s) and read `.claude/rules/<language>/testing.md` for each, if present.
3. If none were found, note it — skills that inject rules into an executor add one line to their final report: "No testing rules found — consider /create-rules". Skills that author gates instead treat the absence as no constraint beyond general good-test practice.

## Consumption modes

- **Inject verbatim into an executor prompt** (`build`, `tdd-build`): append the found contents as a clearly delimited section:
  ```
  Testing rules (binding):
  --- BEGIN TESTING RULES ---
  [contents of each file found, labeled with its path]
  --- END TESTING RULES ---
  ```
- **Constrain authored gates** (`tdd-plan`): read the rules — especially `common/testing.md`'s **What Constitutes a Valuable Test** section — and require every TDD Gate to comply (behavior over implementation, deterministic, one reason to fail, no tautologies) rather than injecting the text into another agent's prompt.
