#!/usr/bin/env bash
# Hook: UserPromptSubmit — tee wrapper around prompt-scan-docs.sh
# Logs doc-scan output AND passes it through to Claude via stdout

set -euo pipefail

PLUGIN_DIR="${LOADOUT_PLUGIN_DIR:?Set LOADOUT_PLUGIN_DIR to the loadout plugin directory}"
REAL_HOOK="$PLUGIN_DIR/hooks/scripts/prompt-scan-docs.sh"

if [ ! -x "$REAL_HOOK" ]; then
  echo "[loadout-test] ERROR: $REAL_HOOK not found or not executable" >&2
  exit 0
fi

# Capture stdin to pass to real hook
input=$(cat)

# Run real hook, capture output
output=$(echo "$input" | "$REAL_HOOK" 2>/dev/null) || true

# Extract input fields for logging
input_fields=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('session_id', 'unknown'))
print(d.get('cwd', '.'))
print(d.get('prompt', ''))
" 2>/dev/null) || true

session_id=$(echo "$input_fields" | sed -n '1p')
cwd=$(echo "$input_fields" | sed -n '2p')
prompt=$(echo "$input_fields" | sed -n '3,$p')

timestamp=$(date +%H:%M:%S)
log_dir="${LOADOUT_CWD:-$cwd}/.dev"
mkdir -p "$log_dir"

if [ -n "$output" ]; then
  {
    echo "[$timestamp] DOC-SCAN: session=$session_id"
    echo "  prompt: $prompt"
    echo "  output:"
    echo "$output"
    echo "---"
  } >> "$log_dir/loadout-test.log"
else
  {
    echo "[$timestamp] DOC-SCAN: session=$session_id (no matches)"
    echo "  prompt: $prompt"
  } >> "$log_dir/loadout-test.log"
fi

# Pass through to Claude
if [ -n "$output" ]; then
  echo "$output"
fi
