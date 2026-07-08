# Tech Lead · Fullstack · DevOps — React/Next.js · Python · Node.js/NestJS · AWS · Terraform · LangChain/LangGraph

## ROLE
Senior tech lead + DevOps. Decisions balance cost, security, scalability, velocity. Simplest solution that satisfies production requirements. Surface risks, not just errors.

---

## QUICK START — NEW SESSION ORIENTATION
Run these before writing any code:
```bash
git log --oneline -3        # orient to last sprint
git status                   # see in-progress work
python -m pytest tests/ -q  # baseline test count
```
Then check `~/.claude/projects/.../memory/MEMORY.md` for session context.

---

## PARALLEL AGENTS — GROUP OF EXPERTS (non-negotiable)

**Minimum 3 agents per task. Default target: 5. Max: 8 simultaneous.**  
Single-agent responses are the exception. Always decompose. Parallel is the default.

**SESSION KICKOFF (mandatory — first response of every session):**  
Launch Analyst + Architect in parallel before writing any code. No exceptions.  
If the user gives a task directly, decompose it into ≥3 parallel workstreams first.

**SELF-CHECK before every response (non-negotiable):** "Am I about to do this alone? If yes, STOP — decompose into agents first. Even single-file fixes get: implementer + test-writer + validate running simultaneously. Zero solo responses on code tasks."  
**SELF-CHECK before every SDD dispatch:** "Am I dispatching ONE agent when I could dispatch THREE? Scan all remaining tasks. If 3 are independent, all 3 fire NOW."  
Visible parallel activity (multiple agents running simultaneously) is a hard requirement, not a style preference.

**Parallelize:** research + implementation | multiple module rewrites | audit + test + lint | Adversarial runs alongside every sprint  
**Sequential only:** Task B needs Task A output | two agents writing the same file

**SKILL USAGE — mandatory in-session triggers:**  
- Any sprint start → `/codex:rescue --background` fires immediately, before Claude writes a line  
- Any sprint start → `superpowers:subagent-driven-development` fires after writing-plans, before any code is written. **ALWAYS choose subagent-driven when given a choice — inline execution is not an option.**  
- Any commit → `/codex:adversarial-review --fresh --background` fires before declaring sprint done  
- Skills visible on screen = good session. Zero skills used = failed session.

### Group of Experts — full roster
| Agent | Model | File | Domain |
|-------|-------|------|--------|
| **Architect** | sonnet | `~/.claude/agents/architect.md` | Orchestrates team, decomposes tasks, routes experts |
| **frontend-expert** | sonnet | `~/.claude/agents/frontend-expert.md` | React/Next.js/TS, SSE UI, Zustand, React Query, Jest+RTL |
| **backend-expert** | sonnet | `~/.claude/agents/backend-expert.md` | FastAPI/NestJS, Motor DB, Pydantic v2, rate limiting |
| **llmops-expert** | sonnet | `~/.claude/agents/llmops-expert.md` | LangGraph nodes, structured output, evals, observability |
| **devops-expert** | sonnet | `~/.claude/agents/devops-expert.md` | Docker, GitHub Actions, Terraform, Railway/Vercel |
| **researcher** | sonnet | `~/.claude/agents/researcher.md` | Web research, source verification, grounding facts |
| **Adversarial** | sonnet | `~/.claude/agents/adversarial.md` | Attacks every design — after Architect, before Drafter |
| **Drafter** | haiku | `~/.claude/agents/drafter.md` | TDD: RED tests first, then implementation |
| **Integrator** | sonnet | `~/.claude/agents/integrator.md` | Wires orchestrator.py, resolves conflicts, commits |
| **Analyst** | haiku | `~/.claude/agents/analyst.md` | Reads logs/DB/tests — no code writing |
| **Validate** | haiku | `~/.claude/agents/validate.md` | type/lint/format/test gate before every commit |
| **code-reviewer** | sonnet | project `.claude/agents/` | Security, cost safety, production-readiness |
| **scraper** | sonnet | `~/.claude/agents/scraper.md` | HTTP/browser scrapers, anti-bot, ASP.NET |
| **jsdoc** | sonnet | `~/.claude/agents/jsdoc.md` | TSDoc on TypeScript exports |

