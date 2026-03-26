#!/usr/bin/env bash
# Test script for prompt-scan-docs.sh
# Run from project root: bash tests/test-prompt-scan.sh
#
# Uses a stub `claude` script on PATH to return canned topic extraction output,
# so tests run without needing real Claude CLI authentication.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HOOK_SCRIPT="$PROJECT_DIR/hooks/scripts/prompt-scan-docs.sh"
TEST_DIR="$PROJECT_DIR/tests/fixtures/ai-docs-test"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; exit 1; }

# --- Setup: stub claude CLI ---
STUB_DIR=$(mktemp -d)
trap 'rm -rf "$STUB_DIR" "$TEST_DIR/.dev/.ai-docs-cache" "$TEST_DIR/.dev/.ai-docs-session-"*' EXIT

cat > "$STUB_DIR/claude" << 'STUB'
#!/usr/bin/env bash
# Stub claude CLI for testing — reads -p argument, extracts user prompt after "Prompt: "
prompt=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p) prompt="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Extract just the user prompt (after "Prompt: " line)
user_prompt=$(echo "$prompt" | sed -n 's/^Prompt: //p')

# Return topics based on user prompt content
if echo "$user_prompt" | grep -qi "database\|migration"; then
  echo '{"topics":["database-queries","migration-strategy","error-handling"]}'
elif echo "$user_prompt" | grep -qi "authentication\|oauth\|auth"; then
  echo '{"topics":["authentication","oauth-integration","auth-flow","token-refresh"]}'
elif echo "$user_prompt" | grep -qi "error\|exception"; then
  echo '{"topics":["error-handling","error-boundaries","validation"]}'
else
  echo '{"topics":["general-patterns"]}'
fi
STUB
chmod +x "$STUB_DIR/claude"
export PATH="$STUB_DIR:$PATH"

# Clean session state
rm -f "$TEST_DIR/.dev/.ai-docs-cache" "$TEST_DIR/.dev/.ai-docs-session-"*

echo "=== Test 1: Basic topic matching ==="
output=$(echo '{"prompt":"refactor authentication to use OAuth2","session_id":"t1","cwd":"'"$TEST_DIR"'"}' | bash "$HOOK_SCRIPT" 2>/dev/null)
if echo "$output" | grep -q "\[loadout\]"; then
  pass "Output contains [loadout] header"
else
  fail "No [loadout] header. Output: $output"
fi
if echo "$output" | grep -q "auth-patterns.md"; then
  pass "Matched auth-patterns.md"
else
  fail "Did not match auth-patterns.md. Output: $output"
fi

echo ""
echo "=== Test 2: Session accumulation (no re-injection) ==="
output2=$(echo '{"prompt":"refactor authentication to use OAuth2","session_id":"t1","cwd":"'"$TEST_DIR"'"}' | bash "$HOOK_SCRIPT" 2>/dev/null)
if [[ -z "$output2" ]]; then
  pass "No output on repeat (topics already scanned)"
else
  fail "Re-injected already scanned topics. Output: $output2"
fi

echo ""
echo "=== Test 3: New topics in same session ==="
output3=$(echo '{"prompt":"fix database migration errors","session_id":"t1","cwd":"'"$TEST_DIR"'"}' | bash "$HOOK_SCRIPT" 2>/dev/null)
if echo "$output3" | grep -q "database-patterns.md\|error-handling.md"; then
  pass "New topics matched new docs"
else
  fail "Did not match new docs. Output: $output3"
fi

echo ""
echo "=== Test 4: Empty prompt (silent exit) ==="
output4=$(echo '{"prompt":"","session_id":"t2","cwd":"'"$TEST_DIR"'"}' | bash "$HOOK_SCRIPT" 2>/dev/null)
if [[ -z "$output4" ]]; then
  pass "Silent exit on empty prompt"
else
  fail "Output on empty prompt: $output4"
fi

echo ""
echo "=== Test 5: No .ai-docs/ directory (silent exit) ==="
output5=$(echo '{"prompt":"test something","session_id":"t3","cwd":"/tmp"}' | bash "$HOOK_SCRIPT" 2>/dev/null)
if [[ -z "$output5" ]]; then
  pass "Silent exit when no .ai-docs/"
else
  fail "Output without .ai-docs/: $output5"
fi

echo ""
echo "=== Test 6: Cache file created ==="
if [[ -f "$TEST_DIR/.dev/.ai-docs-cache" ]]; then
  pass "Cache file exists"
  echo "  Cache contents:"
  cat "$TEST_DIR/.dev/.ai-docs-cache" | sed 's/^/    /'
else
  fail "No cache file created"
fi

echo ""
echo "=== Test 7: Session file tracks topics ==="
if [[ -f "$TEST_DIR/.dev/.ai-docs-session-t1" ]]; then
  pass "Session file exists"
  echo "  Session contents:"
  cat "$TEST_DIR/.dev/.ai-docs-session-t1" | sed 's/^/    /'
else
  fail "No session file created"
fi

echo ""
echo "=== Test 8: Claude CLI failure (silent exit) ==="
# Override stub to simulate failure
cat > "$STUB_DIR/claude" << 'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$STUB_DIR/claude"
rm -f "$TEST_DIR/.dev/.ai-docs-session-t8"
output8=$(echo '{"prompt":"test something new","session_id":"t8","cwd":"'"$TEST_DIR"'"}' | bash "$HOOK_SCRIPT" 2>/dev/null)
if [[ -z "$output8" ]]; then
  pass "Silent exit when claude CLI fails"
else
  fail "Output when claude CLI failed: $output8"
fi

echo ""
echo "=== All tests complete ==="
