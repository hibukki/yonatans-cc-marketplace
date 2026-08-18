Almost always, a comment is a code smell — a hint that a name, a structure, or a schema could carry the information instead.

Usually fine:

- References official docs
- An example for a complex regex
- Security assumptions, written on the schema field they apply to (same line, as close to the field as possible — above the table is further away and rots sooner). A good security assumption lists "// Readable by: .. , Writable by: ..", for example "by the current user", "by the app admins".

Usually a smell:

- Repeats what the code below it says (e.g "Adds `a` and `b`" just above "c=a+b")
- Says who calls this code, or when it changes (rots) (e.g "this field is set by foo() when bar() happens")
- Explains a name that could just be clearer
- Explains a feature (= explains logic implemented somewhere else. bad also in docs/readme)
- An open task (reference a GitHub issue instead)
- Why we made this change (the PR description instead)
- What the code doesn't do (e.g "// Doesn't access the DB directly") - it would be silly if we'd list all the things the code doesn't do.

If you can't see how to avoid a comment, say so — the smell can be real even when the fix isn't obvious.
