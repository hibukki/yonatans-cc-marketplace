#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo ""
  echo "**Warning:** jq is not installed. Some quick-review hooks will be disabled. Install with: brew install jq"
fi

# Surface available package.json scripts so Claude uses them instead of guessing commands
if command -v jq &>/dev/null && [[ -f package.json ]]; then
  scripts=$(jq -r '.scripts // {} | keys[]' package.json 2>/dev/null)
  if [[ -n "$scripts" ]]; then
    # Detect package manager
    if [[ -f pnpm-lock.yaml ]]; then
      pm="pnpm"
    elif [[ -f yarn.lock ]]; then
      pm="yarn"
    elif [[ -f bun.lockb ]] || [[ -f bun.lock ]]; then
      pm="bun"
    else
      pm="npm"
    fi
    echo ""
    echo "**package.json scripts** (use \`$pm run <script>\`):"
    echo "$scripts" | sed 's/^/- /'
  fi
fi
