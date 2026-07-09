# Agent Prompt Upgrade — Design Doc

**Date:** 2026-07-09
**Author:** Claude Code + jcollipal1212@gmail.com brainstorm session
**Status:** Draft — awaiting user review
**Scope:** Rewrite `CLAUDE.md`, all `~/.claude/agents/*.md`, and `medium-agent-factory/AGENTS.md` as one coordinated expertise system.

---

## 1. Executive summary

Rewrite the Group of Experts agent system so that:

1. `CLAUDE.md` becomes a **thin router** (~120-140 lines, down from 391) — session-startup rules only. All deep rules migrate to the agent or skill that enforces them.
2. Every `~/.claude/agents/*.md` follows a shared **10-slot expertise cartridge** template (role, hydration, triggers, patterns, handoff contract, review contract, self-critique, escalation, boundaries, cost budget).
3. The roster consolidates from 14 to **13-14 agents** (7 core + 3 utility [researcher, scraper, drafter] + 3 new [prompt-engineer, eval-writer, sme-reviewer] + `integrator` conditionally kept), driven by a Wave 0 usage audit.
4. Agents coordinate via a **machine-readable task-brief / return-schema** contract that makes parallel dispatch DAG-safe.
5. Codex and Superpowers plugins are wired **inside** each agent's cartridge, not just at the CLAUDE.md level.
6. Every change is validated via **meta-evals** (3 pipeline-driving experts) + a **field test** on medium-agent-factory (baseline vs new, same input).

Rollout is worktree-isolated, wave-by-wave, with clean revert at every stage.

---

## 2. Motivation

Current pain points (verified from file audit + memory):

- **CLAUDE.md is 391 lines** (target per own memory: 200) — deep rules loaded on every session turn cost ~2,400 tokens.
- **Agent prompts are inconsistent in depth** — `frontend-expert` is 123 lines, `backend-expert` is 290, `llmops-expert` is 268. No shared structure. No shared handoff contract.
- **Codex plugin findings pollute the main context** (~2-5K tokens/review) because they're not routed to a specific expert owner.
- **No context-hydration protocol** — agents don't declare which files they must read on kickoff. Cold-start prompting sacrifices ~15-20% accuracy per Anthropic guidance.
- **No self-critique slot** in current cartridges — Reflexion-paper evidence supports 10-15% regression reduction with a single self-review pass.
- **Model IDs inconsistent** — some agents say `sonnet`, others `claude-sonnet-4-6`. `maxTurns` scattered.
- **Deprecated agents live in roster** (`lain-specialist` per memory feedback).
- **No validation loop** — prompt edits ship on vibes, not evidence. User explicitly requested `superpowers:verification-before-completion` posture.

