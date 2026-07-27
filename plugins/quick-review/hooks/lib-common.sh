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

# Counter file behind the "commit small changes" nudge
write_count_file() {
  echo "${TMPDIR:-/tmp}/claude-writes-$1"
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
# `claude -p --output-format json` emits an array of events ending in a "result" event;
# anything else means the review failed, and REVIEW then holds a loud error report.
# Usage: run_agent_review "prompt" [agent_name]
# Output: sets REVIEW, REVIEW_SESSION_ID, REVIEW_COST_USD,
#         REVIEW_CACHE_CREATION, REVIEW_CACHE_READ variables
run_agent_review() {
  local prompt="$1"
  local agent="${2:-quick-reviewer}"
  local review_file="${TMPDIR:-/tmp}/review-$$-${RANDOM}.txt"
  local stderr_file="${TMPDIR:-/tmp}/review-stderr-$$-${RANDOM}.txt"

  local exit_code=0
  (
    exec >/dev/null
    claude -p "$prompt" --agent "$agent" --output-format json > "$review_file" 2>"$stderr_file"
  ) || exit_code=$?

  local raw_output errors
  raw_output=$(cat "$review_file" 2>/dev/null || true)
  errors=$(cat "$stderr_file" 2>/dev/null || true)
  rm -f "$review_file" "$stderr_file"

  local result
  result=$(echo "$raw_output" | jq -r 'if type == "array" then (.[] | select(.type == "result")) else empty end' 2>/dev/null || true)

  REVIEW=$(echo "$result" | jq -r '.result // empty' 2>/dev/null || true)
  REVIEW_COST_USD=$(echo "$result" | jq -r '.total_cost_usd // empty' 2>/dev/null || true)
  REVIEW_SESSION_ID=$(echo "$result" | jq -r '.session_id // empty' 2>/dev/null || true)
  REVIEW_CACHE_CREATION=$(echo "$result" | jq -r '.usage.cache_creation_input_tokens // empty' 2>/dev/null || true)
  REVIEW_CACHE_READ=$(echo "$result" | jq -r '.usage.cache_read_input_tokens // empty' 2>/dev/null || true)

  if [[ $exit_code -ne 0 || -z "$REVIEW" ]]; then
    REVIEW="ERROR: the $agent reviewer returned no review (claude exit code $exit_code).
You can launch the reviewer yourself if you want one.

stderr:
$errors

stdout:
$raw_output"
  fi
}

# Run a review agent and deliver the result.
# Usage: run_and_deliver_review "header" "prompt" "agent" "footer"
run_and_deliver_review() {
  local header="$1"
  local prompt="$2"
  local agent="${3:-quick-reviewer}"
  local footer="${4:-}"

  run_agent_review "$prompt" "$agent"

  local cost_line=""
  if [[ -n "${REVIEW_COST_USD:-}" && "$REVIEW_COST_USD" != "0" && "$REVIEW_COST_USD" != "null" ]]; then
    cost_line="
Review cost: \$${REVIEW_COST_USD}"
    local cache_read="${REVIEW_CACHE_READ:-0}"
    local cache_created="${REVIEW_CACHE_CREATION:-0}"
    local cache_total=$((cache_read + cache_created))
    if [[ "$cache_total" -gt 0 ]]; then
      local pct_read=$((cache_read * 100 / cache_total))
      cost_line="${cost_line} | Cache reads: ${pct_read}%"
    fi
  fi

  local review_body="$header
<Review>
${REVIEW}
</Review>"
  if [[ -n "$footer" ]]; then
    review_body="$review_body

$footer"
  fi
  deliver_review_with_cost "$review_body" "$cost_line"
}

# Output a block decision for Stop hooks.
# To let the stop through instead, print nothing and exit 0 — "block" is the only
# decision Stop hooks accept: https://code.claude.com/docs/en/hooks
# Usage: stop_block "reason message"
stop_block() {
  jq -n --arg reason "$1" '{"decision":"block","reason":$reason}'
}

# Extract user text messages from the transcript.
# Usage: extract_user_quotes "$INPUT_JSON"
extract_user_quotes() {
  local input="$1"
  local transcript
  transcript=$(echo "$input" | jq -r '.transcript_path // empty')
  if [[ -z "$transcript" || ! -f "$transcript" ]]; then
    echo ""
    return
  fi
  jq -s -r '[.[] | select(.type == "user") | .message.content |
    if type == "array" then
      [.[] | select(.type == "text") | .text] | join("")
    else . end // ""] | join("\n---\n")' "$transcript" 2>/dev/null || true
}

# Output PostToolUse JSON adding context for Claude (not shown to the user)
# Usage: post_tool_context "message"
post_tool_context() {
  jq -n --arg msg "$1" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $msg
    }
  }'
}

# Output hook JSON to deliver a review visible to both user and Claude.
# systemMessage = shown to user, additionalContext = shown to Claude, so the
# cost line reaches the user without spending Claude's context on it.
# Usage: deliver_review_with_cost "review body" "cost line"
deliver_review_with_cost() {
  local body="$1"
  local cost_line="${2:-}"
  local user_msg="${body}${cost_line}"
  jq -n --arg user "$user_msg" --arg claude "$body" '{
    "systemMessage": $user,
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": $claude
    }
  }'
}
