#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-common.sh"
require_jq_or_exit

# Read input early so we can pass it to sub-scripts
input=$(cat)

# Extract last assistant message text (reused by several checks below)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
last_assistant_text=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  last_assistant_text=$(tail -100 "$transcript_path" | \
    jq -s '[.[] | select(.type == "assistant")] | last | .message.content |
           if type == "array" then
             [.[] | select(.type == "text") | .text] | join("")
           else . end // ""' -r 2>/dev/null || echo "")
fi

# Escape hatch: ending the message with <STOP/> bypasses all stop-hook logic
if [[ "$last_assistant_text" =~ '<STOP/>'[[:space:]]*$ ]]; then
  stop_approve
  exit 0
fi

# Check if message ends with "?" - remind to use AskUserQuestion
question_check=$("$SCRIPT_DIR/check-question-ending.sh" <<< "$input")
if echo "$question_check" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  echo "$question_check"
  exit 0
fi

# Check for "no blocking comments" — should use the prioritize skill instead
if [[ -n "$last_assistant_text" ]] && \
   echo "$last_assistant_text" | grep -qi 'no \(new \)\?blocking \(comments\|issues\|problems\)'; then
  stop_block "Please prioritize comments not by whether they are blocking, but rather try to make the code we touch amazing (fixing problems even if they're small) (without going out of scope to problems unrelated to the PR/feature we're making because that would overflow to fixing the entire code). To prioritize comments, you can the skill: /prioritize-review-comments. You've got this!"
  exit 0
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  stop_block "There are uncommitted changes. Please commit, stash, gitignore, or whatever fits the situation. Also push (and open a PR) unless a more specific workflow was requested (e.g by the user / claude.md). If you intentionally want to stop without committing, end your next message with <STOP/> to bypass this reminder."
  exit 0
fi

stop_approve
