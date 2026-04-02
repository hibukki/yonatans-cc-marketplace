#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

# Only applies when running inside a worktree
[[ "$PWD" == */.claude/worktrees/* ]] || exit 0

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only care about commands that start with cd
[[ "$command" =~ ^[[:space:]]*cd[[:space:]] ]] || exit 0

# Extract the cd target (first token after cd)
cd_target=$(echo "$command" | sed 's/^[[:space:]]*cd[[:space:]]*//' | awk '{print $1}')

[[ -n "$cd_target" ]] || exit 0

resolved=$(resolve_path "$cd_target")

# Extract worktree root
worktree_root=$(echo "$PWD" | sed 's|^\(.*/.claude/worktrees/[^/]*\).*|\1|')

# If inside worktree, fine
[[ "$resolved" == "$worktree_root/"* || "$resolved" == "$worktree_root" ]] && exit 0

# Extract base repo path
base_repo=$(echo "$worktree_root" | sed 's|/\.claude/worktrees/.*||')

# Only block access to the base repo — not unrelated paths
[[ "$resolved" == "$base_repo/"* || "$resolved" == "$base_repo" ]] || exit 0

deny_with_reason "Please stay in the worktree. You're running in $worktree_root but \`cd\` targets $cd_target"
