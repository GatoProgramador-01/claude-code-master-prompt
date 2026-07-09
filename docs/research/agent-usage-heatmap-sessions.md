# Agent Usage Heatmap — session_logs by_agent (last 90 days)

**Query date:** 2026-07-09
**Source:** `~/.claude/session_logs/*.json` OR MongoDB `session_logs` collection

## Data availability

- Local file check: `ls ~/.claude/session_logs/*.json` returns **0 files** — no local session logs recorded.
- MongoDB `session_logs`: not queried (`MONGODB_URI` unset, see `agent-usage-heatmap-mongodb.md`).

Per plan Section 8 (Risks + mitigations, row 1): fallback to git-log signal. This report is a "no data" placeholder.

## Table (no data)

| Agent | Sessions appeared in | Total tasks completed |
|-------|---------------------|----------------------|
| all agents | no data | no data |

## Note

`session-autopilot` skill (per CLAUDE.md) writes to `session_logs` at ~50% context usage. The absence of local session_logs suggests either:
1. Session-autopilot has not run in recent sessions, OR
2. It writes only to MongoDB (unreachable), OR
3. Logs are being cleared / rotated.

Recommended follow-up (out of scope for this sprint): audit the session-autopilot hook to ensure it writes locally when MongoDB is unavailable.
