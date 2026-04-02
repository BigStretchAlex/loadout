#!/usr/bin/env bash
# Hook: PreToolUse — logs Skill invocations
# Passes through without modifying behavior (no stdout = approve)

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
[ "$tool_name" = "Skill" ] || exit 0

fields=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(d.get('session_id', 'unknown'))
print(d.get('tool_use_id', 'unknown'))
print(ti.get('skill', ''))
print(ti.get('args', ''))
" 2>/dev/null) || exit 0

session_id=$(echo "$fields" | sed -n '1p')
tool_use_id=$(echo "$fields" | sed -n '2p')
skill=$(echo "$fields" | sed -n '3p')
args=$(echo "$fields" | sed -n '4,$p')

timestamp=$(date +%H:%M:%S)
log_dir="${LOADOUT_CWD:-.}/.dev"
mkdir -p "$log_dir"
{
  echo "[$timestamp] SKILL: skill=$skill session=$session_id tool_use_id=$tool_use_id"
  echo "  args: $args"
} >> "$log_dir/loadout-test.log"
