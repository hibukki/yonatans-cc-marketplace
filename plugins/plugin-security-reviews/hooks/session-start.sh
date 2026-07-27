#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-hash.sh"

if ! command -v jq &>/dev/null; then
  echo ""
  echo "**Warning:** jq is not installed, so plugin-security-reviews can't check for unreviewed plugins. Install with: brew install jq"
  exit 0
fi

SETTINGS_FILE="$HOME/.claude/settings.json"
PLUGIN_CACHE_DIR="$HOME/.claude/plugins/cache"
CONFIG_FILE="$HOME/.claude/plugin-security-reviews.local.json"

# Get reminder mode from config (default: on-startup-every-time)
get_reminder_mode() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "on-startup-every-time"
    return
  fi
  local mode
  mode=$(jq -r '.reminder // "on-startup-every-time"' "$CONFIG_FILE" 2>/dev/null)
  echo "$mode"
}

# Check if a plugin was dismissed (for on-startup-once mode)
is_plugin_dismissed() {
  local plugin_name="$1"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 1
  fi
  jq -e --arg p "$plugin_name" '.dismissed_plugins // [] | index($p) != null' "$CONFIG_FILE" >/dev/null 2>&1
}

# Read enabled plugins from settings
get_enabled_plugins() {
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    return
  fi
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS_FILE" 2>/dev/null || true
}

# Parse plugin@marketplace format
parse_plugin_entry() {
  local entry="$1"
  local plugin_name="${entry%@*}"
  local marketplace="${entry#*@}"
  echo "$plugin_name" "$marketplace"
}

# Check for unreviewed plugins
check_unreviewed_plugins() {
  local reminder_mode
  reminder_mode=$(get_reminder_mode)

  # If reminders are off, exit early
  if [[ "$reminder_mode" == "off" ]]; then
    return
  fi

  local unreviewed=()

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue

    read -r plugin_name marketplace <<< "$(parse_plugin_entry "$entry")"
    local plugin_path="$PLUGIN_CACHE_DIR/$marketplace/$plugin_name"

    if [[ ! -d "$plugin_path" ]]; then
      continue
    fi

    local hash
    hash=$(compute_plugin_hash "$plugin_path")

    if ! is_plugin_reviewed "$plugin_name" "$hash"; then
      # For on-startup-once mode, skip dismissed plugins
      if [[ "$reminder_mode" == "on-startup-once" ]] && is_plugin_dismissed "$plugin_name"; then
        continue
      fi
      unreviewed+=("$plugin_name")
    fi
  done < <(get_enabled_plugins)

  if [[ ${#unreviewed[@]} -gt 0 ]]; then
    local plugin_list
    plugin_list=$(printf ", %s" "${unreviewed[@]}")
    plugin_list="${plugin_list:2}"  # Remove leading ", "

    echo "{\"additionalContext\": \"## Plugin Security Notice\\n\\nThe following plugins have not been security reviewed (or have changed since last review): **${plugin_list}**\\n\\nRun \\\`/review-plugins\\\` to scan them for security issues.\"}"
  fi
}

check_unreviewed_plugins
