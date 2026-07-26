#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-common.sh"
require_jq_or_exit

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

# Escape hatch: <STOP/> anywhere in the last message bypasses all stop-hook logic
if [[ "$last_assistant_text" == *"<STOP/>"* ]]; then
  exit 0
fi

# Asking permission to push/commit/open-a-PR
if [[ -n "$last_assistant_text" ]] && \
   echo "$last_assistant_text" | grep -qE 'Ready to (push|commit)\?|Want me to (push|create a PR)\?'; then
  stop_block "It is always ok to commit/push/open-PR unless the user requested something else for this project"
  exit 0
fi

# Check for "no blocking comments" — should use the prioritize skill instead
if [[ -n "$last_assistant_text" ]] && \
   echo "$last_assistant_text" | grep -qi 'no \(new \)\?blocking \(comments\|issues\|problems\)'; then
  stop_block "Please prioritize comments not by whether they are blocking, but rather try to make the code we touch amazing (fixing problems even if they're small) (without going out of scope to problems unrelated to the PR/feature we're making because that would overflow to fixing the entire code). To prioritize comments, you can the skill: /prioritize-review-comments. You've got this!"
  exit 0
fi
