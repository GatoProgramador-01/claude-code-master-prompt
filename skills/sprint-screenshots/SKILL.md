---
name: sprint-screenshots
description: Generate terminal-style PNG screenshots from sprint work for use in Medium posts. Invoke after a sprint completes and before running medium-agent-factory to generate the post. Screenshots replace [IMAGE:] placeholders in the pipeline output.
trigger: user says "take screenshots", "screenshot the terminal work", "generate screenshots for the post", or "document this sprint visually"
---

# Sprint Screenshots Skill

Generates up to 3 terminal-style PNG screenshots (Catppuccin Mocha dark theme) from sprint
work, saves them to `output/screenshots/<slug>/`, and returns the paths for the Medium post pipeline.

## When to invoke

After any sprint where the work will be written up as a Medium post. Typical trigger: the sprint
tree is complete and the user says "take screenshots" or "document this sprint".

Invoke BEFORE running `run_parallel_executor_post.py` (or equivalent) so paths are ready.

## Step 0: Auto-generate spec lines from ctx (REQUIRED before manual authoring)

Before writing any spec.json content, invoke the `ctx-agent-history-search` skill to find real
session evidence. The full workflow:

```bash
# 1. Confirm ctx is ready
ctx status

# 2. Search broadly for the sprint topic — try multiple wordings
ctx search "<sprint topic>" --verbose
ctx search "<key metric or decision>" --session <ctx-session-id> --verbose

# 3. Inspect the top events with context window
ctx show event <ctx-event-id> --window 5

# 4. Pull exact text for each spec.json line
#    Set source_ref = ctx_event_id, source_type = ctx_session
```

For each screenshot, pull the exact text from the ctx event output. Set `source_ref` to the
`ctx_event_id` (e.g., `e5c616f8-5cd2-78ef-ac91-1e5a0b9b4c20`) and `source_type` to `ctx_session`.

