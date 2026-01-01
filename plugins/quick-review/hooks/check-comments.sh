#!/bin/bash
set -euo pipefail

# PreToolUse output format: https://docs.anthropic.com/en/docs/claude-code/hooks

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.p // ""')
new_text=$(echo "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')

# Only check code files (skip markdown, yaml, toml, json, shell scripts)
if [[ ! "$file_path" =~ \.(js|ts|jsx|tsx|py|go|java|c|cpp|h|hpp|rs|swift|kt)$ ]]; then
  exit 0
fi

# Filter out shebangs
filtered=$(echo "$new_text" | grep -vE '^#!')

# Check for comment patterns
has_double_slash=$(echo "$filtered" | grep -qE '//\s*\w' && echo 1 || echo 0)
has_hash=$(echo "$filtered" | grep -qE '#\s*\w' && echo 1 || echo 0)
has_block_start=$(echo "$filtered" | grep -qE '/\*' && echo 1 || echo 0)
has_jsdoc_line=$(echo "$filtered" | grep -qE '^\s*\*\s+\w' && echo 1 || echo 0)
has_html=$(echo "$filtered" | grep -qE '<!--' && echo 1 || echo 0)

if [[ "$has_double_slash" == "1" || "$has_hash" == "1" || "$has_block_start" == "1" || "$has_jsdoc_line" == "1" || "$has_html" == "1" ]]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "permissionDecision": "allow"
  },
  "systemMessage": "This is an automated message for adding comments: Try to have variable/function names that don't require comments, if possible. Especially avoid repeating code-logic in comments (which might lead to comment rot). What do you think about the comments in this case?"
}
EOF
fi

exit 0
