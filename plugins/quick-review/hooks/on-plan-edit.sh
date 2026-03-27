#!/usr/bin/env bash
set -euo pipefail

# Sync PostToolUse hook for plan file edits.
# Runs the plan-reviewer agent whenever a plan file in ~/.claude/plans/ is edited.

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-common.sh"
require_jq_or_exit

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only run for plan files
if [[ "$FILE_PATH" != "$HOME/.claude/plans/"*.md ]]; then
  exit 0
fi

# Invalidate the .reviewed marker (so on-exit-plan-mode knows the plan changed)
rm -f "${FILE_PATH}.reviewed"

# Build review prompt with user context
USER_QUOTES=$(extract_user_quotes "$INPUT")
REVIEW_PROMPT="Review this plan file: $FILE_PATH"
if [[ -n "$USER_QUOTES" ]]; then
  REVIEW_PROMPT="$REVIEW_PROMPT

User messages sent while working on this feature (some of them might not make sense without more context, but hopefully some will):
$USER_QUOTES"
fi

# Run plan-reviewer
review_file="/tmp/plan-review-$$-${RANDOM}.txt"
(
  exec >/dev/null 2>&1
  claude -p "$REVIEW_PROMPT" --allowedTools 'Read,Grep,Glob' --agent plan-reviewer > "$review_file" 2>&1
)
review_exit_code=$?
review_output=$(cat "$review_file" 2>/dev/null || echo "NO REVIEW OUTPUT")
rm -f "$review_file"

# Mark as reviewed (so on-exit-plan-mode doesn't re-review the same version)
touch "${FILE_PATH}.reviewed"

if [[ $review_exit_code -ne 0 ]] || [[ -z "$(echo "$review_output" | tr -d '[:space:]')" ]]; then
  deliver_review "Plan reviewer failed (exit code: $review_exit_code): $review_output"
else
  deliver_review "=== Plan review ===

$review_output

Use the suggestions that are helpful. Discard wrong ones."
fi