Sprint goal (user's words): "make those agents expert on the assigned tasks" + "obey the rule of parallel agents."

---

## 3. Design overview — the 6 waves

```
Wave 0 — USAGE AUDIT (parallel · 3 haiku analysts)
  A. MongoDB agent_runs frequency + cost per agent, last 90d
  B. session_logs by_agent breakdown, tasks completed per agent
  C. git log commit-attribution across medium-agent-factory
  → docs/research/agent-usage-heatmap.md (KILL / MERGE / KEEP / ADD table)

Wave 1 — FOUNDATION (sequential · architect + adversarial)
  architect: design shared cartridge template + task-brief/return schema
  adversarial: attack the template before any agent is rewritten
  → docs/superpowers/specs/agent-cartridge-v2.md

Wave 2 — CORE EXPERTS (parallel · 5 drafters)
  drafter-A → llmops-expert.md
  drafter-B → backend-expert.md
  drafter-C → frontend-expert.md
  drafter-D → devops-expert.md
  drafter-E → architect.md

Wave 3 — SUPPORT + NEW AGENTS (parallel · 5 drafters)
  drafter-F → adversarial.md (absorbs security-reviewer)
  drafter-G → validate.md (rewrite with new cartridge)
  drafter-H → researcher.md + scraper.md rewrites
  drafter-I → NEW prompt-engineer.md
  drafter-J → NEW eval-writer.md + sme-reviewer.md
  → Archive killed agents to ~/.claude/agents/archive/2026-07-09-v1/

Wave 4 — MASTER PROMPT + PROJECT SYNC (sequential)
  drafter → rewrite CLAUDE.md ≤200 lines
  drafter → rewrite medium-agent-factory/AGENTS.md as canonical cartridge
  Codex /codex:adversarial-review --fresh on the whole diff

Wave 5 — VALIDATION (parallel · Track A + Track B)
  Track A: meta-evals on llmops-expert, backend-expert, architect
  Track B: field test — one full medium-factory pipeline run,
           baseline vs new, Codex reviews both
  → Merge worktree → ~/.claude/agents/ only if all gates green
```

Total cost estimate: ~$3-5 API tokens across Waves 0 + 5. Everything else is prompt-writing (cheap).
Total time estimate: ~3-4 hours single session, or 2 sessions if splitting at Wave 3/4.

---

## 4. Detailed design

### 4.1 CLAUDE.md thin router (target: 120-140 lines)

**What stays in CLAUDE.md:**

```
1. ROLE                       (5 lines)
2. QUICK START                (10 lines)
3. NON-NEGOTIABLE RULES       (30 lines)
   - parallel-agents-minimum-3
   - codex-every-sprint
   - SDD-mandatory
   - push-after-commit
   - TDD
   - Docker-first
   - shell-run-discipline
4. AGENT ROUTING (thin)       (15 lines)  — "task pattern → agent name" only
5. CORE RULES                 (10 lines)  — secrets, IaC, MCP.json, naming
6. WINDOWS ENV                (5 lines)
7. SESSION MANAGEMENT         (15 lines)  — /compact policy, /goal, /rewind
8. TECH STACK POINTERS        (25 lines)  — one line each, all reference .claude/rules/
9. .gitignore defaults        (5 lines)
```

**What moves OUT of CLAUDE.md:**

| Currently in CLAUDE.md | Moves to |
|-----------------------|----------|
| Group of Experts roster (14-row table) | `~/.claude/agents/README.md` (auto-generated by Wave 3) |
| Standard workflow teams block | `~/.claude/rules/workflows.md` |
| Parallel Wave pattern detail | `superpowers:dispatching-parallel-agents` skill body |
| SDD routing table | `~/.claude/skills/superpowers/subagent-driven-development/SKILL.md` companion |
| Codex cadence + failure modes | Each agent's own "Review contract" section |
| Sprint status tree spec | `~/.claude/rules/sprint-status.md` |
| Hooks technical detail | `~/.claude/rules/hooks.md` |
| Automation (headless) section | `~/.claude/skills/headless-automation/SKILL.md` |

**Token math per session:**
- Current: ~2,400 tokens per turn (391-line CLAUDE.md loaded every message)
- Target: ~950 tokens per turn (~130-line CLAUDE.md)
- Savings across a 100-turn session: ~145K tokens ≈ $0.44 on Sonnet.

### 4.2 Expertise cartridge template (10 slots)

Every agent follows this structure. Target: 120-180 lines per agent.

```
─── YAML frontmatter ───
name:        <agent>
description: <what triggers this agent — verb-forward, ≤2 sentences>
model:       claude-<full-id>          ← normalized: no bare "sonnet"
maxTurns:    <8-30 based on scope>

─── Slot 1 — ROLE (2-3 lines) ───
Distinctive expertise. NOT "senior X engineer". Name the technique
the agent owns exclusively.

─── Slot 2 — HYDRATION PROTOCOL (5-10 lines) ───
Files to read BEFORE responding. Project-specific.

─── Slot 3 — TRIGGER HEURISTICS (5-10 lines) ───
"When you see X, do Y." Domain-specific decision rules.

─── Slot 4 — DOMAIN PATTERNS (embedded few-shot code, 20-40 lines) ───
2-4 canonical code patterns for the domain.

─── Slot 5 — HANDOFF CONTRACT (5-8 lines) ───
INPUT: task-brief fields consumed
OUTPUT: return-schema this agent produces

─── Slot 6 — REVIEW CONTRACT (3-5 lines) ───
codex_mode: {blocking | concurrent | skip}
How Codex adversarial-review findings feed back in.

─── Slot 7 — SELF-CRITIQUE CHECKLIST (5 lines) ───
3-5 questions the agent asks itself before returning output.
One-shot, not looped.

─── Slot 8 — ESCALATION TRIGGERS (3-5 lines) ───
When to hand off to a different expert.

─── Slot 9 — WHAT YOU DO NOT DO (3-5 lines) ───
Explicit domain boundaries.

─── Slot 10 — COST BUDGET (2-4 lines) ───
max_tokens_per_invocation, max_llm_calls, max_usd_per_run.
Enforced via base.AgentTokenTracker → MongoDB agent_runs.
```

### 4.3 Roster consolidation

Decision matrix applied to Wave 0 data:

```
IF invocations_90d < 5 AND commits_attributed < 2       → KILL
IF invocations_90d in [5-20] AND role duplicates another → MERGE
IF invocations_90d > 20                                  → KEEP + rewrite
IF role not covered but tasks exist in project           → ADD
```

Baseline hypothesis (Wave 0 confirms or overrides):

| Verdict | Agent | Reasoning |
|---------|-------|-----------|
| KEEP (7) | `architect`, `llmops-expert`, `backend-expert`, `frontend-expert`, `devops-expert`, `adversarial`, `validate` | Core loop — used every sprint |
| KEEP (3) | `researcher`, `scraper`, `drafter` | Cross-cutting + `drafter` remains as SDD default-fallback implementer per memory `feedback_sdd_agent_routing.md` — do not remove |
| MERGE | `jsdoc` → `frontend-expert` | Docs are ONE slot of the domain expert |
| MERGE | `security-reviewer` → `adversarial` | Security IS adversarial thinking |
| MERGE | `analyst` → `adversarial` (read-only mode) | Same skill, narrower scope |
| **CONDITIONAL** | `integrator` → keep separate IF Wave 0 shows ≥ 5 orchestrator.py commits/month; otherwise MERGE → `llmops-expert` | Data-driven — memory does not deprecate integrator |
| KILL | `lain-specialist` | Already deprecated in memory |
| ADD | `prompt-engineer` | Owns prompts/*.txt + G-Eval rubric + few-shot injection |
| ADD | `eval-writer` | Owns evals/datasets/*.jsonl + deepeval Layer 1/2/3 |
| ADD | `sme-reviewer` | Subject-matter expert for LLMOps content, fact/tone review |

**Target final roster: 13-14 experts** (from 14, sharper — 3 merged/killed, 3 added, 1 conditional). Exact count depends on Wave 0 verdict on `integrator`.

If Wave 0 contradicts hypothesis (e.g., `analyst` shows 40 invocations/month), the data wins.

### 4.4 Handoff contract + hydration

**Task-brief schema (Architect → Expert):**

```yaml
task_id: sprint-N-task-M
agent: <agent-name>
depends_on: [task-K]                    # [] = parallel-eligible
files_to_read:
  - <hydration files>
files_you_will_write:                   # exclusive claim — DAG safety
  - <output files>
files_you_MUST_NOT_touch:               # blast-radius fence
  - <boundary files>
state_keys_you_read: [...]
state_keys_you_write: [...]
success_criteria:
  - <bulleted list>
cost_budget: {max_tokens, max_llm_calls, max_usd}
review_gate: [codex_adversarial, adversarial_subagent]
```

**Return schema (Expert → Architect):**

```yaml
task_id: sprint-N-task-M
status: completed | blocked | escalated
files_written: [...]
files_modified: [...]
state_keys_added: [...]
tests_added: [...]
lint_status: clean | dirty
codex_findings_addressed: [...]
risks: [...]
escalations:
  - target: <agent-name>
    reason: <string>
    action_required: <string>
cost_actual: {tokens_in, tokens_out, usd}
```

**Parallel-safety DAG rule:** Two experts run in parallel iff all three hold:

1. `files_you_will_write` sets are disjoint
2. `state_keys_you_write` sets are disjoint
3. Neither `depends_on` the other

**Hydration protocol per expert:**

| Expert | Files read on kickoff (always) |
|--------|-------------------------------|
| all | `~/.claude/agents/README.md` + task-brief |
| all on medium-factory | `+ medium-agent-factory/AGENTS.md` |
| architect | `+ orchestrator.py` (state schema top 60 lines) |
| llmops-expert | `+ orchestrator.py` + `.claude/rules/python/langchain.md` |
| backend-expert | `+ backend/app/main.py` + `backend/app/config.py` |
| frontend-expert | `+ frontend/src/app/layout.tsx` + `frontend/package.json` |
| devops-expert | `+ docker-compose.yml` + `.github/workflows/ci.yml` |
| prompt-engineer | `+ backend/prompts/*.txt` inventory + `evals/datasets/*.jsonl` |
| eval-writer | `+ backend/evals/` + langchain rules |
| adversarial | `+ recent Codex findings JSON` |

**Communication channel:** Agents never talk directly. All coordination flows through the task-brief, the return schema, and the `.superpowers/sdd/progress.md` durable ledger.

### 4.5 Codex + Superpowers integration inside each agent

**Codex mode per agent (declared in Slot 6):**

| Mode | When | Behavior |
|------|------|----------|
| codex-blocking | orchestrator.py, auth, secrets, IaC | agent WAITS for /codex:adversarial-review --wait |
| codex-concurrent | standard changes | agent commits, fires --background, next task starts |
| codex-skip | TSDoc / prose-only .md edits | no Codex review |

**Codex findings routing (canonical, lives in `~/.claude/rules/codex-routing.md`):**

| Codex finding category | Owner |
|-----------------------|-------|
| Security / OWASP / secrets | adversarial |
| Cost / rate-limit / DB N+1 | backend-expert |
| LangGraph state race / node contract | llmops-expert |
| Docker / CI / deploy regression | devops-expert |
| React re-render / hook dep / a11y | frontend-expert |
| Prompt injection / prompt drift | prompt-engineer |
| Eval dataset gap / metric threshold | eval-writer |
| Fact accuracy / tone drift | sme-reviewer |

**Superpowers skill routing per agent:**

| Agent | Always invokes | Conditionally |
|-------|---------------|---------------|
| architect | brainstorming, writing-plans | dispatching-parallel-agents |
| llmops-expert | test-driven-development | systematic-debugging |
| backend-expert | test-driven-development | verification-before-completion |
| frontend-expert | test-driven-development | Playwright visual demo (sprint close) |
| devops-expert | verification-before-completion | systematic-debugging on CI red |
| adversarial | receiving-code-review | — |
| prompt-engineer | brainstorming | — |
| eval-writer | writing-plans | — |
| validate | — | — |

**Reconciliation when Codex + Superpowers findings collide:**

| Codex | Superpowers | Verdict |
|-------|-------------|---------|
| BLOCKER | any | block |
| any | BLOCKER | block |
| HIGH | LOW on same file:line | HIGH (defensive) |
| duplicate | duplicate | dedupe by file:line |
| conflict | conflict | escalate to adversarial for arbitration |

### 4.6 Validation gates

**Track A — Meta-evals** at `~/.claude/agents/evals/`. Only 3 pipeline-driving experts.

```
~/.claude/agents/evals/
├── run.py            # runner
├── rubric.py         # slot-coverage + correctness + cost scorer
├── llmops-expert.jsonl        # 8 realistic tasks
├── backend-expert.jsonl       # 8 realistic tasks
└── architect.jsonl            # 8 decomposition tasks
```

**Rubric weights:** slot_coverage 30% (deterministic regex) + correctness 50% (deepeval G-Eval Sonnet judge) + cost 20% (actual vs budget).

**Threshold:** each expert scores ≥ 0.80 aggregate on their 8 tasks.

**Track B — Field test** on medium-factory:

```
Step 1  cp -r ~/.claude/agents ~/.claude/agents-backup-v1   (Windows-safe copy, no symlink)
Step 2  git worktree add ~/.claude-agents-v2 (draft new cartridges here)
Step 3  cd medium-agent-factory
        git checkout -b sprint/agent-v2-fieldtest
Step 4  BASELINE run — old agents still in ~/.claude/agents/.
        Capture quality_score, cost, wall_clock, tokens, blockers.
Step 5  cp -r ~/.claude-agents-v2/agents/* ~/.claude/agents/  (overwrite with new cartridges)
Step 6  NEW run — same input, new agents. Capture same metrics.
Step 7  /codex:adversarial-review --fresh --background on both diffs
Step 8  Compare → merge decision. On failure: cp -r ~/.claude/agents-backup-v1/* ~/.claude/agents/
```

**Pass criteria (all four must hold):**

| Metric | Threshold |
|--------|-----------|
| quality_score(new) − baseline | ≥ −0.03 |
| cost(new) / baseline | ≤ 1.10 |
| wall_clock(new) / baseline | ≤ 1.15 |
| codex_blockers(new) − baseline | ≤ 0 |

**Merge decision:**

```
IF meta-eval pass ≥ 0.80 on all 3 pipeline experts
AND field test passes all 4 criteria
AND Codex adversarial on the agent diff has zero BLOCKERs
THEN merge worktree → ~/.claude/agents/
     archive baseline in ~/.claude/agents/archive/2026-07-09-v1/
ELSE hold in worktree, iterate on failing agents only
```

**Regression discipline (future):** Every future edit to `~/.claude/agents/*.md` re-runs that agent's meta-eval before commit is allowed.

---

## 5. Sprint plan (concrete tasks per wave)

### Wave 0 — Usage audit (parallel · 3 analysts · haiku)

- **Task 0.1**: analyst-A queries MongoDB `agent_runs` collection, groups by `agent_name`, aggregates invocation count + total cost + avg tokens per invocation for last 90 days. Outputs to `docs/research/agent-usage-heatmap-mongodb.md`.
- **Task 0.2**: analyst-B parses `~/.claude/session_logs/*.json` (or MongoDB `session_logs`), sums `by_agent` breakdown per session, ranks agents by tasks-completed. Outputs to `docs/research/agent-usage-heatmap-sessions.md`.
- **Task 0.3**: analyst-C runs `git log --all --format='%an %s'` in medium-agent-factory + master-prompt repos, greps for agent names in commit messages, produces commit-attribution table. Outputs to `docs/research/agent-usage-heatmap-git.md`.
- **Merge**: architect reads all 3 heatmaps, produces final KILL/MERGE/KEEP/ADD verdict per agent → `docs/research/agent-usage-heatmap.md`.

### Wave 1 — Foundation (sequential · architect + adversarial)

- **Task 1.1**: architect writes the cartridge template spec at `docs/superpowers/specs/agent-cartridge-v2.md` (formalizes the 10 slots from Section 4.2 of this doc, with 1 concrete example agent as reference).
- **Task 1.2**: adversarial reviews the spec — attacks the schema, finds ambiguity, proposes fixes. Rating: BLOCKER / HIGH / MEDIUM / LOW.
- **Task 1.3**: architect revises spec until adversarial rates zero BLOCKERs.

### Wave 2 — Core experts (parallel · 5 drafters)

Each drafter dispatch uses the CURRENT `drafter` agent (still alive until end of Wave 3) to write the NEW cartridge files into the worktree. The drafter role during this sprint is a text-editor, not an implementer. All 5 dispatched in one message per parallel-agent rule.

- **Task 2.1**: llmops-expert.md → drafter reads `AGENTS.md` + `orchestrator.py` + current llmops-expert.md, produces new cartridge. No RED tests (prompt is a text file, not code).
- **Task 2.2**: backend-expert.md → same
- **Task 2.3**: frontend-expert.md → same
- **Task 2.4**: devops-expert.md → same
- **Task 2.5**: architect.md → same

### Wave 3 — Support + new agents (parallel · 5 drafters)

- **Task 3.1**: adversarial.md rewritten, absorbs security-reviewer's OWASP checklist as Slot 4 pattern.
- **Task 3.2**: validate.md rewritten with new cartridge.
- **Task 3.3**: researcher.md + scraper.md rewritten.
- **Task 3.4**: prompt-engineer.md CREATED — new agent, owns prompts/*.txt versioning, G-Eval rubric authoring, few-shot exemplar injection.
- **Task 3.5**: eval-writer.md + sme-reviewer.md CREATED.
- **Archive step (sequential, after all Wave 3 tasks)**: move `lain-specialist.md`, `jsdoc.md`, `security-reviewer.md`, `analyst.md` to `~/.claude/agents/archive/2026-07-09-v1/`. `integrator.md` archived ONLY if Wave 0 verdict is MERGE. `drafter.md` is NEVER archived — it remains as SDD default fallback per memory.

### Wave 4 — Master prompt + project sync (sequential)

- **Task 4.1**: drafter rewrites CLAUDE.md following the Section 4.1 outline. Target: 120-140 lines.
- **Task 4.2**: drafter creates `~/.claude/agents/README.md` — auto-generated roster from the new cartridges (parsed from YAML frontmatter).
- **Task 4.3**: drafter creates `~/.claude/rules/codex-routing.md` and `~/.claude/rules/workflows.md` (contents migrated from CLAUDE.md).
- **Task 4.4**: drafter rewrites `medium-agent-factory/AGENTS.md` as the canonical project cartridge — pipeline nodes table, PipelineState schema, prompt inventory, referenced by every hydration protocol.
- **Task 4.5**: `/codex:adversarial-review --fresh` on the whole diff. Zero BLOCKERs required.

### Wave 5 — Validation (parallel · Track A + Track B)

- **Track A (eval-writer + drafter)**: build `~/.claude/agents/evals/` scaffolding (runner + rubric + 24 JSONL cases), run evals, produce pass/fail report.
- **Track B (llmops-expert running in medium-factory)**: execute field test protocol (Section 4.6), capture baseline + new metrics, produce comparison report.
- **Merge gate**: If both tracks green + Codex clean, merge worktree → `~/.claude/agents/`. Otherwise hold in worktree and iterate.

---

## 6. Done definition

- [ ] `~/.claude/agents/` contains 13-14 rewritten cartridges (7 core + 3 utility [researcher, scraper, drafter] + 3 new [prompt-engineer, eval-writer, sme-reviewer] + optional `integrator` if Wave 0 keeps it)
- [ ] Old agents archived at `~/.claude/agents/archive/2026-07-09-v1/`
- [ ] `CLAUDE.md` at 120-140 lines (`wc -l` verified)
- [ ] `medium-agent-factory/AGENTS.md` refactored as canonical project cartridge
- [ ] `~/.claude/agents/README.md` auto-generated roster in place
- [ ] `~/.claude/agents/evals/` with 3 meta-eval datasets + runner passing ≥ 0.80
- [ ] Field test on medium-factory: all 4 Track B thresholds green
- [ ] `/codex:adversarial-review --fresh` on entire diff: zero BLOCKERs
- [ ] Sprint report committed to `docs/superpowers/specs/2026-07-09-agent-prompt-upgrade-design.md` (this doc)
- [ ] MongoDB `session_logs` entry via session-autopilot at sprint close

---

## 7. Out of scope

- Skills authoring (`~/.claude/skills/*`)
- MCP servers configuration
- Superpowers plugin internals
- Codex plugin binary (only wire the cadence)
- medium-agent-factory pipeline nodes themselves
- Frontend Playwright suite

---

## 8. Risks + mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Wave 0 usage data unavailable | Medium | Fallback: git-log commit-attribution + memory audit; hypothesis holds |
| Meta-eval judge scores noisy | Medium | 3-run mean per task; alert if std-dev > 0.10 |
| Field test regression is topic-dependent | Medium | Run field test on 2 topics; reduces variance |
| Codex rate-limits on the big diff | Low | Split diff into 3 chunks, review each independently |
| New agents break in-flight sprint 19 | Medium | Worktree isolation; old agents stay live until Wave 5 merge |
| sme-reviewer lacks clear ground truth | High | Wave 3 drafter must specify: reads recent 3 posts + `docs/HOW-IT-WORKS.md` |
| prompt-engineer + eval-writer overlap with llmops-expert | High | Section 4.4 `files_you_MUST_NOT_touch` enforcement; Wave 1 adversarial reviews for overlap |

---

## 9. Rollback plan

Because everything lives in a git worktree, we can stop at any wave and revert cleanly.

| Stop after | Retained value |
|-----------|---------------|
| Wave 0 | Usage heatmap → reference doc, no agent changes |
| Wave 1 | Cartridge template spec → keep, apply manually later |
| Wave 2 | 5 core experts rewritten → mergeable subset |
| Wave 3 | All 13-14 experts rewritten → mergeable |
| Wave 4 | CLAUDE.md + AGENTS.md refactored → merge if Codex clean |
| Wave 5 | Full validation → merge with confidence |

Full revert: `git worktree remove ~/.claude-agents-v2` — original `~/.claude/agents/` untouched throughout.

---

## 10. References

**External research (integrated from Claude's internal knowledge; researcher agent dispatched during brainstorm did not persist a report — findings verified against Claude's training data):**
- Anthropic prompt engineering guide (docs.anthropic.com) — role framing + explicit output contracts + few-shot embedding
- Reflexion paper (Shinn et al., 2023) — one-shot self-critique reduces regressions ~10-15% on coding tasks; looped self-critique produces diminishing returns and cost blowup
- CrewAI + AutoGen + LangGraph — handoff-schema pattern; task-brief and return-schema as canonical inter-agent contract
- Anthropic Claude Code docs — model-per-role routing (haiku for read/lint, sonnet for write/review, opus for architecture)

**Internal memory (`MEMORY.md`):**
- `reference_group_of_experts.md` — current 14-agent roster
- `feedback_sdd_agent_routing.md` — SDD routing table
- `feedback_parallel_agents.md` — 5-max simultaneous agents rule
- `reference_token_efficiency_claude_code.md` — 200-line CLAUDE.md target
- `feedback_codex_plugin_usage.md` — Codex cadence rules
- `feedback_superpowers_sdd_skill.md` — SDD skill usage
- `project_medium_agent_factory.md` — project context

**Source files audited:**
- `Documents/github/claude-code-master-prompt/CLAUDE.md` (391 lines)
- `~/.claude/agents/architect.md`, `backend-expert.md`, `frontend-expert.md`, `llmops-expert.md`, `devops-expert.md`
- `medium-agent-factory/AGENTS.md` (pipeline nodes + support modules + prompt files tables)
- `.claude/rules/python/langchain.md` (LangGraph rules already extracted)

---

**Next step:** After user review of this doc, invoke `superpowers:writing-plans` to produce the executable implementation plan.