Only add manually authored lines with `source_type: explicit_author` (first-person statements
like "I measured X" that don't appear in any session event).

**Routing rule:** invoke `ctx-agent-history-search` skill, NOT raw ctx CLI commands directly.
The skill sets up PATH and handles the multi-step search → inspect → cite loop.

**Never type a claim into spec.json without a source_ref.** The generator rejects lines missing
`source_type`. Also every screenshot object requires `"image_type": "reconstructed_terminal_summary"`.

## Output location

All screenshots go to:
```
output/screenshots/<sprint-slug>/
  01-<name>.png
  02-<name>.png
  03-<name>.png
```

Inside the claude-code-master-prompt repo. The paths are then passed as `source_images` to
the medium-agent-factory pipeline.

## How to run

### Step 1 — Build the spec

Create a JSON spec file at `output/screenshots/<slug>/spec.json`. Use this template:

```json
{
  "slug": "sprint-name-YYYY-MM-DD",
  "screenshots": [
    {
      "filename": "01-sprint-tree.png",
      "title": "bash — <repo> sprint",
      "lines": [
        {"text": "Sprint — <sprint-name>", "color": "white"},
        {"text": "", "color": ""},
        {"text": "  agentes  — N parallel (<agent1>·<agent2>)", "color": "cyan"},
        {"text": "  skills   — skill1 → skill2 → skill3", "color": "blue"},
        {"text": "  metrics  — N files · X insertions · PR merged", "color": "yellow"},
        {"text": "", "color": ""},
        {"text": "  file1.py  — what changed", "color": "green"},
        {"text": "  file2.md  — what changed", "color": "green"},
        {"text": "  Codex (bg)  — adversarial: N issues found + resolved", "color": "lavender"},
        {"text": "", "color": ""},
        {"text": "$ gh pr merge feat/<slug> --merge --admin --delete-branch", "color": "muted"},
        {"text": "X files changed, Y insertions(+), Z deletions(-)", "color": "green"}
      ]
    },
    {
      "filename": "02-key-change.png",
      "title": "bash — key code change",
      "lines": [
        {"text": "--- THE CORE FIX ---", "color": "yellow"},
        {"text": "", "color": ""},
        {"text": "Before:", "color": "white"},
        {"text": "  <old behavior or code snippet>", "color": "red"},
        {"text": "", "color": ""},
        {"text": "After:", "color": "white"},
        {"text": "  <new behavior or code snippet>", "color": "green"},
        {"text": "", "color": ""},
        {"text": "Result: <measured improvement>", "color": "cyan"}
      ]
    },
    {
      "filename": "03-verification.png",
      "title": "bash — verification / adversarial",
      "lines": [
        {"text": "Adversarial Review — <sprint-name>", "color": "white"},
        {"text": "", "color": ""},
        {"text": "FAIL [HIGH]   <file>:<line>", "color": "red"},
        {"text": "  <what was wrong>", "color": "text"},
        {"text": "", "color": ""},
        {"text": "-- applying fixes --", "color": "muted"},
        {"text": "  <fix 1>   resolved", "color": "green"},
        {"text": "  <fix 2>   resolved", "color": "green"},
        {"text": "", "color": ""},
        {"text": "VERDICT: APPROVED", "color": "green"}
      ]
    }
  ]
}
```

### Step 2 — Run the generator

```bash
cd /c/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt
python scripts/gen_terminal_screenshot.py output/screenshots/<slug>/spec.json
```

Output is saved to `output/screenshots/<slug>/01-*.png`, `02-*.png`, `03-*.png`.

### Step 3 — Pass paths to medium-agent-factory

In the run script (`medium-agent-factory/backend/scripts/run_<topic>_post.py`), set:

```python
SCREENSHOT_DIR = Path(r"C:\Users\lanitaEmperadora\Documents\github\claude-code-master-prompt\output\screenshots\<slug>")

SOURCE_IMAGES = [
    {
        "path": str(SCREENSHOT_DIR / "01-sprint-tree.png"),
        "alt": "Terminal showing sprint tree with N parallel agents and PR merge output",
        "caption": "Wave dispatch: N agents fire simultaneously. Sprint complete in X minutes.",
    },
    {
        "path": str(SCREENSHOT_DIR / "02-key-change.png"),
        "alt": "Terminal showing before/after of the key change",
        "caption": "The core fix: <one sentence>.",
    },
    {
        "path": str(SCREENSHOT_DIR / "03-verification.png"),
        "alt": "Terminal showing adversarial review finding issues and approving after fixes",
        "caption": "Adversarial gate: N issues found before commit, all resolved.",
    },
]
```

Then pass `source_images=SOURCE_IMAGES` to `run_pipeline()`.

## Color reference

| Key | Hex | Use |
|-----|-----|-----|
| `white` | `#ffffff` | Section headers, titles |
| `text` | `#cdd6f4` | Body content, descriptions |
| `cyan` | `#89dceb` | Agent names, process info |
| `blue` | `#89b4fa` | Skill names, commands |
| `green` | `#a6e3a1` | Completed tasks, successes, diffs |
| `yellow` | `#f9e2af` | Metrics, warnings, highlights |
| `red` | `#f38ba8` | Failures, errors, FAIL markers |
| `lavender` | `#b4befe` | Codex/review rows |
| `muted` | `#585b70` | Prompts ($), separators, comments |

## Publishing workflow (after generation)

1. Upload each PNG from `output/screenshots/<slug>/` to Medium (drag-drop into editor)
2. Copy the Medium image CDN URLs
3. In the post content, each `[IMAGE: /local/path.png | alt: ...]` marker has the local path
4. Replace each local path with the Medium CDN URL
5. The `*caption*` line below each marker becomes the Medium image caption

## Notes

- Pillow is required: `pip install Pillow` (already available in medium-agent-factory venv)
- Width is fixed at 860px — fits Medium's article column
- Font: Consolas (Windows) or DejaVu Sans Mono (Linux) — falls back to default
- Max ~55 chars per line before wrapping (continuation lines render in muted color)
- The spec file is kept in `output/screenshots/<slug>/` alongside the PNGs for future reference
