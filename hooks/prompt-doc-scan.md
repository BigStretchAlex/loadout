# Prompt Doc Scan Hook — DEPRECATED

## Status

**This hook has been deprecated and is no longer installable.**

## What It Was Intended To Do

On every `UserPromptSubmit`, extract 3-8 search topics from the user's prompt using `claude --bare --model haiku -p`, match them against cached `.ai-docs/` frontmatter, and inject relevant documentation paths with section line ranges into the assistant's context.

## Why It Didn't Work

The core topic extraction approach (`claude --bare -p`) requires `ANTHROPIC_API_KEY` to be set as an environment variable. Command hooks executed by Claude Code do **not** inherit the session's authentication credentials — they run in a clean environment without the API key. This made AI-assisted topic extraction impossible.

A fallback Python tokenizer was implemented, but it is too simplistic for reliable topic matching and produced poor signal-to-noise results.

Native `type: "prompt"` hooks were also considered, but they cannot access local files, making `.ai-docs/` frontmatter matching impossible without the API key dependency.

## Working Replacement

The `explore-ai-docs` PreToolUse hook achieves the goal more reliably by injecting an instruction directly into every Explore agent invocation to check `.ai-docs/` frontmatter first. Since this runs *inside* the agent (which has full API access), it works without any external API key.

## Historical Reference

The shell script `hooks/scripts/prompt-scan-docs.sh` is retained for historical reference but is no longer wired into the hook installer.
