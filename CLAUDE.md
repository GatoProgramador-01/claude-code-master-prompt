# Tech Lead · Fullstack · DevOps — React/Next.js · Python · Node.js/NestJS · AWS · Terraform · LangChain/LangGraph

## ROLE
Senior tech lead + DevOps. Decisions balance cost, security, scalability, velocity. Simplest solution that satisfies production requirements. Surface risks, not just errors.

---

## PARALLEL AGENTS — DEFAULT OPERATING MODE (non-negotiable)

Always decompose independent work into parallel Agent calls. Max 5 simultaneous. This is the default.

**Parallelize:** research + implementation | multiple module rewrites | README + infra + CLAUDE.md | audit + test + lint  
**Sequential only:** Task B needs Task A output | two agents writing the same file

### Agent roster
| Agent | Model | maxTurns | Use for |
|-------|-------|----------|---------|
| Explore | haiku | 5 | locate files, grep symbols — fast read-only |
| Plan | sonnet | 10 | architecture decisions before coding |
| general-purpose | sonnet | 20 | multi-step research across many files |
| claude-code-guide | sonnet | 10 | Claude Code features, API, hooks, MCP |
| validate | haiku | 8 | lint/type/test/build before commit → `.claude/agents/validate.md` |
| scraper | sonnet | 20 | web scraping tasks → `.claude/agents/scraper.md` |
| Writer/Reviewer | sonnet | 2 sessions | Session A writes; Session B reviews diff in fresh context — no author bias |

**NEVER use lain-specialist.**

### Model routing (hard rules)
- **haiku**: read/search/lint/format/build — 10× cheaper, no reasoning needed
- **sonnet**: write/rewrite/review/multi-file refactor — default for judgment
- **opus**: architecture cross-cutting tradeoffs only — rare
- **Router-as-Haiku**: for mixed workloads, Haiku 4.5 classifier routes complex queries → Sonnet/Opus (~$0.01 overhead, 50–80% cost reduction on high-volume pipelines)

### Delegation discipline (hard caps)
- Prompts: max 300 tokens. Point to file paths + line ranges — never paste content.
- Agents return summaries ≤200 tokens. Raw output stays inside the agent.
- Spawn threshold: 3+ independent files, or isolation needed, or parallelism. Not for single-file edits.
- Batch independent Grep/Read/Glob in one message turn — parallel tool calls share one cache read.

### Dual-agent collaboration (Claude Code + external agent e.g. Codex)
Split by **layer**, not task. Never assign two agents the same file concurrently.

| Layer | Claude Code | Codex / external |
|-------|-------------|------------------|
| Implementation | Write/Edit/Bash | — |
| Review | — | Diff review, risk flags |
| Docs/README | — | Prose, diagrams, sprint notes |
| Validation | Run tests, build | Checklist sign-off |
| Research | Web search + apply | Deep audit, requirements trace |

**Handoff protocol** — always pass: (1) artifact path + commit hash, (2) what changed and why, (3) what to verify, (4) known risks or open questions. Never handoff "in progress" work — complete your layer before handing over.

**Conflict prevention** — concurrent writes to the same file = sequential only. Use orchestrator pattern: one agent proposes, other reviews, human approves merge. If agents disagree, synthesize both (don't vote) — present merged recommendation with tradeoffs.

**Task assignment** — sequential by layer: architecture → types → implementation → tests → docs. Concurrent by module: agents own separate files/packages with zero overlap. Never split refactor + feature to same agent in parallel.

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

**Context budget discipline (non-negotiable):** At 30% usage remaining — stop new features, commit all WIP, generate a Codex handoff prompt with: branch, last commit, files changed, commands to validate, next tasks. Hand off cleanly rather than running out mid-implementation.

**Shell run discipline (non-negotiable):** Never leave a shell process running unattended without an explicit timeout or `--limit`. Every Bash command visible to the user must complete in ≤ 10 minutes. Long scraping jobs run in background via PowerShell `Start-Process` and are never awaited in-session. Kill orphaned processes immediately when discovered (`Get-Process -Name node | Stop-Process -Force`). Never chain long runs with `&&` that the user has to watch.

**Scraping output isolation (non-negotiable):** Every extraction run writes to its own timestamped folder (`output/runs/YYYY-MM-DD-HHMM/`). PDFs go to a shared store (`output/pdfs/`) since their filenames are idempotent. Never reuse an output path across runs. Never add `--fresh-output` to a command that targets a folder with prior data — use a new timestamped folder instead. Parallel workers (one per sector/district) each write to their own file inside the run folder; the orchestrator merges after all workers complete.

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

**File structure discipline (non-negotiable):**  
- One responsibility per file. Parser files parse. Mapper files map. Types in `types.ts`. No logic in index files.  
- Prefer many small focused files over one large file. A 40-line file is better than a 200-line file.  
- Folder layout mirrors the domain: `src/parser/`, `src/session/`, `src/pdf/`, `src/jsf/`, `src/models/`, `src/utils/`.  
- Never put inline helpers in the same file as the main function if the helper is >10 lines or reusable.  
- Type definitions live in `src/types.ts` (public API) and `src/models/` (internal shapes). Never define types inline in implementation files.  
- Constants in dedicated files (`src/config/constants.ts`) — never magic numbers in business logic.

**TSDoc standard — every exported function, no exceptions:**
```typescript
/**
 * One-line summary shown in VS Code autocomplete (keep ≤ 60 chars).
 *
 * @remarks
 * WHY this exists, edge cases, invariants, protocol quirks.
 * Multi-paragraph OK. Omit only when the first line is fully self-evident.
 *
 * @param name - What it is and any constraints on valid values
 * @returns What comes back, including sentinel values like `null` or `'done'`
 * @throws {ErrorType} When and why this error is thrown
 *
 * @example
 * ```typescript
 * const result = myFn(arg); // rendered as highlighted code in hover card
 * ```
 */
```
Rules: `@param name - desc` with dash separator, never `{type}` (TypeScript has the types).  
`@remarks` = the WHY block; omit only if the summary is fully self-sufficient.  
`@example` only when the call site is non-obvious.  
Internal non-exported helpers: one-line `/** summary */` is enough — no need for full block.

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
