# Agent Prompt Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use parallel-executor (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite CLAUDE.md as a ~130-line thin router, refactor all ~/.claude/agents/*.md into a shared 10-slot expertise cartridge format, retire duplicative agents, add 3 new domain experts, and validate the change via meta-evals + a field test on medium-agent-factory.

**Architecture:** Six waves — Wave 0 usage audit, Wave 1 cartridge template foundation, Wave 2 core-experts rewrite (5 parallel), Wave 3 support+new agents (5 parallel) + archive step, Wave 4 CLAUDE.md + AGENTS.md sync, Wave 5 validation (meta-evals + field test). All ~/.claude/agents/ changes happen in a git worktree at `~/.claude-agents-v2` so the live agents keep working until the merge gate opens.

**Tech Stack:** Markdown (agent cartridges), YAML frontmatter, Python (meta-eval runner + rubric), deepeval (G-Eval judge), MongoDB (agent_runs + session_logs collections), Git worktrees, Codex plugin (/codex:adversarial-review), Superpowers skills (SDD, brainstorming, receiving-code-review).

## Global Constraints

- **Roster target:** 13-14 agents (7 core + 3 utility [researcher, scraper, drafter] + 3 new [prompt-engineer, eval-writer, sme-reviewer] + integrator conditional on Wave 0)
- **CLAUDE.md size:** 120-140 lines total, verified via `wc -l`
- **Every agent cartridge:** 120-180 lines total, must contain all 10 slots (ROLE, HYDRATION, TRIGGERS, PATTERNS, HANDOFF, REVIEW, SELF-CRITIQUE, ESCALATION, BOUNDARIES, COST BUDGET)
- **Model ID normalization:** every YAML `model:` field uses full ID (`claude-sonnet-4-6`, `claude-haiku-4-5-20251001`, `claude-opus-4-7`) — no bare `sonnet` or `haiku`
- **Worktree isolation:** `~/.claude/agents/` never edited directly during Waves 2-4; all writes go to `~/.claude-agents-v2/agents/`
- **Backup before overwrite:** `~/.claude/agents-backup-v1/` must exist before any Wave 5 field-test swap
- **Push-after-every-commit:** every commit is followed by `git push origin main` (memory rule)
- **Codex mandate:** `/codex:adversarial-review --fresh --background` fires after Wave 4 completes; zero BLOCKERs required to enter Wave 5
- **Meta-eval threshold:** each of the 3 pipeline experts scores ≥ 0.80 aggregate on their 8-task dataset
- **Field-test thresholds (all four required):** quality_score(new) − baseline ≥ −0.03 AND cost(new)/baseline ≤ 1.10 AND wall_clock(new)/baseline ≤ 1.15 AND codex_blockers(new) − baseline ≤ 0
- **Windows constraint:** No symlinks anywhere. Use `cp -r` / `robocopy` for directory swaps.
- **No emojis in agent cartridges or CLAUDE.md.** User memory rule.
- **Never `--no-verify`** on any commit unless the user explicitly authorizes.

---

## Plan Amendment — 2026-07-09 (executed before Task 0.0)

`~/.claude/` is NOT a git repo — it contains 211MB of session transcripts and 13MB of downloaded plugins that must not be tracked. Initializing git there is high-risk.

**Applies to all tasks below:** replace every `git worktree` / `git -C ~/.claude-agents-v2` command with plain filesystem operations. The staging directory `~/.claude-agents-v2/agents/` is a plain (non-git) directory throughout Waves 1-4. State tracking relies on:
1. File existence in staging
2. The `.superpowers/sdd/progress.md` ledger (master-prompt repo — this IS git)
3. Wave 3.8 archive step: `mv` instead of `git mv`
4. Wave 5.4 field-test swap: unchanged (`cp -r` already used)

The Task 4.1 CLAUDE.md rewrite and Task 4.4 medium-agent-factory AGENTS.md rewrite still happen in their real git repos with normal `git add`/`commit`/`push`.

---

## File Structure

```
Documents/github/claude-code-master-prompt/          # master-prompt repo (in place edits)
├── CLAUDE.md                                        # WAVE 4 — 391 → 130 lines
├── docs/
│   ├── research/
│   │   ├── agent-usage-heatmap-mongodb.md           # WAVE 0 output
│   │   ├── agent-usage-heatmap-sessions.md          # WAVE 0 output
│   │   ├── agent-usage-heatmap-git.md               # WAVE 0 output
│   │   └── agent-usage-heatmap.md                   # WAVE 0 merged verdict
│   └── superpowers/
│       └── specs/
│           ├── 2026-07-09-agent-prompt-upgrade-design.md    # existing (spec)
│           └── agent-cartridge-v2.md                        # WAVE 1 output

~/.claude-agents-v2/                                 # WAVE 2-4 worktree — new cartridges land here
└── agents/
    ├── README.md                                    # WAVE 4 — auto-generated roster
    ├── architect.md                                 # WAVE 2 rewritten
    ├── llmops-expert.md                             # WAVE 2 rewritten
    ├── backend-expert.md                            # WAVE 2 rewritten
    ├── frontend-expert.md                           # WAVE 2 rewritten
    ├── devops-expert.md                             # WAVE 2 rewritten
    ├── adversarial.md                               # WAVE 3 rewritten (absorbs security-reviewer)
    ├── validate.md                                  # WAVE 3 rewritten
    ├── researcher.md                                # WAVE 3 rewritten
    ├── scraper.md                                   # WAVE 3 rewritten
    ├── drafter.md                                   # WAVE 3 rewritten (kept as SDD fallback)
    ├── prompt-engineer.md                           # WAVE 3 NEW
    ├── eval-writer.md                               # WAVE 3 NEW
    ├── sme-reviewer.md                              # WAVE 3 NEW
    ├── integrator.md                                # WAVE 3 conditional — kept iff Wave 0 keeps it
    └── evals/
        ├── run.py                                   # WAVE 5 — meta-eval runner
        ├── rubric.py                                # WAVE 5 — slot/correctness/cost scorer
        ├── llmops-expert.jsonl                      # WAVE 5 — 8 tasks
        ├── backend-expert.jsonl                     # WAVE 5 — 8 tasks
        └── architect.jsonl                          # WAVE 5 — 8 tasks

~/.claude/rules/                                     # WAVE 4 — rules migrated from CLAUDE.md
├── codex-routing.md                                 # NEW
├── workflows.md                                     # NEW
├── sprint-status.md                                 # NEW
└── hooks.md                                         # NEW

~/.claude/agents/archive/2026-07-09-v1/              # WAVE 3 — killed/merged agents
├── lain-specialist.md                               # if it exists
├── jsdoc.md
├── security-reviewer.md
├── analyst.md
└── integrator.md                                    # only if Wave 0 merges it

medium-agent-factory/                                # separate repo (in place edits)
└── AGENTS.md                                        # WAVE 4 — refactored as canonical project cartridge
```

---

## Cartridge Writer Procedure (referenced by every Wave 2 and Wave 3 task)

Every cartridge-writing task (Tasks 2.1 to 2.5, 3.1 to 3.5) follows this procedure. Each task below lists ONLY its unique parameters (which files to hydrate from, which cartridge to write, unique escalation targets). The 5 steps below are identical for all.

```
Step A. Read the cartridge template spec at `docs/superpowers/specs/agent-cartridge-v2.md`
Step B. Read the task-specific hydration files (listed per task below)
Step C. Read the CURRENT agent file (if rewriting) to preserve any load-bearing content
Step D. Draft the new cartridge with all 10 slots filled — write to `~/.claude-agents-v2/agents/<name>.md`
Step E. Run the slot-coverage regex check:
        `python ~/.claude-agents-v2/agents/evals/rubric.py --slot-check ~/.claude-agents-v2/agents/<name>.md`
        Expected output: `PASS: all 10 slots present`
        (Note: rubric.py doesn't exist until Wave 5. For Waves 2-3, use grep manually — see Task 1.1 for the 10 slot header markers.)
Step F. Commit: `git -C ~/.claude-agents-v2 add agents/<name>.md && git commit -m "feat(agents): <name> v2 cartridge"`
Step G. Push: `git -C ~/.claude-agents-v2 push origin HEAD` (see Task 0.0 for worktree branch setup)
```

The 10 slot header markers (used by the manual grep in Step E and by `rubric.py --slot-check` in Wave 5):

```
─── Slot 1 — ROLE
─── Slot 2 — HYDRATION PROTOCOL
─── Slot 3 — TRIGGER HEURISTICS
─── Slot 4 — DOMAIN PATTERNS
─── Slot 5 — HANDOFF CONTRACT
─── Slot 6 — REVIEW CONTRACT
─── Slot 7 — SELF-CRITIQUE CHECKLIST
─── Slot 8 — ESCALATION TRIGGERS
─── Slot 9 — WHAT YOU DO NOT DO
─── Slot 10 — COST BUDGET
```

Manual grep check (used until Wave 5 rubric.py lands):
```bash
grep -c "^─── Slot" ~/.claude-agents-v2/agents/<name>.md
# Expected: 10
```

---

## Task 0.0: Bootstrap staging directory (plain `cp -r`, no git)

**Files:**
- Create: `~/.claude-agents-v2/agents/` (plain directory, non-git)
- Read only: `~/.claude/agents/*.md`

**Interfaces:**
- Consumes: current `~/.claude/agents/` contents
- Produces: a working staging copy at `~/.claude-agents-v2/agents/` where Waves 1-4 write. State tracked via file existence + progress ledger, NOT git.

- [ ] **Step 1: Verify source exists**

```bash
ls ~/.claude/agents/*.md | wc -l
```

Expected: 13-15 (roughly — current roster).

- [ ] **Step 2: Copy staging dir**

```bash
mkdir -p ~/.claude-agents-v2/agents
cp -r ~/.claude/agents/*.md ~/.claude-agents-v2/agents/
```

- [ ] **Step 3: Confirm copy succeeded**

```bash
diff -q <(ls ~/.claude/agents/*.md | xargs -n1 basename | sort) \
        <(ls ~/.claude-agents-v2/agents/*.md | xargs -n1 basename | sort)
```

Expected: no output (identical file lists).