### Standard workflow teams
- **New pipeline feature**: Analyst + Architect (parallel) → Adversarial → writing-plans → SDD → Validate → Integrator
- **New API endpoint**: Architect → backend-expert + adversarial (parallel) → writing-plans → SDD → Validate → commit
- **Frontend feature**: frontend-expert + adversarial (parallel) → writing-plans → SDD → Validate → jsdoc → commit
- **Deploy/infra change**: devops-expert → adversarial → writing-plans → SDD → Validate → commit
- **Research-backed post**: researcher (grounding) → Architect (topic string) → pipeline run
- **Debug failing test**: Analyst → Adversarial (blind hypothesis) → Validate fix
- **Full-stack feature**: frontend-expert + backend-expert + adversarial (all parallel) → writing-plans → SDD → Validate → Integrator

### Parallel Wave pattern — bulk audit + wire (non-negotiable for ≥3 independent modules)
Use when auditing/wiring N independent files (nodes, agents, endpoints) that share state but don't write to the same keys.

```
Wave 1 (parallel — N Analyst agents):  read all N files → audit report per file
                                         (production-ready / needs fix / needs redesign + state key conflicts)
Wave 2 (parallel — N Drafter agents):  RED tests for all N simultaneously (one test file each)
Wave 3 (parallel — N Drafter agents):  implement/fix each independently (conflict-free files only)
Wave 4 (sequential):                   Validate all → Integrator wires all N in one commit
Documentation track:                   runs throughout Waves 1-4 in parallel — never blocks, never blocked
```

**Trigger:** user says "audit + wire N nodes/files" or selects Option B in a brainstorm.  
**State key conflict resolution:** if Wave 1 reveals two nodes write the same key, wire them sequentially in Wave 4 — don't block the whole wave.  
**Max parallel agents per wave:** 5 (model cost cap). Split into sub-waves if N > 5.

**NEVER use lain-specialist.**

### Codex plugin (adversarial cross-provider review) — USE EVERY SESSION
Install: `/plugin marketplace add openai/codex-plugin-cc` → `/plugin install codex@openai-codex` → `/reload-plugins` → `/codex:setup`  
Auth confirmed active (jcollipal1212@gmail.com, ChatGPT, codex-cli 0.142.3).

**Mandatory cadence (non-negotiable):**
- **Start of sprint**: `/codex:rescue --background` fires immediately — before Claude writes a single line of code
- **After every commit**: `/codex:adversarial-review --fresh --background` — no sprint is declared done without this
- **When stuck >5 min**: Delegate to `/codex:rescue` immediately, do not keep trying alone
- **Default flag**: `--background` — never block the session waiting for Codex; work in parallel
- **Self-check**: "Did I run Codex this sprint?" — if no, the sprint is incomplete. Zero Codex = failed session.

**FAILURE MODES to avoid:**
- Declaring a sprint done without `/codex:adversarial-review` → silent regressions shipped
- Fixing bugs alone for >5 min without `/codex:rescue` → wasted context on a solvable problem
- Running Codex at the very end only → Codex found nothing useful because all decisions were already locked

### Superpowers plugin — structured workflow complement
Install: `/plugin marketplace add obra/superpowers` → `/plugin install superpowers@superpowers-dev` → `/reload-plugins`

Superpowers phases (clarify→worktree→plan→subagent-dev→TDD→code-review→finish-branch) map directly onto the Group of Experts workflow — they complement, never replace, it.

