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

  # grep/rg: extract paths from the end of the command (after all flags and pattern).
  # Handles: grep [-flags]... "pattern" path1 path2 | ...
  if [[ "$cmd" =~ ^[[:space:]]*(grep|rg)[[:space:]] ]]; then
    # Strip everything after a pipe
    local before_pipe="${cmd%%|*}"
    # Get the last whitespace-separated token — that's the file/dir path
    local last_token
    last_token=$(echo "$before_pipe" | awk '{print $NF}')
    # Only treat it as a path if it starts with / or .
    if [[ "$last_token" == /* || "$last_token" == .* ]]; then
      echo "$last_token"
    fi
    return
  fi
}

target_path=$(extract_path "$command")

[[ -n "$target_path" ]] || exit 0

resolved=$(resolve_path "$target_path")

# Extract worktree root
worktree_root=$(echo "$PWD" | sed 's|^\(.*/.claude/worktrees/[^/]*\).*|\1|')

# If inside worktree, fine
[[ "$resolved" == "$worktree_root/"* || "$resolved" == "$worktree_root" ]] && exit 0

# Extract base repo path
base_repo=$(echo "$worktree_root" | sed 's|/\.claude/worktrees/.*||')

# Only block access to the base repo — not unrelated paths
[[ "$resolved" == "$base_repo/"* || "$resolved" == "$base_repo" ]] || exit 0

# Extract the command name for the error message
cmd_name=$(echo "$command" | awk '{print $1}')
deny_with_reason "Please stay in the worktree. You're running in $worktree_root but \`$cmd_name\` targets $target_path"
