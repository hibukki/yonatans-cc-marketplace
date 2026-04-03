#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

# Only applies when running inside a worktree
[[ "$PWD" == */.claude/worktrees/* ]] || exit 0

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Extract the path from the command based on which tool is being used.
# Returns empty string (and we exit 0) if the command isn't one we handle.
extract_path() {
  local cmd="$1"

  # cd <path>
  if [[ "$cmd" =~ ^[[:space:]]*cd[[:space:]] ]]; then
    echo "$cmd" | sed 's/^[[:space:]]*cd[[:space:]]*//' | awk '{print $1}'
    return
  fi

  # find <path> ...
  if [[ "$cmd" =~ ^[[:space:]]*find[[:space:]] ]]; then
    echo "$cmd" | sed 's/^[[:space:]]*find[[:space:]]*//' | awk '{print $1}'
    return
  fi

  # grep/rg: check all path-like tokens (starting with / or .)
  # Handles: grep [-flags]... "pattern" path1 path2 | ...
  if [[ "$cmd" =~ ^[[:space:]]*(grep|rg)[[:space:]] ]]; then
    local before_pipe="${cmd%%|*}"
    # Print all tokens that look like paths
    echo "$before_pipe" | tr ' ' '\n' | grep -E '^(/|\.)' || true
    return
  fi
}

target_paths=$(extract_path "$command")

[[ -n "$target_paths" ]] || exit 0

# Extract worktree root and base repo path
worktree_root=$(echo "$PWD" | sed 's|^\(.*/.claude/worktrees/[^/]*\).*|\1|')
base_repo=$(echo "$worktree_root" | sed 's|/\.claude/worktrees/.*||')
cmd_name=$(echo "$command" | awk '{print $1}')

while IFS= read -r target_path; do
  [[ -n "$target_path" ]] || continue
  resolved=$(resolve_path "$target_path")
  [[ "$resolved" == "$worktree_root/"* || "$resolved" == "$worktree_root" ]] && continue
  [[ "$resolved" == "$base_repo/"* || "$resolved" == "$base_repo" ]] || continue
  deny_with_reason "Please stay in the worktree. You're running in $worktree_root but \`$cmd_name\` targets $target_path"
  exit 0
done <<< "$target_paths"
