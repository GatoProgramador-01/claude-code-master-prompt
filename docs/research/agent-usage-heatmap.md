# Agent Usage Heatmap — Final Verdict (Wave 0)

**Date:** 2026-07-09
**Sources:** `agent-usage-heatmap-mongodb.md` (no data), `agent-usage-heatmap-sessions.md` (no data), `agent-usage-heatmap-git.md` (primary signal — 426 commits scanned)

## Decision matrix (from spec Section 4.3)

```
IF invocations_90d < 5 AND commits_attributed < 2       → KILL
IF invocations_90d in [5-20] AND role duplicates another → MERGE
IF invocations_90d > 20                                  → KEEP + rewrite
IF role not covered but tasks exist in project           → ADD
```

Because MongoDB + session_logs are unavailable, "invocations_90d" is proxied by the git-log combined signal (name mentions + domain-keyword hits). The threshold interpretation is directionally the same.

## Final verdict table

| Agent | Git combined signal | Verdict | Reasoning |
|-------|--------------------|---------| ----------|
| **llmops-expert** | 35 | **KEEP + rewrite** | Strongest signal by far — core loop |
| **adversarial** | 28 | **KEEP + rewrite** | Absorbs security-reviewer + analyst (read-only lens) |
| **researcher** | 27 | **KEEP + rewrite** | Grounding + facts, cross-cutting |
| **validate** | 10 | **KEEP + rewrite** | Every-commit gate |
| **frontend-expert** | 9 | **KEEP + rewrite** | Absorbs jsdoc (TSDoc emission) |
| **devops-expert** | 9 | **KEEP + rewrite** | Docker/CI/deploy/IaC |
| **scraper** | 4 | **KEEP + rewrite** | pj-peru project (memory-confirmed) |
| **backend-expert** | 2 | **KEEP + rewrite** | Low signal (keyword undercount); memory + project context confirm active use |
| **drafter** | 1 | **KEEP + rewrite** | SDD default fallback (memory rule — non-negotiable) |
| **architect** | 0 | **KEEP + rewrite** | Invisible in commits (in-session orchestrator role) |
| **integrator** | 15 (domain only) | **MERGE → llmops-expert** | 0 commits on orchestrator.py in 90d; below KEEP threshold. llmops-expert Slot 4 absorbs wiring pattern. |
| **jsdoc** | 3 | **MERGE → frontend-expert** | Docs = one slot of domain expert, not a separate agent |
| **security-reviewer** | 3 | **MERGE → adversarial** | Security IS adversarial thinking |
| **analyst** | 2 | **MERGE → adversarial** | Same skill (read-only diagnostics), narrower scope |
| **lain-specialist** | 0 | **KILL** | Deprecated in memory + zero signal |
| **prompt-engineer** | — | **ADD** | New — owns prompts/*.txt versioning + G-Eval rubric |
| **eval-writer** | — | **ADD** | New — owns evals/datasets/*.jsonl + deepeval Layer 1/2/3 |
| **sme-reviewer** | — | **ADD** | New — owns fact/tone review, hydrates from recent posts |

## Final roster count

- **KEEP + rewrite:** 10 (llmops-expert, adversarial, researcher, validate, frontend-expert, devops-expert, scraper, backend-expert, drafter, architect)
- **ADD (new):** 3 (prompt-engineer, eval-writer, sme-reviewer)
- **MERGE (archived):** 4 (integrator, jsdoc, security-reviewer, analyst)
- **KILL (archived):** 1 (lain-specialist)

**Total post-sprint roster: 13 agents**

## Files to archive (Wave 3.8)

Move these to `~/.claude/agents/archive/2026-07-09-v1/`:
- `integrator.md` (verdict: MERGE — llmops-expert absorbs orchestrator wiring)
- `jsdoc.md` (verdict: MERGE — frontend-expert absorbs TSDoc)
- `security-reviewer.md` (verdict: MERGE — adversarial absorbs OWASP)
- `analyst.md` (verdict: MERGE — adversarial absorbs read-only diagnostics)
- `lain-specialist.md` if present (verdict: KILL)

## Files NOT to archive

- `drafter.md` — MUST stay per memory rule `feedback_sdd_agent_routing.md` (SDD default fallback)

## Wave 3.7 branch decision

`integrator.md` cartridge write → **SKIP** (verdict is MERGE, so no v2 cartridge for integrator; llmops-expert absorbs its role via Slot 4 orchestrator.py wiring pattern).

## Downstream sprint implications

- Wave 2 rewrites 5 core experts as planned
- Wave 3 rewrites 5 support + adds 3 new = 8 total drafts
- Wave 3.7 skipped (integrator merged, not rewritten)
- Wave 3.8 archives 4-5 agents (lain-specialist may or may not be on disk)
- Wave 4.2 auto-generated README.md lists 13 agents

## Data quality caveat

This verdict relies entirely on git-log commit-attribution because MongoDB and session_logs are unreachable. That signal is noisy (agents like architect and drafter are invisible in commits by design). The MERGE decisions on integrator/jsdoc/security-reviewer/analyst are supported by BOTH the git signal AND the spec's baseline hypothesis + memory rules, so confidence is high. If MongoDB becomes available later, re-run Task 0.1 and re-check any borderline decisions.
