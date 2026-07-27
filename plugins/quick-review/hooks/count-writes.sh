#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')

[[ -z "$session_id" || "$session_id" == "null" ]] && exit 0

COUNTER_FILE="$(commit_nudge_counter_file "$session_id")"

count=0
[[ -f "$COUNTER_FILE" ]] && count=$(cat "$COUNTER_FILE")
count=$((count + 1))
echo "$count" > "$COUNTER_FILE"

if [[ "$count" -eq 5 ]]; then
  post_tool_context "Reminder: commit small changes. Push encouraged (not to main)."
fi
