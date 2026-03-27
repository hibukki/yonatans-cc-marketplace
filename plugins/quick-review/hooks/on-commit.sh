#!/usr/bin/env bash
set -euo pipefail

# Sync PostToolUse hook for git commits.
# Runs claude -p to review the commit and delivers via additionalContext.
#
# Why sync instead of async?
# Claude Code async hooks have a bug where output (systemMessage/additionalContext)
# is never delivered to the conversation, regardless of format.
# Tested: systemMessage, hookSpecificOutput.additionalContext, top-level additionalContext.
# None worked with async:true. All work with sync hooks.
# Bug report: TODO(link)

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-common.sh"
require_jq_or_exit

BIG_COMMIT_THRESHOLD=100  # lines changed

# Read JSON input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run on git commit commands
if ! echo "$COMMAND" | grep -qE '(^|[[:space:]])git[[:space:]].*commit([[:space:]]|$)'; then
  exit 0
fi

# Reset write counter on commit
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[[ -n "$SESSION_ID" && "$SESSION_ID" != "null" ]] && rm -f "/tmp/claude-writes-${SESSION_ID}"

# Extract commit SHA from tool_response
# Git outputs commits like "[main abc1234] commit message"
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // empty')
COMMIT_SHA=$(echo "$STDOUT" | grep -oE '\[[a-zA-Z0-9_/-]+ [a-f0-9]+\]' | grep -oE '[a-f0-9]{7,}' | head -1 || true)

if [[ -z "$COMMIT_SHA" ]]; then
  exit 0
fi

# Count total lines changed (insertions + deletions) in a commit
count_commit_changes() {
  local sha="$1"
  git show --stat "$sha" 2>/dev/null \
    | tail -1 \
    | grep -oE '[0-9]+ insertion|[0-9]+ deletion' \
    | grep -oE '[0-9]+' \
    | paste -sd+ - \
    | bc 2>/dev/null || echo "0"
}

# Build review prompt: full branch review on feature branches, commit review on default branch
DEFAULT_BRANCH=$(get_default_branch)
BRANCH=$(git branch --show-current 2>/dev/null || true)

if [[ -n "$BRANCH" && "$BRANCH" != "$DEFAULT_BRANCH" ]]; then
  # Feature branch: full branch review with user context
  USER_QUOTES=$(extract_user_quotes "$INPUT")
  REVIEW_PROMPT="Review the current branch using \`git diff \$(git merge-base origin/$DEFAULT_BRANCH HEAD)..HEAD\`"
  if [[ -n "$USER_QUOTES" ]]; then
    REVIEW_PROMPT="$REVIEW_PROMPT

User messages sent while working on this feature (some of them might not make sense without more context, but hopefully some will):
$USER_QUOTES"
  fi
else
  # Main/default branch: just review the commit
  REVIEW_PROMPT="Review commit $COMMIT_SHA"
fi

run_agent_review "$REVIEW_PROMPT"

# Build the output message
OUTPUT="=== Branch review (after commit ${COMMIT_SHA}) ===

${REVIEW}

Remember the /prioritize-review-comments skill."

# Large commit warning
if command -v bc &>/dev/null; then
  DIFF_LINES=$(count_commit_changes "$COMMIT_SHA")
  if [[ "$DIFF_LINES" -gt "$BIG_COMMIT_THRESHOLD" ]]; then
    OUTPUT="${OUTPUT}

Note: This was a large commit (${DIFF_LINES} lines changed). Smaller, self-contained commits are easier to review."
  fi
fi

deliver_post_tool_context "$OUTPUT"
