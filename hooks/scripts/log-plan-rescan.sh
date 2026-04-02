#!/usr/bin/env bash
# Hook: SubagentStop — tee wrapper around plan-rescan-docs.sh
# Logs rescan output AND passes it through to Claude via stdout
# NOTE: Must run AFTER log-agent-stop.sh (ordering in settings.json matters)

set -euo pipefail

PLUGIN_DIR="${LOADOUT_PLUGIN_DIR:?Set LOADOUT_PLUGIN_DIR to the loadout plugin directory}"
REAL_HOOK="$PLUGIN_DIR/hooks/scripts/plan-rescan-docs.sh"

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
agent_type = d.get('subagent_type', d.get('agent_type', 'unknown'))
session_id = d.get('session_id', 'unknown')
cwd = d.get('cwd', 'unknown')
print(agent_type)
print(session_id)
print(cwd)
" 2>/dev/null) || true

agent_type=$(echo "$input_fields" | sed -n '1p')
session_id=$(echo "$input_fields" | sed -n '2p')
cwd=$(echo "$input_fields" | sed -n '3p')

# Log the output
timestamp=$(date +%H:%M:%S)
log_dir="${LOADOUT_CWD:-$cwd}/.dev"
mkdir -p "$log_dir"

if [ -n "$output" ]; then
  {
    echo "[$timestamp] RESCAN: agent_type=$agent_type session=$session_id cwd=$cwd"
    echo "  output:"
    echo "$output"
    echo "---"
  } >> "$log_dir/loadout-test.log"
else
  echo "[$timestamp] RESCAN: skipped (agent_type=$agent_type session=$session_id cwd=$cwd)" >> "$log_dir/loadout-test.log"
fi

# Pass through to Claude
if [ -n "$output" ]; then
  echo "$output"
fi
