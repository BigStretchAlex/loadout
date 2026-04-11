# Plan Rescan Hook — DEPRECATED

## Status

**This hook has been deprecated and is no longer installable.**

## What It Was Intended To Do

After an Explore or Plan agent completed (`SubagentStop`), read previously scanned topics from session state, use `claude --bare --model haiku -p` to suggest additional related topics, score them against cached `.ai-docs/` frontmatter, and inject any newly matched documentation not already surfaced in the session.

## Why It Didn't Work

The core topic discovery approach (`claude --bare -p`) requires `ANTHROPIC_API_KEY` to be set as an environment variable. Command hooks executed by Claude Code do **not** inherit the session's authentication credentials — they run in a clean environment without the API key. This made AI-assisted topic expansion impossible.

The same root cause that blocked `prompt-doc-scan` applies here: without API access in the hook environment, there is no reliable way to derive new topics from an existing topic set.

## Working Replacement

The `explore-ai-docs` PreToolUse hook achieves the underlying goal more reliably by injecting an instruction directly into every Explore agent invocation to check `.ai-docs/` frontmatter first. The agent itself handles the relevance assessment using its own API access, without needing a separate hook-based rescan pass.

## Historical Reference

The shell script `hooks/scripts/plan-rescan-docs.sh` is retained for historical reference but is no longer wired into the hook installer.
