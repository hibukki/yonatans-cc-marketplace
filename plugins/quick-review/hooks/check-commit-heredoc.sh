#!/usr/bin/env bash

exit 0 # Maybe not needed with auto-mode

set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only check git commit commands that use $(cat <<'EOF' or $(cat <<EOF
if echo "$command" | grep -q 'git commit' && echo "$command" | grep -qE '\$\(cat\s+<<'; then
  deny_with_reason 'The `$(cat <<EOF)` syntax makes it hard for the permission system. Could you commit without it please?'
fi
