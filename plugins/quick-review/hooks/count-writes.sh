#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')

[[ -z "$session_id" || "$session_id" == "null" ]] && exit 0

COUNTER_FILE="${TMPDIR:-/tmp}/claude-writes-${session_id}"

count=0
[[ -f "$COUNTER_FILE" ]] && count=$(cat "$COUNTER_FILE")
count=$((count + 1))
echo "$count" > "$COUNTER_FILE"
# TODO: consider making the threshold configurable (currently 5)

if [[ "$count" -eq 5 ]]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Reminder: commit small changes. Push encouraged (not to main)."
  }
}
EOF
fi
