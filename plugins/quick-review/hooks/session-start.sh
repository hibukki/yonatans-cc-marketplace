#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo ""
  echo "**Warning:** jq is not installed. Some quick-review hooks will be disabled. Install with: brew install jq"
fi
