# Agent Usage Heatmap — MongoDB agent_runs (last 90 days)

**Query date:** 2026-07-09
**Source:** MongoDB `agent_runs` collection
**Data range:** 2026-04-09 → 2026-07-09

## Data availability

**MongoDB is running on `localhost:27017` (verified 2026-07-09 22:35 UTC).** The `MONGODB_URI` env var was unset in the shell, causing an initial misdiagnosis of "unavailable" — pymongo default host works fine.

**BUT** — the `agent_runs` collection tracks a DIFFERENT set of agents than the Claude Code experts we are auditing:

- **`agent_runs` tracks** medium-factory PIPELINE agents (LangGraph nodes): `content_generator_initial`, `content_generator_revision_1-4`, `quality_analyzer`, `read_ratio_analyzer`, `human_authenticity_gate`, `topic_refiner`, `title_optimizer`, `formatter`, `close_optimizer`, `web_researcher`, `image_description_enricher`, `cover_image_generator`, `grounding_synthesis`, `content_generator_expand`. **17 pipeline agents, 669 documents total in 90 days.**
- **`agent_runs` does NOT track** Claude Code experts (`architect`, `backend-expert`, `llmops-expert`, etc.) — those are model invocations under the Superpowers SDK, not instrumented via the pipeline's `AgentTokenTracker`.

So for THIS sprint's audit, `agent_runs` is not directly informative — it's the wrong dimension. Wave 0.3 (git commit attribution) remains the correct primary signal. The verdict in `agent-usage-heatmap.md` stands unchanged.

## Pipeline agent usage table (for reference — DIFFERENT scope from this sprint)

| Pipeline agent (in medium-agent-factory) | Invocations 90d |
|-----------------------------------------|-----------------|
| human_authenticity_gate | 119 |
| quality_analyzer | 119 |
| read_ratio_analyzer | 114 |
| content_generator_initial | 31 |
| topic_refiner | 30 |
| content_generator_revision_1 | 30 |
| title_optimizer | 29 |
| formatter | 29 |
| close_optimizer | 28 |
| web_researcher | 28 |
| image_description_enricher | 24 |
| content_generator_revision_3 | 23 |
| content_generator_expand | 20 |
| content_generator_revision_2 | 19 |
| content_generator_revision_4 | 14 |
| grounding_synthesis | 6 |
| cover_image_generator | 6 |

**cost_usd = $0.00 across all rows** — suggests either local Ollama models or the cost tracker isn't wired to real API pricing. Not investigating in this sprint.

## Claude Code experts table (out-of-scope for agent_runs)

The 14 agents this sprint audits (`architect`, `backend-expert`, `llmops-expert`, `frontend-expert`, `devops-expert`, `adversarial`, `drafter`, `integrator`, `analyst`, `validate`, `researcher`, `scraper`, `jsdoc`, `security-reviewer`, `lain-specialist`) are Claude Code custom agents — they run as model invocations under the Superpowers SDK, not as Python processes with `AgentTokenTracker` instrumentation. Their usage cannot be measured from `agent_runs`.

## Instrumentation recommendation (future work — out of this sprint's scope)

To measure Claude Code expert usage properly, wire the `.claude/hooks/PostToolUse` on `Agent` calls to log to a new `claude_code_agent_runs` collection with `{agent_name, session_id, timestamp, tokens_estimate}`. Wave 0.4 verdict stands regardless — git-log signal cleanly distinguishes expert names in commit subjects.
