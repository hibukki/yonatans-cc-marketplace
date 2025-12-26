# quick-review

Claude Code plugin that auto-reviews git commits.

## Installation

```bash
# Add the marketplace
/plugin marketplace add hibukki/yonatans-cc-plugin

# Install the plugin
/plugin install quick-review@yonatans-cc-plugin
```

## Setup (for contributors)

```bash
git config core.hooksPath .githooks
```

This enables the pre-commit hook that auto-bumps the plugin version.
