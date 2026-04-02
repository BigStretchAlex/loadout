#!/usr/bin/env bash
# Hook: PreToolUse — logs Agent subagent spawns
# Passes through without modifying behavior (no stdout = approve)

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
[ "$tool_name" = "Agent" ] || exit 0

fields=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(d.get('session_id', 'unknown'))
print(d.get('tool_use_id', 'unknown'))
print(ti.get('subagent_type', 'general-purpose'))
print(ti.get('description', ''))
print(str(ti.get('run_in_background', False)).lower())
print(ti.get('prompt', ''))
" 2>/dev/null) || exit 0

session_id=$(echo "$fields" | sed -n '1p')
tool_use_id=$(echo "$fields" | sed -n '2p')
subagent_type=$(echo "$fields" | sed -n '3p')
description=$(echo "$fields" | sed -n '4p')
bg=$(echo "$fields" | sed -n '5p')
prompt=$(echo "$fields" | sed -n '6,$p')

timestamp=$(date +%H:%M:%S)
log_dir="${LOADOUT_CWD:-.}/.dev"
mkdir -p "$log_dir"
{
  echo "[$timestamp] SPAWN: type=$subagent_type bg=$bg session=$session_id tool_use_id=$tool_use_id"
  echo "  desc: $description"
  echo "  prompt: $prompt"
} >> "$log_dir/loadout-test.log"
