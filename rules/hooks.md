# Hooks — Technical Detail

**Rule scope:** loaded on-demand when editing `~/.claude/settings.json`, project `.claude/settings.json`, or authoring new hooks.

## Locations

- **Project hooks:** `.claude/settings.json`
- **User hooks:** `~/.claude/settings.json`
- **MCP servers:** `.mcp.json` at project root — NEVER `settings.json`

## Exit conventions

- `exit 2` + stderr → block the tool call
- `exit 0` → proceed
- Any other non-zero → treated as block with stderr shown

## Key hooks (current session-wide setup)

### PostToolUse (Edit | Write) — auto-format
- `.py` → `black`
- `.ts` / `.tsx` → `prettier`
- Fires automatically after every Edit / Write; keeps commits ruff/black-clean.

### PostToolUse (Bash) — compress verbose build output
Pipe through `grep -E "(ERROR|error|WARN|FAIL)" | head -200` before Claude reads it. 10K lines → 200. Prevents context pollution from noisy CI output.

### PreToolUse (Bash) — block `git push --force*`
Exits with code 2 and stderr explaining the block. Bypass requires explicit user request.

### Pre-push auto-fix pattern
If the pre-push hook fails on ruff/black:

1. `ruff check --fix backend/ && black backend/`
2. Re-stage the format changes: `git add backend/`
3. Commit the format fix as a separate commit
4. Retry `git push`

Never `--no-verify` unless the user explicitly says so.

### Stop hook — verification gate
Verification script that blocks turn-end until it passes. Strongest gate for unattended runs — prevents Claude from claiming completion while validators still fail.

### User-level — Windows MessageBox notification
Fires on `idle_prompt` event. Useful for long-running background tasks.

## Automation (headless) recipes

- `claude -p "prompt"` — non-interactive, for CI / cron / scripts
- `claude -p "..." --output-format stream-json --verbose` — streaming JSON for pipelines
- `claude -p "..." --allowedTools "Edit,Bash(git commit *)"` — scoped permissions for batch runs
- `claude --permission-mode auto -p "..."` — classifier safety for unattended runs (blocks scope escalation)
- Fan-out: `for file in $(cat files.txt); do claude -p "migrate $file" --allowedTools "Edit"; done`

## CLAUDE.md hygiene rule

Keep short — bloated files cause rules to be ignored. For each line: "Would removing this cause mistakes?" If not, cut it.

- `@path/to/file` inside CLAUDE.md loads that file into context (use for team-shared docs)
- `CLAUDE.local.md` at project root = personal overrides, never committed (add to `.gitignore`)
- Domain-specific rules → `.claude/rules/` with path patterns (only load when matching files are touched)

## Skills location

`.claude/skills/<name>/SKILL.md` — domain knowledge loaded on-demand, not every session. Apply automatically when relevant, or invoke with `/skill-name`.

Use `disable-model-invocation: true` in SKILL.md frontmatter for workflow skills with side effects (e.g., `/fix-issue 1234`).

**Prefer skills over adding to CLAUDE.md** for knowledge that's only needed sometimes.
