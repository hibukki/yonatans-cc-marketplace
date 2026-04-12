#!/usr/bin/env bash
set -euo pipefail

exit 0; # TODO: Did disabling this work? is it still ok?

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Block commands where a line after the first starts with #.
# This pattern ("quoted newline followed by a #-prefixed line") confuses the
# permission system because # could hide arguments from line-based checks.
if printf '%s\n' "$command" | tail -n +2 | grep -q '^[[:space:]]*#'; then
  deny_with_reason 'This command has a quoted newline followed by a #-prefixed line, which confuses the permission system. Could you use a different approach please?'
fi
