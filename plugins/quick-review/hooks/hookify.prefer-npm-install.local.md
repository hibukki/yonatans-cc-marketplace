---
name: prefer-npm-install
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: package\.json$
  - field: new_text
    operator: regex_match
    pattern: "dependencies".*:.*\{
---

Use `npm install <pkg>` or `pnpm add <pkg>` instead of editing package.json directly.
