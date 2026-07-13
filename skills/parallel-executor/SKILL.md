---
name: parallel-executor
description: "Parallel sprint executor — replacement for superpowers:subagent-driven-development. Use at the start of every sprint, immediately after writing-plans. Groups independent tasks into parallel waves by file overlap, fires all implementers in a wave simultaneously, then fires all reviewers simultaneously. One blocked task never freezes others. Uses the same SDD scripts (task-brief, review-package, progress ledger) unchanged. Trigger: user says 'start sprint', 'implement the plan', or 'run SDD'. Never use superpowers:subagent-driven-development — use this instead."
---

# Parallel Executor — Wave-Parallel Sprint Controller

Replacement for `superpowers:subagent-driven-development`. Reuses all SDD scripts unchanged. Replaces only the sequential controller with a wave-parallel one.

**Root cause fixed:** SDD's "Never: Dispatch multiple implementation subagents in parallel" rule forced sequential execution regardless of task independence. A 3-task sprint that could finish in ~10 min took 34 min.

---

## PHASE 0 — Wave Analysis (before any agent fires)

Read the plan file (ask user for path if not obvious — usually `docs/superpowers/plans/<date>-<name>.md`).

For each task in the plan, collect its `Files:` block:
- `Create:` entries → new files this task writes
- `Modify:` entries → existing files this task touches

Build a **file-set** per task (union of Create + Modify paths, normalized to relative paths).

**Grouping rules:**
1. Two tasks go in the **same wave** if their file-sets have **no intersection**
2. If task brief says `prerequisite: Task N`, it goes in the wave **after** Task N's wave
3. Max **5 tasks per wave** (cost cap)
4. Tasks with empty file-sets (research-only, config-only) can share a wave with anything

**Output before firing any agent — print the wave plan:**

```
Wave plan:
  Wave 1: [Task 1, Task 3]  — implementers fire simultaneously
  Wave 2: [Task 2, Task 4]  — fires after Wave 1 approved
```

If only 1 task exists, it forms Wave 1 alone (still fires as an agent, not inline).

---

## PHASE 1 — Per-Wave Execution

Repeat for each wave in order:

### Step 1 — Record base SHA

```bash
git rev-parse HEAD
```

Store as `WAVE_BASE_SHA`. Used for per-task review packages.

### Step 2 — Extract task briefs

Run `task-brief PLAN N` for each task in the wave (sequential, fast — these are script calls, not agents).

If `task-brief` scripts don't exist, read the task section directly from the plan file.

### Step 3 — Dispatch all implementers simultaneously

**One message, multiple `Agent()` calls** — this is the core change from SDD.

For each task in the wave, dispatch one agent using the routing table below. All fire in the same message turn.

Each implementer receives:
- Task brief path
- Working directory
- "Report results to `task-N-report.md`. Include: status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), list of commits made (SHA + message), files changed."

**Routing table** (from `codex-routing.md`):

| Task type | subagent_type |
|-----------|---------------|
| New Python files, TDD, new agent/node/prompt files | `drafter` |
| LangGraph nodes, LLMOps, orchestrator wiring, PipelineState | `llmops-expert` |
| FastAPI routes, Pydantic, Motor, rate limits, auth | `backend-expert` |
| React/Next.js/TS, App Router, RTL tests, TSDoc | `frontend-expert` |
| Docker, GitHub Actions, Railway/Vercel, Terraform | `devops-expert` |
| Prompt files, prompt versioning, G-Eval rubrics | `prompt-engineer` |
| Eval datasets, deepeval/RAGAS wiring | `eval-writer` |
| HTTP/browser scrapers, anti-bot, ASP.NET forms | `scraper` |
| No exact match | `drafter` |

**Never use `general-purpose` as an implementer.**

### Step 4 — Collect all implementer results

Wait for all N implementers to return. For each task, read `task-N-report.md` and handle by status:

| Status | Action |
|--------|--------|
| `DONE` | Generate review package → queue for reviewer wave |
| `DONE_WITH_CONCERNS` | Read concerns. If correctness risk → treat as BLOCKED. If observation → proceed to review, note in ledger. |
| `NEEDS_CONTEXT` | Answer inline, re-dispatch that single agent. Other slots proceed to reviewer wave without waiting. |
| `BLOCKED` | Surface to user immediately with specific blocker. Other slots continue. Re-dispatch after user resolves. |

### Step 5 — Generate review packages (per task independently)

Each implementer reports the commits it made (SHA range). For each DONE task:

```bash
git diff <task-N-base-sha>..<task-N-head-sha> > .superpowers/sdd/review-<task-N-base>..<task-N-head>.diff
```

