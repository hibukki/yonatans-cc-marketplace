#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib-common.sh"
require_jq_or_exit

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

if [[ "$tool_name" != "Edit" ]]; then
  exit 0
fi

old_string=$(echo "$input" | jq -r '.tool_input.old_string // ""')
new_string=$(echo "$input" | jq -r '.tool_input.new_string // ""')

if [[ -z "$old_string" || -z "$new_string" ]]; then
  exit 0
fi

result=$(OLD="$old_string" NEW="$new_string" python3 <<'PYEOF'
import os
old = os.environ.get("OLD", "")
new = os.environ.get("NEW", "")

i = 0
while i < min(len(old), len(new)) and old[i] == new[i]:
    i += 1

j_old = len(old)
j_new = len(new)
while j_old > i and j_new > i and old[j_old-1] == new[j_new-1]:
    j_old -= 1
    j_new -= 1

removed = old[i:j_old]
added = new[i:j_new]

# Pure insertion that starts with ",\n" (the previously-last line is being
# given a trailing comma + line break, then more lines), inserted right after
# a non-comma/non-whitespace char, and right before a newline or closing
# delimiter. That's the "added new item at end of list/object/params" smell.
if (removed == ""
    and (added.startswith(",\n") or added.startswith(",\r\n"))
    and i > 0
    and old[i-1] not in (",", "\n", "\r", " ", "\t")
    and i < len(old)
    and old[i] in ("\n", "\r", ")", "]", "}")):
    print("APPEND_DETECTED")
PYEOF
)

if [[ "$result" == "APPEND_DETECTED" ]]; then
  jq -n --arg msg "Tip: this edit appended a new item at the very end of a list/object/param list, so the previously-last line got a diff just to add ',\\n' to it. Consider inserting the new item BEFORE the last one (or earlier) — that keeps the diff to pure additions, no modification of an existing line. Ignore if order matters (e.g. positional arguments)." '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'
fi