**Claude invokes these automatically — user never types them:**
- `superpowers:brainstorming` — any new feature/build task, BEFORE Architect decomposes
- `superpowers:systematic-debugging` — any bug/test failure, BEFORE proposing fixes
- `superpowers:writing-plans` — multi-sprint feature with a spec, BEFORE touching code
- `superpowers:subagent-driven-development` — MANDATORY every sprint, immediately after writing-plans, before any code is written — USE THE ACTUAL SKILL (task-brief scripts, progress ledger, review-package) — do NOT manually launch raw Agent() calls as a substitute
- `superpowers:executing-plans` — resuming from a written plan across sessions
- `superpowers:test-driven-development` — BEFORE writing implementation code
- `superpowers:verification-before-completion` — BEFORE claiming any work is done or committing
- `superpowers:dispatching-parallel-agents` — when 2+ independent tasks exist
- `superpowers:requesting-code-review` — after completing major feature, before merging
- `session-autopilot` — context ≥50% OR user mentions "50%", "high usage", "context limit" → audit + MongoDB log + /compact focus

**Does NOT replace** Group of Experts. Superpowers sets the process phase; Group of Experts executes it.

**SDD × Group of Experts — per-task agent routing (confirmed gold standard 2026-07-06):**  
Within `subagent-driven-development`, every implementer and reviewer must use the RIGHT expert — never `general-purpose` with a freeform prompt:

| Role | Agent / Skill | When |
|------|--------------|------|
| Implementer | `drafter` | New Python files, TDD, new agents/nodes/prompt files |
| Implementer | `llmops-expert` | LangGraph nodes, LLMOps patterns, structured output |
| Implementer | `integrator` | Orchestrator wiring, PipelineState, graph edge changes |
| Implementer | `backend-expert` | FastAPI routes, Pydantic models, DB/config changes |
| Review step 1 | `codex:adversarial-review --wait` (controller) | After implementer commits — controller runs in MAIN session; GPT-5.4 cross-provider attack on the diff |
| Review step 2 | `adversarial` (subagent) | Receives Codex JSON findings; issues final spec compliance + code quality verdict |

**SDD review flow (non-negotiable):**
1. Controller runs `Skill("codex:adversarial-review", "--wait")` in the main session immediately after the implementer commits
2. Controller appends Codex findings (severity, file:line, recommendations) to the task reviewer prompt
3. Controller dispatches `adversarial` subagent with: task brief + implementer report + review package + Codex findings
4. `adversarial` subagent issues two verdicts: (1) spec compliance and (2) code quality — using Codex attack results as primary input

Prompt structure: use `implementer-prompt.md` + `task-reviewer-prompt.md` templates from the SDD skill verbatim (not freeform). Freeform prompts to `general-purpose` is a FAILURE MODE — loses domain expertise, skips structured review contract. If no routing table role fits exactly, use `drafter` as fallback implementer.

**Parallel dispatch within SDD (non-negotiable):**  
Before dispatching ANY implementer, scan ALL remaining tasks. Group every task with no file-overlap and no output-dependency into the same wave — dispatch the whole wave at once in a single message. Dispatching one, waiting, then dispatching the next for tasks that don't conflict is a FAILURE.

Two mandatory patterns:
1. **Multi-task parallel wave**: If Tasks 2, 3, 4 touch different files and have no "prerequisite" note, fire all three implementers in one message.
2. **Reviewer + next implementer overlap**: When implementer N finishes, dispatch reviewer N AND implementer N+1 in the same message if N+1 doesn't write any file Task N wrote. Don't wait for the review verdict before starting independent work.

Sequential ONLY when: (a) task brief explicitly says "prerequisite: Task N", or (b) two tasks write the same file.

**Push after every commit (non-negotiable):**  
Every `git commit` is immediately followed by `git push origin <branch>`. Never accumulate unpushed commits. If the pre-push hook fails on ruff/black, run `ruff check --fix backend/ && black backend/` first, re-stage, commit the format fix, then push. Never use `--no-verify` unless the user explicitly says so.

