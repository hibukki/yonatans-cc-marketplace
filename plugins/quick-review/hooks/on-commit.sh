#!/bin/bash
set -euo pipefail

# Read JSON input from stdin
input=$(cat)

# Extract the command that was run
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Check if this was a git commit command
if [[ "$command" == *"git commit"* ]]; then
  # Tell Claude to spawn the quick-reviewer agent in the background
  cat <<'EOF'
{
  "systemMessage": "A git commit just completed. Please spawn the quick-reviewer agent in the background (using the Task tool with run_in_background: true) to review the commit. Continue with your current work - the review will complete asynchronously."
}
EOF
fi

# Exit successfully (don't block anything)
exit 0
