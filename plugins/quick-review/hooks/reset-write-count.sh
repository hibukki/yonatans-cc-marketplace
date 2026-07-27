#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

echo "$command" | grep -qE '(^|[[:space:]])git[[:space:]].*commit([[:space:]]|$)' || exit 0

session_id=$(echo "$input" | jq -r '.session_id // ""')
[[ -n "$session_id" && "$session_id" != "null" ]] || exit 0

rm -f "$(commit_nudge_counter_file "$session_id")"
