#!/usr/bin/env bash
# plan-rescan-docs.sh — Re-evaluates .ai-docs/ topics after subagent completion
# Called by the plan-rescan hook on SubagentStop
#
# Reads JSON from stdin with session and agent info
# If an Explore-type agent completed, extracts new topics and re-scans

set -euo pipefail

AI_DOCS_DIR=".ai-docs"
CACHE_DIR=".dev"
CACHE_FILE="${CACHE_DIR}/.ai-docs-cache"
MAX_DOCS=5
MAX_SECTIONS=10

# --- Parse stdin JSON ---
input=$(cat)
session_id=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "default")
agent_type=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('subagent_type','') or d.get('agent_type',''))" 2>/dev/null || echo "")
agent_name=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('subagent_type','') or d.get('agent_type','') or d.get('name',''))" 2>/dev/null || echo "")
cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")

# Change to project directory if provided (env var override for testing)
cwd="${LOADOUT_CWD:-$cwd}"
if [[ -n "$cwd" ]]; then
  cd "$cwd" 2>/dev/null || exit 0
fi

# Exit silently if no .ai-docs/
[[ -d "$AI_DOCS_DIR" ]] || exit 0

SESSION_FILE="${CACHE_DIR}/.ai-docs-session-${session_id}"

# Only fire for Explore-type agents
is_explore=false
for pattern in "Explore" "explore" "Plan" "plan"; do
  if [[ "$agent_type" == *"$pattern"* ]] || [[ "$agent_name" == *"$pattern"* ]]; then
    is_explore=true
    break
  fi
done

$is_explore || exit 0

# Need existing session file and cache
[[ -f "$SESSION_FILE" ]] || exit 0
[[ -f "$CACHE_FILE" ]] || exit 0

mkdir -p "$CACHE_DIR"

# --- Get previously scanned topics ---
previous_topics=$(awk '/^# topics$/{f=1; next} /^#/{f=0} f' "$SESSION_FILE" | tr '\n' ' ')

# --- Discover new related topics using claude CLI ---
TOPIC_SCHEMA='{"type":"object","properties":{"topics":{"type":"array","items":{"type":"string"},"minItems":1,"maxItems":5}},"required":["topics"]}'

