#!/usr/bin/env bash
# Hook: PostToolUse (Edit|Write) — run Jest tests related to the edited JS/TS file
# Report-only: prints test output but ALWAYS exits 0 (never blocks an edit).

set -euo pipefail

input=$(cat)

file=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
[ -n "$file" ] || exit 0

# Only JS/TS family files
echo "$file" | grep -Eq '\.(ts|tsx|js|jsx|mjs|cjs)$' || exit 0

# Only run when the project actually uses Jest
has_jest() {
  local f
  for f in jest.config.js jest.config.cjs jest.config.mjs jest.config.json \
           jest.config.ts jest.config.cts jest.config.mts; do
    [ -f "$f" ] && return 0
  done
  if [ -f package.json ]; then
    python3 -c "
import json, sys
d = json.load(open('package.json'))
deps = {}
deps.update(d.get('dependencies', {}))
deps.update(d.get('devDependencies', {}))
sys.exit(0 if 'jest' in d or 'jest' in deps else 1)
" 2>/dev/null && return 0
  fi
  return 1
}

has_jest || exit 0

npx --no-install jest --findRelatedTests "$file" --passWithNoTests --silent 2>&1 || true

exit 0
