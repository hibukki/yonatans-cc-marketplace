#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Check if any line AFTER the first starts with #.
# The permission system flags this pattern ("quoted newline followed by a #-prefixed line")
# because # could hide arguments from line-based permission checks.
if printf '%s\n' "$command" | tail -n +2 | grep -q '^[[:space:]]*#'; then
  deny_with_reason 'This command has a quoted newline followed by a #-prefixed line, which confuses the permission system. Could you use a different approach please?'
fi
