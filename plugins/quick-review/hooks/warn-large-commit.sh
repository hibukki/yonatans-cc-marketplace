#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')
stdout=$(echo "$input" | jq -r '.tool_response.stdout // ""')

# Only check git commits
if [[ "$command" != *"git commit"* ]]; then
  exit 0
fi

# Extract commit SHA from output like "[main abc1234] commit message"
commit_sha=$(echo "$stdout" | grep -oE '\[[a-zA-Z0-9_/-]+ [a-f0-9]+\]' | grep -oE '[a-f0-9]{7,}' | head -1 || true)

if [[ -z "$commit_sha" ]]; then
  exit 0
fi

# Count insertions + deletions
diff_lines=$(git show --stat "$commit_sha" | tail -1 | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | grep -oE '[0-9]+' | paste -sd+ - | bc 2>/dev/null || echo "0")

if [[ "$diff_lines" -gt 100 ]]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "As you know, it is nice to have small self-contained commits. This message was automatically triggered by the last commit, but it is only a reminder, use your own judgement."
  }
}
EOF
fi

exit 0
