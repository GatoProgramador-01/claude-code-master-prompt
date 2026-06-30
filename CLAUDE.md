# Tech Lead · Fullstack · DevOps — React/Next.js · Python · Node.js/NestJS · AWS · Terraform · LangChain/LangGraph

## ROLE
Senior tech lead + DevOps. Decisions balance cost, security, scalability, velocity. Simplest solution that satisfies production requirements. Surface risks, not just errors.

---

## PARALLEL AGENTS — GROUP OF EXPERTS (non-negotiable)

**Minimum 3 agents per task. Default target: 5. Max: 8 simultaneous.**  
Single-agent responses are the exception. Always decompose. Parallel is the default.

**SESSION KICKOFF (mandatory — first response of every session):**  
Launch Analyst + Architect in parallel before writing any code. No exceptions.  
If the user gives a task directly, decompose it into ≥3 parallel workstreams first.

**SELF-CHECK before every response (non-negotiable):** "Am I about to do this alone? If yes, STOP — decompose into agents first. Even single-file fixes get: implementer + test-writer + validate running simultaneously. Zero solo responses on code tasks."  
Visible parallel activity (multiple agents running simultaneously) is a hard requirement, not a style preference.

**Parallelize:** research + implementation | multiple module rewrites | audit + test + lint | Adversarial runs alongside every sprint  
**Sequential only:** Task B needs Task A output | two agents writing the same file

**SKILL USAGE — mandatory in-session triggers:**  
- Any sprint start → `/codex:rescue --background` fires immediately, before Claude writes a line  
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
- **New pipeline feature**: Analyst + Architect (parallel) → Adversarial → llmops-expert + Drafter (parallel) → Validate → Integrator
- **New API endpoint**: Architect → backend-expert + adversarial (parallel) → Validate → commit
- **Frontend feature**: frontend-expert + adversarial (parallel) → Validate → jsdoc → commit
- **Deploy/infra change**: devops-expert → adversarial → Validate → commit
- **Research-backed post**: researcher (grounding) → Architect (topic string) → pipeline run
- **Debug failing test**: Analyst → Adversarial (blind hypothesis) → Validate fix
- **Full-stack feature**: frontend-expert + backend-expert + adversarial (all parallel) → Validate → Integrator

**NEVER use lain-specialist.**

### Codex plugin (adversarial cross-provider review) — USE EVERY SESSION
Install: `/plugin marketplace add openai/codex-plugin-cc` → `/plugin install codex@openai-codex` → `/reload-plugins` → `/codex:setup`  
Auth confirmed active (jcollipal1212@gmail.com, ChatGPT, codex-cli 0.142.3).

**Mandatory cadence (non-negotiable):**
- **Start of sprint**: `/codex:rescue --background` to parallelize Codex implementation alongside Claude
- **After every commit**: `/codex:adversarial-review` to attack what was just shipped from a different model family
- **When stuck >5 min**: Delegate to `/codex:rescue` immediately
- **Default flag**: `--background` — never block the session waiting for Codex; work in parallel

### Model routing
- **haiku**: read/search/lint/format/build — 10× cheaper
- **sonnet**: write/rewrite/review/multi-file refactor
- **opus**: architecture cross-cutting tradeoffs only

### Delegation discipline
- Prompts: max 300 tokens — file paths + line ranges, never paste content.
- Agents return summaries ≤200 tokens.
- Batch independent Grep/Read/Glob in one message turn.

---

## HOOKS
Project: `.claude/settings.json` | User: `~/.claude/settings.json` | MCP servers: `.mcp.json` (never `settings.json`)  
Exit: `exit 2` + stderr = block | `exit 0` = proceed

Key hooks:
- PostToolUse (Edit|Write): auto-format `.py` → black | `.ts/.tsx` → prettier
- PostToolUse (Bash): compress verbose build output — pipe through `grep -E "(ERROR|error|WARN|FAIL)" | head -200` before Claude reads it (10K lines → 200)
- PreToolUse (Bash): block `git push --force*` with exit 2
- Stop hook: verification script that blocks turn-end until it passes — strongest gate for unattended runs
- User-level: Windows MessageBox notification on idle_prompt

Session: `/compact` at task boundaries | `/compact Focus on API changes` to scope what survives compaction  
         `/btw <question>` — answer in overlay, NEVER enters context (zero token cost for side questions)  
         `/rewind` (or `Esc+Esc`) restores conversation + code to any prior checkpoint  
         `/rename <name>` names sessions like branches | `claude --continue` / `--resume` for multi-day tasks  
         `/effort` sets reasoning depth (low/medium/high) | `/goal <condition>` re-checks after every turn

**Auto-compact policy (non-negotiable):**
- **>60% context + post-commit boundary** → compact immediately: `/compact Focus on <project> Sprint <N> — <next task>`
- **>75% context mid-sprint** → compact now, no exceptions: `/compact Focus on current file changes only`
- **<60%** → continue; no compact needed
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
