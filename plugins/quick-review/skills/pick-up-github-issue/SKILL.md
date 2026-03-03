---
name: pick-up-github-issue
description: Use this skill when the user wants to find and work on a GitHub issue.
---

# Pick Up GitHub Issue

Find, claim, and plan a GitHub issue labeled "ready-to-implement".

## Prerequisites

- Must be in a git repo with a GitHub remote
- `gh` CLI must be authenticated

## Steps

### 1. Detect the repo

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

### 2. Find issues labeled "ready-to-implement"

```bash
gh issue list --label "ready-to-implement" --state open --json number,title,body,comments,assignees
```

If no issues found, tell the user and stop.

### 3. Check availability of each issue

For each issue, check if someone is already working on it:

- **Assigned?** Skip if `.assignees` is non-empty.
- **Claimed in comments?** Look for comments like "I'm on it", "taking this", "working on this", or similar intent signals.
  - If the most recent claim comment is **< 24 hours old**: skip this issue, someone is actively on it.
  - If the most recent claim comment is **24h - 7 days old**: note it as "possibly abandoned".
  - If the most recent claim comment is **> 7 days old**: treat as abandoned / available.

Pick the first clearly available issue.

- **Clearly available** (unassigned, no claim comments, has the label): proceed directly to step 4 — no user confirmation needed.
- **Possibly abandoned** (claim comment 24h–7d old): ask the user first — mention the commenter, how long ago, and let them decide. Use `AskUserQuestion` with options: "Yes, pick it up" / "Show me other issues" / "Skip".

### 4. Comment on the issue

After user confirms, post a comment to claim it. This serves as the "assignee" since Claude doesn't have a separate GitHub account:

```bash
gh issue comment <NUMBER> --body "Picking this up. - Claude (<your model name/version>)"
```

### 5. Enter plan mode

Call `EnterPlanMode` to plan the implementation for this issue.
