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

plans_dir="$HOME/.claude/plans"
if [[ ! -d "$plans_dir" ]]; then
  exit 0
fi

plan_file=$(ls -t "$plans_dir"/*.md 2>/dev/null | head -1)
if [[ -z "$plan_file" ]]; then
  exit 0
fi

review_marker="${plan_file}.reviewed"
if [[ -f "$review_marker" ]]; then
  exit 0
fi

review_output=$(claude -p "Review this plan file: $plan_file" --allowedTools 'Read,Grep,Glob' --agent plan-reviewer 2>&1)
review_exit_code=$?

touch "$review_marker"

if [[ $review_exit_code -ne 0 ]] || [[ -z "$(echo "$review_output" | tr -d '[:space:]')" ]]; then
  deny_with_reason "Plan reviewer failed to run (exit code: $review_exit_code). Error:
$review_output

If you want to run the reviewer, launch the plan-reviewer subagent."
else
  deny_with_reason "A plan-reviewer-claude has suggestions for this plan. Use the suggestions that are helpful for making a top-notch plan, even if the suggestions are small. Discard suggestions that are wrong, of course. You can also AskUserQuestion.
<Suggestions>
$review_output
</Suggestions>

If you want to call this reviewer again, you can launch the plan-reviewer subagent."
fi
