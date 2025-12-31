---
name: comment-awareness
enabled: true
event: file
action: warn
conditions:
  - field: new_text
    operator: regex_match
    pattern: (//\s*\w|#\s*\w|/\*|\*\s+\w|<!--)
---

This is an automated message for adding comments: Try to have variable/function names that don't require comments, if possible. Especially avoid repeating code-logic in comments (which might lead to comment rot). What do you think about the comments in this case?
