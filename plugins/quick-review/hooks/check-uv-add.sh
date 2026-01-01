#!/bin/bash
set -euo pipefail

# PreToolUse output format: https://docs.anthropic.com/en/docs/claude-code/hooks

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.p // ""')
new_text=$(echo "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')

# Only check pyproject.toml files
if [[ ! "$file_path" =~ pyproject\.toml$ ]]; then
  exit 0
fi

# Check for version specifier patterns (>=1, ==2, ~=3, etc)
if echo "$new_text" | grep -qE '[>=<~]=?\s*[0-9]'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Use `uv add <pkg>` instead of editing pyproject.toml directly."
  }
}
EOF
  exit 0
fi

exit 0
