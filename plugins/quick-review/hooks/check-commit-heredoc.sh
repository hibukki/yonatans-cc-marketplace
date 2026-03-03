#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only check git commit commands that use $(cat <<'EOF' or $(cat <<EOF
if echo "$command" | grep -q 'git commit' && echo "$command" | grep -qE '\$\(cat\s+<<'; then
  deny_with_reason 'The $(cat <<EOF) heredoc syntax makes it hard for the user to review the command in the permissions dialog. Please commit without using this pattern.'
fi
