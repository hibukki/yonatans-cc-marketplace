#!/bin/bash
set -euo pipefail

LOG="/tmp/hook-debug.log"

# Require jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed. Install with: brew install jq" >&2
  exit 1
fi

# Read JSON input from stdin
input=$(cat)

# Namespace reviews by session ID to avoid cross-contamination
session_id=$(echo "$input" | jq -r '.session_id')
if [[ -z "$session_id" || "$session_id" == "null" ]]; then
  echo "Error: session_id not found in hook input" >&2
  exit 1
fi
REVIEW_DIR="/tmp/claude-reviews-${session_id}"

# Ensure review directory exists
mkdir -p "$REVIEW_DIR"

echo "$(date): PostToolUse hook called (session: $session_id)" >> "$LOG"

# --- Check for and inject any completed reviews ---
inject_output=""
if [[ -d "$REVIEW_DIR" ]]; then
  for review_file in "$REVIEW_DIR"/review-*.txt; do
    [[ -e "$review_file" ]] || continue

    filename=$(basename "$review_file")
    commit_sha="${filename#review-}"
    commit_sha="${commit_sha%.txt}"

    review_content=$(cat "$review_file")
    inject_output="${inject_output}

=== Review ready for commit ${commit_sha}. Reminder: These are only suggestions, you can pick what to do. Default prioritization: Fix things in-scope even if low-severity ===
<Review>
${review_content}
</Review>
"
    rm -f "$review_file"
    echo "$(date): Injected review for $commit_sha" >> "$LOG"
  done
fi

# --- If this was a git commit, spawn a new review ---
command=$(echo "$input" | jq -r '.tool_input.command // ""')
stdout=$(echo "$input" | jq -r '.tool_response.stdout // ""')
spawned_msg=""

if [[ "$command" == *"git commit"* ]]; then
  # Extract commit SHA from output like "[main abc1234] commit message"
  # Use || true to handle case where grep doesn't match (no commit in output)
  new_commit_sha=$(echo "$stdout" | grep -oE '\[[a-zA-Z0-9_/-]+ [a-f0-9]+\]' | grep -oE '[a-f0-9]{7,}' | head -1 || true)

  if [[ -n "$new_commit_sha" ]]; then
    echo "$(date): Detected commit $new_commit_sha, spawning background review" >> "$LOG"

    # Spawn review using the quick-reviewer agent
    (
      claude -p "Review commit $new_commit_sha" \
        --agent quick-reviewer \
        2>>"$LOG" \
        > "$REVIEW_DIR/review-$new_commit_sha.tmp"

      mv "$REVIEW_DIR/review-$new_commit_sha.tmp" "$REVIEW_DIR/review-$new_commit_sha.txt"
      echo "$(date): Review for $new_commit_sha completed" >> "$LOG"
    ) </dev/null &  # detach stdin so parent doesn't wait for background process

    spawned_msg="[Spawned background review for commit $new_commit_sha]"
  fi
fi

# --- Output additionalContext (always output something for debugging) ---
# debug_msg="[quick-review hook ran]"
debug_msg=""
combined="${inject_output}${spawned_msg}${debug_msg}"
escaped=$(echo "$combined" | jq -Rs .)

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ${escaped}
  }
}
EOF

exit 0
