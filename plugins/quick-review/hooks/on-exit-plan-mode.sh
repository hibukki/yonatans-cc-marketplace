#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
plan_content=$(echo "$input" | jq -r '.tool_input.plan // ""')

if [[ -z "$plan_content" ]]; then
  exit 0
fi

if ! echo "$plan_content" | grep -qi "commit"; then
  # Use this as an excuse to remind claude about best-practices, not only about commits
  deny_with_reason "Please use the plan-checklist skill and update the plan, then you can exit plan mode"
  exit 0
fi

# Plan review is handled by on-plan-edit.sh (fires on every plan file edit).
# No need to review again here.
