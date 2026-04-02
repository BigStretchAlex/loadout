#!/usr/bin/env bash
# Hook: SubagentStop — logs when subagents complete
# No stdout needed (informational hook)

set -euo pipefail

input=$(cat)

fields=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
agent_type = d.get('subagent_type', d.get('agent_type', 'unknown'))
session_id = d.get('session_id', 'unknown')
stop_reason = d.get('stop_reason', 'unknown')
cwd = d.get('cwd', 'unknown')
print(agent_type)
print(session_id)
print(stop_reason)
print(cwd)
" 2>/dev/null) || exit 0

agent_type=$(echo "$fields" | sed -n '1p')
session_id=$(echo "$fields" | sed -n '2p')
stop_reason=$(echo "$fields" | sed -n '3p')
cwd=$(echo "$fields" | sed -n '4p')

timestamp=$(date +%H:%M:%S)
log_dir="${LOADOUT_CWD:-.}/.dev"
mkdir -p "$log_dir"
{
  echo "[$timestamp] STOP: agent_type=$agent_type stop_reason=$stop_reason session=$session_id"
  echo "  cwd: $cwd"
} >> "$log_dir/loadout-test.log"
