#!/usr/bin/env bash
set -euo pipefail

# Sync PostToolUse hook for git push.
# Reviews the full branch vs default branch when pushing a feature branch.

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/lib-common.sh"
require_jq_or_exit

# Read JSON input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run on "git push" (not "git stash push" etc.)
if ! echo "$COMMAND" | grep -qE '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
  exit 0
fi

DEFAULT_BRANCH=$(get_default_branch)

# Skip if on default branch (nothing to review against)
BRANCH=$(git branch --show-current 2>/dev/null || true)
if [[ -z "$BRANCH" || "$BRANCH" == "$DEFAULT_BRANCH" ]]; then
  exit 0
fi

run_agent_review "Review the current branch vs $DEFAULT_BRANCH, e.g with \`git diff \$(git merge-base origin/$DEFAULT_BRANCH HEAD)..HEAD\`"

OUTPUT="=== Branch review for ${BRANCH} (pushed) ===

${REVIEW}

Remember the /prioritize-review-comments skill.
Reminder: check if ci passed (if the project uses ci)."

deliver_post_tool_context "$OUTPUT"
