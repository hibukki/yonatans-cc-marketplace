# lib-common.sh - sourced by hook scripts

# Exit silently if jq is not installed (avoids errors on every hook call)
require_jq_or_exit() {
  command -v jq &>/dev/null || exit 0
}

# Output a deny decision for PreToolUse hooks
# Usage: deny_with_reason "reason message"
deny_with_reason() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

# Run a claude agent review in an isolated subshell.
# Captures output to a temp file to prevent claude stdout from corrupting hook JSON.
# Usage: run_agent_review "Review commit abc1234"
# Output: sets REVIEW variable with review text (or error message)
run_agent_review() {
  local prompt="$1"
  local review_file="/tmp/review-$$-${RANDOM}.txt"

  (
    exec >/dev/null 2>&1
    claude -p "$prompt" --agent quick-reviewer > "$review_file" 2>&1
  )
  local exit_code=$?
  local output
  output=$(cat "$review_file" 2>/dev/null || echo "NO REVIEW OUTPUT")
  rm -f "$review_file"

  if [[ $exit_code -ne 0 ]]; then
    REVIEW="ERROR (exit code $exit_code): $output"
  else
    REVIEW="$output"
  fi
}

# Output hook JSON to deliver feedback via additionalContext (non-blocking).
# Usage: deliver_post_tool_context "Your review message here"
deliver_post_tool_context() {
  local message="$1"
  jq -n --arg ctx "$message" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": $ctx
    }
  }'
}
