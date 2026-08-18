---
description: Find ways to remove ~all comments from the code
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/comment-guidance/SKILL.md`, plus whatever memory / claude.md say about comments, and start working with the user on how to remove them from [the relevant code you're working on].

If you learn new relevant things about which comments to keep/remove or how to do that, it's ok to add them to memory, to the *same* memory file already about comments (keep only one), and make sure not to repeat existing suggestions (including: avoid repeating subsets of the suggestions), ask the user if you're not sure.

Success here is usually 0 comments left in the code, usually together with "we made function/variable names more clear" or perhaps "we organized the code in a way easier to understand".

Remember not to conform to "the code already has lots of fluff comments". that situation is a problem that we're trying to solve.
