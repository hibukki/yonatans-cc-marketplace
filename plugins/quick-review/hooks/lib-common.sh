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
# Usage: run_agent_review "prompt" [agent_name] [allowed_tools]
#   agent_name defaults to "quick-reviewer"
#   allowed_tools is optional (e.g. "Read,Grep,Glob")
# Output: sets REVIEW variable with review text (or error message)
run_agent_review() {
  local prompt="$1"
  local agent="${2:-quick-reviewer}"
  local allowed_tools="${3:-}"
  local review_file="/tmp/review-$$-${RANDOM}.txt"

  local agent_args=(--agent "$agent")
  if [[ -n "$allowed_tools" ]]; then
    agent_args+=(--allowedTools "$allowed_tools")
  fi

  (
    exec >/dev/null 2>&1
    claude -p "$prompt" "${agent_args[@]}" > "$review_file" 2>&1
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

# Output a block decision for Stop hooks
# Usage: stop_block "reason message"
stop_block() {
  jq -n --arg reason "$1" '{"decision":"block","reason":$reason}'
}

# Output an approve decision for Stop hooks
stop_approve() {
  echo '{"decision":"approve"}'
}

# Detect the default branch (main or master)
get_default_branch() {
  local branch
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  echo "${branch:-main}"
}

# Extract all user text messages from the transcript.
# Usage: extract_user_quotes "$INPUT_JSON"
# Reads transcript_path from the input JSON, extracts all user messages.
extract_user_quotes() {
  local input="$1"
  local transcript
  transcript=$(echo "$input" | jq -r '.transcript_path // empty')
  if [[ -z "$transcript" || ! -f "$transcript" ]]; then
    echo ""
    return
  fi
  jq -s '[.[] | select(.type == "user") | .message.content |
    if type == "array" then
      [.[] | select(.type == "text") | .text] | join("")
    else . end // ""] | join("\n---\n")' -r "$transcript" 2>/dev/null || true
}

# Output hook JSON to deliver a review visible to both user and Claude.
# systemMessage = shown to user, additionalContext = shown to Claude.
# Usage: deliver_review "Your review output here"
deliver_review() {
  local message="$1"
  jq -n --arg msg "$message" '{
    "systemMessage": $msg,
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": $msg
    }
  }'
}