Use the implementer's reported commit SHAs — **not** `HEAD~N` — to avoid truncating other tasks' commits in the same wave.

### Step 6 — Dispatch all reviewers simultaneously

**One message, multiple `Agent()` calls** — same pattern as implementers.

Each reviewer (subagent_type: `adversarial`) receives:
- Task brief path
- Implementer report path (`task-N-report.md`)
- Review diff path
- Constraint: "Issue verdicts: APPROVED / Critical / Important / Minor. Be specific — file:line for every finding."

### Step 7 — Handle reviewer findings (per task independently)

| Verdict | Action |
|---------|--------|
| `APPROVED` | Mark task complete in progress ledger. Done. |
| Critical or Important findings | Dispatch one fix agent for that task (same routing table). Re-review after fix. Other tasks in wave that are already APPROVED are unblocked — do not hold them. |
| Minor findings only | Note in ledger. Mark complete. Flag for final whole-branch review. |

### Step 8 — Update progress ledger

For each approved task, append to `.superpowers/sdd/progress.md`:

```
Task N: complete (commits <base>..<head>, review APPROVED — <one-line summary>)
```

---

## PHASE 2 — Next Wave

Once **all tasks in Wave N** reach APPROVED state, fire Wave N+1 following Phase 1 steps exactly.

Sequential **between** waves. Parallel **within** each wave.

If Wave N has a task stuck on NEEDS_CONTEXT or waiting for user on BLOCKED, fire Wave N+1 for tasks with no dependency on the blocked slot — don't wait.

---

## PHASE 3 — Final Review

After all waves complete:

1. Get merge base:
   ```bash
   git merge-base main HEAD
   ```
   → `MERGE_BASE`

2. Generate whole-branch diff:
   ```bash
   git diff $MERGE_BASE HEAD > .superpowers/sdd/review-final.diff
   ```

3. Dispatch `adversarial` subagent with the diff file. Prompt: "Final branch review. Issue verdict: MERGE-READY or NEEDS-FIX with specific findings."

4. If NEEDS-FIX: dispatch one fix agent with complete findings list, then re-review.

5. Append to progress ledger:
   ```
   Final review: MERGE-READY (commits <base>..<head>; <N> tests pass)
   SPRINT STATUS: MERGE-READY
   ```

6. Invoke `superpowers:finishing-a-development-branch` → then `gitflow close`.

---

## Sprint Status Tree

Print **before firing each wave** (shows plan) and **after each wave completes** (shows delta):

```
😸 Sprint N — Wave X/Y active
├── 🤖 agentes  — N parallel (agent1·agent2·agent3)
├── 🧠 skills   — parallel-executor
├── 📊 metrics  — tests X→Y · build ✅
├── ✅ task1.py  — completed summary
├── 🔄 task2.py  — Wave 2 pending
├── 🔄 task3.py  — in current wave
└── 🔍 Codex   — adversarial review after wave
```

---

## Progress Ledger Format

Identical to SDD format. File: `.superpowers/sdd/progress.md`

```
# <Sprint Name> Sprint
# Branch: feat/<slug>
# Base: <SHA>
Wave 1: Tasks [1, 3]
Wave 2: Tasks [2, 4, 5]
Task 1: complete (commits <base>..<head>, review APPROVED — <summary>)
Task 3: complete (commits <base>..<head>, review APPROVED — <summary>)
Task 2: complete (commits <base>..<head>, review APPROVED — <summary>)
...
Final review: MERGE-READY (commits <base>..<head>; <N> tests pass)
SPRINT STATUS: MERGE-READY
```

---

## Red Flags — Stop and Re-read This File If You Notice:

- About to dispatch implementers one at a time → **STOP. Group the wave. Fire all at once.**
- About to wait for Task 1 to finish before starting Task 2 → **STOP. Check if they share files. If not, same wave.**
- Using `general-purpose` as an implementer → **STOP. Use the routing table above.**
- Reviewer for Task 1 blocking Task 2's implementer when they touch different files → **STOP. Fire both in parallel.**
- All 3+ tasks finishing in 34 minutes when they should finish in 10 → the wave analysis was wrong. Re-check file overlap.

---

## Key Difference vs SDD

| SDD (old) | parallel-executor (this) |
|-----------|--------------------------|
| One implementer at a time | All independent implementers in one message |
| One reviewer at a time | All reviewers in one message |
| One blocked task freezes sprint | One blocked task pauses only its slot |
| 3-task sprint: ~34 min | 3-task sprint: ~10 min |
| Hard "Never parallelize" rule | Parallel is the default |
