#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-review.sh"

input=$(cat)
review_dir=$(get_review_dir "$input")

# Check for completed reviews only
completed=$(get_completed_reviews "$review_dir")

if [[ -n "$completed" ]]; then
  escaped=$(echo "$completed" | jq -Rs .)
  cat <<EOF
{
  "decision": "block",
  "reason": ${escaped}
}
EOF
else
  echo '{"decision": "approve"}'
fi

exit 0
