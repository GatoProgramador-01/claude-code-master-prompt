# Design: SDD Mandatory Every Sprint

**Date:** 2026-07-05  
**Status:** Approved  
**Scope:** CLAUDE.md master prompt + auto-memory

---

## Problem

`superpowers:subagent-driven-development` was described in CLAUDE.md as conditional — "when user picks this option after writing-plans." This made it feel optional, causing inconsistent behavior: some sprints used it, others skipped it and fell back to raw `Agent()` calls or inline execution.

The user's system is built around parallel execution as a hard requirement. SDD is the enforcement mechanism for that parallelism. Skipping it is not a style difference — it breaks the Group of Experts workflow.

---

## Decision

Make SDD mandatory for every sprint, with the same unconditional grammar as `superpowers:brainstorming`.

Required skill sequence for any sprint with implementation code:
```
superpowers:brainstorming → superpowers:writing-plans → superpowers:subagent-driven-development
```

No sprint is complete without all three.

---

## Changes

### 1. CLAUDE.md — line 109 (SDD trigger wording)

**Before:**
```
- `superpowers:subagent-driven-development` — when user picks this option after writing-plans, USE THE ACTUAL SKILL (task-brief scripts, progress ledger, review-package) — do NOT manually launch raw Agent() calls as a substitute
```

**After:**
```
- `superpowers:subagent-driven-development` — MANDATORY every sprint, immediately after writing-plans, before any code is written — USE THE ACTUAL SKILL (task-brief scripts, progress ledger, review-package) — do NOT manually launch raw Agent() calls as a substitute
```

### 2. CLAUDE.md — SKILL USAGE mandatory cadence block (lines 34–37)

**Before:**
```
**SKILL USAGE — mandatory in-session triggers:**  
- Any sprint start → `/codex:rescue --background` fires immediately, before Claude writes a line  
- Any commit → `/codex:adversarial-review --fresh --background` fires before declaring sprint done  
- Skills visible on screen = good session. Zero skills used = failed session.
```

**After:**
```
**SKILL USAGE — mandatory in-session triggers:**  
- Any sprint start → `/codex:rescue --background` fires immediately, before Claude writes a line  
- Any sprint start → `superpowers:subagent-driven-development` fires after writing-plans, before any code is written  
- Any commit → `/codex:adversarial-review --fresh --background` fires before declaring sprint done  
- Skills visible on screen = good session. Zero skills used = failed session.
```

### 3. CLAUDE.md — Standard workflow teams (lines 57–65)

Add `→ SDD` after the plan step in every workflow team that includes implementation.

**Before (example):**
```
- **New pipeline feature**: Analyst + Architect (parallel) → Adversarial → llmops-expert + Drafter (parallel) → Validate → Integrator
```

**After:**
```
- **New pipeline feature**: Analyst + Architect (parallel) → Adversarial → writing-plans → SDD → Validate → Integrator
```

Apply same pattern to all other workflow rows.

### 4. Memory — new file `memory/feedback_sdd_mandatory.md`

Rule, Why, and How-to-apply entry encoding the mandatory SDD trigger across all sessions and projects.

### 5. Memory — `memory/MEMORY.md` index

One-line pointer to the new memory file.

---

## Non-Goals

- No stop hook — too blunt for a workflow rule
- No changes to the SDD skill itself (superpowers plugin — 94% PR rejection rate, do not touch)
- No changes to brainstorming skill

---

## Success Criteria

- Every sprint tree's `🧠 skills` row shows `brainstorming → writing-plans → SDD` in sequence
- No sprint is declared done with SDD absent from the skills row
- The feedback memory survives sessions without the master CLAUDE.md loaded
