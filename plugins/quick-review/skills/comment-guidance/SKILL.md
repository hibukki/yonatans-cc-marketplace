---
name: comment-guidance
description: Use this skill when writing, reviewing, or removing code comments — which comments are usually fine and which are a smell.
---

Hey Claude!
So, it seems like comments are often a thing you add reflexively when you notice there is something wrong with the code. I'm writing this file, to be used as an attempt to help you introspect for what's wrong, listing some common reasons. I hope it will also be useful when reviewing other code. It also has some of my own preferences, for example I like referencing official docs when possible.

So,

Usually fine imo:

- References official docs, making it easier for future devs (including you) to understand/verify something. e.g "This is Twilio's official recommended verification algorithm, see https://..". Often it's better to import types/sdk-functions directly but that's not always available.
- An example for a complex regex (often better to use a built in regex, e.g .emailregex() , but we can't always)
- Security assumptions, written on the schema field they apply to (same line, as close to the field as possible — above the table is further away and rots sooner). A good security assumption lists "// Readable by: .. , Writable by: ..", for example "by the current user", "by the app admins".

Usually a smell:

- Repeats what the code below it says (e.g "Adds `a` and `b`" just above "c=a+b")
- Says who calls this code, or when it changes (rots) (e.g "this field is set by foo() when bar() happens")
- Explains a name that could just be clearer
- Explains a feature (= explains logic implemented somewhere else. bad also in docs/readme)
- An open task (reference a GitHub issue instead)
- Why we made this change (the PR description instead)
- What the code doesn't do (e.g "// Doesn't access the DB directly") - it would be silly if we'd list all the things the code doesn't do.

If you can't see how to avoid a comment, I prefer if you say so and we'll think it through together.
