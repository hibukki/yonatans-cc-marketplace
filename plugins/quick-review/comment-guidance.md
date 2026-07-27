Almost always, a comment is a code smell — a hint that a name, a structure, or a schema could carry the information instead.

Usually fine:

- References official docs
- An example for a complex regex
- Security assumptions, written on the schema field they apply to (same line, as close to the field as possible — above the table is further away and rots sooner)

Usually a smell:

- Repeats what the code below it says
- Says who calls this code, or when it changes (rots)
- Explains a name that could just be clearer
- Explains a feature (belongs in the code itself)
- An open task (a GitHub issue instead)
- Why we made this change (the PR description instead)

If you can't see how to avoid a comment, say so — the smell can be real even when the fix isn't obvious.
