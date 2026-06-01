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
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "This is an automated message for adding comments: Try to have variable/function names that don't require comments, if possible. Especially avoid (1) repeating code-logic in comments (which might lead to comment rot), (2) in a comment on a variable/field, saying what code uses that field, (3) similarly, in a comment on a function, saying who calls that function (if we'd list all code that references x in a comment on x, that will definitely rot). Comments explaining complex code (like examples for a regex) are still ok, but hopefully such complex code can be minimized. Links to relevant official docs are also ok. Advanced: Your intuition to add comments *might indicate a code small* that it would be good to fix or raise to the user. What do you think about the comments in this case? (this might require introspection)"
  }
}
EOF
fi
