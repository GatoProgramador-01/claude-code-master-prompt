# SDD Mandatory Every Sprint — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce `superpowers:subagent-driven-development` as a mandatory step in every implementation sprint, encoded in both the master CLAUDE.md and the user's live auto-memory.

**Architecture:** Three targeted text edits to `CLAUDE.md` change the wording from conditional to mandatory. Two memory file writes (one in the master prompt repo, one in the user's live auto-memory) encode the rule so it persists across projects and sessions that don't load the master CLAUDE.md. Each task commits independently.

**Tech Stack:** Plain Markdown edits. No code, no dependencies.

## Global Constraints

- Never rewrite surrounding context — surgical edits only, exact old→new strings
- Commit CLAUDE.md edits in one commit, memory file edits in a separate commit
- Files in the master prompt repo: `C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt/`
- User live auto-memory: `C:/Users/lanitaEmperadora/.claude/projects/C--Users-lanitaEmperadora/memory/`
- No new files created in CLAUDE.md — edits only
- Memory files use the standard frontmatter format (name, description, type fields)

---

### Task 1: Edit CLAUDE.md — fix SDD trigger wording (line 109)

**Files:**
- Modify: `C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt/CLAUDE.md` (line 109)

**Interfaces:**
- Produces: CLAUDE.md with SDD listed as mandatory (Tasks 2 and 3 modify the same file sequentially)

- [ ] **Step 1: Open and verify current content**

Read line 109 of CLAUDE.md and confirm it contains exactly:
```
- `superpowers:subagent-driven-development` — when user picks this option after writing-plans, USE THE ACTUAL SKILL (task-brief scripts, progress ledger, review-package) — do NOT manually launch raw Agent() calls as a substitute
```

- [ ] **Step 2: Apply the edit**

Replace that line with:
```
- `superpowers:subagent-driven-development` — MANDATORY every sprint, immediately after writing-plans, before any code is written — USE THE ACTUAL SKILL (task-brief scripts, progress ledger, review-package) — do NOT manually launch raw Agent() calls as a substitute
```

- [ ] **Step 3: Verify the change**

Read line 109 again and confirm it now starts with `- \`superpowers:subagent-driven-development\` — MANDATORY`.

- [ ] **Step 4: Do NOT commit yet — Task 2 edits the same file**

---

### Task 2: Edit CLAUDE.md — add SDD to mandatory cadence block (lines 34–37)

**Files:**
- Modify: `C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt/CLAUDE.md` (lines 34–37)

**Interfaces:**
- Consumes: CLAUDE.md after Task 1 edit
- Produces: Mandatory cadence block with SDD listed alongside Codex triggers

- [ ] **Step 1: Verify current content of the cadence block**

Read lines 34–37 and confirm they contain exactly:
```
**SKILL USAGE — mandatory in-session triggers:**  
- Any sprint start → `/codex:rescue --background` fires immediately, before Claude writes a line  
- Any commit → `/codex:adversarial-review --fresh --background` fires before declaring sprint done  
- Skills visible on screen = good session. Zero skills used = failed session.
```

- [ ] **Step 2: Apply the edit**

Replace the block with:
```
**SKILL USAGE — mandatory in-session triggers:**  
- Any sprint start → `/codex:rescue --background` fires immediately, before Claude writes a line  
- Any sprint start → `superpowers:subagent-driven-development` fires after writing-plans, before any code is written  
- Any commit → `/codex:adversarial-review --fresh --background` fires before declaring sprint done  
- Skills visible on screen = good session. Zero skills used = failed session.
```

- [ ] **Step 3: Verify the change**

Read lines 34–38 and confirm the new SDD line appears between the codex:rescue line and the adversarial-review line.

- [ ] **Step 4: Do NOT commit yet — Task 3 edits the same file**

---

### Task 3: Edit CLAUDE.md — wire SDD into standard workflow teams (lines 57–65)

**Files:**
- Modify: `C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt/CLAUDE.md` (lines 57–65)

**Interfaces:**
- Consumes: CLAUDE.md after Tasks 1 and 2 edits
- Produces: All implementation workflow teams show `writing-plans → SDD` before the implementation step

- [ ] **Step 1: Verify current content**

Read lines 57–65 and confirm the Standard workflow teams block contains exactly:
```
### Standard workflow teams
- **New pipeline feature**: Analyst + Architect (parallel) → Adversarial → llmops-expert + Drafter (parallel) → Validate → Integrator
- **New API endpoint**: Architect → backend-expert + adversarial (parallel) → Validate → commit
- **Frontend feature**: frontend-expert + adversarial (parallel) → Validate → jsdoc → commit
- **Deploy/infra change**: devops-expert → adversarial → Validate → commit
- **Research-backed post**: researcher (grounding) → Architect (topic string) → pipeline run
- **Debug failing test**: Analyst → Adversarial (blind hypothesis) → Validate fix
- **Full-stack feature**: frontend-expert + backend-expert + adversarial (all parallel) → Validate → Integrator
```

- [ ] **Step 2: Apply the edit**

Replace that block with (add `→ writing-plans → SDD` before Validate in every implementation workflow; leave Research and Debug unchanged since they don't produce implementation code):
```
### Standard workflow teams
- **New pipeline feature**: Analyst + Architect (parallel) → Adversarial → writing-plans → SDD → Validate → Integrator
- **New API endpoint**: Architect → backend-expert + adversarial (parallel) → writing-plans → SDD → Validate → commit
- **Frontend feature**: frontend-expert + adversarial (parallel) → writing-plans → SDD → Validate → jsdoc → commit
- **Deploy/infra change**: devops-expert → adversarial → writing-plans → SDD → Validate → commit
- **Research-backed post**: researcher (grounding) → Architect (topic string) → pipeline run
- **Debug failing test**: Analyst → Adversarial (blind hypothesis) → Validate fix
- **Full-stack feature**: frontend-expert + backend-expert + adversarial (all parallel) → writing-plans → SDD → Validate → Integrator
```

- [ ] **Step 3: Verify all five implementation workflows now show `writing-plans → SDD`**

Read lines 57–66 and confirm Research-backed post and Debug failing test are unchanged.

- [ ] **Step 4: Commit all three CLAUDE.md edits together**

```bash
cd "C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt"
git add CLAUDE.md
git commit -m "feat: make superpowers:subagent-driven-development mandatory every sprint"
```

Expected: `[main <hash>] feat: make superpowers:subagent-driven-development mandatory every sprint`

---

### Task 4: Write feedback memory file (master prompt repo)

**Files:**
- Create: `C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt/memory/feedback_sdd_mandatory.md`
- Modify: `C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt/memory/MEMORY.md`

**Interfaces:**
- Produces: Memory entry encoding the mandatory SDD rule in the master prompt repo

- [ ] **Step 1: Create the memory file**

Write `memory/feedback_sdd_mandatory.md` with this exact content:
```markdown
---
name: SDD Mandatory Every Sprint
description: superpowers:subagent-driven-development is mandatory after writing-plans in every implementation sprint — parallel is the default, never optional
type: feedback
---

Make `superpowers:subagent-driven-development` mandatory immediately after `superpowers:writing-plans` in every sprint that produces implementation code. Never skip it for "small" tasks.

**Why:** User confirmed parallel subagent execution is non-negotiable in every session. Prior CLAUDE.md wording ("when user picks this option") made SDD feel optional, causing inconsistent behavior across sprints.

**How to apply:** Required skill sequence for any sprint with code: `brainstorming` → `writing-plans` → `subagent-driven-development`. If SDD is absent from the `🧠 skills` row of the sprint tree, the sprint is incomplete. Do NOT substitute raw `Agent()` calls — use the actual skill with task-brief scripts, progress ledger, and review-package.
```

- [ ] **Step 2: Add index entry to `memory/MEMORY.md`**

Read the current `memory/MEMORY.md` and append this line at the end:
```
- [SDD Mandatory Every Sprint](feedback_sdd_mandatory.md) — subagent-driven-development is non-negotiable after writing-plans; parallel is the default, never optional
```

- [ ] **Step 3: Verify both files look correct**

Read `memory/feedback_sdd_mandatory.md` and confirm frontmatter has `type: feedback`. Read the last line of `memory/MEMORY.md` and confirm the pointer is present.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/lanitaEmperadora/Documents/github/claude-code-master-prompt"
git add memory/feedback_sdd_mandatory.md memory/MEMORY.md
git commit -m "memory: add SDD mandatory every sprint feedback rule"
```

Expected: `[main <hash>] memory: add SDD mandatory every sprint feedback rule`

---

### Task 5: Write feedback memory file (user live auto-memory)

**Files:**
- Create: `C:/Users/lanitaEmperadora/.claude/projects/C--Users-lanitaEmperadora/memory/feedback_sdd_mandatory.md`
- Modify: `C:/Users/lanitaEmperadora/.claude/projects/C--Users-lanitaEmperadora/memory/MEMORY.md`

**Interfaces:**
- Consumes: Same content as Task 4 (identical rule, different location)
- Produces: Rule persists in sessions that don't load the master CLAUDE.md

- [ ] **Step 1: Create the live auto-memory file**

Write `C:/Users/lanitaEmperadora/.claude/projects/C--Users-lanitaEmperadora/memory/feedback_sdd_mandatory.md` with this exact content:
```markdown
---
name: SDD Mandatory Every Sprint
description: superpowers:subagent-driven-development is mandatory after writing-plans in every implementation sprint — parallel is the default, never optional
type: feedback
---

Make `superpowers:subagent-driven-development` mandatory immediately after `superpowers:writing-plans` in every sprint that produces implementation code. Never skip it for "small" tasks.

**Why:** User confirmed parallel subagent execution is non-negotiable in every session. Prior CLAUDE.md wording ("when user picks this option") made SDD feel optional, causing inconsistent behavior across sprints.

**How to apply:** Required skill sequence for any sprint with code: `brainstorming` → `writing-plans` → `subagent-driven-development`. If SDD is absent from the `🧠 skills` row of the sprint tree, the sprint is incomplete. Do NOT substitute raw `Agent()` calls — use the actual skill with task-brief scripts, progress ledger, and review-package.
```

- [ ] **Step 2: Add index entry to live `MEMORY.md`**

Read `C:/Users/lanitaEmperadora/.claude/projects/C--Users-lanitaEmperadora/memory/MEMORY.md` and append this line:
```
- [SDD Mandatory Every Sprint](feedback_sdd_mandatory.md) — subagent-driven-development is non-negotiable after writing-plans; parallel is the default, never optional
```

- [ ] **Step 3: Verify**

Read the live `MEMORY.md` and confirm the new line appears. Read `feedback_sdd_mandatory.md` and confirm `type: feedback` is in frontmatter.

- [ ] **Step 4: No git commit needed — live auto-memory is not version-controlled**
