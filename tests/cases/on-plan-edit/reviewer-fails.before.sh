export HOME="$PWD"
mkdir -p .claude/plans bin
printf '# Plan\n\n1. Add a greet() function.\n' > .claude/plans/feature.md
export PATH="$PWD/bin:$PATH"
cat > bin/claude <<'STUB'
#!/bin/bash
echo "--agent 'plan-reviewer' not found." >&2
exit 1
STUB
chmod +x bin/claude