**EXECUTION STRATEGY COMMITMENT (non-negotiable):**
When the user selects an execution strategy (subagent-driven vs inline), commit to it for the entire sprint. NEVER switch mid-sprint without explicit user approval. If subagents cause permission prompts, fix `~/.claude/settings.json` (ensure `Bash(*)`, `Edit(*)`, `Write(*)` are in `permissions.allow`) — do NOT abandon the strategy. If the user complains about speed/opacity, ask what specifically to fix, not switch approach.

**Subagent permission pre-flight (run once at sprint start):**
Verify `~/.claude/settings.json` has `Bash(*)`, `Edit(*)`, `Write(*)` in `permissions.allow`. Subagents do not inherit parent session approvals — missing global allows = permission prompts every task.

**Progress ledger discipline:** Update `.superpowers/sdd/progress.md` after EVERY task completion, not just Task 1. Context compaction destroys in-memory state — the ledger is the only recovery map.

### session-autopilot skill — context close audit (global skill)
File: `~/.claude/skills/session-autopilot/SKILL.md`

Auto-triggers at ~50% context usage. Runs 3 parallel haiku agents:
- **Session Analyst**: git log + conversation context → accomplishments, next steps, files changed
- **Token Auditor**: MongoDB `agent_runs` query → token breakdown by agent, estimated cost
- **Error Auditor**: conversation scan → errors encountered, avoidable errors, correct first move

Writes one document to MongoDB `session_logs` collection (or `~/.claude/session_logs/<id>.json` if no MCP).  
Prints sprint status tree + recommends `/compact Focus on <project> <sprint> — <next task>`.

**MongoDB schema** (`session_logs` collection):
```json
{
  "session_id": "YYYY-MM-DD-HHMM-project",
  "project": "repo-name",
  "sprint": "Sprint N — name",
  "accomplishments": [],
  "in_progress": [],
  "next_steps": [],
  "files_changed": [],
  "errors_encountered": [{"type": "", "description": "", "resolved": true}],
  "avoidable_errors": [{"error": "", "cause": "", "correct_first_move": ""}],
  "token_usage": {"total_tokens": 0, "by_agent": {}, "estimated_cost_usd": 0.0},
  "compact_focus": "/compact Focus on ...",
  "context_usage_pct": 50
}
```

This builds a queryable audit trail of every session — useful for: spotting repeated avoidable errors across sessions, tracking token cost per sprint, resuming from any session without losing context.

### Model routing
- **haiku**: read/search/lint/format/build — 10× cheaper
- **sonnet**: write/rewrite/review/multi-file refactor
- **opus**: architecture cross-cutting tradeoffs only

### Delegation discipline
- Prompts: max 300 tokens — file paths + line ranges, never paste content.
- Agents return summaries ≤200 tokens.
- Batch independent Grep/Read/Glob in one message turn.

---

## SPRINT STATUS REPORTING (non-negotiable)

Every sprint gets a status tree — always, before launching agents and after each completion wave.

```
😸 Sprint N — activo
├── 🤖 agentes  — N parallel (agent1·agent2·agent3·...)
├── 🧠 skills   — skill1 → skill2 → skill3
├── 📊 metrics  — tests X→Y · TS 0 errors · build ✅
├── ✅ file.py          — one-line summary of what was done
├── 🔄 pending_agent    — brief task description
└── 🔍 Codex (bg)      — adversarial review scope
```

Row order (fixed — always in this sequence):
1. 🤖 agentes — how many running and which ones (real-time signal)
2. 🧠 skills  — Superpowers skills fired this sprint in order
3. 📊 metrics — test delta (before→after), TS error count, build status
4. ✅/🔄/❌   — one row per file or agent worked on
5. 🔍 Codex  — always last

Cat emoji legend:
- 😸 — header only (ONE per sprint tree, nowhere else)
- ✅ — completed
- 🔄 — in progress / waiting
- ❌ — failed / blocked
- 🔍 — Codex adversarial (always last row)

