# lib-common.sh - sourced by hook scripts

# Portable realpath -m: resolve path without requiring it to exist
# (macOS doesn't ship GNU realpath, so we use python3)
resolve_path() {
  local p="$1"
  [[ "$p" != /* ]] && p="$PWD/$p"
  python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$p"
}

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
  local stderr_file="/tmp/review-stderr-$$-${RANDOM}.txt"

  local agent_args=(--agent "$agent")
  if [[ -n "$allowed_tools" ]]; then
    agent_args+=(--allowedTools "$allowed_tools")
  fi

  local exit_code=0
  (
    exec >/dev/null
    claude -p "$prompt" "${agent_args[@]}" > "$review_file" 2>"$stderr_file"
  ) || exit_code=$?
  local output
  output=$(cat "$review_file" 2>/dev/null || true)
  local stderr_output
  stderr_output=$(cat "$stderr_file" 2>/dev/null || true)
  rm -f "$review_file" "$stderr_file"

  # Try to extract session ID from stderr (UUID format)
  REVIEW_SESSION_ID=$(echo "$stderr_output" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || true)

  if [[ $exit_code -ne 0 ]]; then
    REVIEW="ERROR (exit code $exit_code): $output"
  else
    REVIEW="$output"
  fi
}

# Run a review agent and deliver the result (or an error if empty).
# Usage: run_and_deliver_review "header" "prompt" "agent" "footer"
run_and_deliver_review() {
  local header="$1"
  local prompt="$2"
  local agent="${3:-quick-reviewer}"
  local footer="${4:-}"

  run_agent_review "$prompt" "$agent"

  if [[ -z "$REVIEW" ]]; then
    local debug_msg="Bug in scaffolding: no output from reviewer ($agent)."
    if [[ -n "${REVIEW_SESSION_ID:-}" ]]; then
      debug_msg="$debug_msg
To debug: claude --resume $REVIEW_SESSION_ID"
    fi
    deliver_review "$header

$debug_msg"
    return
  fi

  local output="$header
<Review>
${REVIEW}
</Review>
"
  if [[ -n "$footer" ]]; then
    output="$output

$footer"
  fi
  deliver_review "$output"
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
