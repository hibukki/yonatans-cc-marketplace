#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-review.sh"

input=$(cat)
review_dir=$(get_review_dir "$input")

# Check for completed reviews
completed=$(get_completed_reviews "$review_dir")

# Check for pending reviews
pending_count=$(count_pending_reviews "$review_dir")

# Build response
if [[ -n "$completed" || "$pending_count" -gt 0 ]]; then
  message=""

  if [[ -n "$completed" ]]; then
    message="${completed}"
  fi

  if [[ "$pending_count" -gt 0 ]]; then
    message="${message}

⏳ ${pending_count} review(s) still in progress. You may want to wait for them before stopping."
  fi

  escaped=$(echo "$message" | jq -Rs .)
  cat <<EOF
{
  "decision": "block",
  "reason": "Reviews pending",
  "systemMessage": ${escaped}
}
EOF
else
  echo '{"decision": "approve"}'
fi

exit 0