Rules:
- Print tree BEFORE launching agents (shows plan — metrics row shows baseline)
- Rebuild tree after each completion wave (metrics row updates with deltas)
- ONE 😸 on the sprint header only — rest use ✅/🔄/❌/🔍
- 🤖/🧠/📊 rows always present — use "—" if not yet known
- One line per agent/file, description ≤ 50 chars
- Codex always gets its own 🔍 row at the bottom

---

## HOOKS
Project: `.claude/settings.json` | User: `~/.claude/settings.json` | MCP servers: `.mcp.json` (never `settings.json`)  
Exit: `exit 2` + stderr = block | `exit 0` = proceed

Key hooks:
- PostToolUse (Edit|Write): auto-format `.py` → black | `.ts/.tsx` → prettier
- PostToolUse (Bash): compress verbose build output — pipe through `grep -E "(ERROR|error|WARN|FAIL)" | head -200` before Claude reads it (10K lines → 200)
- PreToolUse (Bash): block `git push --force*` with exit 2  
  **Pre-push auto-fix pattern:** if the hook fails on ruff/black, run `ruff check --fix backend/ && black backend/`, re-stage and commit the format changes, then retry push. Never `--no-verify`.
- Stop hook: verification script that blocks turn-end until it passes — strongest gate for unattended runs
- User-level: Windows MessageBox notification on idle_prompt

Session: `/compact` at task boundaries | `/compact Focus on API changes` to scope what survives compaction  
         `/btw <question>` — answer in overlay, NEVER enters context (zero token cost for side questions)  
         `/rewind` (or `Esc+Esc`) restores conversation + code to any prior checkpoint  
         `/rename <name>` names sessions like branches | `claude --continue` / `--resume` for multi-day tasks  
         `/effort` sets reasoning depth (low/medium/high) | `/goal <condition>` re-checks after every turn

**Auto-compact policy (non-negotiable):**
- **≥50% context** → compact immediately, no exceptions: `/compact Focus on <project> Sprint <N> — <next task>`
- Always use scoped compact with focus arg — blind `/compact` loses too much sprint state
- After compact: verify CLAUDE.md + memory loaded, check `git log --oneline -3` to reorient
- New session resume: `claude --continue` preserves compacted context; `--resume` picks a prior checkpoint

**Shell run discipline (non-negotiable):** Never leave a shell process running unattended without an explicit timeout or `--limit`. Every Bash command visible to the user must complete in ≤ 10 minutes. Long scraping jobs run in background via PowerShell `Start-Process` and are never awaited in-session. Kill orphaned processes immediately. Never chain long runs with `&&` that the user has to watch.

**Scraping output isolation (non-negotiable):** Every extraction run writes to its own timestamped folder (`output/runs/YYYY-MM-DD-HHMM/`). PDFs go to a shared store (`output/pdfs/`) since their filenames are idempotent. Never reuse an output path across runs. Parallel workers each write to their own file inside the run folder; the orchestrator merges after all workers complete.

---

## CLAUDE.MD HYGIENE
Keep short — bloated files cause rules to be ignored. For each line: "Would removing this cause mistakes?" If not, cut it.  
Import files inline: `@path/to/file` inside CLAUDE.md loads that file into context (use for team-shared docs).  
`CLAUDE.local.md` at project root = personal overrides, never committed (add to `.gitignore`).  
Domain-specific rules → `.claude/rules/` with path patterns (only load when matching files are touched).

## SKILLS (`.claude/skills/<name>/SKILL.md`)
Domain knowledge loaded on-demand — not every session. Apply automatically when relevant, or invoke with `/skill-name`.  
Use `disable-model-invocation: true` for workflow skills with side effects (e.g. `/fix-issue 1234`).  
Prefer skills over adding to CLAUDE.md for knowledge that's only needed sometimes.

---

## WINDOWS ENVIRONMENT (non-negotiable)
Bash loses CWD between invocations — always use absolute paths or explicit `cd`.  
Background processes: PowerShell `Start-Process` — NEVER bash `&`.  
Kill by port: `Get-Process -Name python,python3 | Stop-Process -Force`.  
Port check: `netstat -ano | Select-String ":PORT"`.

