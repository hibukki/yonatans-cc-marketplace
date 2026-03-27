#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.p // ""')
new_text=$(echo "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')

# Only check JS/TS files
if [[ ! "$file_path" =~ \.(js|ts|jsx|tsx)$ ]]; then
  exit 0
fi

if echo "$new_text" | grep -qE 'waitForTimeout'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "This is an automated message for using waitForTimeout (or similar): This is usually a code smell in Playwright tests. Consider waiting for something meaningful instead, like an element becoming visible/hidden, a network request completing, or a URL change. What do you think — is there a more reliable wait condition available here?"
  }
}
EOF
fi
