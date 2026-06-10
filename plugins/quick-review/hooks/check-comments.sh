#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.p // ""')
new_text=$(echo "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')
old_text=$(echo "$input" | jq -r '.tool_input.old_string // ""')

is_code_file=0
is_html_like_file=0
if [[ "$file_path" =~ \.(js|ts|jsx|tsx|py|go|java|c|cpp|h|hpp|rs|swift|kt)$ ]]; then
  is_code_file=1
fi
if [[ "$file_path" =~ \.(html|htm|vue|svelte|astro|md|mdx|jsx|tsx)$ ]]; then
  is_html_like_file=1
fi

if [[ "$is_code_file" == "0" && "$is_html_like_file" == "0" ]]; then
  exit 0
fi

comment_patterns=()
if [[ "$is_code_file" == "1" ]]; then
  comment_patterns+=('//[[:space:]]*[[:alnum:]_]')
  comment_patterns+=('#[[:space:]]*[[:alnum:]_]')
  comment_patterns+=('/\*')
  comment_patterns+=('^[[:space:]]*\*[[:space:]]+[[:alnum:]_]')
fi
if [[ "$is_html_like_file" == "1" ]]; then
  comment_patterns+=('<!--')
fi
combined_pattern=$(IFS='|'; echo "${comment_patterns[*]}")

# Count comment lines, ignoring shebangs and TS triple-slash directives
count_comment_lines() {
  echo "$1" \
    | grep -vE "^#!" \
    | grep -vE '^///[[:space:]]*<reference' \
    | grep -cE "$combined_pattern" || true
}

new_count=$(count_comment_lines "$new_text")
old_count=$(count_comment_lines "$old_text")

# Only nudge when the edit adds more comment lines than it removes
if (( new_count > old_count )); then
  message=$(cat <<'EOF'
This is an automated message for adding comments:
Comments usually indicate a code smell, please introspect what is the case here.

Good comments:
- Reference official docs
- Give an example for a complex regex
- Security assumptions in the schema
Bad comments:
- List who currently uses this code or how (will rot)
- Summarize what the code below/elsewhere does (DRY, will rot)
- Open tasks (gh issue instead)
- Explain why we decided to make this change (goes in the PR description instead)

The project memory might have more examples.

Which case is this one?
EOF
)
  jq -n --arg msg "$message" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $msg
    }
  }'
fi