topics_json=$(claude --bare --model haiku \
  --system-prompt "Suggest related documentation topics given previously identified topics. Return lowercase kebab-case topics." \
  --tools "" \
  --json-schema "$TOPIC_SCHEMA" \
  -p "Given these previously identified topics from a codebase exploration session:
${previous_topics}

What 3-5 additional related topics might be relevant that are NOT already listed? Think about related patterns, dependencies, and architectural concerns." < /dev/null 2>/dev/null || echo "")

# Parse validated JSON → filter to genuinely new topics
new_topics=()

while IFS= read -r topic; do
  [[ -z "$topic" ]] && continue
  if ! echo " $previous_topics " | grep -qi " $topic "; then
    new_topics+=("$topic")
  fi
done < <(echo "$topics_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for t in data['topics']:
        print(t.strip())
except Exception:
    pass
" 2>/dev/null)

# No new topics discovered — exit silently
[[ ${#new_topics[@]} -eq 0 ]] && exit 0

# --- Score new topics against cache ---
declare -A doc_scores
declare -A doc_sections

# Get already-injected docs to avoid repeats
previously_injected=""
if [[ -f "$SESSION_FILE" ]]; then
  previously_injected=$(awk '/^# injected$/{f=1; next} f' "$SESSION_FILE")
fi

while IFS=$'\t' read -r doc_path domain patterns_csv keywords_csv sections_csv; do
  score=0
  matched_sections=""

  for topic in "${new_topics[@]}"; do
    topic_lower=$(echo "$topic" | tr '[:upper:]' '[:lower:]')

    # Score patterns
    IFS=',' read -ra pats <<< "$patterns_csv"
    for pat in "${pats[@]}"; do
      pat_lower=$(echo "$pat" | tr '[:upper:]' '[:lower:]' | xargs)
      if [[ "$pat_lower" == "$topic_lower" ]]; then
        score=$((score + 5))
      elif [[ "$pat_lower" == *"$topic_lower"* ]]; then
        score=$((score + 2))
      fi
    done

    # Score keywords
    IFS=',' read -ra kws <<< "$keywords_csv"
    for kw in "${kws[@]}"; do
      kw_lower=$(echo "$kw" | tr '[:upper:]' '[:lower:]' | xargs)
      if [[ "$kw_lower" == "$topic_lower" ]]; then
        score=$((score + 3))
      elif [[ "$kw_lower" == *"$topic_lower"* ]]; then
        score=$((score + 1))
      fi
    done

    # Score sections
    IFS=';' read -ra secs <<< "$sections_csv"
    for sec in "${secs[@]}"; do
      IFS='|' read -r sec_name sec_ls sec_le sec_sum <<< "$sec"
      sec_name_lower=$(echo "$sec_name" | tr '[:upper:]' '[:lower:]')
      sec_sum_lower=$(echo "$sec_sum" | tr '[:upper:]' '[:lower:]')
      sec_matched=false

      if [[ "$sec_name_lower" == *"$topic_lower"* ]]; then
        score=$((score + 2))
        sec_matched=true
      fi
      if [[ "$sec_sum_lower" == *"$topic_lower"* ]]; then
        score=$((score + 2))
        sec_matched=true
      fi

      if $sec_matched; then
        local_basename=$(basename "$doc_path")
        # Skip if already injected
        if ! echo "$previously_injected" | grep -q "${local_basename}|${sec_name}"; then
          matched_sections="${matched_sections}${sec_name}|${sec_ls}|${sec_le}|${sec_sum}\n"
        fi
      fi
    done
  done

  if [[ $score -ge 2 ]]; then
    doc_scores["$doc_path"]=$score
    doc_sections["$doc_path"]="$matched_sections"
  fi
done < "$CACHE_FILE"

# Exit if no new matches
[[ ${#doc_scores[@]} -eq 0 ]] && exit 0

# --- Update session file with new topics ---
{
  echo "# topics"
  if [[ -f "$SESSION_FILE" ]]; then
    awk '/^# topics$/{f=1; next} /^#/{f=0} f' "$SESSION_FILE"
  fi
  for topic in "${new_topics[@]}"; do
    echo "$topic"
  done
  echo "# injected"
  if [[ -f "$SESSION_FILE" ]]; then
    awk '/^# injected$/{f=1; next} f' "$SESSION_FILE"
  fi
} > "${SESSION_FILE}.tmp"

# --- Build output ---
output=""
high_docs=""
medium_docs=""
doc_count=0
section_count=0

for doc_path in $(for k in "${!doc_scores[@]}"; do echo "${doc_scores[$k]} $k"; done | sort -rn | awk '{print $2}'); do
  [[ $doc_count -ge $MAX_DOCS ]] && break

  score=${doc_scores[$doc_path]}
  sections_str=${doc_sections[$doc_path]}
  basename=$(basename "$doc_path")

  # Skip docs with no new sections
  [[ -z "$sections_str" ]] && continue

  section_lines=""
  while IFS='|' read -r sec_name sec_ls sec_le sec_sum; do
    [[ -z "$sec_name" ]] && continue
    [[ $section_count -ge $MAX_SECTIONS ]] && break
    section_lines="${section_lines}  - \"${sec_name}\" (lines ${sec_ls}-${sec_le}): ${sec_sum}\n"
    echo "${basename}|${sec_name}|${sec_ls}-${sec_le}" >> "${SESSION_FILE}.tmp"
    section_count=$((section_count + 1))
  done < <(echo -e "$sections_str")

  [[ -z "$section_lines" ]] && continue

  entry="${doc_path}\n${section_lines}"

  if [[ $score -ge 5 ]]; then
    high_docs="${high_docs}${entry}"
  else
    medium_docs="${medium_docs}${entry}"
  fi

  doc_count=$((doc_count + 1))
done

mv "${SESSION_FILE}.tmp" "$SESSION_FILE"

# Only output if we have actual new sections to show
[[ -z "$high_docs" && -z "$medium_docs" ]] && exit 0

{
  echo "[loadout] New .ai-docs/ matches discovered after exploration:"
  echo ""

  if [[ -n "$high_docs" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if [[ "$line" == .ai-docs/* || "$line" == ".ai-docs/"* ]]; then
        echo "HIGH: $line"
      else
        echo "$line"
      fi
    done < <(echo -e "$high_docs")
    echo ""
  fi

  if [[ -n "$medium_docs" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if [[ "$line" == .ai-docs/* || "$line" == ".ai-docs/"* ]]; then
        echo "MEDIUM: $line"
      else
        echo "$line"
      fi
    done < <(echo -e "$medium_docs")
    echo ""
  fi

  echo "Read sections with: Read .ai-docs/<file>.md lines <start>-<end>"
}
