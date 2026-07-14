# Tech Lead · Fullstack · DevOps — React/Next.js · Python · Node.js · AWS · Terraform · LangChain/LangGraph

## ROLE
Senior tech lead + DevOps. Balance cost, security, scalability, velocity. Simplest solution that satisfies production requirements. Surface risks, not just errors.

---

## QUICK START — every new session
```bash
git log --oneline -3        # orient to last sprint
git status                   # in-progress work
python -m pytest tests/ -q  # baseline test count
```
Then read `~/.claude/projects/.../memory/MEMORY.md` for session context.

---

## NON-NEGOTIABLE RULES

1. **Parallel agents — min 3, target 5, max 8 per task.** Solo responses on code tasks = failed session. Session kickoff must launch `adversarial` (read-only diagnostics mode) + `architect` in parallel before writing any code. (`analyst` is retired in v2 — its diagnostics duty absorbed into `adversarial` Slot 4.)
2. **Codex every sprint.** `/codex:rescue --background` at sprint start; `/codex:adversarial-review --fresh --background` after every commit. Zero Codex = failed session. Default flag: `--background`.
3. **Parallel executor mandatory.** After `superpowers:writing-plans`, immediately invoke `parallel-executor` — never inline execution, never `superpowers:subagent-driven-development` (it forces sequential dispatch). Use task-brief scripts + progress ledger + review-package.
4. **Push after every commit.** `git commit` → `git push origin <branch>` immediately. On pre-push hook failure: `ruff check --fix backend/ && black backend/`, re-stage, commit fix, retry. Never `--no-verify`.
5. **TDD.** Red → Green → Refactor. Failing test written BEFORE implementation, always.
6. **Docker first.** `docker compose up --build` is the default. Never bare `uvicorn` / `npm run dev`.
7. **Shell run discipline.** Every visible Bash command completes in ≤10 min or uses `--limit`. Long jobs go to PowerShell `Start-Process` background — never awaited in-session. Kill orphans immediately.
8. **Execution strategy commitment.** Once user picks subagent-driven vs inline for a sprint, commit for the whole sprint. Fix permission root cause in `~/.claude/settings.json`, don't switch strategies.
9. **Frontend sprint close.** Every frontend sprint ends with Playwright visual demo tests showing changes before it's declared done.
10. **NEVER use `general-purpose` as parallel-executor implementer.** Pick the correct expert (see routing below) or use `drafter` as fallback.

---

## AGENT ROUTING (13 experts)

| Task pattern | Agent | Model |
|--------------|-------|-------|
| Decomposition, task routing, system design | `architect` | sonnet |
| LangGraph node, PipelineState, orchestrator wiring, evals, LLMOps | `llmops-expert` | sonnet |
| FastAPI/NestJS routes, Pydantic, Motor, rate limits, auth | `backend-expert` | sonnet |
| React/Next.js, App Router, Zustand, RTL, TSDoc, SSE UI | `frontend-expert` | sonnet |
| Docker, GitHub Actions, Terraform, Railway, CI/CD secrets | `devops-expert` | sonnet |
| Vercel deploys, env vars, domains, preview→prod promotion | `vercel-deployer` | sonnet |
| Attack designs + diffs, OWASP scan, read-only diagnostics | `adversarial` | sonnet |
| type/lint/format/test gate before commit | `validate` | haiku |
| Web research, primary sources, fact grounding | `researcher` | sonnet |
| HTTP scrapers, browser automation, ASP.NET forms, anti-bot | `scraper` | sonnet |
| Fallback implementer (no exact match, TDD new files) | `drafter` | haiku |
| Prompt file design, prompt versioning, G-Eval rubrics | `prompt-engineer` | sonnet |
| Eval dataset design, JSONL fixtures, deepeval/RAGAS wiring | `eval-writer` | sonnet |
| Domain-expert review (product/legal/compliance sanity) | `sme-reviewer` | sonnet |

Full cartridges at `~/.claude/agents/<name>.md`. Auto-generated roster at `~/.claude/agents/README.md`.

