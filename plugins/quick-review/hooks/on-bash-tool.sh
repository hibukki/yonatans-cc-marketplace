#!/bin/bash
set -euo pipefail

LOG="/tmp/hook-debug.log"
REVIEW_DIR="/tmp/claude-reviews"

# Ensure review directory exists
mkdir -p "$REVIEW_DIR"

# Read JSON input from stdin
input=$(cat)
echo "$(date): PostToolUse hook called" >> "$LOG"

# Extract the command and response
command=$(echo "$input" | jq -r '.tool_input.command // ""')
stdout=$(echo "$input" | jq -r '.tool_response.stdout // ""')

# Check if this was a git commit command
if [[ "$command" == *"git commit"* ]]; then
  # Extract commit SHA from output like "[main abc1234] commit message"
  commit_sha=$(echo "$stdout" | grep -oE '\[[a-zA-Z0-9_/-]+ [a-f0-9]+\]' | grep -oE '[a-f0-9]{7,}' | head -1)

  if [[ -n "$commit_sha" ]]; then
    echo "$(date): Detected commit $commit_sha, spawning background review" >> "$LOG"

    # Spawn claude -p in background to review the commit
    (
      claude -p "Review the git commit $commit_sha. Run: git show $commit_sha

Look for: obvious bugs, security issues, forgotten debug code, broken imports.
Skip: style nitpicks, naming suggestions, refactoring ideas.

Be concise. If no issues found, just say 'No issues found.'" \
        --dangerously-skip-permissions 2>>"$LOG" \
        > "$REVIEW_DIR/review-$commit_sha.tmp"

      # Atomic rename - file only appears as .txt when review is complete
      mv "$REVIEW_DIR/review-$commit_sha.tmp" "$REVIEW_DIR/review-$commit_sha.txt"
      echo "$(date): Review for $commit_sha completed" >> "$LOG"
    ) &

    # Output confirmation that review was spawned
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[DEBUG] PostToolUse: Spawned background review for commit $commit_sha"
  }
}
EOF
  fi
fi

exit 0
