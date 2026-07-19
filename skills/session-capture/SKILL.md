---
name: session-capture
description: Capture real terminal evidence from a sprint as PNG screenshots and store in ~/.ctx/screenshots/<slug>/ for use as Medium post sources. Invoke after any sprint where the work will be written up as a Medium post, before running medium-agent-factory.
trigger: user says "capture screenshots", "take screenshots", "screenshot the terminal work", "generate screenshots for the post", or "document this sprint visually"
---

# Session-Capture Skill

Generates terminal-style PNG screenshots (Catppuccin Mocha dark theme) from real
sprint work — either by running real commands or rendering agent-curated sprint trees.
Saves to `~/.ctx/screenshots/<slug>/` with a `manifest.json` index.

## When to invoke

After any sprint where the work will be written up as a Medium post. Invoke BEFORE
running `python -m app.cli` so paths are ready.

## How to run

### Step 1 — Build the spec

Two entry types:

**`type: manual`** — agent provides explicit colored lines (sprint tree, before/after diffs):
```json
{
  "filename": "01-sprint-tree.png",
  "title": "bash — <repo>",
  "type": "manual",
  "alt": "Sprint tree showing parallel agent dispatch",
  "caption": "5 agents fired simultaneously. Sprint complete in 12 minutes.",
  "lines": [
    {"text": "Sprint N — <name>",                               "color": "white"},
    {"text": "  agentes  — N parallel (agent1·agent2·...)",    "color": "cyan"},
    {"text": "  skills   — brainstorming → writing-plans",      "color": "blue"},
    {"text": "  metrics  — X tests · Y insertions · PR merged", "color": "yellow"},
    {"text": "",                                                 "color": ""},
    {"text": "  file.py  — what changed",                      "color": "green"},
    {"text": "  Codex (bg)  — 0 issues",                       "color": "lavender"},
    {"text": "",                                                 "color": ""},
    {"text": "$ gh pr merge feat/<slug> --merge --admin",      "color": "muted"},
    {"text": "X files changed, Y insertions(+), Z deletions(-)", "color": "green"}
  ]
}
```

**`type: command`** — runs a real command and captures stdout (no shell=True, args as list):
```json
{
  "filename": "02-pytest.png",
  "title": "bash — pytest",
  "type": "command",
  "args": ["python", "-m", "pytest", "tests/", "-q", "--no-header", "--tb=short"],
  "cwd": "C:\\Users\\lanitaEmperadora\\<repo>\\backend",
  "max_lines": 30,
  "alt": "Real pytest run showing all tests passing",
  "caption": "Zero regressions after the change."
}
```

Full spec template:
```json
{
  "slug": "sprint-name-YYYY-MM-DD",
  "project": "repo-name",
  "screenshots": [
    {
      "filename": "01-sprint-tree.png",
      "title": "bash — <repo>",
      "type": "manual",
      "alt": "Sprint tree showing parallel agents and PR merge",
      "caption": "N agents fired simultaneously.",
      "lines": [...]
    },
    {
      "filename": "02-tests.png",
      "title": "bash — pytest",
      "type": "command",
      "args": ["python", "-m", "pytest", "tests/", "-q", "--no-header"],
      "cwd": "C:\\Users\\lanitaEmperadora\\<repo>\\backend",
      "max_lines": 30,
      "alt": "pytest output — all tests passing",
      "caption": "N tests pass, 0 regressions."
    }
  ]
}
```

### Step 2 — Run the generator

```bash
cd C:\Users\lanitaEmperadora\claude-code-master-prompt
python scripts/gen_session_screenshots.py path/to/spec.json
```

Output: PNGs + `manifest.json` in `~/.ctx/screenshots/<slug>/`.

### Step 3 — Pass to medium-agent-factory

```bash
# Auto-load from ctx manifest (recommended)
python -m app.cli --topic "..." --ctx-screenshots <slug>

# Or explicit paths
python -m app.cli --topic "..." --screenshots ~/.ctx/screenshots/<slug>/01.png ~/.ctx/screenshots/<slug>/02.png
```

## Color reference

| Key       | Hex       | Use                                      |
|-----------|-----------|------------------------------------------|
| `white`   | `#ffffff` | Section headers, sprint title            |
| `text`    | `#cdd6f4` | Body content, descriptions               |
| `cyan`    | `#89dceb` | Agent names, process info                |
| `blue`    | `#89b4fa` | Skill names, commands                    |
| `green`   | `#a6e3a1` | Completed tasks, test passes, diffs      |
| `yellow`  | `#f9e2af` | Metrics, warnings, numbers               |
| `red`     | `#f38ba8` | Failures, errors, FAIL markers           |
| `lavender`| `#b4befe` | Codex/review rows                        |
| `muted`   | `#585b70` | Shell prompts ($), separators, comments  |

## Output location

```
~/.ctx/screenshots/<slug>/
  manifest.json
  01-sprint-tree.png
  02-pytest.png
  03-git-log.png
```

## Notes

- Pillow required: `pip install Pillow` (already available in medium-agent-factory venv)
- Width fixed at 860px — fits Medium's article column
- Font: Consolas (Windows) or DejaVu Sans Mono (Linux) — falls back to default
- `type: command` entries use `args` list — no shell injection possible
