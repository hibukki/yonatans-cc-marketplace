#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Check if the command contains a newline followed by a #-prefixed line.
# The permission system flags this pattern ("quoted newline followed by a #-prefixed line")
# because # could hide arguments from line-based permission checks.
if echo "$command" | grep -q '^\s*#'; then
  deny_with_reason 'This command has a quoted newline followed by a #-prefixed line, which confuses the permission system. Could you use a different approach please?'
fi
