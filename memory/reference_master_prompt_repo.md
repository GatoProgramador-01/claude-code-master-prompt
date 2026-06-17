---
name: Master Prompt Repo Location
description: Where CLAUDE.md is versioned — git repo in Documents/github
type: reference
originSessionId: 33ae9746-2b4e-4d1d-bef6-71a4dbdb8d44
---
The master prompt (`CLAUDE.md`) lives in two places:
- **Working copy**: `C:\Users\lanitaEmperadora\CLAUDE.md` (used by Claude Code at runtime)
- **Git repo**: `C:\Users\lanitaEmperadora\Documents\github\claude-code-master-prompt\` (public GitHub repo: `https://github.com/GatoProgramador-01/claude-code-master-prompt`, branch `main`)

**Workflow when updating CLAUDE.md:**
1. Edit `C:\Users\lanitaEmperadora\CLAUDE.md`
2. `cp` to `Documents\github\claude-code-master-prompt\CLAUDE.md`
3. Commit in that repo and push
