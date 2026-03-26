#!/usr/bin/env bash
# prompt-scan-docs.sh — Intelligent .ai-docs/ scanning on prompt submission
# Called by the prompt-doc-scan hook on UserPromptSubmit
#
# Reads JSON from stdin: {"prompt":"...","session_id":"...","cwd":"..."}
# Output: Matched docs with relevance tiers and section line ranges

set -euo pipefail

AI_DOCS_DIR=".ai-docs"
CACHE_DIR=".dev"
CACHE_FILE="${CACHE_DIR}/.ai-docs-cache"
MAX_DOCS=5
MAX_SECTIONS=10

# --- Parse stdin JSON ---
input=$(cat)
prompt=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")
session_id=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "default")
cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")

# Change to project directory if provided (env var override for testing)
cwd="${LOADOUT_CWD:-$cwd}"
if [[ -n "$cwd" ]]; then
  cd "$cwd" 2>/dev/null || exit 0
fi

# Exit silently if no prompt or no .ai-docs/
[[ -z "$prompt" ]] && exit 0
[[ -d "$AI_DOCS_DIR" ]] || exit 0

# Create cache directory
mkdir -p "$CACHE_DIR"

SESSION_FILE="${CACHE_DIR}/.ai-docs-session-${session_id}"

# --- Extract topics using claude CLI ---
# --bare: fast start, no recursive hooks
# --model haiku: cheapest/fastest model
# --system-prompt: minimal prompt replaces default system prompt
# --tools "": no tools, pure text-in text-out
# --json-schema: validated structured output
TOPIC_SCHEMA='{"type":"object","properties":{"topics":{"type":"array","items":{"type":"string"},"minItems":1,"maxItems":8}},"required":["topics"]}'

