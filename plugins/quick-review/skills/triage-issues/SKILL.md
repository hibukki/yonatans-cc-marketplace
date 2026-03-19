---
name: triage-issues
description: Use this skill when the user explicitly asks to triage issues. Goes over open GitHub issues that are not labeled someday-maybe or ready-to-implement, and asks the user what to do with each one.
---

# Triage Issues

Go over issues that are open, not marked someday-maybe, not marked ready-to-implement (those are labels).

For each, AskUserQuestion what to do with it: either mark it as one of those labels, or if the user gives a free text response then usually the response should be commented on the issue.

Don't mark ready-to-implement without the user explicitly asking for it (it is used by the user to indicate they reviewed it).

It is fine to give your own opinions on each issue. The general approach is that valid issues should be solved (regardless of whether they are small). Some issues require brainstorming an approach (which will usually be only a suggestion for the issue, left for the implementor to decide if the suggestion is good). It is ok to launch subagents to get context about issues if you want to give a more detailed comment. Use your memory feature to check previous user preferences and to update them (for example, writing that the user usually wants to solve DRY/naming/schema problems).