- [ ] **Step 4: Record marker**

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ" > ~/.claude-agents-v2/agents/.sprint-marker
echo "Task 0.0: staging bootstrapped at $(cat ~/.claude-agents-v2/agents/.sprint-marker)"
```

Progress-ledger entry (added by controller after completion): `Task 0.0: complete (staging seeded from ~/.claude/agents/, N files)`.

---

## Wave 0 — Usage Audit (parallel · 3 haiku analysts)

Wave 0 tasks are analytical, not code-changing. Each analyst writes ONE markdown report and returns a return-schema summary. Tasks 0.1, 0.2, 0.3 are parallel-eligible (disjoint output files, no dependencies).

### Task 0.1: MongoDB agent_runs frequency + cost report

**Files:**
- Create: `Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-mongodb.md`

**Interfaces:**
- Consumes: MongoDB `agent_runs` collection (fields: `agent_name`, `tokens_in`, `tokens_out`, `cost_usd`, `timestamp`, `duration_ms`)
- Produces: markdown table `| agent | invocations_90d | total_cost_usd | avg_tokens_per_call |` — used by Task 0.4

**Task brief (Section 4.4 schema):**
```yaml
task_id: sprint-cartridge-v2-task-0.1
agent: analyst
depends_on: []
files_to_read:
  - Documents/github/claude-code-master-prompt/docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md
files_you_will_write:
  - Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-mongodb.md
