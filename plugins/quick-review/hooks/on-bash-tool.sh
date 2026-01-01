#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-review.sh"

LOG="/tmp/hook-debug.log"

# Read JSON input from stdin
input=$(cat)
REVIEW_DIR=$(get_review_dir "$input")

# Ensure review directory exists
mkdir -p "$REVIEW_DIR"

echo "$(date): PostToolUse hook called" >> "$LOG"

# --- Check for and inject any completed reviews ---
inject_output=$(get_completed_reviews "$REVIEW_DIR")

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
