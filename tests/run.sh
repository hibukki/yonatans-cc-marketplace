#!/usr/bin/env bash
# Golden-file tests for the quick-review hooks.
#
# tests/cases/<hook>/<case>.in       stdin for hooks/<hook>.sh
# tests/cases/<hook>/<case>.out      expected stdout
# tests/cases/<hook>/<case>.before.sh   optional, sourced first (cwd is a fresh
#                                       temp dir which is also $TMPDIR)
# tests/cases/<hook>/<case>.after.sh    optional, sourced last; its stdout is
#                                       appended to the hook's, so a case can
#                                       assert on state the hook changed
#
# __WORK_DIR__ stands for the temp dir in both the .in and the .out.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/plugins/quick-review/hooks"

passed=0
failed=0

for case_file in "$REPO_ROOT"/tests/cases/*/*.in; do
  hook=$(basename "$(dirname "$case_file")")
  case_name="$hook/$(basename "$case_file" .in)"
  hook_script="$HOOKS_DIR/$hook.sh"
  expected_file="${case_file%.in}.out"

  for required in "$hook_script" "$expected_file"; do
    if [[ ! -f "$required" ]]; then
      echo "FAIL $case_name — missing $required"
      failed=$((failed + 1))
      continue 2
    fi
  done

  work_dir=$(mktemp -d)
  actual=$(
    export TMPDIR="$work_dir"
    cd "$work_dir" || exit 1
    before="${case_file%.in}.before.sh"
    after="${case_file%.in}.after.sh"
    [[ -f "$before" ]] && source "$before"
    sed "s|__WORK_DIR__|$work_dir|g" "$case_file" | bash "$hook_script"
    [[ -f "$after" ]] && source "$after"
  )
  rm -rf "$work_dir"
  actual=${actual//$work_dir/__WORK_DIR__}

  if [[ "$actual" == "$(cat "$expected_file")" ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL $case_name"
    diff "$expected_file" <(printf '%s\n' "$actual") | sed 's/^/    /'
  fi
done

"$REPO_ROOT/tests/check-hook-registration.sh" || failed=$((failed + 1))

echo "$passed passed, $failed failed"
[[ "$failed" -eq 0 ]]
