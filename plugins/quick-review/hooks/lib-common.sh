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
# If SESSION_ID is set (exported by caller), persists the reviewer's session ID
# in /tmp so subsequent reviews use --resume for context accumulation.
# Usage: run_agent_review "prompt" [agent_name] [allowed_tools]
#   agent_name defaults to "quick-reviewer"
#   allowed_tools is optional (e.g. "Read,Grep,Glob")
# Output: sets REVIEW, REVIEW_SESSION_ID, REVIEW_COST_USD,
#         REVIEW_CACHE_CREATION, REVIEW_CACHE_READ variables
run_agent_review() {
  local prompt="$1"
  local agent="${2:-quick-reviewer}"
  local allowed_tools="${3:-}"
  local review_file="${TMPDIR:-/tmp}/review-$$-${RANDOM}.txt"
  local stderr_file="${TMPDIR:-/tmp}/review-stderr-$$-${RANDOM}.txt"

  # Check for a persisted reviewer session to resume
  local sid_file=""
  local reviewer_session_id=""
  if [[ -n "${SESSION_ID:-}" ]]; then
    sid_file="${TMPDIR:-/tmp}/claude-reviewer-${SESSION_ID}-${agent}.sid"
    reviewer_session_id=$(cat "$sid_file" 2>/dev/null || true)
  fi

  local claude_args=()
  if [[ -n "$reviewer_session_id" ]]; then
    claude_args+=(--resume "$reviewer_session_id")
  else
    claude_args+=(--agent "$agent")
  fi
  if [[ -n "$allowed_tools" ]]; then
    claude_args+=(--allowedTools "$allowed_tools")
  fi

  local exit_code=0
  (
    exec >/dev/null
    claude -p "$prompt" "${claude_args[@]}" --output-format json > "$review_file" 2>"$stderr_file"
  ) || exit_code=$?
  local raw_output
  raw_output=$(cat "$review_file" 2>/dev/null || true)
  rm -f "$review_file" "$stderr_file"

  # If --resume failed, delete session file and retry fresh
  if [[ $exit_code -ne 0 && -n "$reviewer_session_id" && -n "$sid_file" ]]; then
    rm -f "$sid_file"
    reviewer_session_id=""
    review_file="${TMPDIR:-/tmp}/review-$$-${RANDOM}.txt"
    stderr_file="${TMPDIR:-/tmp}/review-stderr-$$-${RANDOM}.txt"
    exit_code=0
    (
      exec >/dev/null
      claude -p "$prompt" --agent "$agent" ${allowed_tools:+--allowedTools "$allowed_tools"} --output-format json > "$review_file" 2>"$stderr_file"
    ) || exit_code=$?
    raw_output=$(cat "$review_file" 2>/dev/null || true)
    rm -f "$review_file" "$stderr_file"
  fi

  # Extract cost, cache stats, session ID, and review text from JSON output
  local output=""
  REVIEW_COST_USD=""
  REVIEW_CACHE_CREATION=""
  REVIEW_CACHE_READ=""
  REVIEW_SESSION_ID=""
  if command -v jq &>/dev/null && echo "$raw_output" | jq -e '.[0]' &>/dev/null 2>&1; then
    output=$(echo "$raw_output" | jq -r '.[] | select(.type == "result") | .result // empty' 2>/dev/null || true)
    REVIEW_COST_USD=$(echo "$raw_output" | jq -r '.[] | select(.type == "result") | .total_cost_usd // empty' 2>/dev/null || true)
    REVIEW_SESSION_ID=$(echo "$raw_output" | jq -r '.[] | select(.type == "result") | .session_id // empty' 2>/dev/null || true)
    REVIEW_CACHE_CREATION=$(echo "$raw_output" | jq -r '.[] | select(.type == "result") | .usage.cache_creation_input_tokens // empty' 2>/dev/null || true)
    REVIEW_CACHE_READ=$(echo "$raw_output" | jq -r '.[] | select(.type == "result") | .usage.cache_read_input_tokens // empty' 2>/dev/null || true)
  else
    output="$raw_output"
  fi

  # Persist reviewer session ID for next review
  if [[ -n "$sid_file" && -n "$REVIEW_SESSION_ID" && "$REVIEW_SESSION_ID" != "null" ]]; then
    echo "$REVIEW_SESSION_ID" > "$sid_file"
  fi

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
    local debug_msg="Bug: Failed to run reviewer ($agent). Claude can choose to launch a reviewer if they want to."
    if [[ -n "${REVIEW_SESSION_ID:-}" ]]; then
      debug_msg="$debug_msg
To debug: claude --resume $REVIEW_SESSION_ID"
    fi
    deliver_review "$header

$debug_msg"
    return
  fi

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

# Detect the default branch (main or master)
get_default_branch() {
  local branch
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  echo "${branch:-main}"
}

# Extract user text messages from the transcript.
# Usage: extract_user_quotes "$INPUT_JSON" [skip_count]
#   skip_count: number of leading user messages to skip (for resumed sessions)
# Also sets USER_MSG_COUNT to the total number of user messages found.
extract_user_quotes() {
  local input="$1"
  local skip="${2:-0}"
  local transcript
  transcript=$(echo "$input" | jq -r '.transcript_path // empty')
  if [[ -z "$transcript" || ! -f "$transcript" ]]; then
    USER_MSG_COUNT=0
    echo ""
    return
  fi
  local all_msgs
  all_msgs=$(jq -s '[.[] | select(.type == "user") | .message.content |
    if type == "array" then
      [.[] | select(.type == "text") | .text] | join("")
    else . end // ""]' -r "$transcript" 2>/dev/null || true)
  USER_MSG_COUNT=$(echo "$all_msgs" | jq 'length' 2>/dev/null || echo 0)
  echo "$all_msgs" | jq -r ".[$skip:] | join(\"\\n---\\n\")" 2>/dev/null || true
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
# systemMessage = shown to user, additionalContext = shown to Claude.
# Usage: deliver_review "Your review output here"
deliver_review() {
  deliver_review_with_cost "$1"
}

# Like deliver_review but appends extra info (e.g. cost) only to systemMessage (user-visible).
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
