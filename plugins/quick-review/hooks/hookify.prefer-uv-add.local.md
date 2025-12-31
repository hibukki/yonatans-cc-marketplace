---
name: prefer-uv-add
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: pyproject\.toml$
  - field: new_text
    operator: regex_match
    pattern: '[>=<~]=?\s*\d'
---

Use `uv add <pkg>` instead of editing pyproject.toml directly.
