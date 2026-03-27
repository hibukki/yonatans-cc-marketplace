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

# Build review prompt with user context
USER_QUOTES=$(extract_user_quotes "$INPUT")
REVIEW_PROMPT="Review this plan file: $FILE_PATH"
if [[ -n "$USER_QUOTES" ]]; then
  REVIEW_PROMPT="$REVIEW_PROMPT

User messages sent while working on this feature (some of them might not make sense without more context, but hopefully some will):
$USER_QUOTES"
fi

run_agent_review "$REVIEW_PROMPT" plan-reviewer "Read,Grep,Glob"

deliver_review "=== Plan review ===

${REVIEW}

Use the suggestions that are helpful. Discard wrong ones."
