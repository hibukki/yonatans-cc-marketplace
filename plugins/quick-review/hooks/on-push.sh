#!/usr/bin/env bash
set -euo pipefail

# Sync PostToolUse hook for git push.
# Reviews the full branch vs main when pushing a non-main branch.

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-common.sh"
require_jq_or_exit

# Read JSON input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run on git push commands
if ! echo "$COMMAND" | grep -qE '(^|[[:space:]])git[[:space:]].*push([[:space:]]|$)'; then
  exit 0
fi

# Skip if on main branch (nothing to review against)
BRANCH=$(git branch --show-current 2>/dev/null || true)
if [[ -z "$BRANCH" || "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  exit 0
fi

run_agent_review "Review the current branch vs main"

OUTPUT="=== Branch review for ${BRANCH} (pushed) ===

${REVIEW}

Use the prioritize-review-comments skill to decide which suggestions to implement."

deliver_post_tool_context "$OUTPUT"