files_you_MUST_NOT_touch:
  - ~/.claude/agents/*
  - ~/.claude-agents-v2/agents/*
  - CLAUDE.md
state_keys_you_read: []
state_keys_you_write: []
success_criteria:
  - markdown table with 14 rows (one per current agent)
  - invocations_90d column populated OR "no data" note per row
  - total_cost_usd rounded to 4 decimals
  - "empty collection" fallback documented if MongoDB returns nothing
cost_budget: {max_tokens: 8000, max_llm_calls: 0, max_usd: 0.02}
review_gate: []
```

- [ ] **Step 1: Check MongoDB connectivity**

```bash
python -c "from pymongo import MongoClient; import os; c = MongoClient(os.environ['MONGODB_URI']); print(c.admin.command('ping'))"
```

Expected: `{'ok': 1.0}`. If `MONGODB_URI` is unset or connection fails, skip to Step 3 (write the "no data" fallback).

- [ ] **Step 2: Query aggregation for last 90 days**

```python
# Save this as /tmp/agent_heatmap_mongo.py then run
from pymongo import MongoClient
import os, datetime, json
c = MongoClient(os.environ["MONGODB_URI"])
db = c[os.environ.get("MONGODB_DB", "medium_agent_factory")]
since = datetime.datetime.utcnow() - datetime.timedelta(days=90)
pipeline = [
    {"$match": {"timestamp": {"$gte": since}}},
    {"$group": {
        "_id": "$agent_name",
        "invocations_90d": {"$sum": 1},
        "total_cost_usd": {"$sum": "$cost_usd"},
        "avg_tokens_in": {"$avg": "$tokens_in"},
        "avg_tokens_out": {"$avg": "$tokens_out"},
    }},
    {"$sort": {"invocations_90d": -1}},
]
rows = list(db.agent_runs.aggregate(pipeline))
print(json.dumps(rows, default=str, indent=2))
```

Run: `python /tmp/agent_heatmap_mongo.py > /tmp/agent_heatmap_mongo.json`.
Expected: JSON array of rows, one per agent that has runs.

- [ ] **Step 3: Write the markdown report**

Write to `Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-mongodb.md`:

```markdown
# Agent Usage Heatmap — MongoDB agent_runs (last 90 days)

Query date: <YYYY-MM-DD>
Source: MongoDB `agent_runs` collection
Data range: <since_date> to <now>

| Agent | Invocations (90d) | Total cost (USD) | Avg tokens/call |
|-------|------------------|------------------|-----------------|
| llmops-expert | 42 | 1.23 | 3400 |
| ... | ... | ... | ... |
| lain-specialist | 0 | 0.0000 | — |

## Notes
- Rows with 0 invocations are candidates for KILL.
- Rows with < 5 invocations and no commits attributed (see Task 0.3) are candidates for MERGE or KILL.
- If MongoDB was unreachable, this report contains only "no data" rows and Task 0.4 must fall back to git-log + memory audit per spec Risks section.
```

Replace the sample rows with real data from `/tmp/agent_heatmap_mongo.json`.

- [ ] **Step 4: Commit and push**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/research/agent-usage-heatmap-mongodb.md
git commit -m "docs(research): Wave 0.1 — MongoDB agent_runs heatmap"
git push origin main
```

Expected: push succeeds.

---

### Task 0.2: session_logs by_agent breakdown

**Files:**
- Create: `Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-sessions.md`

**Interfaces:**
- Consumes: `~/.claude/session_logs/*.json` OR MongoDB `session_logs` collection (fields: `session_id`, `by_agent: {agent_name: {tokens, invocations}}`)
- Produces: markdown table `| agent | sessions_appeared_in | total_tasks_completed |` — used by Task 0.4

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-0.2
agent: analyst
depends_on: []
files_to_read: [~/.claude/session_logs/*.json]
files_you_will_write:
  - Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-sessions.md
files_you_MUST_NOT_touch: [~/.claude/agents/*, CLAUDE.md]
success_criteria:
  - one row per known agent, ordered by sessions_appeared_in desc
  - "no data" fallback rows if session_logs is empty
cost_budget: {max_tokens: 6000, max_llm_calls: 0, max_usd: 0.02}
```

- [ ] **Step 1: Locate session_logs source**

```bash
ls ~/.claude/session_logs/*.json 2>/dev/null | wc -l
```

Expected: a positive integer, or 0. If 0, check MongoDB: `python -c "from pymongo import MongoClient; import os; print(MongoClient(os.environ['MONGODB_URI']).medium_agent_factory.session_logs.count_documents({}))"`.

- [ ] **Step 2: Aggregate by agent**

```python
# /tmp/agent_heatmap_sessions.py
import json, glob, collections, pathlib
sessions = []
for path in glob.glob(str(pathlib.Path.home() / ".claude/session_logs/*.json")):
    with open(path) as f:
        sessions.append(json.load(f))
# Fallback to MongoDB if empty
if not sessions:
    from pymongo import MongoClient
    import os
    c = MongoClient(os.environ["MONGODB_URI"])
    sessions = list(c.medium_agent_factory.session_logs.find({}))
counts = collections.Counter()
tasks = collections.Counter()
for s in sessions:
    by = s.get("token_usage", {}).get("by_agent", {})
    for agent, info in by.items():
        counts[agent] += 1
        tasks[agent] += info.get("invocations", 1) if isinstance(info, dict) else 1
for agent, cnt in counts.most_common():
    print(f"| {agent} | {cnt} | {tasks[agent]} |")
```

Run: `python /tmp/agent_heatmap_sessions.py > /tmp/agent_heatmap_sessions.txt`.
Expected: markdown table rows in stdout. If empty, treat as "no data" case.

- [ ] **Step 3: Write the markdown report**

Header + notes identical in shape to Task 0.1, table filled from Step 2 stdout. Save to `Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-sessions.md`.

- [ ] **Step 4: Commit and push**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/research/agent-usage-heatmap-sessions.md
git commit -m "docs(research): Wave 0.2 — session_logs by-agent heatmap"
git push origin main
```

---

### Task 0.3: git log commit-attribution report

**Files:**
- Create: `Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-git.md`

**Interfaces:**
- Consumes: `git log --format='%s'` on medium-agent-factory + claude-code-master-prompt repos
- Produces: markdown table `| agent | commit_mentions_last_90d | orchestrator_py_commits |` — used by Task 0.4

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-0.3
agent: analyst
depends_on: []
files_to_read: [git log output only]
files_you_will_write:
  - Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-git.md
files_you_MUST_NOT_touch: [~/.claude/agents/*, CLAUDE.md]
success_criteria:
  - Mentions column derived from grepping commit subjects for agent names
  - orchestrator_py_commits column derived from `git log --oneline -- backend/app/orchestrator.py`
  - This column is load-bearing for the integrator KEEP/MERGE decision
cost_budget: {max_tokens: 4000, max_llm_calls: 0, max_usd: 0.01}
```

- [ ] **Step 1: Collect commit subjects from both repos**

```bash
cd ~/medium-agent-factory && git log --since='90 days ago' --format='%s' > /tmp/git_subjects_mf.txt
cd ~/Documents/github/claude-code-master-prompt && git log --since='90 days ago' --format='%s' > /tmp/git_subjects_mp.txt
```

Expected: two files, each with one commit subject per line.

- [ ] **Step 2: Count mentions per agent**

```python
# /tmp/agent_heatmap_git.py
import re, collections, pathlib
agents = ["architect", "llmops-expert", "backend-expert", "frontend-expert",
          "devops-expert", "adversarial", "drafter", "integrator", "analyst",
          "validate", "researcher", "scraper", "jsdoc", "security-reviewer",
          "lain-specialist"]
subjects = pathlib.Path("/tmp/git_subjects_mf.txt").read_text() + pathlib.Path("/tmp/git_subjects_mp.txt").read_text()
counts = collections.Counter()
for a in agents:
    counts[a] = len(re.findall(rf"\b{re.escape(a)}\b", subjects))
for a in agents:
    print(f"| {a} | {counts[a]} |")
```

Run: `python /tmp/agent_heatmap_git.py > /tmp/agent_heatmap_git.txt`.

- [ ] **Step 3: Count orchestrator.py commits (integrator signal)**

```bash
cd ~/medium-agent-factory
git log --since='90 days ago' --oneline -- backend/app/orchestrator.py | wc -l
```

Expected: integer. Record it — this feeds the integrator KEEP/MERGE decision (spec Section 4.3 CONDITIONAL rule: keep if ≥ 5 commits/month = ≥ 15 in 90 days).

- [ ] **Step 4: Write markdown report + commit**

Write to `Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-git.md`:

```markdown
# Agent Usage Heatmap — git commit attribution (last 90 days)

Query date: <YYYY-MM-DD>
Repos scanned: medium-agent-factory, claude-code-master-prompt

| Agent | Commit mentions (90d) |
|-------|----------------------|
| <fill from /tmp/agent_heatmap_git.txt> | |

## orchestrator.py commit frequency (integrator KEEP/MERGE signal)

Total commits touching `backend/app/orchestrator.py` in last 90 days: <N>
Threshold per spec Section 4.3: KEEP integrator iff ≥ 15 commits (≈ 5/month).
Verdict: **KEEP** / **MERGE**
```

```bash
cd Documents/github/claude-code-master-prompt
git add docs/research/agent-usage-heatmap-git.md
git commit -m "docs(research): Wave 0.3 — git commit-attribution heatmap"
git push origin main
```

---

### Task 0.4: Merge three heatmaps into final verdict

**Files:**
- Create: `Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap.md`
- Read: all three heatmap-*.md files from Tasks 0.1, 0.2, 0.3

**Interfaces:**
- Consumes: three heatmap tables (Tasks 0.1, 0.2, 0.3)
- Produces: final verdict table used to gate Waves 2-3 archival

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-0.4
agent: architect
depends_on: [sprint-cartridge-v2-task-0.1, sprint-cartridge-v2-task-0.2, sprint-cartridge-v2-task-0.3]
files_to_read:
  - Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-mongodb.md
  - Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-sessions.md
  - Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap-git.md
  - Documents/github/claude-code-master-prompt/docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md (Section 4.3)
files_you_will_write:
  - Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap.md
success_criteria:
  - Verdict per agent: KILL | MERGE (target) | KEEP | ADD
  - Reasoning column cites which heatmap drove the verdict
  - integrator verdict explicit — KEEP or MERGE based on orchestrator.py commit count
cost_budget: {max_tokens: 6000, max_llm_calls: 1, max_usd: 0.05}
```

- [ ] **Step 1: Read the three heatmap files + spec Section 4.3**

Use Read tool. Note per-agent numbers into a scratch table.

- [ ] **Step 2: Apply decision matrix from spec Section 4.3**

```
IF invocations_90d < 5 AND commits_attributed < 2       → KILL
IF invocations_90d in [5-20] AND role duplicates another → MERGE
IF invocations_90d > 20                                  → KEEP + rewrite
IF role not covered but tasks exist in project           → ADD
```

For `integrator`: KEEP iff `orchestrator_py_commits_90d ≥ 15` (spec Section 4.3 threshold). Otherwise MERGE → llmops-expert.

- [ ] **Step 3: Write merged verdict file**

```markdown
# Agent Usage Heatmap — Final Verdict (Wave 0)

Sources: agent-usage-heatmap-mongodb.md, agent-usage-heatmap-sessions.md, agent-usage-heatmap-git.md

| Agent | Verdict | Invocations 90d | Commit mentions | Reasoning |
|-------|---------|-----------------|-----------------|-----------|
| architect | KEEP | <n> | <m> | Core loop |
| llmops-expert | KEEP | <n> | <m> | Core loop |
| ... | ... | ... | ... | ... |
| integrator | <KEEP or MERGE> | <n> | <m> | orchestrator.py commits: <k> (threshold 15) |
| lain-specialist | KILL | 0 | 0 | Deprecated in memory + zero usage |
| prompt-engineer | ADD | — | — | Not present; owns prompts/*.txt versioning |
| eval-writer | ADD | — | — | Not present; owns evals/datasets/*.jsonl |
| sme-reviewer | ADD | — | — | Not present; owns fact/tone review |

## Final roster count
- Verdict: **<N>** agents post-sprint (from 14)
```

- [ ] **Step 4: Commit and push**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/research/agent-usage-heatmap.md
git commit -m "docs(research): Wave 0.4 — final agent verdict table"
git push origin main
```

Expected: push succeeds. Wave 0 complete.

---

## Wave 1 — Cartridge Template Foundation (sequential · architect + adversarial)

### Task 1.1: Architect writes the cartridge template spec

**Files:**
- Create: `Documents/github/claude-code-master-prompt/docs/superpowers/specs/agent-cartridge-v2.md`

**Interfaces:**
- Consumes: spec Section 4.2 (10-slot layout), Wave 0 final verdict
- Produces: canonical cartridge-v2 spec — every Wave 2/3 drafter reads this as Step A of the Cartridge Writer Procedure

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-1.1
agent: architect
depends_on: [sprint-cartridge-v2-task-0.4]
files_to_read:
  - docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md (Section 4.2, 4.4, 4.5)
  - docs/research/agent-usage-heatmap.md (verdict table)
  - ~/.claude/agents/llmops-expert.md (as concrete reference example)
files_you_will_write:
  - docs/superpowers/specs/agent-cartridge-v2.md
success_criteria:
  - All 10 slots documented with heading marker `─── Slot N — NAME`
  - One complete example cartridge (llmops-expert v2 skeleton) inside the spec as reference
  - Task-brief + return-schema YAML from spec Section 4.4 reproduced verbatim
  - Codex-mode declaration example for each of {blocking, concurrent, skip}
cost_budget: {max_tokens: 12000, max_llm_calls: 2, max_usd: 0.10}
review_gate: [adversarial_subagent]
```

- [ ] **Step 1: Read prerequisite files**

Read tool on:
- `docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md` Sections 4.2, 4.4, 4.5
- `docs/research/agent-usage-heatmap.md`
- `~/.claude/agents/llmops-expert.md`

- [ ] **Step 2: Draft the cartridge spec**

Write `docs/superpowers/specs/agent-cartridge-v2.md` with structure:

```markdown
# Agent Cartridge v2 — canonical template

Every ~/.claude/agents/*.md follows this template. All 10 slots required.

## YAML frontmatter (required fields)

```yaml
---
name: <agent-name>
description: <verb-forward, ≤2 sentences>
model: claude-sonnet-4-6      # or claude-haiku-4-5-20251001 or claude-opus-4-7
maxTurns: <8-30>
---
```

## Slot layout (headers are load-bearing — do not rename)

<For each of the 10 slots: header marker, purpose, min/max lines, example>

## Task-brief schema (Section 4.4 of design spec)

<YAML schema copied verbatim from design spec>

## Return schema

<YAML schema copied verbatim from design spec>

## Codex mode declarations (Slot 6)

<3 examples showing codex-blocking, codex-concurrent, codex-skip>

## Reference example — llmops-expert v2 skeleton

<full example cartridge with all 10 slots populated>
```

- [ ] **Step 3: Manual slot-count check**

```bash
grep -c "^─── Slot" docs/superpowers/specs/agent-cartridge-v2.md
```

Expected: at least 11 (10 template + 1 in the reference example, likely more).

- [ ] **Step 4: Commit and push**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/superpowers/specs/agent-cartridge-v2.md
git commit -m "spec: cartridge-v2 template (Wave 1)"
git push origin main
```

---

### Task 1.2: Adversarial reviews the cartridge template

**Files:**
- Create: `Documents/github/claude-code-master-prompt/docs/research/2026-07-09-cartridge-v2-adversarial.md`

**Interfaces:**
- Consumes: cartridge-v2 spec from Task 1.1
- Produces: severity-rated findings that gate Task 1.3 (revise until zero BLOCKERs)

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-1.2
agent: adversarial
depends_on: [sprint-cartridge-v2-task-1.1]
files_to_read:
  - docs/superpowers/specs/agent-cartridge-v2.md
files_you_will_write:
  - docs/research/2026-07-09-cartridge-v2-adversarial.md
success_criteria:
  - Every finding rated BLOCKER | HIGH | MEDIUM | LOW
  - Adversarial explicitly checks: prompt-engineer/eval-writer/llmops-expert overlap
    (spec Risks section — HIGH likelihood)
  - Adversarial confirms Slot 5 handoff contract prevents file collisions in parallel dispatch
cost_budget: {max_tokens: 8000, max_llm_calls: 2, max_usd: 0.08}
```

- [ ] **Step 1: Attack the template**

Adversarial reviews `agent-cartridge-v2.md`, produces `docs/research/2026-07-09-cartridge-v2-adversarial.md`:

```markdown
# Adversarial review — cartridge-v2 spec

## BLOCKER findings
<none, or listed with file:line>

## HIGH findings
<listed>

## MEDIUM findings
<listed>

## LOW findings
<listed>

## Explicit overlap check — prompt-engineer / eval-writer / llmops-expert
<verdict>

## Explicit parallel-safety check — Slot 5 handoff contract
<verdict>
```

- [ ] **Step 2: Commit and push**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/research/2026-07-09-cartridge-v2-adversarial.md
git commit -m "docs(research): Wave 1.2 — adversarial review of cartridge-v2"
git push origin main
```

---

### Task 1.3: Revise cartridge spec until zero BLOCKERs

**Files:**
- Modify: `Documents/github/claude-code-master-prompt/docs/superpowers/specs/agent-cartridge-v2.md`

**Interfaces:**
- Consumes: adversarial findings from Task 1.2
- Produces: BLOCKER-free spec — gate for Wave 2 to start

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-1.3
agent: architect
depends_on: [sprint-cartridge-v2-task-1.2]
files_to_read:
  - docs/research/2026-07-09-cartridge-v2-adversarial.md
files_you_will_write:
  - docs/superpowers/specs/agent-cartridge-v2.md (modification)
success_criteria:
  - Every BLOCKER finding either fixed or explicitly rejected with reasoning in the spec
  - Task 1.2 re-run reports zero BLOCKERs (may need 1-2 iterations)
cost_budget: {max_tokens: 8000, max_llm_calls: 2, max_usd: 0.08}
```

- [ ] **Step 1: Apply BLOCKER fixes to spec**

Edit each BLOCKER-flagged section of `agent-cartridge-v2.md`.

- [ ] **Step 2: Re-run adversarial**

Repeat Task 1.2 with the revised spec. If BLOCKERs remain, loop Steps 1-2.

- [ ] **Step 3: Commit + push once zero BLOCKERs**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/superpowers/specs/agent-cartridge-v2.md
git commit -m "spec: cartridge-v2 revised — zero BLOCKERs (Wave 1.3)"
git push origin main
```

Wave 1 gate: adversarial re-run must return zero BLOCKERs before Wave 2 dispatches.

---

## Wave 2 — Core Experts Rewrite (parallel · 5 drafters)

All five tasks are parallel-eligible. Dispatch all 5 in a single SDD wave. Each task follows the **Cartridge Writer Procedure** defined at the top of this plan. Below, each task lists ONLY its unique parameters.

### Task 2.1: llmops-expert v2

**Files:**
- Read: `~/.claude/agents/llmops-expert.md` (current), `medium-agent-factory/backend/app/orchestrator.py` (top 60 lines), `~/.claude/rules/python/langchain.md`, `docs/superpowers/specs/agent-cartridge-v2.md`
- Create: `~/.claude-agents-v2/agents/llmops-expert.md`

**Interfaces:**
- Consumes: cartridge-v2 spec (Task 1.1), current llmops-expert.md
- Produces: v2 cartridge — hydration reads orchestrator.py + langchain rules; Codex mode = **codex-blocking** (touches orchestrator.py); escalates to integrator for graph-wiring changes

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-2.1
agent: drafter
depends_on: [sprint-cartridge-v2-task-1.3]
files_to_read: [as above]
files_you_will_write: [~/.claude-agents-v2/agents/llmops-expert.md]
files_you_MUST_NOT_touch:
  - ~/.claude/agents/*
  - ~/.claude-agents-v2/agents/backend-expert.md
  - ~/.claude-agents-v2/agents/frontend-expert.md
  - ~/.claude-agents-v2/agents/devops-expert.md
  - ~/.claude-agents-v2/agents/architect.md
success_criteria:
  - grep -c "^─── Slot" file returns 10
  - YAML frontmatter model field: claude-sonnet-4-6
  - Slot 6 declares codex_mode: codex-blocking
  - Slot 10 declares max_usd_per_run: 0.30
  - line count between 120 and 180 (wc -l)
cost_budget: {max_tokens: 10000, max_llm_calls: 2, max_usd: 0.08}
```

- [ ] **Steps A-G** — Follow the Cartridge Writer Procedure.

- [ ] **Step H: Verify line count**

```bash
wc -l ~/.claude-agents-v2/agents/llmops-expert.md
```

Expected: 120-180.

- [ ] **Step I: Verify 10 slots**

```bash
grep -c "^─── Slot" ~/.claude-agents-v2/agents/llmops-expert.md
```

Expected: 10.

---

### Task 2.2: backend-expert v2

**Files:**
- Read: `~/.claude/agents/backend-expert.md`, `medium-agent-factory/backend/app/main.py`, `medium-agent-factory/backend/app/config.py`, cartridge-v2 spec
- Create: `~/.claude-agents-v2/agents/backend-expert.md`

**Interfaces:**
- Consumes: cartridge-v2 spec, current backend-expert.md
- Produces: v2 cartridge — hydration reads FastAPI main.py + config; Codex mode = **codex-concurrent**; delegates auth/secret changes to devops-expert

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-2.2
agent: drafter
depends_on: [sprint-cartridge-v2-task-1.3]
files_you_will_write: [~/.claude-agents-v2/agents/backend-expert.md]
files_you_MUST_NOT_touch:
  - ~/.claude/agents/*
  - ~/.claude-agents-v2/agents/llmops-expert.md
  - ~/.claude-agents-v2/agents/frontend-expert.md
  - ~/.claude-agents-v2/agents/devops-expert.md
  - ~/.claude-agents-v2/agents/architect.md
success_criteria:
  - 10 slots (grep check)
  - model: claude-sonnet-4-6
  - Slot 4 keeps the Motor async DB + Pydantic v2 patterns
  - Slot 9 explicit: does NOT touch LangGraph pipeline nodes or orchestrator.py
  - line count 120-180
cost_budget: {max_tokens: 10000, max_llm_calls: 2, max_usd: 0.08}
```

- [ ] **Steps A-G** — Follow the Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 120-180.
- [ ] **Step I: slot grep** — expected 10.

---

### Task 2.3: frontend-expert v2

**Files:**
- Read: `~/.claude/agents/frontend-expert.md`, `~/.claude/agents/jsdoc.md` (absorbing), `medium-agent-factory/frontend/src/app/layout.tsx`, `medium-agent-factory/frontend/package.json`, cartridge-v2 spec
- Create: `~/.claude-agents-v2/agents/frontend-expert.md`

**Interfaces:**
- Consumes: cartridge-v2 spec, current frontend-expert.md + jsdoc.md (which merges in)
- Produces: v2 cartridge that also owns TSDoc-emission (formerly jsdoc's job); Codex mode = **codex-concurrent**; Slot 4 includes both React patterns AND TSDoc emission pattern

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-2.3
agent: drafter
depends_on: [sprint-cartridge-v2-task-1.3]
files_you_will_write: [~/.claude-agents-v2/agents/frontend-expert.md]
files_you_MUST_NOT_touch: [as Task 2.1, excluding frontend-expert.md itself]
success_criteria:
  - 10 slots
  - model: claude-sonnet-4-6
  - Slot 4 contains TSDoc emission pattern absorbed from jsdoc.md
  - Slot 6 codex_mode: codex-concurrent (but codex-skip for TSDoc-only edits)
  - Includes Playwright visual demo mandate at sprint close (memory rule)
  - line count 120-180
cost_budget: {max_tokens: 10000, max_llm_calls: 2, max_usd: 0.08}
```

- [ ] **Steps A-G** — Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 120-180.
- [ ] **Step I: slot grep** — expected 10.
- [ ] **Step J: TSDoc absorption check** — `grep -c "TSDoc\|@param" ~/.claude-agents-v2/agents/frontend-expert.md` expected ≥ 3.

---

### Task 2.4: devops-expert v2

**Files:**
- Read: `~/.claude/agents/devops-expert.md`, `medium-agent-factory/docker-compose.yml`, `medium-agent-factory/.github/workflows/ci.yml`, cartridge-v2 spec
- Create: `~/.claude-agents-v2/agents/devops-expert.md`

**Interfaces:**
- Consumes: cartridge-v2 spec, current devops-expert.md
- Produces: v2 cartridge — Codex mode = **codex-blocking** for IaC/secret changes; Slot 8 escalates App code back to backend-expert

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-2.4
agent: drafter
depends_on: [sprint-cartridge-v2-task-1.3]
files_you_will_write: [~/.claude-agents-v2/agents/devops-expert.md]
files_you_MUST_NOT_touch: [as Task 2.1, excluding devops-expert.md itself]
success_criteria:
  - 10 slots
  - model: claude-sonnet-4-6
  - Slot 6 codex_mode: codex-blocking (touches IaC + secrets)
  - Slot 4 preserves 5-job CI pattern + Terraform lifecycle rule + OIDC pattern
  - line count 120-180
cost_budget: {max_tokens: 10000, max_llm_calls: 2, max_usd: 0.08}
```

- [ ] **Steps A-G** — Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 120-180.
- [ ] **Step I: slot grep** — expected 10.

---

### Task 2.5: architect v2

**Files:**
- Read: `~/.claude/agents/architect.md`, `medium-agent-factory/backend/app/orchestrator.py` (top 60 lines for PipelineState), Wave 0 verdict (`docs/research/agent-usage-heatmap.md`), cartridge-v2 spec
- Create: `~/.claude-agents-v2/agents/architect.md`

**Interfaces:**
- Consumes: cartridge-v2 spec, current architect.md, Wave 0 roster verdict
- Produces: v2 cartridge — its Slot 4 (patterns) contains the routing table matching the FINAL roster from Wave 0; its Slot 5 (handoff contract) IS the schema every other agent implements

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-2.5
agent: drafter
depends_on: [sprint-cartridge-v2-task-1.3, sprint-cartridge-v2-task-0.4]
files_you_will_write: [~/.claude-agents-v2/agents/architect.md]
files_you_MUST_NOT_touch: [as Task 2.1, excluding architect.md itself]
success_criteria:
  - 10 slots
  - model: claude-sonnet-4-6
  - Slot 4 routing table matches Wave 0 final roster (13 or 14 agents)
  - Slot 5 handoff contract matches cartridge-v2 spec verbatim
  - line count 120-180
cost_budget: {max_tokens: 12000, max_llm_calls: 2, max_usd: 0.10}
```

- [ ] **Steps A-G** — Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 120-180.
- [ ] **Step I: slot grep** — expected 10.
- [ ] **Step J: Roster match check** — routing table agent list matches `docs/research/agent-usage-heatmap.md` KEEP+ADD list.

---

### Wave 2 gate (sequential — do NOT parallelize with Wave 3)

- [ ] **Step: verify all 5 new cartridges exist and pass slot count**

```bash
for a in llmops-expert backend-expert frontend-expert devops-expert architect; do
  n=$(grep -c "^─── Slot" ~/.claude-agents-v2/agents/$a.md 2>/dev/null)
  echo "$a: $n slots"
done
```

Expected: each reports `10 slots`. If any is missing or short, that task re-runs.

- [ ] **Step: adversarial pass on the 5 cartridges together**

Dispatch adversarial agent with task brief:
```yaml
files_to_read: [all 5 v2 cartridges above]
files_you_will_write: [docs/research/2026-07-09-wave2-adversarial.md]
success_criteria: [check cross-cartridge overlap; check every Slot 5 handoff contract references the same schema fields]
```

Wave 3 does not dispatch until adversarial reports zero BLOCKERs on Wave 2.

---

## Wave 3 — Support + New Agents (parallel · 5 drafters)

All five parallel-eligible. Same Cartridge Writer Procedure.

### Task 3.1: adversarial v2 (absorbs security-reviewer)

**Files:**
- Read: `~/.claude/agents/adversarial.md`, `~/.claude/agents/security-reviewer.md`, cartridge-v2 spec, sample recent Codex findings JSON if available
- Create: `~/.claude-agents-v2/agents/adversarial.md`

**Interfaces:**
- Produces: v2 cartridge whose Slot 4 includes both adversarial-attack patterns AND the full OWASP + secrets checklist merged from security-reviewer.md

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.1
agent: drafter
depends_on: [sprint-cartridge-v2-task-2.5 gate]
files_you_will_write: [~/.claude-agents-v2/agents/adversarial.md]
files_you_MUST_NOT_touch: [all other agent files in worktree]
success_criteria:
  - 10 slots
  - Slot 4 explicitly includes OWASP Top 10 + secrets-scan checklist (absorbed from security-reviewer.md)
  - Slot 6 codex_mode: codex-concurrent (adversarial IS the review; concurrent with Codex)
  - line count 120-180
cost_budget: {max_tokens: 10000, max_llm_calls: 2, max_usd: 0.08}
```

- [ ] **Steps A-G** — Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 120-180.
- [ ] **Step I: slot grep** — expected 10.
- [ ] **Step J: OWASP absorption check** — `grep -ci "OWASP\|SQL injection\|XSS" ~/.claude-agents-v2/agents/adversarial.md` expected ≥ 3.

---

### Task 3.2: validate v2

**Files:**
- Read: `~/.claude/agents/validate.md`, cartridge-v2 spec
- Create: `~/.claude-agents-v2/agents/validate.md`

**Interfaces:**
- Produces: v2 cartridge — model = **claude-haiku-4-5-20251001** (cost-optimized last-gate); Codex mode = **codex-skip** (validate IS the last gate, no re-review needed)

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.2
agent: drafter
depends_on: [sprint-cartridge-v2-task-2.5 gate]
files_you_will_write: [~/.claude-agents-v2/agents/validate.md]
success_criteria:
  - 10 slots
  - model: claude-haiku-4-5-20251001
  - Slot 4 preserves current type+lint+format+test+build sequence
  - Slot 6 codex_mode: codex-skip
  - line count 100-160 (validate is a smaller role)
cost_budget: {max_tokens: 8000, max_llm_calls: 2, max_usd: 0.05}
```

- [ ] **Steps A-G** — Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 100-160.
- [ ] **Step I: slot grep** — expected 10.

---

### Task 3.3: researcher + scraper v2 (bundled — both small)

**Files:**
- Read: `~/.claude/agents/researcher.md`, `~/.claude/agents/scraper.md`, cartridge-v2 spec
- Create: `~/.claude-agents-v2/agents/researcher.md` AND `~/.claude-agents-v2/agents/scraper.md`

**Interfaces:**
- Produces: two v2 cartridges — both `codex-skip` (utility agents, no code-writing risk); researcher preserves grounding-facts mandate; scraper preserves anti-bot + ASP.NET patterns

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.3
agent: drafter
depends_on: [sprint-cartridge-v2-task-2.5 gate]
files_you_will_write:
  - ~/.claude-agents-v2/agents/researcher.md
  - ~/.claude-agents-v2/agents/scraper.md
success_criteria:
  - Both files have 10 slots, line count 100-160
  - researcher.md model: claude-sonnet-4-6 (web research needs Sonnet)
  - scraper.md model: claude-sonnet-4-6 (code-writing)
  - Both Slot 6: codex_mode: codex-concurrent
cost_budget: {max_tokens: 12000, max_llm_calls: 3, max_usd: 0.10}
```

- [ ] **Steps A-G × 2** — Cartridge Writer Procedure for each file.
- [ ] **Step H: line count both files** — expected 100-160 each.
- [ ] **Step I: slot grep both files** — expected 10 each.

---

### Task 3.4: prompt-engineer v2 (NEW)

**Files:**
- Read: cartridge-v2 spec, `medium-agent-factory/backend/prompts/` inventory (`ls`), `medium-agent-factory/backend/evals/datasets/` inventory, spec Section 4.3 rationale
- Create: `~/.claude-agents-v2/agents/prompt-engineer.md`

**Interfaces:**
- Produces: NEW cartridge — owns prompts/*.txt versioning, G-Eval rubric authoring, few-shot exemplar injection; overlap-guard: Slot 9 explicitly says "does NOT wire LangGraph nodes (that is llmops-expert)"

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.4
agent: drafter
depends_on: [sprint-cartridge-v2-task-2.5 gate]
files_you_will_write: [~/.claude-agents-v2/agents/prompt-engineer.md]
files_you_MUST_NOT_touch:
  - ~/.claude-agents-v2/agents/llmops-expert.md
  - ~/.claude-agents-v2/agents/eval-writer.md
success_criteria:
  - 10 slots
  - model: claude-sonnet-4-6
  - Slot 4 includes prompt file versioning + few-shot injection + G-Eval rubric structure
  - Slot 8 escalates any node wiring to llmops-expert
  - Slot 9 explicit overlap-boundary with llmops-expert AND eval-writer
  - line count 120-180
cost_budget: {max_tokens: 12000, max_llm_calls: 2, max_usd: 0.10}
```

- [ ] **Steps A-G** — Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 120-180.
- [ ] **Step I: slot grep** — expected 10.
- [ ] **Step J: overlap-boundary check** — `grep -i "llmops-expert\|eval-writer" ~/.claude-agents-v2/agents/prompt-engineer.md` expected ≥ 2 matches (mentioned in Slot 8 and 9).

---

### Task 3.5: eval-writer + sme-reviewer v2 (bundled — both NEW)

**Files:**
- Read: cartridge-v2 spec, `medium-agent-factory/backend/evals/` layout, `.claude/rules/python/langchain.md` (Layer 1/2/3 eval section), sample recent posts from `medium-agent-factory/output/`, `medium-agent-factory/docs/HOW-IT-WORKS.md`
- Create: `~/.claude-agents-v2/agents/eval-writer.md` AND `~/.claude-agents-v2/agents/sme-reviewer.md`

**Interfaces:**
- Produces: eval-writer cartridge (owns deepeval Layer 1/2/3 + JSONL datasets) + sme-reviewer cartridge (fact/tone review; hydrates from recent posts + HOW-IT-WORKS.md per spec Risks section)

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.5
agent: drafter
depends_on: [sprint-cartridge-v2-task-2.5 gate]
files_you_will_write:
  - ~/.claude-agents-v2/agents/eval-writer.md
  - ~/.claude-agents-v2/agents/sme-reviewer.md
files_you_MUST_NOT_touch:
  - ~/.claude-agents-v2/agents/llmops-expert.md
  - ~/.claude-agents-v2/agents/prompt-engineer.md
success_criteria:
  - Both files: 10 slots, model: claude-sonnet-4-6, line count 120-180
  - eval-writer Slot 4: deepeval Layer 1/2/3 pattern + JSONL schema + threshold ≥ 0.75
  - eval-writer Slot 9: does NOT author prompts (that is prompt-engineer) or wire nodes (that is llmops-expert)
  - sme-reviewer Slot 2 hydration: reads latest 3 posts + docs/HOW-IT-WORKS.md
  - sme-reviewer Slot 4: fact-accuracy + tone-drift + LLMOps-domain terminology check
cost_budget: {max_tokens: 14000, max_llm_calls: 3, max_usd: 0.12}
```

- [ ] **Steps A-G × 2** — Cartridge Writer Procedure for each file.
- [ ] **Step H: line count both** — expected 120-180 each.
- [ ] **Step I: slot grep both** — expected 10 each.
- [ ] **Step J: sme-reviewer hydration check** — `grep -c "HOW-IT-WORKS\|latest.*post" ~/.claude-agents-v2/agents/sme-reviewer.md` expected ≥ 1.

---

### Task 3.6: drafter v2 (kept per memory rule)

**Files:**
- Read: `~/.claude/agents/drafter.md`, cartridge-v2 spec
- Create: `~/.claude-agents-v2/agents/drafter.md`

**Interfaces:**
- Produces: v2 cartridge for the SDD default-fallback implementer per memory rule `feedback_sdd_agent_routing.md`; DO NOT KILL

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.6
agent: drafter
depends_on: [sprint-cartridge-v2-task-2.5 gate]
files_you_will_write: [~/.claude-agents-v2/agents/drafter.md]
success_criteria:
  - 10 slots
  - model: claude-haiku-4-5-20251001 (drafter is haiku per current roster)
  - Slot 1 explicitly declares role as SDD default-fallback implementer (memory rule)
  - Slot 4 preserves RED-tests-first TDD pattern
  - Slot 8 escalates to any domain expert if task clearly matches their surface
  - line count 100-160
cost_budget: {max_tokens: 8000, max_llm_calls: 2, max_usd: 0.05}
```

- [ ] **Steps A-G** — Cartridge Writer Procedure.
- [ ] **Step H: wc -l check** — expected 100-160.
- [ ] **Step I: slot grep** — expected 10.

---

### Task 3.7: integrator v2 (CONDITIONAL — only if Wave 0 verdict = KEEP)

**Files:**
- Read: `docs/research/agent-usage-heatmap.md` (verdict), `~/.claude/agents/integrator.md`, `medium-agent-factory/backend/app/orchestrator.py`
- Create: `~/.claude-agents-v2/agents/integrator.md` (skip entirely if verdict is MERGE)

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.7
agent: drafter
depends_on: [sprint-cartridge-v2-task-2.5 gate, sprint-cartridge-v2-task-0.4]
files_you_will_write: [~/.claude-agents-v2/agents/integrator.md — CONDITIONAL]
success_criteria:
  - IF Wave 0 verdict = KEEP integrator: file exists with 10 slots + codex-blocking + line count 120-180
  - IF Wave 0 verdict = MERGE integrator: file does NOT exist (skip task entirely — llmops-expert Slot 4 absorbs orchestrator.py wiring pattern)
cost_budget: {max_tokens: 8000, max_llm_calls: 2, max_usd: 0.06}
```

- [ ] **Step 1: Read verdict**

```bash
grep -A2 "^| integrator" ~/Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap.md
```

- [ ] **Step 2: Branch on verdict**

If verdict = KEEP: follow Cartridge Writer Procedure Steps A-G, target line count 120-180.
If verdict = MERGE: skip. Log to `docs/research/wave3-integrator-skipped.md` a one-liner explaining the merge decision.

---

### Task 3.8: Archive killed/merged agents (sequential — runs AFTER all Wave 3 parallel tasks)

**Files:**
- Move: `~/.claude/agents/lain-specialist.md`, `~/.claude/agents/jsdoc.md`, `~/.claude/agents/security-reviewer.md`, `~/.claude/agents/analyst.md` → `~/.claude/agents/archive/2026-07-09-v1/`
- Move (conditional): `~/.claude/agents/integrator.md` → same archive dir IF Wave 0 verdict = MERGE

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-3.8
agent: drafter
depends_on: [3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7 all complete]
files_you_will_write: [~/.claude/agents/archive/2026-07-09-v1/*.md]
files_you_MUST_NOT_touch: [any file NOT in the archive list]
success_criteria:
  - archive dir contains the killed files
  - original ~/.claude/agents/*.md files for archived agents are absent (moved, not copied)
  - drafter.md NOT in archive (per memory rule — remains as SDD fallback)
cost_budget: {max_tokens: 4000, max_llm_calls: 0, max_usd: 0.02}
```

**IMPORTANT:** This task modifies the LIVE `~/.claude/agents/` directory (not the worktree). It runs AFTER Waves 2-3 complete in the worktree, so the live agents are still available until this task fires. Track A of Wave 5 depends on this state.

- [ ] **Step 1: Create archive dir**

```bash
mkdir -p ~/.claude/agents/archive/2026-07-09-v1
```

- [ ] **Step 2: Move mandatory archives**

```bash
cd ~/.claude/agents
for f in lain-specialist.md jsdoc.md security-reviewer.md analyst.md; do
  [ -f "$f" ] && git mv "$f" archive/2026-07-09-v1/ && echo "archived $f"
done
```

Expected: 3-4 files archived (lain-specialist may not exist per user memory — that is fine).

- [ ] **Step 3: Conditional integrator archive**

```bash
verdict=$(grep -A0 "^| integrator" ~/Documents/github/claude-code-master-prompt/docs/research/agent-usage-heatmap.md | head -1)
if echo "$verdict" | grep -q "MERGE"; then
  git -C ~/.claude mv agents/integrator.md agents/archive/2026-07-09-v1/
  echo "integrator archived (Wave 0 verdict: MERGE)"
else
  echo "integrator kept (Wave 0 verdict: KEEP)"
fi
```

- [ ] **Step 4: Commit + push in ~/.claude/**

```bash
git -C ~/.claude add -A
git -C ~/.claude commit -m "chore(agents): archive killed/merged agents (Wave 3.8)"
git -C ~/.claude push origin main 2>/dev/null || echo "no remote — local commit only"
```

---

### Wave 3 gate

- [ ] **Step: Adversarial pass on all Wave 2 + Wave 3 cartridges**

Dispatch adversarial with task brief targeting all 12-13 new cartridge files. Look for cross-cartridge overlap, Slot 5 handoff-contract inconsistencies, cost-budget outliers.

- [ ] **Step: Zero-BLOCKER gate**

If BLOCKERs found, re-run the offending Wave 2/3 task. Otherwise proceed to Wave 4.

---

## Wave 4 — Master Prompt + Project Sync (sequential)

### Task 4.1: Rewrite CLAUDE.md as thin router (120-140 lines)

**Files:**
- Read: current `Documents/github/claude-code-master-prompt/CLAUDE.md` (391 lines), `docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md` Section 4.1
- Modify: `Documents/github/claude-code-master-prompt/CLAUDE.md` (in place)

**Interfaces:**
- Consumes: design spec Section 4.1 layout + move-out table
- Produces: 120-140 line CLAUDE.md; deep rules migrated to owner files (see Tasks 4.2-4.4)

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-4.1
agent: drafter
depends_on: [Wave 3 gate]
files_to_read:
  - Documents/github/claude-code-master-prompt/CLAUDE.md
  - docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md
files_you_will_write:
  - Documents/github/claude-code-master-prompt/CLAUDE.md (rewrite)
success_criteria:
  - wc -l returns 120-140
  - Contains sections: ROLE, QUICK START, NON-NEGOTIABLE RULES, AGENT ROUTING (thin),
    CORE RULES, WINDOWS ENV, SESSION MANAGEMENT, TECH STACK POINTERS, gitignore
  - Every removed section has a pointer to where it lives now
cost_budget: {max_tokens: 12000, max_llm_calls: 2, max_usd: 0.10}
review_gate: [codex_adversarial]
```

- [ ] **Step 1: Read the current CLAUDE.md end to end**

- [ ] **Step 2: Draft the new CLAUDE.md following Section 4.1 outline**

Structure (exact section names):

```markdown
# Tech Lead · Fullstack · DevOps

## ROLE
<5 lines>

## QUICK START
<10 lines — git log/status/pytest + MEMORY.md pointer>

## NON-NEGOTIABLE RULES
<30 lines: parallel-agents-min-3, codex-every-sprint, SDD-mandatory,
 push-after-commit, TDD, Docker-first, shell-run-discipline>

## AGENT ROUTING (thin)
<15 lines — task pattern → agent name ONLY. See ~/.claude/agents/README.md for descriptions.>

## CORE RULES
<10 lines — secrets, IaC, MCP.json, naming>

## WINDOWS ENV
<5 lines — bash CWD, PowerShell background, port kill>

## SESSION MANAGEMENT
<15 lines — /compact policy, /goal, /rewind>

## TECH STACK POINTERS
<25 lines — one line each, references .claude/rules/*.md>

## .gitignore defaults
<5 lines>
```

- [ ] **Step 3: Line-count verification**

```bash
wc -l Documents/github/claude-code-master-prompt/CLAUDE.md
```

Expected: 120-140. If over, trim. If under 120, ensure all sections present.

- [ ] **Step 4: Commit**

```bash
cd Documents/github/claude-code-master-prompt
git add CLAUDE.md
git commit -m "refactor: CLAUDE.md thin router (391→<N> lines, Wave 4.1)"
git push origin main
```

---

### Task 4.2: Auto-generate `~/.claude/agents/README.md`

**Files:**
- Read: all `~/.claude-agents-v2/agents/*.md` YAML frontmatter
- Create: `~/.claude-agents-v2/agents/README.md`

**Interfaces:**
- Produces: rendered roster table used by every agent's Slot 2 hydration ("all agents read README.md on kickoff")

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-4.2
agent: drafter
depends_on: [Wave 3.8]
files_to_read: [~/.claude-agents-v2/agents/*.md]
files_you_will_write: [~/.claude-agents-v2/agents/README.md]
success_criteria:
  - Table has one row per file in ~/.claude-agents-v2/agents/ (excluding README.md, evals/, archive/)
  - Columns: Agent | Model | maxTurns | Description (from YAML) | Codex mode (from Slot 6)
cost_budget: {max_tokens: 8000, max_llm_calls: 1, max_usd: 0.05}
```

- [ ] **Step 1: Extract YAML frontmatter from every cartridge**

```python
# /tmp/build_agent_readme.py
import pathlib, re, yaml
rows = []
for p in sorted(pathlib.Path.home().glob(".claude-agents-v2/agents/*.md")):
    if p.name in ("README.md",): continue
    text = p.read_text()
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m: continue
    fm = yaml.safe_load(m.group(1))
    # Slot 6 codex_mode extraction
    cm = re.search(r"codex_mode:\s*(\S+)", text)
    rows.append({
        "name": fm.get("name"),
        "model": fm.get("model"),
        "maxTurns": fm.get("maxTurns"),
        "description": fm.get("description", "").split("\n")[0][:120],
        "codex_mode": cm.group(1) if cm else "unset",
    })
print("| Agent | Model | maxTurns | Codex mode | Description |")
print("|-------|-------|----------|------------|-------------|")
for r in rows:
    print(f"| {r['name']} | {r['model']} | {r['maxTurns']} | {r['codex_mode']} | {r['description']} |")
```

- [ ] **Step 2: Write README.md**

```bash
python /tmp/build_agent_readme.py > ~/.claude-agents-v2/agents/README.md
```

- [ ] **Step 3: Commit in worktree**

```bash
git -C ~/.claude-agents-v2 add agents/README.md
git -C ~/.claude-agents-v2 commit -m "docs(agents): auto-generated roster README (Wave 4.2)"
```

---

### Task 4.3: Migrate rules out of CLAUDE.md

**Files:**
- Create: `~/.claude/rules/codex-routing.md`, `~/.claude/rules/workflows.md`, `~/.claude/rules/sprint-status.md`, `~/.claude/rules/hooks.md`
- Read: original CLAUDE.md (from git history: `git show HEAD~<n>:CLAUDE.md`) for the migrated sections

**Interfaces:**
- Consumes: sections listed in spec Section 4.1 move-out table
- Produces: 4 rule files that CLAUDE.md now references by path

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-4.3
agent: drafter
depends_on: [Task 4.1]
files_you_will_write:
  - ~/.claude/rules/codex-routing.md
  - ~/.claude/rules/workflows.md
  - ~/.claude/rules/sprint-status.md
  - ~/.claude/rules/hooks.md
success_criteria:
  - Each rule file exists
  - Contents match the corresponding section from pre-refactor CLAUDE.md
  - codex-routing.md matches spec Section 4.5 findings routing table
cost_budget: {max_tokens: 6000, max_llm_calls: 0, max_usd: 0.03}
```

- [ ] **Step 1: Fetch the original CLAUDE.md sections**

```bash
cd Documents/github/claude-code-master-prompt
git show HEAD~1:CLAUDE.md > /tmp/claude-md-pre-refactor.md
```

- [ ] **Step 2: Create the 4 rule files**

- `~/.claude/rules/codex-routing.md` — copy spec Section 4.5 findings routing table + reconciliation matrix.
- `~/.claude/rules/workflows.md` — copy pre-refactor CLAUDE.md "Standard workflow teams" block.
- `~/.claude/rules/sprint-status.md` — copy pre-refactor CLAUDE.md "SPRINT STATUS REPORTING" section.
- `~/.claude/rules/hooks.md` — copy pre-refactor CLAUDE.md "HOOKS" section.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude
git add rules/codex-routing.md rules/workflows.md rules/sprint-status.md rules/hooks.md
git commit -m "docs(rules): migrate deep rules out of CLAUDE.md (Wave 4.3)"
git push origin main 2>/dev/null || true
```

---

### Task 4.4: Rewrite `medium-agent-factory/AGENTS.md`

**Files:**
- Read: current `medium-agent-factory/AGENTS.md`, `medium-agent-factory/backend/app/orchestrator.py` (PipelineState), `medium-agent-factory/backend/prompts/` ls
- Modify: `medium-agent-factory/AGENTS.md` (in place)

**Interfaces:**
- Consumes: current AGENTS.md pipeline table + spec Section 4.4 hydration protocol
- Produces: AGENTS.md restructured as canonical project cartridge — every agent's Slot 2 hydration reads it

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-4.4
agent: drafter
depends_on: [Task 4.1]
files_to_read:
  - medium-agent-factory/AGENTS.md
  - medium-agent-factory/backend/app/orchestrator.py (top 60 lines)
  - medium-agent-factory/backend/prompts/ (ls)
files_you_will_write: [medium-agent-factory/AGENTS.md]
success_criteria:
  - Preserves the Pipeline Nodes Table (current lines 4-45)
  - Preserves Support Modules Table
  - Preserves Prompt Files Table
  - ADD: PipelineState schema snippet (extracted from orchestrator.py top 60 lines)
  - ADD: "How to hydrate this cartridge" section pointing agents at which sections to read
  - REMOVE: Claude Code Dev Agents section (that content now lives in ~/.claude/agents/README.md)
cost_budget: {max_tokens: 12000, max_llm_calls: 2, max_usd: 0.10}
```

- [ ] **Step 1: Read + preserve**

Read tool on the 3 files.

- [ ] **Step 2: Rewrite in place**

Sections (in order):
1. Overview (project purpose, 1 paragraph)
2. Canonical hydration ("Agents reading this file: read Sections 3, 4, 5 always.")
3. Pipeline Nodes Table (preserved verbatim from current AGENTS.md)
4. PipelineState Schema (extracted TypedDict from orchestrator.py)
5. Support Modules Table (preserved)
6. Prompt Files Table (preserved)
7. How to Add a New Agent (preserved from current AGENTS.md)
8. Cross-Platform Context Sharing (preserved)

- [ ] **Step 3: Commit + push medium-agent-factory**

```bash
cd ~/medium-agent-factory
git add AGENTS.md
git commit -m "docs(agents): AGENTS.md as canonical project cartridge (Wave 4.4)"
git push origin master
```

---

### Task 4.5: Codex adversarial-review on the full diff

**Files:** none created; produces `docs/research/2026-07-09-wave4-codex.md`

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-4.5
agent: adversarial
depends_on: [4.1, 4.2, 4.3, 4.4]
files_to_read: [git diff of ~/.claude-agents-v2, Documents/github/claude-code-master-prompt/CLAUDE.md, medium-agent-factory/AGENTS.md]
files_you_will_write: [Documents/github/claude-code-master-prompt/docs/research/2026-07-09-wave4-codex.md]
success_criteria:
  - Codex report saved
  - Zero BLOCKERs required to enter Wave 5
cost_budget: {max_tokens: 15000, max_llm_calls: 3, max_usd: 0.20}
```

- [ ] **Step 1: Fire Codex on full diff**

```bash
/codex:adversarial-review --fresh --background
```

Wait for completion (Codex writes findings to the plugin's report file — location depends on plugin version; check `~/.codex/reports/` or similar).

- [ ] **Step 2: Copy findings into research doc**

Move Codex findings to `docs/research/2026-07-09-wave4-codex.md`.

- [ ] **Step 3: Gate — zero BLOCKERs required**

If BLOCKERs found: route to the owner per `~/.claude/rules/codex-routing.md`, dispatch fix, re-run Task 4.5. Otherwise proceed to Wave 5.

- [ ] **Step 4: Commit**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/research/2026-07-09-wave4-codex.md
git commit -m "docs(research): Wave 4.5 — Codex adversarial review report"
git push origin main
```

---

## Wave 5 — Validation (parallel · Track A + Track B)

### Task 5.1: Meta-eval runner + rubric (Track A infrastructure)

**Files:**
- Create: `~/.claude-agents-v2/agents/evals/run.py`, `~/.claude-agents-v2/agents/evals/rubric.py`
- Test: `~/.claude-agents-v2/agents/evals/test_rubric.py`

**Interfaces:**
- Consumes: cartridge files at `~/.claude-agents-v2/agents/<name>.md`, JSONL dataset at `~/.claude-agents-v2/agents/evals/<name>.jsonl`
- Produces: eval scores per task; aggregate score per agent; JSON report at `~/.claude-agents-v2/agents/evals/report-<agent>.json`

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-5.1
agent: eval-writer     # now available since Wave 3.5
depends_on: [Task 4.5]
files_you_will_write:
  - ~/.claude-agents-v2/agents/evals/run.py
  - ~/.claude-agents-v2/agents/evals/rubric.py
  - ~/.claude-agents-v2/agents/evals/test_rubric.py
success_criteria:
  - test_rubric.py passes (5+ test cases)
  - rubric.py --slot-check on any cartridge returns "PASS: all 10 slots present" or "FAIL: missing slots N, M"
  - run.py --agent <name> loads its JSONL + computes weighted score (slot 30%, correctness 50%, cost 20%)
cost_budget: {max_tokens: 15000, max_llm_calls: 4, max_usd: 0.15}
```

- [ ] **Step 1: Write the failing test**

```python
# ~/.claude-agents-v2/agents/evals/test_rubric.py
import pytest
from rubric import slot_check, score_correctness, score_cost, aggregate

def test_slot_check_pass(tmp_path):
    f = tmp_path / "agent.md"
    body = "\n".join(f"─── Slot {i} — X" for i in range(1, 11))
    f.write_text(f"---\nname: x\n---\n{body}")
    ok, missing = slot_check(str(f))
    assert ok is True
    assert missing == []

def test_slot_check_missing_slots(tmp_path):
    f = tmp_path / "agent.md"
    body = "\n".join(f"─── Slot {i} — X" for i in [1, 2, 5])
    f.write_text(f"---\nname: x\n---\n{body}")
    ok, missing = slot_check(str(f))
    assert ok is False
    assert set(missing) == {3, 4, 6, 7, 8, 9, 10}

def test_score_cost_under_budget():
    assert score_cost(actual_usd=0.05, budget_usd=0.20) == 1.0

def test_score_cost_over_budget_linear_penalty():
    # actual=0.25, budget=0.20 → 20% over → 0.80 score
    assert score_cost(actual_usd=0.24, budget_usd=0.20) == pytest.approx(0.80, abs=0.01)

def test_aggregate_weights():
    # slot=1.0, correctness=0.6, cost=1.0 → 0.30 + 0.30 + 0.20 = 0.80
    assert aggregate(slot=1.0, correctness=0.6, cost=1.0) == pytest.approx(0.80)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ~/.claude-agents-v2/agents/evals
pytest test_rubric.py -v
```

Expected: FAIL with "No module named 'rubric'".

- [ ] **Step 3: Write minimal rubric.py**

```python
# ~/.claude-agents-v2/agents/evals/rubric.py
import re, sys, argparse
from pathlib import Path

REQUIRED_SLOTS = list(range(1, 11))

def slot_check(md_path: str) -> tuple[bool, list[int]]:
    text = Path(md_path).read_text(encoding="utf-8")
    present = set(int(m.group(1)) for m in re.finditer(r"^─── Slot (\d+) —", text, re.MULTILINE))
    missing = [n for n in REQUIRED_SLOTS if n not in present]
    return (len(missing) == 0, missing)

def score_correctness(agent_output: str, golden: dict) -> float:
    # Deterministic first pass — pattern matching. Deepeval G-Eval upgrade in run.py.
    must = golden.get("must_include_patterns", [])
    must_not = golden.get("must_NOT_include_patterns", [])
    hits = sum(1 for p in must if re.search(p, agent_output))
    misses = sum(1 for p in must_not if re.search(p, agent_output))
    if not must:
        return 1.0 if misses == 0 else 0.0
    base = hits / len(must)
    penalty = 0.5 if misses > 0 else 0.0
    return max(0.0, base - penalty)

def score_cost(actual_usd: float, budget_usd: float) -> float:
    if actual_usd <= budget_usd:
        return 1.0
    over_ratio = (actual_usd - budget_usd) / budget_usd
    return max(0.0, 1.0 - over_ratio)

def aggregate(slot: float, correctness: float, cost: float) -> float:
    return 0.30 * slot + 0.50 * correctness + 0.20 * cost

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slot-check", type=str, help="path to cartridge to check")
    args = ap.parse_args()
    if args.slot_check:
        ok, missing = slot_check(args.slot_check)
        if ok:
            print("PASS: all 10 slots present")
            sys.exit(0)
        else:
            print(f"FAIL: missing slots {missing}")
            sys.exit(1)

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd ~/.claude-agents-v2/agents/evals
pytest test_rubric.py -v
```

Expected: PASS (5 tests).

- [ ] **Step 5: Write run.py (orchestrator)**

```python
# ~/.claude-agents-v2/agents/evals/run.py
import argparse, json, sys, pathlib
from rubric import slot_check, score_correctness, score_cost, aggregate

def load_jsonl(path: pathlib.Path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]

def run_agent_evals(agent: str, agents_dir: pathlib.Path) -> dict:
    md_path = agents_dir / f"{agent}.md"
    jsonl_path = pathlib.Path(__file__).parent / f"{agent}.jsonl"
    if not md_path.exists() or not jsonl_path.exists():
        print(f"skipping {agent} — missing {md_path} or {jsonl_path}")
        return {"agent": agent, "aggregate": None, "reason": "missing files"}
    ok, missing = slot_check(str(md_path))
    slot_score = 1.0 if ok else max(0.0, 1.0 - len(missing) / 10)
    cases = load_jsonl(jsonl_path)
    correctness_scores = []
    cost_scores = []
    for case in cases:
        golden = case.get("golden_pattern", {})
        # For Wave 5.1 scaffolding: agent_output is the cartridge itself (does it match the golden pattern?)
        # Wave 5.2 will replace this with a real agent-invocation stub.
        text = md_path.read_text(encoding="utf-8")
        correctness_scores.append(score_correctness(text, golden))
        # cost stub — assumes zero cost until real invocation runs
        cost_scores.append(score_cost(actual_usd=0.0, budget_usd=float(golden.get("max_cost_usd", 0.20))))
    correctness_avg = sum(correctness_scores) / len(correctness_scores)
    cost_avg = sum(cost_scores) / len(cost_scores)
    total = aggregate(slot_score, correctness_avg, cost_avg)
    return {
        "agent": agent,
        "slot_score": slot_score,
        "correctness_avg": correctness_avg,
        "cost_avg": cost_avg,
        "aggregate": total,
        "cases": len(cases),
        "passed": total >= 0.80,
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent", required=True)
    ap.add_argument("--agents-dir", default=str(pathlib.Path(__file__).parent.parent))
    args = ap.parse_args()
    result = run_agent_evals(args.agent, pathlib.Path(args.agents_dir))
    out_path = pathlib.Path(__file__).parent / f"report-{args.agent}.json"
    out_path.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("passed") else 1)

if __name__ == "__main__":
    main()
```

- [ ] **Step 6: Commit in worktree**

```bash
git -C ~/.claude-agents-v2 add agents/evals/
git -C ~/.claude-agents-v2 commit -m "feat(evals): meta-eval runner + rubric (Wave 5.1)"
```

---

### Task 5.2: Build 24-case meta-eval dataset

**Files:**
- Create: `~/.claude-agents-v2/agents/evals/llmops-expert.jsonl`, `backend-expert.jsonl`, `architect.jsonl` — 8 cases each

**Interfaces:**
- Consumes: canonical example tasks from real historical work + spec Section 4.6
- Produces: 24 JSONL cases used by run.py

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-5.2
agent: eval-writer
depends_on: [Task 5.1]
files_you_will_write:
  - ~/.claude-agents-v2/agents/evals/llmops-expert.jsonl
  - ~/.claude-agents-v2/agents/evals/backend-expert.jsonl
  - ~/.claude-agents-v2/agents/evals/architect.jsonl
success_criteria:
  - each file: 8 JSONL lines
  - each line has: task_id, task_brief, golden_pattern (must_include_patterns, must_NOT_include_patterns, max_cost_usd)
  - llmops-expert cases cover: node design, structured output, eval architecture, checkpointer, LangSmith config
  - backend-expert cases cover: FastAPI route, Pydantic v2 model, Motor query, rate limit, error handling
  - architect cases cover: task decomposition (2, 3, 5 subtasks), routing table use, dependency graph
cost_budget: {max_tokens: 20000, max_llm_calls: 3, max_usd: 0.20}
```

- [ ] **Step 1: Draft llmops-expert.jsonl**

```json
{"task_id": "llmops-01-node-with-structured-output", "task_brief": {"agent": "llmops-expert", "goal": "Add a new tone_scorer LangGraph node that scores post tone from [-1, 1]"}, "golden_pattern": {"must_include_patterns": ["get_llm\\(", "\\.with_structured_output\\(", "async def tone_scorer_node", "Annotated\\[list"], "must_NOT_include_patterns": ["ChatAnthropic\\(", "\\.invoke\\("], "max_cost_usd": 0.15}}
{"task_id": "llmops-02-3-layer-eval", "task_brief": {"agent": "llmops-expert", "goal": "Design 3-layer eval for a new fact_checker agent"}, "golden_pattern": {"must_include_patterns": ["Layer 1", "Layer 2", "Layer 3", "eval_deep", "GEval|HallucinationMetric"], "must_NOT_include_patterns": ["GEval.*Layer 1", "HallucinationMetric.*Layer 1"], "max_cost_usd": 0.15}}
{"task_id": "llmops-03-checkpointer-choice", "task_brief": {"agent": "llmops-expert", "goal": "Pick checkpointer for prod deploy on Railway with PostgreSQL"}, "golden_pattern": {"must_include_patterns": ["PostgresSaver"], "must_NOT_include_patterns": ["MemorySaver"], "max_cost_usd": 0.05}}
{"task_id": "llmops-04-config-runnable", "task_brief": {"agent": "llmops-expert", "goal": "Fix node so LangSmith shows LLM calls as span children"}, "golden_pattern": {"must_include_patterns": ["RunnableConfig", "config=config"], "must_NOT_include_patterns": [], "max_cost_usd": 0.05}}
{"task_id": "llmops-05-json-coerce-fallback", "task_brief": {"agent": "llmops-expert", "goal": "Handle LLM curly quotes in Pydantic str→list validator"}, "golden_pattern": {"must_include_patterns": ["field_validator", "json.JSONDecodeError", "replace.*['‘’]"], "must_NOT_include_patterns": [], "max_cost_usd": 0.05}}
{"task_id": "llmops-06-node-purity", "task_brief": {"agent": "llmops-expert", "goal": "Review a node that reads and writes state"}, "golden_pattern": {"must_include_patterns": ["Read from state", "Return only", "never mutate"], "must_NOT_include_patterns": ["state\\[.*\\] ="], "max_cost_usd": 0.05}}
{"task_id": "llmops-07-cost-role-routing", "task_brief": {"agent": "llmops-expert", "goal": "Route between worker and supervisor for quality analysis"}, "golden_pattern": {"must_include_patterns": ["get_llm\\(.worker.\\)", "get_llm\\(.supervisor.\\)", "min_quality_score"], "must_NOT_include_patterns": [], "max_cost_usd": 0.05}}
{"task_id": "llmops-08-orchestrator-escalation", "task_brief": {"agent": "llmops-expert", "goal": "Adding a new node — how to wire it into orchestrator.py"}, "golden_pattern": {"must_include_patterns": ["integrator|escalation"], "must_NOT_include_patterns": ["orchestrator.py:.*add_node|g\\.add_edge"], "max_cost_usd": 0.05}}
```

Save exactly as above (one line per JSON object) at `~/.claude-agents-v2/agents/evals/llmops-expert.jsonl`.

- [ ] **Step 2: Draft backend-expert.jsonl** (analogous — 8 cases for FastAPI/Motor/Pydantic scenarios)

- [ ] **Step 3: Draft architect.jsonl** (analogous — 8 cases for decomposition scenarios)

- [ ] **Step 4: Validate JSONL**

```bash
for f in ~/.claude-agents-v2/agents/evals/{llmops-expert,backend-expert,architect}.jsonl; do
  cat "$f" | while read line; do echo "$line" | python -c "import sys, json; json.loads(sys.stdin.read())" || echo "BAD: $line"; done
  wc -l "$f"
done
```

Expected: no BAD lines, 8 lines per file.

- [ ] **Step 5: Commit**

```bash
git -C ~/.claude-agents-v2 add agents/evals/*.jsonl
git -C ~/.claude-agents-v2 commit -m "feat(evals): 24-case meta-eval dataset (Wave 5.2)"
```

---

### Task 5.3: Run meta-evals — 3-run mean

**Files:** none created; produces `~/.claude-agents-v2/agents/evals/report-*.json` × 3

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-5.3
agent: eval-writer
depends_on: [Task 5.2]
success_criteria:
  - report-llmops-expert.json aggregate ≥ 0.80
  - report-backend-expert.json aggregate ≥ 0.80
  - report-architect.json aggregate ≥ 0.80
  - std-dev of 3-run mean < 0.10 per agent (else re-run)
cost_budget: {max_tokens: 40000, max_llm_calls: 15, max_usd: 0.30}
```

- [ ] **Step 1: Run 3 times per agent**

```bash
cd ~/.claude-agents-v2/agents/evals
for agent in llmops-expert backend-expert architect; do
  for i in 1 2 3; do
    python run.py --agent "$agent" > "report-$agent-run$i.json"
  done
done
```

- [ ] **Step 2: Compute 3-run mean and std-dev**

```python
# /tmp/eval_mean.py
import json, pathlib, statistics
for agent in ["llmops-expert", "backend-expert", "architect"]:
    runs = [json.loads(pathlib.Path(f"report-{agent}-run{i}.json").read_text())["aggregate"] for i in [1,2,3]]
    print(f"{agent}: mean={statistics.mean(runs):.3f} stdev={statistics.stdev(runs):.3f} pass={statistics.mean(runs) >= 0.80}")
```

Expected: mean ≥ 0.80 and stdev < 0.10 per agent.

- [ ] **Step 3: On failure, iterate the failing agent's cartridge**

If any agent fails: identify low-scoring cases via `report-<agent>-run<i>.json` `correctness_scores`; edit that agent's cartridge in the worktree; re-run Step 1 for that agent only.

- [ ] **Step 4: Commit final reports**

```bash
git -C ~/.claude-agents-v2 add agents/evals/report-*.json
git -C ~/.claude-agents-v2 commit -m "eval: Wave 5.3 meta-eval 3-run means (all >= 0.80)"
```

---

### Task 5.4: Field test on medium-agent-factory

**Files:**
- Create: `~/.claude/agents-backup-v1/` (backup dir)
- Modify: `~/.claude/agents/*.md` (temporarily overwritten during New run, then restored on fail)
- Create: `Documents/github/claude-code-master-prompt/docs/research/2026-07-09-field-test.md`

**Interfaces:**
- Consumes: baseline pipeline metrics + new-agent pipeline metrics
- Produces: comparison report; go/no-go verdict for merge

**Task brief:**
```yaml
task_id: sprint-cartridge-v2-task-5.4
agent: llmops-expert  # now v2, in worktree — but this task RUNS in medium-factory context
depends_on: [Task 5.3 pass]
files_to_read:
  - medium-agent-factory/AGENTS.md
files_you_will_write:
  - ~/.claude/agents-backup-v1/*
  - ~/.claude/agents/*.md (temporary overwrite during New run)
  - Documents/github/claude-code-master-prompt/docs/research/2026-07-09-field-test.md
success_criteria (all four must hold):
  - quality_score(new) - baseline >= -0.03
  - cost(new) / baseline <= 1.10
  - wall_clock(new) / baseline <= 1.15
  - codex_blockers(new) - baseline <= 0
cost_budget: {max_tokens: 100000, max_llm_calls: 60, max_usd: 2.00}
```

- [ ] **Step 1: Backup live agents**

```bash
cp -r ~/.claude/agents ~/.claude/agents-backup-v1
ls ~/.claude/agents-backup-v1 | head
```

Expected: file list matches `~/.claude/agents/`.

- [ ] **Step 2: BASELINE run — old agents still live**

```bash
cd ~/medium-agent-factory
git checkout -b sprint/agent-v2-fieldtest
python run_master_prompt_post.py > /tmp/fieldtest-baseline.log 2>&1
```

Extract from log or MongoDB:
```
BASELINE
  quality_score:  0.__
  cost_usd:       __.__
  wall_clock_s:   ___
  tokens_total:   ___
  codex_blockers: _
```

- [ ] **Step 3: Swap in new agents from worktree**

```bash
cp -r ~/.claude-agents-v2/agents/* ~/.claude/agents/
```

Verify: `ls ~/.claude/agents/ | wc -l` should reflect the new roster count (12-14 depending on integrator).

- [ ] **Step 4: NEW run — same topic input**

```bash
cd ~/medium-agent-factory
python run_master_prompt_post.py > /tmp/fieldtest-new.log 2>&1
```

Extract metrics same as Step 2.

- [ ] **Step 5: Codex adversarial-review on both outputs**

```bash
/codex:adversarial-review --fresh --background
# wait for completion, count blockers in report
```

- [ ] **Step 6: Compare + write report**

Write `Documents/github/claude-code-master-prompt/docs/research/2026-07-09-field-test.md`:

```markdown
# Field Test — cartridge v2 vs baseline

Date: <date>
Topic: <topic used>

| Metric | Baseline | New | Delta | Threshold | Pass |
|--------|---------|-----|-------|-----------|------|
| quality_score | 0.__ | 0.__ | ±0.__ | ≥ −0.03 | ✅/❌ |
| cost_usd | | | | ≤ 1.10× | |
| wall_clock_s | | | | ≤ 1.15× | |
| codex_blockers | | | | ≤ 0 delta | |

## Verdict
- All four criteria: PASS / FAIL
- Merge decision: MERGE / HOLD

## Notes
- Any anomalies, expected regressions, topic-related caveats
```

- [ ] **Step 7a: On PASS — merge worktree into live**

```bash
# Backup dir already has the pre-swap state — the NEW agents from Step 3 are the merge state.
# Confirm ~/.claude/agents/ matches worktree.
diff -qr ~/.claude/agents ~/.claude-agents-v2/agents
# Archive the baseline formally
mv ~/.claude/agents-backup-v1 ~/.claude/agents/archive/2026-07-09-v1-baseline
# Commit in ~/.claude/
git -C ~/.claude add -A
git -C ~/.claude commit -m "feat(agents): cartridge v2 merge (field test PASS, Wave 5.4)"
git -C ~/.claude push origin main 2>/dev/null || true
# Remove worktree
git -C ~/.claude worktree remove ~/.claude-agents-v2
```

- [ ] **Step 7b: On FAIL — restore baseline**

```bash
rm -rf ~/.claude/agents
mv ~/.claude/agents-backup-v1 ~/.claude/agents
diff -qr ~/.claude/agents ~/.claude-agents-v2/agents  # confirm live is baseline again
```

Then loop back to the failing agent's Wave 2 or 3 task, revise, re-run meta-eval + field-test.

- [ ] **Step 8: Commit final report to master-prompt repo**

```bash
cd Documents/github/claude-code-master-prompt
git add docs/research/2026-07-09-field-test.md
git commit -m "docs(research): Wave 5.4 field test report (verdict: <MERGE|HOLD>)"
git push origin main
```

---

## Wave 5 gate

- [ ] **Meta-eval Track A**: all 3 agents ≥ 0.80 aggregate.
- [ ] **Field test Track B**: all 4 thresholds met.
- [ ] **Codex Wave 4.5**: zero BLOCKERs.
- [ ] All three green → sprint DONE. If any red → hold in worktree, iterate on failing agents only, re-run Wave 5.

---

## Sprint completion — final steps

- [ ] **Step 1: Update MEMORY.md**

Add a project memory entry via the auto-memory system:

```markdown
- [Cartridge v2 sprint](project_cartridge_v2.md) — 2026-07-09: rewrote 14 agents into 10-slot cartridges, thinned CLAUDE.md to <N> lines, added prompt-engineer/eval-writer/sme-reviewer, retired jsdoc/security-reviewer/analyst
```

- [ ] **Step 2: Session-autopilot audit**

Invoke `session-autopilot` skill — produces MongoDB `session_logs` entry with accomplishments + cost breakdown.

- [ ] **Step 3: Final verification**

```bash
wc -l ~/Documents/github/claude-code-master-prompt/CLAUDE.md   # expected 120-140
ls ~/.claude/agents/*.md | wc -l                                # expected 13 or 14
ls ~/.claude/agents/archive/2026-07-09-v1/                      # expected 3-5 files
```

Sprint is DONE when all three commands return the expected numbers AND the field-test report says MERGE.
