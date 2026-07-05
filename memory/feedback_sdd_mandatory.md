---
name: SDD Mandatory Every Sprint
description: superpowers:subagent-driven-development is mandatory after writing-plans in every implementation sprint — parallel is the default, never optional
type: feedback
---

Make `superpowers:subagent-driven-development` mandatory immediately after `superpowers:writing-plans` in every sprint that produces implementation code. Never skip it for "small" tasks.

**Why:** User confirmed parallel subagent execution is non-negotiable in every session. Prior CLAUDE.md wording ("when user picks this option") made SDD feel optional, causing inconsistent behavior across sprints.

**How to apply:** Required skill sequence for any sprint with code: `brainstorming` → `writing-plans` → `subagent-driven-development`. If SDD is absent from the `🧠 skills` row of the sprint tree, the sprint is incomplete. Do NOT substitute raw `Agent()` calls — use the actual skill with task-brief scripts, progress ledger, and review-package.
