# yonatans-cc-marketplace

A Claude Code plugin marketplace with tools for better coding habits.

## Plugins

### quick-review

The main plugin - enforces good development practices and automates code review.

#### Code Review Workflow

**Uncommitted changes block** - Don't let Claude ask the user questions if there are uncommitted changes.

**Auto-review commits** - Claude's code gets reviewed automatically after each commit.

**Review comment prioritization** - Framework for deciding which automated review comments to fix vs skip. ([skill](plugins/quick-review/skills/prioritize-review-comments/SKILL.md))

**Manual review command** - `/quick-review` to trigger a code review on demand.

#### Planning

**Plan review** - Review agent for plans, automatically executed after every plan file edit. ([agent](plugins/quick-review/agents/plan-reviewer.md))

**Plan checklist** - Remind Claude to mention in the plan: small commits, a comprehensive TODO list, etc. ([skill](plugins/quick-review/skills/plan-checklist/SKILL.md))

#### Code Quality

**Comment quality check** - Reminds Claude that redundant comments are bad.

**Package management** - Blocks editing package.json/pyproject.toml directly. Enforces `npm install` / `uv add`.

#### Other

**WebFetch tip** - Remind Claude it can download the file instead.

**Brainstorm mode** - Multiple perspectives on a problem before deciding. ([skill](plugins/quick-review/skills/brainstorm/SKILL.md))

**Stack recommendations** - Tips for starting new projects (Vite+React, uv for Python, etc.) ([skill](plugins/quick-review/skills/new-project-good-stacks/SKILL.md))

### plugin-security-reviews

Security review for Claude Code plugins with auto-detection of new/changed plugins.

### google-workspace-connector

Access Google Workspace APIs (Gmail, Drive, Sheets, Docs) via oauth2l + curl. ([skill](plugins/google-workspace-connector/skills/google-workspace-connector/SKILL.md))

## Requirements

- **jq** - Required for most hooks. Install with `brew install jq` (macOS) or `apt install jq` (Linux). If missing, you'll see a warning at session start and hooks will be disabled.

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

## Setup (for contributors)

```bash
git config core.hooksPath .githooks
```

This enables the pre-commit hook that auto-bumps the plugin version.

## Other plugins that seem promising

### Search

[exa MCP](https://exa.ai/docs/reference/exa-mcp)

### Getting docs

As markdown, with optimizations for LLMs

[context7](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/context7)

### Interacting with a browser

[dev browser](https://github.com/SawyerHood/dev-browser)

Seems more promising than the playwright MCP and the claude chrome plugin.
