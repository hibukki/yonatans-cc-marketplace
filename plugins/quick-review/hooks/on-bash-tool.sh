#!/bin/bash
set -euo pipefail

LOG="/tmp/hook-debug.log"
REVIEW_DIR="/tmp/claude-reviews"

# Ensure review directory exists
mkdir -p "$REVIEW_DIR"

# Read JSON input from stdin
input=$(cat)
echo "$(date): PostToolUse hook called" >> "$LOG"

# --- PART 1: Check for and inject any completed reviews ---
inject_output=""
if [[ -d "$REVIEW_DIR" ]]; then
  for review_file in "$REVIEW_DIR"/review-*.txt; do
    [[ -e "$review_file" ]] || continue

    filename=$(basename "$review_file")
    commit_sha="${filename#review-}"
    commit_sha="${commit_sha%.txt}"

    review_content=$(cat "$review_file" 2>/dev/null || echo "Error reading review")
    inject_output="${inject_output}

=== Review for commit ${commit_sha} ===
${review_content}
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
  new_commit_sha=$(echo "$stdout" | grep -oE '\[[a-zA-Z0-9_/-]+ [a-f0-9]+\]' | grep -oE '[a-f0-9]{7,}' | head -1)

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

# --- PART 3: Output combined additionalContext ---
if [[ -n "$inject_output" || -n "$spawned_msg" ]]; then
  combined="${inject_output}${spawned_msg}"
  escaped=$(echo "$combined" | jq -Rs .)

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ${escaped}
  }
}
EOF
fi

exit 0
