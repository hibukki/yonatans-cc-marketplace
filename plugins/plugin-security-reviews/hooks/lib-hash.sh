#!/usr/bin/env bash
# Library for computing plugin folder hashes

compute_plugin_hash() {
  local plugin_path="$1"
  if [[ ! -d "$plugin_path" ]]; then
    echo ""
    return 1
  fi
  # Hash all file contents (sorted by path for determinism), excluding .git
  find "$plugin_path" -type f -not -path '*/.git/*' -print0 | sort -z | xargs -0 cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1
}

get_review_file_path() {
  local plugin_name="$1"
  local hash="$2"
  echo "$HOME/.claude/plugin-reviews/${plugin_name}-${hash}.json"
}

is_plugin_reviewed() {
  local plugin_name="$1"
  local hash="$2"
  local review_file
  review_file=$(get_review_file_path "$plugin_name" "$hash")
  [[ -f "$review_file" ]]
}
