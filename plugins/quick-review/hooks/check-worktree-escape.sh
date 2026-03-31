#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

# Only applies when running inside a worktree
[[ "$PWD" == */.claude/worktrees/* ]] || exit 0

# Portable realpath -m: resolve path without requiring it to exist
resolve_path() {
  local p="$1"
  [[ "$p" != /* ]] && p="$PWD/$p"
  python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$p"
}

# Extract the worktree root: everything up to and including the worktree name
# e.g. /Users/foo/project/.claude/worktrees/eager-hypatia-14828
worktree_root=$(echo "$PWD" | sed 's|^\(.*/.claude/worktrees/[^/]*\).*|\1|')

input=$(cat)
target_path=$(echo "$input" | jq -r '.tool_input.path // .tool_input.file_path // ""')

# No path specified (defaults to cwd) — that's fine
[[ -n "$target_path" ]] || exit 0

# Resolve ".." to prevent traversal bypass
resolved=$(resolve_path "$target_path")

# If the resolved path is inside this worktree, it's fine
[[ "$resolved" == "$worktree_root/"* || "$resolved" == "$worktree_root" ]] && exit 0

# Extract the base repo path: everything before /.claude/worktrees/
# e.g. /Users/foo/project/.claude/worktrees/nice-tesla-32458 → /Users/foo/project
base_repo=$(echo "$worktree_root" | sed 's|/\.claude/worktrees/.*||')

# Only block access to the base repo itself — not to unrelated paths like ~/.claude/
[[ "$resolved" == "$base_repo/"* || "$resolved" == "$base_repo" ]] || exit 0

deny_with_reason "Please stay in the worktree. You're running in $worktree_root but tried to access $target_path"
