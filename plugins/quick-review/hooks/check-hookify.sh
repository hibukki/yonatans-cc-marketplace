#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="$(dirname "$0")/.."

# Check if we have hookify rules
hookify_rules=$(find "$PLUGIN_ROOT/hooks" -name "hookify.*.local.md" 2>/dev/null | wc -l | tr -d ' ')

if [ "$hookify_rules" -gt 0 ]; then
  # Check if hookify plugin is installed by looking for its hooks in the system
  # We check if the hookify skill is available (crude but works)
  if ! claude --print-plugins 2>/dev/null | grep -q "hookify"; then
    cat <<'EOF'
{
  "systemMessage": "⚠️ This plugin includes hookify rules but the hookify plugin doesn't appear to be installed. The rules in hooks/hookify.*.local.md won't work. To install: /plugin install hookify@claude-plugins-official"
}
EOF
    echo "⚠️ quick-review plugin: Found hookify rules but hookify plugin not detected. Some hooks may not work." >&2
  fi
fi

exit 0
