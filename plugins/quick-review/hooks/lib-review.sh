#!/bin/bash
# Shared library for review-related hooks

# Get review directory for current session
get_review_dir() {
  local input="$1"
  local session_id=$(echo "$input" | jq -r '.session_id')
  if [[ -z "$session_id" || "$session_id" == "null" ]]; then
    echo "/tmp/claude-reviews-unknown"
  else
    echo "/tmp/claude-reviews-${session_id}"
  fi
}

# Check for completed reviews (.txt files) and return their content
# Also removes the files after reading
get_completed_reviews() {
  local review_dir="$1"
  local output=""

  if [[ -d "$review_dir" ]]; then
    for review_file in "$review_dir"/review-*.txt; do
      [[ -e "$review_file" ]] || continue

      local filename=$(basename "$review_file")
      local commit_sha="${filename#review-}"
      commit_sha="${commit_sha%.txt}"

      local review_content=$(cat "$review_file")
      output="${output}

=== Review ready for commit ${commit_sha}. Reminder: These are only suggestions, you can pick what to do. User preference is: Fix correct suggestions that are in-scope, including minor suggestions. e.g if the code removed a variable then also remove comments explaining that variable, even though that is small. ===
<Review>
${review_content}
</Review>
"
      rm -f "$review_file"
    done
  fi

  echo "$output"
}

# Check for pending reviews (.tmp files) - still in progress
count_pending_reviews() {
  local review_dir="$1"

  if [[ -d "$review_dir" ]]; then
    ls "$review_dir"/review-*.tmp 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}
