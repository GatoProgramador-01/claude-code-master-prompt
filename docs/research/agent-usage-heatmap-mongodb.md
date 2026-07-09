# Agent Usage Heatmap — MongoDB agent_runs (last 90 days)

**Query date:** 2026-07-09
**Source:** MongoDB `agent_runs` collection
**Data range:** 2026-04-09 → 2026-07-09

## Data availability

`MONGODB_URI` environment variable is **not set** in the current shell. No `agent_runs` data could be queried directly for this report.

Per plan Section 8 (Risks + mitigations, row 1): "Wave 0 usage data unavailable → Fallback: git-log commit-attribution + memory audit; hypothesis holds". This report is a "no data" placeholder — the merged verdict in `agent-usage-heatmap.md` relies on Wave 0.3 (git commit attribution) as the primary usage signal.

## Table (no data)

| Agent | Invocations (90d) | Total cost (USD) | Avg tokens/call |
|-------|------------------|------------------|-----------------|
| architect | no data | no data | no data |
| llmops-expert | no data | no data | no data |
| backend-expert | no data | no data | no data |
| frontend-expert | no data | no data | no data |
| devops-expert | no data | no data | no data |
| adversarial | no data | no data | no data |
| drafter | no data | no data | no data |
| integrator | no data | no data | no data |
| analyst | no data | no data | no data |
| validate | no data | no data | no data |
| researcher | no data | no data | no data |
| scraper | no data | no data | no data |
| jsdoc | no data | no data | no data |
| security-reviewer | no data | no data | no data |
| lain-specialist | no data | no data | no data |

## Recommendation

To generate real data for future audits, either:
1. Configure `MONGODB_URI` for the medium-agent-factory MongoDB instance and re-run the plan's Task 0.1 query pipeline, OR
2. Set up MongoDB Atlas free tier and update `~/.claude/settings.json` env vars to include the connection string.

The merged verdict below relies on Wave 0.3 git signal instead.