Deep rules live at BOTH `~/.claude/rules/` (user-scope override) AND `<repo>/rules/` (tracked, ships with this repo — canonical source):
- Workflow teams + parallel wave patterns → `rules/workflows.md`
- Codex cadence + failure modes + SDD × Group of Experts routing → `rules/codex-routing.md`
- Sprint status tree spec → `rules/sprint-status.md`
- Hooks + CLAUDE.md hygiene + headless automation → `rules/hooks.md`

Installer (`scripts/install-rules.sh`, forthcoming) copies `rules/*.md` → `~/.claude/rules/` so every session loads the same operating contract.

---

## CORE RULES
- Secrets: AWS Secrets Manager / SSM — never in code, committed `.env`, or `.tfvars`
- MCP servers: `.mcp.json` at project root (never `settings.json`), `${ENV_VAR}` for secrets
- Naming: `{project}-{env}-{service}-{resource}`
- IaC: Terraform only — no click-ops for persistent AWS resources
- Playwright: `browser_run_code` only — never `browser_snapshot`
- Branch: `git branch --show-current` before writing any workflow `branches:` trigger
- No API keys in committed docs — placeholders only

---

## WINDOWS ENV
Bash loses CWD between invocations — use absolute paths or explicit `cd`.
Background: PowerShell `Start-Process` — NEVER bash `&`.
Kill by name: `Get-Process -Name python,node | Stop-Process -Force`.
Port check: `netstat -ano | Select-String ":PORT"`.

---

## SESSION MANAGEMENT
- **Auto-compact at ≥50% context** with scoped focus: `/compact Focus on <project> Sprint <N> — <next task>`
- `session-autopilot` skill fires at 50% — writes MongoDB `session_logs` entry + prints sprint status tree
- `/btw <question>` — overlay answer, never enters context (zero token cost)
- `/rewind` or `Esc+Esc` restores conversation + code to any prior checkpoint
- `/rename <name>` for session identity; `claude --continue` / `--resume` for multi-day tasks
- `/effort <low|medium|high>` sets reasoning depth; `/goal <condition>` re-checks each turn
- After compact: verify CLAUDE.md loaded, `git log --oneline -3` to reorient

Sprint status tree → `~/.claude/rules/sprint-status.md` (cat emoji legend + row order).
Hooks → `~/.claude/rules/hooks.md` (PostToolUse, PreToolUse, Stop, MessageBox).

---

## TECH STACK POINTERS
- **Python packaging:** `[tool.setuptools.packages.find] include = ["app*"]` when `evals/` or `scripts/` sit next to `app/`
- **NestJS:** `nest g resource` only — never hand-write boilerplate
- **MCP tools:** `@Tool({ name, description, parameters: z.object({}) })`
- **React state:** local → Zustand → React Query (never Redux unless pre-existing)
- **React tests:** `getByRole` > `getByText` > `getByTestId`
- **LangChain rules** → `~/.claude/rules/python/langchain.md` (auto-load on `**/agents/**` + `**/prompts/**`) — `.with_structured_output(PydanticModel)`, `ainvoke`/`astream`, `get_llm(role)` factory
- **Python testing rules** → `~/.claude/rules/python/testing.md` — unique class names, no `__init__.py` in `tests/`, Motor event-loop reset
- **Terraform rules** → `~/.claude/rules/infra/terraform.md` — `lifecycle` inside resource, `archive_file` not `filebase64sha256`, OIDC not static keys
- **CI/CD pipeline rules** → `~/.claude/rules/cicd/pipeline.md` — 5-job: backend-ci → backend-e2e → frontend-ci → frontend-e2e → docker-build
- **Scraping isolation:** every run writes to `output/runs/YYYY-MM-DD-HHMM/`; PDFs to shared `output/pdfs/`; never reuse an output path
- **README standard:** 16 required sections, prose in Problem + Story Arc, two Mermaid diagrams, sprint history in `<details>`
- **Automation (headless):** `claude -p "..." --allowedTools "Edit,Bash(git commit *)"` for CI/cron; `--permission-mode auto` for unattended runs; full recipes → `~/.claude/skills/headless-automation/SKILL.md`

---

## .gitignore defaults
`.env` `.env.*` `*.pem` `*.key` `credentials.json` `*.tfstate*` `.terraform/` `node_modules/` `dist/` `.next/` `build/` `__pycache__/` `.venv/` `.claude/worktrees/` `CLAUDE.local.md`
