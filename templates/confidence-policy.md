# Confidence Policy

Classify every finding or proposed fix before acting on it:

- **Objective (auto-apply)**: the fix is mechanically verifiable — a factual error, broken path, missing required field, failing command, or a direct contradiction of a rule, plan, or template. Apply it without asking, then re-run the relevant check once to confirm.
- **Subjective (ask)**: the fix is a judgment call — scope, naming, architecture, trade-offs. Surface it via AskUserQuestion; never apply it unprompted.

Never auto-apply a fix that deletes user-authored content, changes scope, or contradicts a decision recorded in `scratch.md`. When in doubt, treat the finding as subjective.
