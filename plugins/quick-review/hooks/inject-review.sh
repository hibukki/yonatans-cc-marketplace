#!/bin/bash
set -euo pipefail

REVIEW_DIR="/tmp/claude-reviews"
LOG="/tmp/hook-debug.log"

# Check if any review files exist
if [[ ! -d "$REVIEW_DIR" ]]; then
  exit 0
fi

# Find completed review files
reviews=$(find "$REVIEW_DIR" -name "review-*.txt" -type f 2>/dev/null || true)

if [[ -z "$reviews" ]]; then
  exit 0
fi

# Collect all reviews
all_reviews=""
for review_file in $reviews; do
  # Extract commit SHA from filename (review-abc1234.txt -> abc1234)
  filename=$(basename "$review_file")
  commit_sha="${filename#review-}"
  commit_sha="${commit_sha%.txt}"

  # Read review content
  review_content=$(cat "$review_file" 2>/dev/null || echo "Error reading review")

  all_reviews="${all_reviews}

=== Review for commit ${commit_sha} ===
${review_content}
"

  # Delete the processed review file
  rm -f "$review_file"
  echo "$(date): Injected review for $commit_sha" >> "$LOG"
done

# Output the reviews as additionalContext
if [[ -n "$all_reviews" ]]; then
  # Escape the reviews for JSON
  escaped_reviews=$(echo "$all_reviews" | jq -Rs .)

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": ${escaped_reviews}
  }
}
EOF
fi

exit 0
