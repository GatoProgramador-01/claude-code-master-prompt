# Master Prompt Repo Management

**Rule scope:** loaded when any task involves reading or writing to
`~/Documents/github/claude-code-master-prompt/`.

## Repo Purpose

This is the pinned public repository that documents the AI engineering operating system.
It is both a functional config (installed via `scripts/install-rules.sh`) and a portfolio
artifact for recruiters and tech leads. Every commit must serve at least one of:
1. Functional: improves agent behavior, fixes a rule, adds a verified case study
2. Portfolio: demonstrates shipping velocity, depth, or systems thinking

## When to Update the Repo

| Trigger | What to update |
|---------|----------------|
| Session produces a lesson (see `rules/self-improvement.md`) | agents/ slot edit or rules/ entry |
| A new case study is written in a project repo | Copy to `case-studies/`, update README |
| An agent was misrouted during a session | architect.md Slot 4 routing table |
| CLAUDE.md exceeded 120 lines | Move content to relevant rules/ file |
| New plugin verified safe and impactful | Add install command to relevant rules/ section |
| Sprint history has a new entry | Add to README.md Sprint History |
| A new agent was added | Update agents/README.md, architect.md Slot 4, CLAUDE.md routing table |

## File Ownership

```
CLAUDE.md                   — thin router, ≤ 120 lines, no prose rules
agents/<name>.md            — one file per agent, cartridge-v2 10-slot template
agents/README.md            — auto-generated roster (run scripts/gen-roster.sh after changes)
rules/workflows.md          — parallel wave patterns + standard team recipes
rules/codex-routing.md      — Codex cadence + failure modes + SDD routing
rules/sprint-status.md      — sprint status tree spec (cat emoji legend)
rules/hooks.md              — PostToolUse / PreToolUse / Stop hooks
rules/self-improvement.md   — self-improvement session protocol + derived rules
rules/prompt-repo.md        — this file: repo management discipline
case-studies/<name>.md      — one file per production case study
docs/evals/                 — meta-eval dataset + runner + tests
```

## CLAUDE.md Hygiene

**Hard limit: 120 lines.** If adding a rule would exceed this:
1. Check if the rule belongs in a rules/ file instead
2. If it's a pointer (e.g., "LangChain rules → rules/python/langchain.md"), keep it
3. If it's prose guidance, move it to the relevant rules/ file

**Never add to CLAUDE.md:**
- Multi-line code examples — these belong in rules/ or agent Slot 4
- Per-technology guides (Terraform, GitHub Actions, etc.) — these live in rules/
- Sprint-specific state — that belongs in the project's continue.txt

## Agent Cartridge Versioning

When editing a cartridge:
- Only edit the slots that changed — preserve all others exactly
- Add a comment in the git commit: `fix(agents): update <agent> Slot <N> — <incident>`
- Always re-run meta-eval after any Slot 1, 4, 5, or 7 edit:
  ```bash
  cd ~/Documents/github/claude-code-master-prompt
  python docs/evals/runner.py
  ```
- If meta-eval drops below 0.80 for any agent, revert that slot and flag for review

## Case Study Standards

A case study is worth adding when it demonstrates:
- A production delivery with concrete metrics (N docs, N tests, N hours)
- A technical insight that isn't obvious (protocol-level understanding, failure mode)
- A before/after improvement with measured data (34 min → 10 min, 0 → 9 bugs found)

**Case study must contain:**
- The specific problem solved (not "I built a scraper" — what portal, what protocol, what challenge)
- Concrete outcome numbers
- At least one non-obvious technical insight
- Lessons that generalize beyond this specific project

**Template:** see `case-studies/pj-peru-scraper-2026-06-28.md` for format.

## Commit Message Convention

```
feat(agents): add session-improver cartridge
fix(agents): update adversarial Slot 7 — asyncio.gather for grounding checks
docs(rules): add Windows Unicode rule — UnicodeEncodeError cp1252 incident 2026-07-21
docs(case-studies): self-improvement loop 24h session — 9 bugs, 1 patch auto-applied
chore(readme): update sprint history table
```

## README Recruiter Discipline

The README is the first thing a recruiter or tech lead sees. Every update must preserve:
- The hero statement (what this is in one sentence)
- At least 2 Mermaid diagrams
- The case studies section (with metrics)
- The "Rules From Real Failures" table
- Sprint history at the bottom in a `<details>` block

Never replace diagrams with prose tables. Never remove measured numbers (34 min → 10 min).

## Sync to Local Install

After committing to the repo, sync to the local install:
```bash
cp ~/Documents/github/claude-code-master-prompt/agents/*.md ~/.claude/agents/
bash ~/Documents/github/claude-code-master-prompt/scripts/install-rules.sh
```

This ensures the running system matches the repo.
