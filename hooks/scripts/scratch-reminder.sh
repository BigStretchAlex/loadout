#!/usr/bin/env bash
# scratch-reminder.sh — Reminds to capture insights in scratch memory
# Called by the scratch-capture hook on PostToolUse (Bash)
#
# Output: Prints a reminder to stdout if working in a .dev/ context

set -euo pipefail

DEV_DIR=".dev"
REMINDED_FILE="${DEV_DIR}/.scratch-reminded"

# Exit silently if no .dev/ directory
if [[ ! -d "$DEV_DIR" ]]; then
  exit 0
fi

# Find active work items (directories in .dev/ that aren't hidden)
active_items=()
for item_dir in "$DEV_DIR"/*/; do
  [[ -d "$item_dir" ]] || continue
  item_name=$(basename "$item_dir")
  # Skip hidden directories
  [[ "$item_name" == .* ]] && continue
  # Only include items with a plan.md (actively being worked on)
  if [[ -f "${item_dir}plan.md" ]]; then
    active_items+=("$item_name")
  fi
done

# No active work items with plans
if [[ ${#active_items[@]} -eq 0 ]]; then
  exit 0
fi

# Check if we've already reminded for these items this session
mkdir -p "$DEV_DIR"
for item in "${active_items[@]}"; do
  if grep -qxF "$item" "$REMINDED_FILE" 2>/dev/null; then
    continue
  fi

  # Check if scratch.md exists for this item
  scratch_file="${DEV_DIR}/${item}/scratch.md"
  if [[ -f "$scratch_file" ]]; then
    echo "[loadout] Working on ${item} — remember to capture insights in .dev/${item}/scratch.md"
    echo "$item" >> "$REMINDED_FILE"
    # Only remind for one item at a time to avoid noise
    break
  fi
done