topics_json=$(claude --bare --model haiku \
  --system-prompt "Extract search topics from user prompts. Return lowercase kebab-case topics." \
  --tools "" \
  --json-schema "$TOPIC_SCHEMA" \
  -p "Extract 3-8 search topics from this prompt. Topics should match documentation patterns like: authentication, error-handling, api-design, testing-patterns, database-queries, jwt-authentication, oauth-integration, etc.

Prompt: ${prompt}" < /dev/null 2>/dev/null || echo "")

# Parse validated JSON → one topic per line
topics=$(echo "$topics_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for t in data['topics']:
        print(t.strip())
except Exception:
    pass
" 2>/dev/null)

[[ -z "$topics" ]] && exit 0

# --- Filter to new topics only ---
previously_scanned=""
if [[ -f "$SESSION_FILE" ]]; then
  previously_scanned=$(awk '/^# topics$/{f=1; next} /^#/{f=0} f' "$SESSION_FILE" | tr '\n' ' ')
fi

new_topics=()
while IFS= read -r topic; do
  [[ -z "$topic" ]] && continue
  if ! echo " $previously_scanned " | grep -qi " $topic "; then
    new_topics+=("$topic")
  fi
done <<< "$topics"

[[ ${#new_topics[@]} -eq 0 ]] && exit 0

# --- Build/refresh frontmatter cache ---
rebuild_cache() {
  local cache_tmp="${CACHE_FILE}.tmp"
  > "$cache_tmp"

  for doc in "$AI_DOCS_DIR"/*.md; do
    [[ -f "$doc" ]] || continue

    # Use python3 to parse YAML frontmatter reliably
    python3 -c "
import sys

# Read frontmatter between --- markers
lines = []
in_fm = False
count = 0
with open('$doc') as f:
    for line in f:
        line = line.rstrip('\n')
        if line.strip() == '---':
            count += 1
            if count == 2:
                break
            in_fm = True
            continue
        if in_fm:
            lines.append(line)

# Simple YAML parser for our known structure
domain = ''
patterns = []
keywords = []
sections = []
current_field = None
current_section = {}

for line in lines:
    stripped = line.strip()
    # Top-level fields
    if line.startswith('domain:'):
        domain = stripped.split(':', 1)[1].strip().strip('\"')
        current_field = None
    elif line.startswith('title:'):
        current_field = None
    elif line.startswith('patterns:'):
        current_field = 'patterns'
    elif line.startswith('keywords:'):
        current_field = 'keywords'
    elif line.startswith('sections:'):
        current_field = 'sections'
    elif current_field == 'patterns' and stripped.startswith('- '):
        patterns.append(stripped[2:].strip().strip('\"'))
    elif current_field == 'keywords' and stripped.startswith('- '):
        keywords.append(stripped[2:].strip().strip('\"'))
    elif current_field == 'sections':
        if stripped.startswith('- name:'):
            if current_section:
                sections.append(current_section)
            current_section = {'name': stripped.split(':', 1)[1].strip().strip('\"')}
        elif stripped.startswith('line_start:'):
            current_section['ls'] = stripped.split(':', 1)[1].strip()
        elif stripped.startswith('line_end:'):
            current_section['le'] = stripped.split(':', 1)[1].strip()
        elif stripped.startswith('summary:'):
            current_section['sum'] = stripped.split(':', 1)[1].strip().strip('\"')

if current_section:
    sections.append(current_section)

# Format sections as name|line_start|line_end|summary joined by ;
sec_strs = []
for s in sections:
    if 'name' in s and 'ls' in s and 'le' in s:
        sec_strs.append(f\"{s['name']}|{s['ls']}|{s['le']}|{s.get('sum','')}\")

p = ','.join(patterns)
k = ','.join(keywords)
ss = ';'.join(sec_strs)
print(f'$doc\t{domain}\t{p}\t{k}\t{ss}')
" >> "$cache_tmp" 2>/dev/null
  done

  mv "$cache_tmp" "$CACHE_FILE"
}

# Refresh cache if stale
needs_rebuild=false
if [[ ! -f "$CACHE_FILE" ]]; then
  needs_rebuild=true
else
  cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  for doc in "$AI_DOCS_DIR"/*.md; do
    [[ -f "$doc" ]] || continue
    doc_mtime=$(stat -c %Y "$doc" 2>/dev/null || stat -f %m "$doc" 2>/dev/null || echo 0)
    if [[ "$doc_mtime" -gt "$cache_mtime" ]]; then
      needs_rebuild=true
      break
    fi
  done
fi

if $needs_rebuild; then
  rebuild_cache
fi

[[ -f "$CACHE_FILE" ]] || exit 0

# --- Score topics against cache ---
declare -A doc_scores
declare -A doc_sections

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
        matched_sections="${matched_sections}${sec_name}|${sec_ls}|${sec_le}|${sec_sum}\n"
      fi
    done
  done

  if [[ $score -ge 2 ]]; then
    doc_scores["$doc_path"]=$score
    doc_sections["$doc_path"]="$matched_sections"
  fi
done < "$CACHE_FILE"

# Exit if no matches
[[ ${#doc_scores[@]} -eq 0 ]] && exit 0

# --- Update session file ---
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

# Sort docs by score (descending)
for doc_path in $(for k in "${!doc_scores[@]}"; do echo "${doc_scores[$k]} $k"; done | sort -rn | awk '{print $2}'); do
  [[ $doc_count -ge $MAX_DOCS ]] && break

  score=${doc_scores[$doc_path]}
  sections_str=${doc_sections[$doc_path]}
  basename=$(basename "$doc_path")

  # Build section lines
  section_lines=""
  while IFS='|' read -r sec_name sec_ls sec_le sec_sum; do
    [[ -z "$sec_name" ]] && continue
    [[ $section_count -ge $MAX_SECTIONS ]] && break
    section_lines="${section_lines}  - \"${sec_name}\" (lines ${sec_ls}-${sec_le}): ${sec_sum}\n"
    echo "${basename}|${sec_name}|${sec_ls}-${sec_le}" >> "${SESSION_FILE}.tmp"
    section_count=$((section_count + 1))
  done < <(echo -e "$sections_str")

  entry="${doc_path}\n${section_lines}"

  if [[ $score -ge 5 ]]; then
    high_docs="${high_docs}${entry}"
  else
    medium_docs="${medium_docs}${entry}"
  fi

  doc_count=$((doc_count + 1))
done

mv "${SESSION_FILE}.tmp" "$SESSION_FILE"

# Format and output
{
  echo "[loadout] Relevant .ai-docs/ for this prompt:"
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
