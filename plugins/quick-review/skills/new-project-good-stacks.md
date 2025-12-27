---
description: Tips for starting new projects with good technology stacks
---

# New Project Stack Recommendations

## React

Use the Vite + TypeScript template:

```sh
npm create vite@latest . -- --template react-ts
```

## Python

Use uv for project management:

```sh
uv init
uv add libraryname
uv run main.py
```

## Obsidian Plugin

Clone this template repo and use it as a base:

```sh
git clone https://github.com/hibukki/obsidian_claude_code_copilot
```

Remove the functionality unrelated to your project, but keep the dev environment setup (like how to link to the Obsidian vault).

## App

If the user asks for an "App" or "Android App", help them (in your own way) try to understand if actually a website that runs on mobile (or another solution, like react native or so) would also satisfy them. Perhaps the user isn't technical and doesn't understand the tradeoffs here.
