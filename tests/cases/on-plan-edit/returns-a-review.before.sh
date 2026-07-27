export HOME="$PWD"
mkdir -p .claude/plans bin
printf '# Plan\n\n1. Add a greet() function.\n' > .claude/plans/feature.md
export PATH="$PWD/bin:$PATH"
cat > bin/claude <<'STUB'
#!/bin/bash
echo '[{"type":"system","subtype":"init"},{"type":"result","result":"1. ❌ Too complex.","total_cost_usd":0.03,"session_id":"sess-abc","usage":{"cache_creation_input_tokens":10,"cache_read_input_tokens":90}}]'
STUB
chmod +x bin/claude
