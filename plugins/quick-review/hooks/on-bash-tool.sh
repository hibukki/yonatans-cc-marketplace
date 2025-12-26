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

# Namespace reviews by workspace (cwd) to avoid cross-contamination
cwd=$(echo "$input" | jq -r '.cwd // ""')
cwd_hash=$(echo "$cwd" | md5sum | cut -c1-8)
REVIEW_DIR="/tmp/claude-reviews-${cwd_hash}"

# Ensure review directory exists
mkdir -p "$REVIEW_DIR"

echo "$(date): PostToolUse hook called (workspace: $cwd_hash)" >> "$LOG"

# --- PART 1: Check for and inject any completed reviews ---
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

# --- PART 2: If this was a git commit, spawn a new review ---
command=$(echo "$input" | jq -r '.tool_input.command // ""')
stdout=$(echo "$input" | jq -r '.tool_response.stdout // ""')
spawned_msg=""

if [[ "$command" == *"git commit"* ]]; then
  # Extract commit SHA from output like "[main abc1234] commit message"
  # Use || true to handle case where grep doesn't match (no commit in output)
  new_commit_sha=$(echo "$stdout" | grep -oE '\[[a-zA-Z0-9_/-]+ [a-f0-9]+\]' | grep -oE '[a-f0-9]{7,}' | head -1 || true)

  if [[ -n "$new_commit_sha" ]]; then
    echo "$(date): Detected commit $new_commit_sha, spawning background review" >> "$LOG"

    # Spawn review using the quick-reviewer agent with read-only permissions
    (
      claude -p "Review commit $new_commit_sha" \
        --agent quick-reviewer \
        --permission-mode plan \
        2>>"$LOG" \
        > "$REVIEW_DIR/review-$new_commit_sha.tmp"

      mv "$REVIEW_DIR/review-$new_commit_sha.tmp" "$REVIEW_DIR/review-$new_commit_sha.txt"
      echo "$(date): Review for $new_commit_sha completed" >> "$LOG"
    ) &

    spawned_msg="[Spawned background review for commit $new_commit_sha]"
  fi
fi

# --- PART 3: Output additionalContext (always output something for debugging) ---
debug_msg="[quick-review hook ran]"
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
