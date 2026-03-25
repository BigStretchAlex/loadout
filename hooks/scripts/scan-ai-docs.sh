#!/usr/bin/env bash
# scan-ai-docs.sh — Scans .ai-docs/ frontmatter for relevant context
# Called by the load-relevant-docs hook on PreToolUse (Read/Glob)
#
# Usage: scan-ai-docs.sh "$TOOL_INPUT"
# Output: Prints relevant .ai-docs/ paths to stdout (consumed as hook output)

set -euo pipefail

AI_DOCS_DIR=".ai-docs"
CACHE_DIR=".dev"
CACHE_FILE="${CACHE_DIR}/.ai-docs-cache"

# Exit silently if no .ai-docs/ directory
if [[ ! -d "$AI_DOCS_DIR" ]]; then
  exit 0
fi

# Create cache directory if needed
mkdir -p "$CACHE_DIR"

# Check if cache is still valid (based on .ai-docs/ modification time)
if [[ -f "$CACHE_FILE" ]]; then
  cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  docs_mtime=$(stat -c %Y "$AI_DOCS_DIR" 2>/dev/null || stat -f %m "$AI_DOCS_DIR" 2>/dev/null || echo 0)

  # If cache is newer than .ai-docs/ dir, use cached results
  if [[ "$cache_mtime" -gt "$docs_mtime" ]]; then
    # Check if the current directory context has already been scanned
    tool_input="${1:-}"
    if [[ -n "$tool_input" ]]; then
      # Extract directory from tool input (best effort)
      dir_context=$(echo "$tool_input" | grep -oP '"(?:file_path|path|pattern)"\s*:\s*"([^"]*)"' | head -1 | sed 's/.*".*"\s*:\s*"\(.*\)"/\1/' | xargs dirname 2>/dev/null || echo ".")
      if grep -qF "$dir_context" "$CACHE_FILE" 2>/dev/null; then
        exit 0  # Already scanned this context
      fi
    fi
  fi
fi

# Scan .ai-docs/ frontmatter
relevant_docs=()

for doc in "$AI_DOCS_DIR"/*.md; do
  [[ -f "$doc" ]] || continue

  # Extract frontmatter (between first and second ---)
  frontmatter=$(awk '/^---$/{if(++count==2) exit} count==1' "$doc")

  # Extract patterns and keywords
  patterns=$(echo "$frontmatter" | grep -A 100 '^patterns:' | grep '^\s*-' | sed 's/^\s*-\s*//' | sed 's/"//g' | head -20)
  keywords=$(echo "$frontmatter" | grep -A 100 '^keywords:' | grep '^\s*-' | sed 's/^\s*-\s*//' | sed 's/"//g' | head -20)
  domain=$(echo "$frontmatter" | grep '^domain:' | sed 's/domain:\s*//' | sed 's/"//g')

  # Store in cache format: path|domain|patterns|keywords
  echo "${doc}|${domain}|${patterns//$'\n'/,}|${keywords//$'\n'/,}" >> "$CACHE_FILE.tmp"
done

# Atomically update cache
if [[ -f "$CACHE_FILE.tmp" ]]; then
  mv "$CACHE_FILE.tmp" "$CACHE_FILE"
fi

# Output available docs summary (brief, for context injection)
doc_count=$(find "$AI_DOCS_DIR" -name "*.md" -type f 2>/dev/null | wc -l)
if [[ "$doc_count" -gt 0 ]]; then
  echo "[loadout] .ai-docs/ knowledge base available: ${doc_count} document(s). Use arbiter agent for pattern lookups."
fi
