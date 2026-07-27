#!/usr/bin/env bash
# Every hook script is registered in plugin.json, and every registered hook exists.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/plugins/quick-review/hooks"
PLUGIN_JSON="$REPO_ROOT/plugins/quick-review/.claude-plugin/plugin.json"

problems=0

registered=$(jq -r '.. | .command? // empty | capture("hooks/(?<hook>[^ ]+\\.sh)").hook' "$PLUGIN_JSON" | sort -u)

while IFS= read -r hook; do
  [[ -f "$HOOKS_DIR/$hook" ]] || { echo "FAIL registration — plugin.json points at missing hooks/$hook"; problems=$((problems + 1)); }
done <<< "$registered"

for script in "$HOOKS_DIR"/*.sh; do
  name=$(basename "$script")
  [[ "$name" == lib-* ]] && continue
  grep -qx "$name" <<< "$registered" || { echo "FAIL registration — hooks/$name is not registered in plugin.json"; problems=$((problems + 1)); }
done

[[ "$problems" -eq 0 ]]
