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

strip_yaml_frontmatter() {
  awk 'NR==1 && $0=="---" { inside=1; next } inside && $0=="---" { inside=0; next } !inside'
}

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
  post_tool_context "This is an automated message about the comment lines this edit added.

$(strip_yaml_frontmatter < "$(dirname "$0")/../skills/comment-guidance/SKILL.md")

The project memory might have more examples. Which case is this one?"
fi
