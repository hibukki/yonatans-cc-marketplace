# quick-review

Claude Code plugin that auto-reviews git commits.

## Installation

### Option 1: Via slash commands

```bash
/plugin marketplace add hibukki/yonatans-cc-marketplace
/plugin install quick-review@yonatans-cc-marketplace
```

### Option 2: Manual (in settings.json)

Add to your `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "quick-review@yonatans-cc-marketplace": true
  },
  "extraKnownMarketplaces": {
    "yonatans-cc-marketplace": {
      "source": {
        "source": "github",
        "repo": "hibukki/yonatans-cc-marketplace"
      }
    }
  }
}
```

## Optional: Install hookify

This plugin includes hookify rules for extra nudges (e.g., prefer `npm install` over editing package.json). To enable them:

```bash
/plugin install hookify@claude-plugins-official
```

## Setup (for contributors)

```bash
git config core.hooksPath .githooks
```

This enables the pre-commit hook that auto-bumps the plugin version.
