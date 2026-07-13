---
name: parallel-executor Mandatory Every Sprint
description: parallel-executor is mandatory after writing-plans in every implementation sprint — parallel is the default, never optional. Never use superpowers:subagent-driven-development (banned).
type: feedback
---

Make `parallel-executor` mandatory immediately after `superpowers:writing-plans` in every sprint that produces implementation code. Never skip it for "small" tasks. Never use `superpowers:subagent-driven-development` — it forces sequential dispatch and is banned by CLAUDE.md.

**Why:** User confirmed parallel subagent execution is non-negotiable in every session. `parallel-executor` replaced SDD because SDD had a "Never parallelize" rule that caused ~34 min sprints; parallel-executor brings them to ~10 min via wave dispatch.

**How to apply:** Required skill sequence for any sprint with code: `brainstorming` → `writing-plans` → `parallel-executor`. If parallel-executor is absent from the `🧠 skills` row of the sprint tree, the sprint is incomplete. Do NOT substitute raw `Agent()` calls — use the actual skill with task-brief scripts, progress ledger, and review-package.
