---
name: prioritize-review-comments
description: Decide which automated review comments to fix vs skip. Use after receiving feedback from hooks, GitHub bots, or review agents.
---

# Prioritize Review Comments

After receiving automated review feedback, apply this framework to decide what to fix.

## What to Fix

TL;DR: Valid problems that are in-scope.

For example:

- A bug in the implementation: fix
- Created code duplication: fix
- Touched (called / edited) duplicated code: fix the DRY
- A mistaken bug (the reviewer didn't understand the code): skip
- A valid problem that doesn't happen in practice: If this problem could happen if the code around would change (e.g creating a component that could be called in a way that creates a bug but nobody calls it this way now): fix
  - For example, an API that would break if called in some way but it isn't called in that way: we want our APIs to be robust
- A pre-existing problem that wasn't touched by this code, e.g noticing a problem in an unrelated util: skip (don't scope creep)
- A valid in-scope problem that is tiny and takes seconds to fix: fix
  - if it takes a long time to fix: still fix. (the amount of work is not a factor, we want to keep the code we touched clean)
- No SSOT (doesn't cause a bug) : this is a design problem, fix
- There is another idea for a feature that might be good: probably out of scope, consider suggesting it to the user, perhaps as a follow-up
- Changed a variable from containing only the user meetings to containing all meetings: is changing the variable name or tests about it in scope? yes, otherwise the incorrect name is a problem caused by this PR, definitely in scope

## Show Your Decisions

Consider showing the user your decisions. For each review comment:

1. Is it a valid problem?
2. Is it in code that was touched?
3. (If you want: how big is the fix. Though this shouldn't affect whether we do it.)
4. Fix / Skip / Open follow-up issue
