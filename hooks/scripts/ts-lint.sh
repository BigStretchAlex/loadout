#!/usr/bin/env bash
# Hook: PostToolUse (Edit|Write) — run ESLint on edited JS/TS files
# Report-only: prints lint output but ALWAYS exits 0 (never blocks an edit).

set -euo pipefail

input=$(cat)

file=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
[ -n "$file" ] || exit 0

# Only JS/TS family files
echo "$file" | grep -Eq '\.(ts|tsx|js|jsx|mjs|cjs)$' || exit 0

# Only run when the project actually has an ESLint config
has_eslint_config() {
  local f
  for f in .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml \
           eslint.config.js eslint.config.mjs eslint.config.cjs \
           eslint.config.ts eslint.config.mts eslint.config.cts; do
    [ -f "$f" ] && return 0
  done
  if [ -f package.json ]; then
    python3 -c "import json,sys; sys.exit(0 if 'eslintConfig' in json.load(open('package.json')) else 1)" 2>/dev/null && return 0
  fi
  return 1
}

has_eslint_config || exit 0

npx --no-install eslint --no-warn-ignored "$file" 2>&1 || true

exit 0
