# Claude Code Skills Reference

Skills are slash commands that run structured workflows inside Claude Code. Invoke them by typing `/skill-name` in the prompt.

## Available Skills

### `/init`
Scans your codebase and generates a `CLAUDE.md` from scratch.
- Detects frameworks, conventions, folder structure automatically
- Use on day 1 of any new repo

### `/review`
Full code review of the current branch diff, or a GitHub PR.
```
/review        ← reviews current branch vs main
/review 42     ← reviews PR #42
```
Checks correctness, readability, performance, security. Structured like a senior engineer review.

### `/security-review`
Focused security audit of staged/changed code.
- Checks OWASP Top 10, secrets exposure, injection vectors, auth issues
- Run before every push on anything touching auth, APIs, or user data

### `/simplify`
Audits changed code for duplication, unnecessary complexity, and efficiency issues — then fixes them.
- Use after a feature is complete, before opening a PR

### `/update-config`
Edits `settings.json` to wire up hooks — shell commands that fire automatically on Claude events.
```
/update-config    ← follow prompts to add hooks/permissions
```
Use to automate formatting/linting so it never gets skipped.

### `/fewer-permission-prompts`
Reads recent session transcripts, finds tools you keep manually approving, adds an allowlist to `.claude/settings.json`.
- Reduces daily friction — run once per project

### `/keybindings-help`
Remaps keyboard shortcuts in `~/.claude/keybindings.json`.
- Change submit key, add chord shortcuts, etc.

### `/loop`
Runs a prompt or skill on a recurring interval.
```
/loop 10m /review     ← run /review every 10 minutes
/loop 5m check build  ← custom prompt every 5 minutes
```

### `/schedule`
Creates remote scheduled agents that run on a cron without you being in the session.
- Persists between sessions
- Use for automated nightly checks, reminders, recurring reviews

### `/claude-api`
Specialized workflow for apps using the Anthropic SDK directly.
- Handles prompt caching, tool use, model migration (4.5 → 4.6 → 4.7)
- Use when code imports `anthropic` or `@anthropic-ai/sdk`

---

## Mental Model

```
Memory        → what Claude remembers about you across sessions
CLAUDE.md     → rules Claude follows in every project (the master prompt)
Skills        → workflows you trigger on demand with /command
Hooks         → shell commands that fire automatically on events (set via /update-config)
```

## Priority by Role

| Role / Context | Daily | Per Repo | Situational |
|---|---|---|---|
| Full Stack (React/Next.js + NestJS) | `/review` `/security-review` `/simplify` | `/init` `/fewer-permission-prompts` | `/update-config` `/loop` |
| AI Features | `/claude-api` `/review` | `/init` | `/schedule` |
| Solo Projects | `/simplify` `/security-review` | `/init` | `/fewer-permission-prompts` |
