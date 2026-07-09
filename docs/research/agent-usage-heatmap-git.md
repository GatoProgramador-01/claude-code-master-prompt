# Agent Usage Heatmap — git commit attribution (last 90 days)

**Query date:** 2026-07-09
**Repos scanned:** medium-agent-factory (350 commits), claude-code-master-prompt (76 commits) — 426 commits total

## Methodology

Because MongoDB `agent_runs` and local `session_logs` are unavailable (see companion reports), this git-based analysis is the **primary usage signal** for Wave 0.

Two sub-signals extracted per agent:
- **Name mentions** — literal `<agent-name>` token in commit subject (case-insensitive)
- **Domain-keyword hits** — keywords that reflect the agent's problem domain (e.g. `langgraph|prompt|eval` for llmops-expert, `docker|railway|terraform` for devops-expert)

Combined signal = name mentions + domain hits. Ranked descending.

## Ranking

| Agent | Name mentions | Domain hits | Combined | Verdict |
|-------|---------------|-------------|----------|---------|
| llmops-expert | 1 | 34 | 35 | **KEEP** (strongest signal) |
| adversarial | 6 | 22 | 28 | **KEEP** |
| researcher | 1 | 26 | 27 | **KEEP** |
| integrator | 0 | 15 | 15 | **MERGE** (see below) |
| validate | 1 | 9 | 10 | **KEEP** |
| frontend-expert | 0 | 9 | 9 | **KEEP** |
| devops-expert | 0 | 9 | 9 | **KEEP** |
| scraper | 1 | 3 | 4 | **KEEP** (pj-peru project) |
| jsdoc | 1 | 2 | 3 | **MERGE → frontend-expert** |
| security-reviewer | 0 | 3 | 3 | **MERGE → adversarial** |
| backend-expert | 0 | 2 | 2 | **KEEP** (see caveat) |
| analyst | 1 | 1 | 2 | **MERGE → adversarial** |
| drafter | 0 | 1 | 1 | **KEEP** (SDD fallback per memory) |
| architect | 0 | 0 | 0 | **KEEP** (invisible in commits) |
| lain-specialist | 0 | 0 | 0 | **KILL** |

## Integrator — the borderline case

- `git log --oneline -- backend/app/orchestrator.py` (90d): **0 commits**
- But "orchestrator" appears 6 times in commit subjects across other files
- Domain keywords "integrator|wire" hit 15 times

Plan Section 4.3 threshold: KEEP integrator iff `orchestrator_py_commits_90d ≥ 15`. Actual: 0. Verdict: **MERGE → llmops-expert**. LLMOps-expert absorbs the orchestrator.py wiring pattern into its Slot 4.

## Backend-expert caveat

Only 2 domain hits looks weak, but keyword search for "fastapi|pydantic|motor" undercounts backend work — most commits describe features (e.g., "add tone_scorer endpoint") not the underlying framework. medium-agent-factory's FastAPI backend is clearly active (350 commits total, many API-adjacent). Baseline hypothesis (KEEP backend-expert) holds despite low signal here.

## Architect + drafter — invisible-in-commits agents

Both are 0-signal here but that's expected: architect operates in-session (never commits under its name); drafter is the SDD fallback implementer. Trust memory rules, keep both.