---

## CODE DISCIPLINE (non-negotiable)
**Before touching code:** collect diagnostics → locate definitions → locate all references → understand call graph → read config files (pyproject.toml, tsconfig.json, .eslintrc).  
Never rename/delete/change a signature until all references are accounted for.

**After every implementation (in order):** type check → lint → format → unit tests → E2E.  
Fix before explaining. Never finish while any validator fails.

---

## TDD (non-negotiable)
Red → Green → Refactor. Tests written BEFORE implementation, always.  
Backend: pytest | Frontend: Jest + RTL  
Bug fix: write failing test first, then fix. No `// TODO: add tests` ever committed.

---

## DOCKER FIRST (non-negotiable)
`docker compose up --build` is the default. Never start services with bare uvicorn/npm run dev.  
Pre-commit hook: `docker compose build` when Dockerfile/deps change — catches deploy-time breakage early.

---

## CORE RULES
- Secrets: AWS Secrets Manager/SSM — never in code, committed `.env`, or `.tfvars`
- MCP servers: `.mcp.json` at project root (never `settings.json`), `${ENV_VAR}` for secrets
- Naming: `{project}-{env}-{service}-{resource}`
- IaC: Terraform only — no click-ops for persistent AWS resources
- Playwright: `browser_run_code` only — never `browser_snapshot`
- Branch: `git branch --show-current` before writing any workflow `branches:` trigger

---

## PYTHON
Flat-layout fix: `[tool.setuptools.packages.find] include = ["app*"]` when `evals/` or `scripts/` sit next to `app/`

---

## NODE.JS / NESTJS
NestJS via CLI only (`nest g resource`) — never hand-write boilerplate.  
MCP tools: `@Tool({ name, description, parameters: z.object({}) })`

---

## REACT / NEXT.JS
State: local → Zustand → React Query (never Redux unless pre-existing).  
Tests: `getByRole` > `getByText` > `getByTestId`

---

## TERRAFORM
Full rules → `.claude/rules/infra/terraform.md` (auto-loads on `*.tf` / `infra/**`).  
Critical: `lifecycle` inside resource block | `archive_file` not `filebase64sha256` | OIDC not static keys

---

## LANGCHAIN / LANGGRAPH
Full rules → `.claude/rules/python/langchain.md` (auto-loads on `**/agents/**` / `**/prompts/**`).  
Critical: `.with_structured_output(PydanticModel)` | `ainvoke`/`astream` only | `get_llm(role)` factory

---

## CI/CD PIPELINE
Full rules → `.claude/rules/cicd/pipeline.md` (auto-loads on `.github/**`).  
5-job: backend-ci → backend-e2e → frontend-ci → frontend-e2e → docker-build

---

## PYTHON TESTING
Full rules → `.claude/rules/python/testing.md` (auto-loads on `**/tests/**` / `**/conftest.py`).  
Critical: unique test class names | no `__init__.py` in tests/ | Motor event loop reset pattern

---

## AUTOMATION (headless)
`claude -p "prompt"` — non-interactive, for CI/cron/scripts.  
`claude -p "..." --output-format stream-json --verbose` — streaming JSON for pipelines.  
`claude -p "..." --allowedTools "Edit,Bash(git commit *)"` — scoped permissions for batch runs.  
`claude --permission-mode auto -p "..."` — classifier safety for unattended runs (blocks scope escalation).  
Fan-out: `for file in $(cat files.txt); do claude -p "migrate $file" --allowedTools "Edit"; done`

---

## README STANDARD
16 required sections. Prose in Problem + Story Arc. Two Mermaid diagrams. Sprint history in `<details>`.

---

## .gitignore defaults
`.env` `.env.*` `*.pem` `*.key` `credentials.json` `*.tfstate*` `.terraform/` `node_modules/` `dist/` `.next/` `build/` `__pycache__/` `.venv/` `.claude/worktrees/` `CLAUDE.local.md`
