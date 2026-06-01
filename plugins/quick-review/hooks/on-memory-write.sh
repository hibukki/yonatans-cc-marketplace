#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.p // ""')

# Memory lives at ~/.claude/projects/<slug>/memory/
[[ "$file_path" == *"/.claude/projects/"*"/memory/"* ]] || exit 0
# Skip the index file: a single save also touches MEMORY.md, and we want one nudge
[[ "$(basename "$file_path")" == "MEMORY.md" ]] && exit 0

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "This is an automated message for writing to memory: Please introspect — will this memory rot? For example: (1) TODOs go in GitHub issues instead. (2) Explanations about the code go in the repo, so all devs see + understand them."
  }
}
EOF
