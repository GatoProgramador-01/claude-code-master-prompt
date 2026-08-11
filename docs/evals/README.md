# Master Prompt Meta-Eval

Structural consistency checker for the claude-code-master-prompt system.

## Run

```bash
python docs/evals/runner.py
```

## Pass threshold

`>= 0.80` (currently 25 checks). Checks:
- CLAUDE.md exists and is <= 120 lines
- All 6 required rules files exist (workflows, codex-routing, sprint-status, hooks, self-improvement, prompt-repo)
- All 17 routing-table agent cartridges exist
- Haiku agents (drafter, validate) have haiku in frontmatter
- Sonnet agents (llmops-expert, backend-expert, adversarial) do not force haiku
- Sampled cartridges (drafter, llmops-expert, backend-expert) have all 10 required slots
- workflows.md has parallel agent min-3 rule
- workflows.md has model routing section
- workflows.md has prompt-by-reference rule (300 token max)
- self-improvement.md has derived rules table
- self-improvement.md has incident evidence pattern

Run this after any agent cartridge edit or rules update. CI gate: block if score < 0.80.
