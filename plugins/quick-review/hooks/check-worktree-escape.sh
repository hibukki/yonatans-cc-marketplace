#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

# Only applies when running inside a worktree
[[ "$PWD" == */.claude/worktrees/* ]] || exit 0

# Extract the worktree root: everything up to and including the worktree name
# e.g. /Users/foo/project/.claude/worktrees/eager-hypatia-14828
worktree_root=$(echo "$PWD" | sed 's|^\(.*/.claude/worktrees/[^/]*\).*|\1|')
worktree_root=$(realpath -m "$worktree_root" 2>/dev/null || echo "$worktree_root")

input=$(cat)
target_path=$(echo "$input" | jq -r '.tool_input.path // .tool_input.file_path // ""')

# No path specified (defaults to cwd) — that's fine
[[ -n "$target_path" ]] || exit 0

# Resolve symlinks and ".." to prevent traversal bypass
resolved=$(realpath -m "$target_path" 2>/dev/null || echo "$target_path")

# If the resolved path is inside this worktree, it's fine
[[ "$resolved" == "$worktree_root/"* || "$resolved" == "$worktree_root" ]] && exit 0

deny_with_reason "Please stay in the worktree. You're running in $worktree_root but tried to access $target_path"
