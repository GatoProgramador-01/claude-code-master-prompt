# Sprint Handoff — Cartridge v2 Rewrite (as of 2026-07-09 22:06 UTC)

## Sprint state

**COMPLETE:**
- Design spec: `docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md` (commit 9aa3422)
- Implementation plan: `docs/superpowers/plans/2026-07-09-agent-prompt-upgrade.md` (commit 715d106, amendment d013613)
- **Wave 0 — Usage Audit** (commit 8d96f6f)
  - Task 0.0: staging bootstrap at `~/.claude-agents-v2/agents/`
  - Task 0.1: MongoDB unreachable — "no data" report
  - Task 0.2: session_logs empty — "no data" report
  - Task 0.3: git-log analysis of 426 commits over 90d
  - Task 0.4: final verdict — 13-agent post-sprint roster

**PENDING:**
- Wave 1 — Cartridge template foundation (Tasks 1.1, 1.2, 1.3)
- Wave 2 — Core experts rewrite (Tasks 2.1-2.5, parallel)
- Wave 3 — Support + new agents (Tasks 3.1-3.6, parallel; Task 3.7 SKIPPED per Wave 0)
- Wave 3.8 — Archive killed/merged agents
- Wave 4 — CLAUDE.md + AGENTS.md sync (Tasks 4.1-4.5)
- Wave 5 — Validation (Tasks 5.1-5.4)

## Wave 0 verdict summary (drives Waves 2-3)

| Verdict | Agents |
|---------|--------|
| KEEP + rewrite | llmops-expert, adversarial, researcher, validate, frontend-expert, devops-expert, scraper, backend-expert, drafter, architect (10) |
| ADD (new) | prompt-engineer, eval-writer, sme-reviewer (3) |
| MERGE (archive) | integrator → llmops-expert, jsdoc → frontend-expert, security-reviewer → adversarial, analyst → adversarial |
| KILL (archive) | lain-specialist |

**Final roster: 13 agents.**

## Wave 3.7 branch decision

`integrator.md` cartridge write → **SKIPPED**. Verdict is MERGE. llmops-expert Slot 4 absorbs the `orchestrator.py` wiring pattern instead. Reasoning: 0 commits touching `backend/app/orchestrator.py` in the last 90 days, below the plan's threshold of 15 (5/month).

## How to resume in a fresh session

Copy-paste this bootstrap prompt into a new Claude Code session:

```
Resume the agent-prompt-upgrade sprint. Read these files in order:
1. Documents/github/claude-code-master-prompt/.superpowers/sdd/progress.md — ledger (Wave 0 complete)
2. Documents/github/claude-code-master-prompt/docs/research/2026-07-09-cartridge-v2-handoff.md — this file
3. Documents/github/claude-code-master-prompt/docs/superpowers/plans/2026-07-09-agent-prompt-upgrade.md — full plan
4. Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap.md — Wave 0 verdict

Start at Task 1.1 (architect writes cartridge template spec).
Invoke superpowers:subagent-driven-development to continue.
Wave 3.7 (integrator cartridge) is SKIPPED per Wave 0 verdict.
Staging dir already seeded: ~/.claude-agents-v2/agents/ (14 baseline files present).
```

## Files on disk (verifiable)

```bash
# Baseline staging (already populated)
ls ~/.claude-agents-v2/agents/*.md | wc -l         # → 14
cat ~/.claude-agents-v2/agents/.sprint-marker      # → 2026-07-09T22:06:18Z

# Wave 0 outputs
ls Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap*.md   # → 4 files

# Ledger
grep "Task 0" Documents/github/claude-code-master-prompt/.superpowers/sdd/progress.md   # → 5 lines
```

## Cost so far (this session)

- Design + plan writing: ~1.5 hours, ~$0.30-0.50 API tokens (Sonnet 4.6 primary session)
- Wave 0 execution: ~15 min inline (no subagent dispatch — Wave 0.1/0.2 fell back to "no data" reports; Wave 0.3 was deterministic Python)

## Cost projection for remaining waves

- Wave 1: ~$0.15 (architect + adversarial pass on template spec)
- Wave 2: ~$0.40 (5 parallel drafter cartridges × ~$0.08 each)
- Wave 3: ~$0.50 (8 drafter cartridges + archive step)
- Wave 4: ~$0.20 (CLAUDE.md + AGENTS.md rewrites + Codex adversarial)
- Wave 5: ~$1.50-2.50 (meta-evals × 3 runs + field-test full pipeline run)

**Remaining sprint cost: ~$2.75-3.75.**

## Risks noted during Wave 0

1. **Data quality** — verdict driven by git-log only (MongoDB + session_logs unreachable). Confidence high on MERGE decisions (they align with baseline hypothesis + memory rules), but future audits should configure MongoDB for stronger signal.
2. **backend-expert has low git signal (2 hits)** — likely because commit subjects describe features not framework. Baseline hypothesis (KEEP) held because medium-agent-factory has an active FastAPI backend. Not a real risk, but worth flagging.
3. **integrator MERGE risks orchestrator.py wiring quality** — the merge sends wiring to llmops-expert. Wave 2 Task 2.1 llmops-expert cartridge MUST include an orchestrator wiring pattern in Slot 4 to absorb this role safely.

## What's next on resume

**Task 1.1** — architect writes `docs/superpowers/specs/agent-cartridge-v2.md` per plan section "Wave 1 — Cartridge Template Foundation". Then Task 1.2 (adversarial reviews) → Task 1.3 (revise until zero BLOCKERs). Only after Wave 1 gate opens can Wave 2 parallel dispatch begin.
