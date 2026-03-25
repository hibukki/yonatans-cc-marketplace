#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-common.sh"
require_jq_or_exit

# Read input early so we can pass it to sub-scripts
input=$(cat)

# Check if message ends with "?" - remind to use AskUserQuestion
question_check=$("$SCRIPT_DIR/check-question-ending.sh" <<< "$input")
if echo "$question_check" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  echo "$question_check"
  exit 0
fi

# Check for "no blocking comments" — should use the prioritize skill instead
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  last_assistant_text=$(tail -100 "$transcript_path" | \
    jq -s '[.[] | select(.type == "assistant")] | last | .message.content |
           if type == "array" then
             [.[] | select(.type == "text") | .text] | join("")
           else . end // ""' -r 2>/dev/null || echo "")
  if echo "$last_assistant_text" | grep -qi 'no \(new \)\?blocking comments'; then
    stop_block "To prioritize comments, use the skill: /prioritize-review-comments. We don't prioritize by whether the comment is blocking or not"
    exit 0
  fi
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  stop_block "There are uncommitted changes. Please commit, stash, gitignore, or whatever fits the situation. Also push (and open a PR) unless a more specific workflow was requested (e.g by the user / claude.md)"
  exit 0
fi

stop_approve
