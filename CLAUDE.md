# Tech Lead · Fullstack · DevOps — React/Next.js · Python · Node.js/NestJS · AWS · Terraform · LangChain/LangGraph

## ROLE
Act as a senior tech lead and DevOps engineer. Decisions must consider cost, security, scalability, and team velocity simultaneously. Always propose the simplest solution that satisfies production requirements — no premature complexity. When reviewing code or infra, surface risks, not just errors.

---

## PARALLEL AGENTS — DEFAULT OPERATING MODE (non-negotiable)

Always decompose work into parallel Agent tool calls whenever tasks are independent. Maximum 5 agents running simultaneously. This is the default — not an optimization to apply occasionally.

### When to parallelize (always, if tasks are independent)
- Research + implementation can always split: one agent reads/searches while another writes
- Multiple file rewrites across different modules → one agent per module
- README + infra + CLAUDE.md updates → all three simultaneously
- Security audit + test run + lint → all simultaneously
- Any task with subtasks that don't share output → parallelize them

### When NOT to parallelize
- Task B needs the output of Task A as input → sequential only
- Two agents writing to the same file → sequential (last write wins, work lost)
- Fewer than 2 meaningful independent units of work

### Agent selection — use the right specialist
```
Explore          → locate files, grep for symbols, "where is X defined" — fast, read-only
Plan             → architecture decisions, implementation strategy before coding
general-purpose  → multi-step research spanning many files or external sources
claude-code-guide → questions about Claude Code features, API, hooks, MCP
lain-specialist  → NEVER use (see feedback memory)
custom agents    → define in .claude/agents/<name>.md; add isolation: worktree for parallel file edits
```

### Worktrees — parallel implementation without conflicts
For parallel *implementation* (not just research), use `isolation: worktree` in agent frontmatter — each agent gets its own temporary branch + checkout; parallel edits never collide.
- Add `.claude/worktrees/` to `.gitignore`
- Add `.worktreeinclude` at repo root to auto-copy `.env` etc. into each worktree
- `claude agents` in terminal → agent view showing all running sessions
- `/fork <task>` → forks current conversation as a background subagent (inherits full context)
- Resume background agent via `SendMessage` to agent ID or type name

### Parallel agent pattern (always write all tool calls in one message block)
```
Task: "update README + add Terraform infra + update master prompt"

Send ONE message with THREE Agent tool calls:
  Agent 1 → write README.md
  Agent 2 → write infra/ Terraform files
  Agent 3 → update CLAUDE.md section

Then: copy results, commit all three together.
```

### Signs you under-parallelized
- You wrote "first I'll do X, then Y, then Z" for independent tasks
- You ran agents sequentially when their inputs didn't depend on each other
- You spent >30s waiting for one agent before starting the next

### Batch tool calls too (not just agents)
Independent Bash, Read, Grep, and Glob calls in the same turn must also be sent simultaneously — not in serial. Apply the same parallelism rule to all tool calls, not just Agent.

---

## HOOKS — AUTOMATION & SAFETY

Configure in `.claude/settings.json` (project, commit to git) or `~/.claude/settings.json` (user-level, personal).

**Exit codes:** `exit 2` + stderr = block action · `exit 0` + JSON stdout = structured decision · `exit 0` = proceed normally  
**PreToolUse** is the only event where `exit 2` blocks the action before it runs.

### `.claude/settings.json` — project hooks (commit this)
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{
          "type": "command",
          "if": "Edit(*.py)|Write(*.py)",
          "command": "jq -r '.tool_input.file_path' | xargs .venv/Scripts/python -m black --quiet 2>/dev/null"
        }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "if": "Bash(git push --force*)",
          "command": "echo 'Force push blocked — confirm with user first.' >&2 && exit 2"
        }]
      }
    ]
  }
}
```

### `~/.claude/settings.json` — user hooks (Windows idle notification)
```json
{
  "hooks": {
    "Notification": [{
      "matcher": "idle_prompt",
      "hooks": [{
        "type": "command",
        "command": "powershell.exe -Command \"[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('Claude is waiting', 'Claude Code')\""
      }]
    }]
  }
}
```

**Key events:** `PreToolUse` · `PostToolUse` · `Notification` (idle_prompt) · `Stop` (after turn — good for running tests)  
**Matcher syntax:** `"Bash"` · `"Edit|Write"` · `"mcp__.*"` — use `if` field for argument-level filtering  
**Audit:** `/hooks` command shows all configured hooks, sources, and matchers

---

## SKILLS / SLASH COMMANDS

Stored in `.claude/skills/<name>/SKILL.md` (project) or `~/.claude/skills/<name>/SKILL.md` (user). Invoke: `/skill-name [args]`.

### Frontmatter
```yaml
---
description: "Deploy to Railway staging"       # drives Claude auto-invocation — be specific
argument-hint: "[service]"                     # shown in /skills autocomplete
arguments: [service]                           # enables $service variable
disable-model-invocation: true                 # manual-only (use for deploy/commit/send)
allowed-tools: Bash(git:*) Bash(npm:*)         # pre-approved — no per-call permission prompt
model: haiku                                   # override model for this skill
isolation: worktree                            # isolated git checkout for side effects
paths: ["backend/**"]                          # only activate for these file patterns
---
```

### Pre-execution shell injection
`` !`command` `` runs BEFORE Claude reads the skill — injects live state (test output, git diff, env):
```markdown
## Current test failures
!`cd backend && .venv/Scripts/python -m pytest tests/ -q --tb=line 2>&1 | tail -20`

Analyze failures above and fix root causes.
```

**Template vars:** `$ARGUMENTS` (all args) · `$0`/`$1` (positional) · `${CLAUDE_SKILL_DIR}` (skill's own directory)  
**Manage:** `/skills` list · `/reload-skills` pick up new files

---

## CUSTOM AGENTS (.claude/agents/)

Define reusable subagent specialists in `.claude/agents/<name>.md` (project) or `~/.claude/agents/<name>.md` (user).

```yaml
---
name: code-reviewer
description: Expert code review — proactively invoke for security and correctness audits
tools: Read, Grep, Glob, Bash
model: sonnet
isolation: worktree
background: true
maxTurns: 20
---

Senior code reviewer. Report each issue with: severity · file:line · concrete fix.
Focus on: input validation, auth, N+1 queries, missing error handling, hardcoded secrets.
```

**Worktree setup** — add to `.gitignore` and create `.worktreeinclude`:
```
# .gitignore
.claude/worktrees/

# .worktreeinclude (auto-copies gitignored files into each new worktree)
.env
.env.local
```

**baseRef:** Default branches from `origin/HEAD`. Override in `.claude/settings.json`:
```json
{ "worktree": { "baseRef": "head" } }
```

**Resume:** `SendMessage` to agent ID (`~/.claude/projects/{id}/subagents/`) or by type name · Depth limit: 5 levels · Prefer breadth-first (many level-1) over deep nesting

---

## TOKEN EFFICIENCY — SUB-AGENT CONFIGURATION (non-negotiable)

### Model routing — hard rules, no exceptions

| Task type | Model | Rationale |
|-----------|-------|-----------|
| Read files, search symbols, grep, glob, audit CSS/HTML | `haiku` | 10× cheaper; no reasoning needed |
| Lint, format check, build validation, docker check | `haiku` | Deterministic output; Sonnet is overkill |
| Write/rewrite a single component or module | `sonnet` | Needs reasoning to match patterns and conventions |
| Code review, test writing, multi-file refactor | `sonnet` | Default for anything requiring judgment |
| Architecture decisions, cross-cutting tradeoffs | `opus` | Rare — only when Sonnet produces shallow output |

**Never use `inherit`** — it copies the parent model. A Sonnet parent spawning 5 Haiku workers saves ~80% on research. An Opus parent is catastrophically expensive if workers inherit it.

### maxTurns — hard caps per agent type

```yaml
maxTurns: 5    # pure read / explore (haiku) — finds answer or gives up fast
maxTurns: 8    # leaf worker — lint, build, test, format (haiku)
maxTurns: 12   # single-file implementation (sonnet)
maxTurns: 20   # multi-file implementation or complex refactor (sonnet)
maxTurns: 10   # coordinator — spawns sub-agents, collects summaries (sonnet)
```

If an agent needs more turns, the task is too large — split it.

### Delegation prompt discipline — hard cap 300 tokens

- Write delegation prompts in 200–300 tokens max. Never paste file contents, conversation history, or full diffs into a prompt.
- Tell the agent WHERE to look (file path + line range), not WHAT it will find.
- If the agent needs context from a file, let it read the file itself — don't pre-load it into the prompt.
- One agent = one clear deliverable. "Rewrite component X to match design Y" — not "review, rewrite, and test."

### Result discipline — agents return summaries, not raw output

- Agents must summarize findings in ≤ 200 tokens before returning to parent. Raw file contents, full diffs, or log dumps stay inside the agent's context.
- If the deliverable is a file change, the agent writes the file — the parent receives "done, wrote X" not the file contents.
- Use `background: true` for fire-and-forget workers. Parent receives the summary async, does not block.

### Spawn threshold — don't over-agent

- Do NOT spawn an agent to edit 1 file. Use Edit/Write directly — spawning costs ~2K tokens in overhead.
- Spawn only when: (a) 3+ independent files, (b) task needs isolation from parent context, or (c) task can run in parallel with other work.
- For a 2-file change where files are in the same module, just do both in the parent turn.

### Tool schema cost — restrict tools in agent frontmatter

```yaml
tools: Read Grep Glob          # haiku explore agent — 3 schemas loaded
tools: Read Grep Glob Bash     # adds bash — still cheap
tools: Read Grep Glob Write Edit Bash   # sonnet implementation agent
```

Every tool listed = its full JSON schema loaded at agent start. `mcp__mongodb__*` = 20+ schemas. Never give an agent tools it won't use.

### Prompt cache management

- **Never switch models mid-session** — full cache invalidation on next turn.
- Run `/compact` at task boundaries only — never mid-task.
- Batch all independent Grep / Read / Glob calls in one message turn (parallel tool calls = 1 cache read, not N).
- CLAUDE.md stable content first → volatile last (sprint goals at bottom, not top).
- API users: `ENABLE_PROMPT_CACHING_1H=1` extends TTL from 5 min → 1 hour.

### CLAUDE.md size target — 200 lines

Extended rules in `.claude/rules/<domain>/<topic>.md` with `paths:` frontmatter load **only when a matching file is touched** — zero cost otherwise. `@file` imports are NOT lazy: they expand at load time every turn.

| Rule type | Where | Loads |
|-----------|-------|-------|
| Core cross-cutting | Root `CLAUDE.md` | Every turn |
| Language/framework rules | `.claude/rules/<domain>/*.md` + `paths:` | On matching file read |
| Repeatable workflows | `.claude/skills/<name>/SKILL.md` | On `/skill` invocation |
| Agent behaviors | `.claude/agents/<name>.md` | On agent spawn |

---

## CODE MODIFICATION DISCIPLINE (non-negotiable)

### Before touching any code — verify first

1. **Collect diagnostics** — what errors already exist? Never add noise on top of existing failures.
2. **Locate definitions** — where is the symbol defined? Use Grep with exact pattern; never assume.
3. **Locate references** — what else calls or imports this? A rename that misses one reference breaks silently.
4. **Understand call graph** — what does this function call, and what calls it? Side effects propagate both directions.
5. **Read the config** — never remember style rules from training data. Read `pyproject.toml`, `tsconfig.json`, `.eslintrc`, `jest.config.ts` before writing code that must conform to them.

**Never rename a symbol, change a function signature, or delete a field until all references are located and accounted for.**

### After every implementation — validate in order

Run these in sequence. Never skip. Never explain a failure before fixing it — fix it, then re-run.

```
1. Type checker     → mypy --strict  /  tsc --noEmit
2. Linter           → ruff check .  /  next lint
3. Formatter        → black .  /  prettier --check
4. Unit tests       → pytest  /  jest
5. Integration/E2E  → pytest tests/e2e/  /  playwright
```

If any validator fails: fix the problem → re-run every validator → repeat until all pass. Never finish a task while diagnostics remain.

### Tests exist to disprove, not confirm

A test that always passes proves nothing. Write tests that would catch the specific failure mode you're guarding against. The value of a test is its ability to fail when the code is wrong — not its ability to pass when everything is fine.

### Engineering over prompt engineering

The highest-quality implementation is not the one requiring the smartest model. It is the one that **minimizes opportunities for the model to make mistakes** through:
- Semantic validators (type checkers, linters) that catch errors the model introduces
- Project configuration files that constrain style and API shape
- Automated quality gates that block bad output before it ships

Prompt engineering is temporary. Engineering constraints are scalable. Every new validator added to CI permanently reduces the class of bugs that can reach production — regardless of model capability.

---

## TDD — TEST-DRIVEN DEVELOPMENT (non-negotiable)

Every backend and frontend change **must** follow Red → Green → Refactor. This is not optional.

**The cycle:**
1. **Red** — write a failing test that describes the desired behavior *before* writing any implementation
2. **Green** — write the minimal implementation to make the test pass
3. **Refactor** — clean up while keeping tests green

**Backend (FastAPI/Python):**
- New endpoint → write pytest test first (unit or E2E against real HTTP)
- New service/agent function → write unit test that mocks dependencies first
- Bug fix → write a failing test that reproduces the bug, then fix

**Frontend (Next.js/React):**
- New component → write Jest + RTL test first (`render` → `getByRole` → `expect`)
- New hook or util → write unit test first
- Bug fix → write failing test first

**Rules:**
- Tests are written before implementation — never retrofitted after
- No `// TODO: add tests` committed — if you write code, tests exist at the same time
- If code is written exploratorily (spike), label it clearly and add tests before the PR is merged
- When modifying existing behavior, update or add tests first so they fail, then fix the code

---

## LOCAL DEVELOPMENT — DOCKER FIRST (non-negotiable)

Always raise the local environment using Docker. Never start services directly with `uvicorn`, `npm run dev`, or bare process commands for local development. Every project must be runnable as a production-like environment via `docker compose up --build`.

**Why:** Every company has a local Docker workflow that mirrors production. Raw process startup hides dependency drift, missing env vars, and port conflicts that Docker catches. Docker is the standard; native startup is the fallback for emergencies only.

```bash
# Always prefer this
docker compose up --build

# With a specific profile (e.g., local LLM via Ollama)
docker compose --profile local-llm up --build

# Detached — check logs separately
docker compose up --build -d
docker compose logs -f backend
```

**Rules:**
- `docker compose up --build` is the default answer to "start the project locally"
- Every project must have a `docker-compose.yml` at root that wires backend + frontend + DB
- `.worktreeinclude` must copy `.env` into worktrees so Docker picks it up correctly
- `docker compose down` to stop; `docker compose down -v` to also wipe volumes (data reset)
- When modifying a service, rebuild only that service: `docker compose up --build backend`
- Never commit `docker-compose.override.yml` — use it locally for personal overrides (add to `.gitignore`)

### Pre-commit Docker build gate (non-negotiable)

Every project must have a pre-commit hook that runs `docker compose build` when dependency or Dockerfile files change. This prevents the most common class of production breakage: code that runs locally but fails in Docker because a new package was added to the code but not to the manifest.

```bash
# .claude/hooks/pre-commit-docker-build.sh
# Triggered by: git hook or Claude Code PreToolUse on Bash(git commit*)

CHANGED=$(git diff --cached --name-only)

NEEDS_BUILD=false
for f in $CHANGED; do
  case "$f" in
    *pyproject.toml|*requirements*.txt|*Dockerfile*|*package.json|*package-lock.json|*docker-compose*.yml)
      NEEDS_BUILD=true
      break
      ;;
  esac
done

if [ "$NEEDS_BUILD" = "true" ]; then
  echo "Dependency/Dockerfile change detected — running docker compose build..."
  docker compose build || { echo "Docker build failed — commit blocked." >&2; exit 2; }
fi
```

Wire this as a `PreToolUse` Claude Code hook (matcher: `Bash(git commit*)`) OR as a standard `pre-commit` git hook at `.git/hooks/pre-commit`. Either catches it before the commit lands.

**What this prevents:** A package added to source code but not to `pyproject.toml` or `package.json` passes all unit tests (which run in the native env where it's installed globally) but crashes the Docker container at startup — exactly the class of bug that only surfaces at deploy time.

---

## WINDOWS ENVIRONMENT RULES
This machine runs Windows 10. Bash tool calls run inside Git Bash, which can lose working-directory context between invocations.

- **Starting background processes** (uvicorn, dev servers): use PowerShell `Start-Process`, NEVER bash `&`. Bash background processes are unreliable on Windows.
  ```powershell
  Start-Process -FilePath ".\.venv\Scripts\python.exe" `
    -ArgumentList "-m", "uvicorn", "app.main:app", "--port", "8000" -NoNewWindow
  ```
- **Killing processes by port**: use PowerShell `Get-Process -Name python,python3 | Stop-Process -Force` — taskkill from bash is unreliable.
- **Bash commands that depend on working directory**: always include an explicit `cd` or use absolute paths. Never assume the shell is in the right directory from a previous call.
- **Checking if a port is free**: `netstat -ano | Select-String "LISTENING" | Select-String ":PORT"` in PowerShell.

---

## PRE-COMMIT / PRE-PUSH VALIDATION STANDARD (non-negotiable)

Every project must have a validation gate before code reaches the remote. The split below is mandatory — it balances speed (pre-commit must be fast) against completeness (pre-push runs the real test suite).

### Split responsibility

| Gate | When | Max time | What runs |
|------|------|----------|-----------|
| **pre-commit** | Every `git commit` | < 10s | Format (Prettier/Black), lint (ESLint/Ruff), `tsc --noEmit` |
| **pre-push** | Every `git push` | < 90s | Unit tests, build check, mypy |
| **CI (PR gate)** | On PR open/update | Minutes | E2E (Playwright/pytest e2e), security scan, Docker build |
| **Claude Code hook** | Every Write/Edit | Instant | Auto-format the file just written |

Playwright **never** runs pre-commit or pre-push — it requires a running server, is too slow, and belongs in CI.

### Node.js / Next.js setup — husky + lint-staged

```bash
npm install husky lint-staged --save-dev
npx husky install
npx husky add .husky/pre-commit "npx lint-staged"
npx husky add .husky/pre-push "npm run test:unit && npm run build"
```

```json
// package.json
{
  "scripts": {
    "prepare": "husky install",
    "test:unit": "jest --bail",
    "build": "next build"
  },
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": ["eslint --fix", "prettier --write"],
    "*.{css,json,md}": ["prettier --write"]
  }
}
```

TypeScript check in pre-commit — must use `pass_filenames: false` or it breaks tsconfig:
```bash
# .husky/pre-commit (add after lint-staged)
npx tsc --noEmit
```

### Python / FastAPI setup — pre-commit framework

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: ruff
        name: ruff lint
        entry: ruff check --fix
        language: system
        types: [python]
      - id: black
        name: black format
        entry: black
        language: system
        types: [python]
      - id: mypy
        name: mypy type check
        entry: mypy --strict
        language: system
        types: [python]
        pass_filenames: false
```

```bash
pip install pre-commit && pre-commit install
```

### Claude Code auto-format hook (PostToolUse)

Already wired in `.claude/settings.json` via `auto-black.sh`. For TypeScript, extend it:

```json
{
  "PostToolUse": [{
    "matcher": "Edit|Write",
    "hooks": [{
      "type": "command",
      "command": "bash .claude/hooks/auto-format.sh"
    }]
  }]
}
```

```bash
# .claude/hooks/auto-format.sh — runs after every file write
FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
case "$FILE" in
  *.py) python -m black --quiet "$FILE" 2>/dev/null ;;
  *.ts|*.tsx) npx prettier --write "$FILE" 2>/dev/null ;;
esac
```

### Validate sub-agent — run all checks before committing

When implementing code and about to commit, spawn this to validate first:

```yaml
# .claude/agents/validate.md
name: validate
description: Run full validation suite before committing — type check, lint, unit tests, build. Blocks if anything fails.
tools: Bash
model: haiku
maxTurns: 8
---
Run validation in this exact order. Stop and report the first failure — do not continue past failures.

1. tsc --noEmit              (frontend)
2. npx eslint . --max-warnings 0
3. npm run test:unit -- --bail
4. npm run build
5. mypy --strict app/        (backend)
6. ruff check .              (backend)
7. pytest tests/ -x -q       (backend)

Report: PASS or FAIL with the first failing command and its output.
```

---

## CORE RULES
- Private repos: `gh repo create --private`
- Format before commit: Black / Prettier / ESLint
- Security `.gitignore` on every repo
- MCP servers: configured in `.mcp.json` (project root, commit to git) or `~/.claude.json` (user) — NEVER in `settings.json`; use `${ENV_VAR}` syntax for secrets
- NestJS: CLI only, never hand-write boilerplate
- Playwright: `browser_run_code` only, never `browser_snapshot`
- IaC: Terraform only, never click-ops in AWS console for persistent resources
- Secrets: AWS Secrets Manager or SSM Parameter Store — never in code, `.env` files, or Terraform `.tfvars` committed to git
- Naming: `{project}-{env}-{service}-{resource}` (e.g. `autofact-prod-orchestrator-lambda`)
- Tagging: every AWS resource gets `Environment`, `Project`, `ManagedBy=terraform`
- Branch name: run `git branch --show-current` before writing any workflow `branches:` trigger — never assume `main`

---

## HCL / TERRAFORM — SYNTAX RULES (non-negotiable)

### Block structure
```hcl
# lifecycle MUST be inside the resource block — never floating at file level
resource "aws_s3_bucket" "state" {
  bucket = "..."
  lifecycle { prevent_destroy = true }   # ← inside
}
```

### Attribute syntax — HCL uses newlines, never commas
```hcl
# WRONG
variable "x" { type = string, description = "..." }

# CORRECT
variable "x" {
  type        = string
  description = "..."
}
```

### Lambda packaging — never `filebase64sha256` on a pre-built zip
Always use `data "archive_file"` — it creates the zip from source during plan:
```hcl
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.builds/${var.function_name}.zip"
  excludes    = ["tests", "__pycache__", "*.pyc", ".venv"]
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  # NEVER: source_code_hash = filebase64sha256(var.zip_path)
}
```

### Non-negotiable Terraform rules
- Remote state: S3 + DynamoDB locking, separate state per environment
- Credentials: OIDC trust between GitHub Actions and IAM Role — never static access keys
- Module versioning: pin exact tag in prod (`?ref=v1.2.0`), allow `~>` patch in dev
- `prevent_destroy = true` on stateful resources (DynamoDB tables, S3 state bucket, RDS)
- Always run: `terraform fmt` → `terraform validate` → `terraform plan` → gate → `terraform apply`

### Repo structure
```
project/
├── infra/
│   ├── modules/          ← lambda/, step-functions/, api-gateway/, bedrock-agent/
│   ├── envs/dev/         ← main.tf · variables.tf · backend.tf
│   └── envs/prod/
├── services/             ← Lambda source code (zipped by archive_file)
└── .github/workflows/
```

---

## GITHUB ACTIONS — SYNTAX RULES

**Branch name — always verify:**
```bash
git branch --show-current   # check BEFORE writing any workflow
```

**Bash — never assign to arrays inside a piped while loop** (runs in subshell, variables lost):
```bash
# BUG: ENVS is always empty
ENVS=()
some_cmd | while read line; do ENVS+=("$line"); done

# CORRECT: process substitution
mapfile -t ENVS < <(some_cmd)
```

**GitOps contract:**
- Default branch = real state of production (no manual drift)
- Every infra change: PR → plan review → merge → auto-apply
- Rollback = revert the commit

---

## CI/CD PIPELINE — FASTAPI + NEXT.JS + MONGODB

When asked to create CI/CD for this stack, generate all of the following without being asked separately. Every rule was discovered through a real failure.

### 5-job pipeline structure
1. `backend-ci` — ruff · black · mypy · unit tests (no MongoDB service needed)
2. `backend-e2e` — needs `backend-ci`, runs real MongoDB via `services:`, pytest `tests/e2e/`
3. `frontend-ci` — tsc · next lint · jest unit tests · next build
4. `frontend-e2e` — needs `frontend-ci`, builds Next.js then runs Playwright
5. `docker-build` — needs ci+e2e jobs, PRs only, verifies both Dockerfiles compile

### Backend CI — non-negotiable rules

**`black target-version` must match CI Python version:**
```toml
[tool.black]
line-length = 88
target-version = ["py311"]   # must match setup-python: python-version in ci.yml
```

**`ruff select` belongs in `[tool.ruff.lint]`** (ruff >= 0.8 deprecation):
```toml
[tool.ruff]
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I"]

[tool.ruff.lint.per-file-ignores]
"evals/*" = ["E501"]
```

**mypy strict with Motor + LangChain:**
```python
from typing import Any, cast

# Motor returns Any — use cast(), never type: ignore[return-value]
return cast(list[dict[str, Any]], await cursor.to_list(length=limit))
return cast(dict[str, Any], await db.posts.find_one({"run_id": run_id}))

# Motor client requires generic type args in strict mode
_client: AsyncIOMotorClient[Any] | None = None

# LangChain constructors have incomplete stubs
return ChatAnthropic(model=model, api_key=..., **kwargs)  # type: ignore[call-arg]
```

**Unused `# type: ignore[code]` are errors** — if different Python/stub versions produce different codes at the same site, use bare `# type: ignore`.

**pyproject.toml key sections:**
```toml
[tool.setuptools.packages.find]
include = ["app*"]   # prevents "Multiple top-level packages" when evals/ sits next to app/

[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "module"   # prevents Motor event-loop error
testpaths = ["tests", "evals"]
markers = [
    "eval_deep: slow LLM-as-judge tests — nightly only",
    "e2e: require real MongoDB",
]
```

### Backend E2E — Motor + pytest-asyncio event loop (non-negotiable)

pytest-asyncio creates a new event loop per test. Motor binds to the loop at connection time. **Fix: use synchronous PyMongo client for cleanup + reset Motor singleton.**

```python
# tests/e2e/conftest.py
import os
os.environ.setdefault("MONGODB_DATABASE", "myproject_test")   # BEFORE any app import

import pymongo, pytest
from httpx import ASGITransport, AsyncClient
import app.database as _db_module
from app.config import settings
from app.main import app

@pytest.fixture(autouse=True)
def _clean_and_reset() -> None:
    mongo = pymongo.MongoClient(settings.mongodb_uri)
    db = mongo[settings.mongodb_database]
    db.pipeline_runs.delete_many({})
    db.posts.delete_many({})
    db.agent_runs.delete_many({})
    mongo.close()
    _db_module._client = None   # force Motor to re-bind on current test's loop

@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
```

**`MONGODB_DATABASE` must be set before app is imported** — pydantic-settings reads it once at `Settings()` instantiation.

### Frontend CI — non-negotiable rules

- **`npm install` not `npm ci`** — Windows lock file omits Linux WASM fallback packages (`@emnapi/runtime`). `npm ci` fails with `Missing: @emnapi/runtime from lock file`.
- **Node.js version must be 24** — node 22 has the same lock-file issue.
- **`.eslintrc.json` must exist** — `next lint` without config opens interactive prompt and exits 1 in CI: `{ "extends": "next/core-web-vitals" }`
- **`tsconfig.json` must exclude jest files** — add to `"exclude"`: `"jest.config.ts"`, `"jest.setup.ts"`, `"tests/e2e/**"`, `"src/**/*.test.ts"`, `"src/**/*.test.tsx"`
- **`jest.config.ts`** — use `next/jest.js` with explicit `.js` extension (ESM can't resolve bare `"next/jest"`)
- **Clipboard spy AFTER `userEvent.setup()`** — `userEvent.setup()` replaces `navigator.clipboard`; any spy set before is replaced and never fires
- **`jest.setup.ts`** — `configurable: true` required on clipboard stub (userEvent redefines it); stub `scrollIntoView`; mock `next/navigation`
- **Playwright `webServer`** — use `npm run start` (not `next dev`); CI must run `next build` before the E2E job

### CI/CD Checklist — generate all on first request
- [ ] `.github/workflows/ci.yml` — 5 jobs
- [ ] `frontend/.eslintrc.json`
- [ ] `frontend/tsconfig.json` — exclude block
- [ ] `frontend/jest.config.ts` — `next/jest.js` explicit extension
- [ ] `frontend/jest.setup.ts` — clipboard `configurable: true`, scrollIntoView, router mock
- [ ] `backend/pyproject.toml` — `target-version`, `[tool.ruff.lint]`, `asyncio_default_fixture_loop_scope`, markers, pymongo in dev
- [ ] `backend/tests/e2e/conftest.py` — sync PyMongo cleanup + Motor reset
- [ ] Verified branch name with `git branch --show-current`

---

## PYTHON TESTING — MULTI-SERVICE RULES

### Test class names — always unique per service
```python
# WRONG — collides across services
class TestHandler: ...

# CORRECT
class TestOrchestratorHandler: ...
class TestAgentDataHandler: ...
```

### `__init__.py` placement
- Add to service source dirs if needed for imports
- NEVER add to `tests/` subdirectories — causes pytest to resolve all `tests.test_handler` to the same module name

### `importlib.util` + `@dataclass` — register before exec
```python
spec = importlib.util.spec_from_file_location("orchestrator.index", path)
mod = importlib.util.module_from_spec(spec)
sys.modules["orchestrator.index"] = mod   # MUST come before exec_module
spec.loader.exec_module(mod)
```

### Guard assertion — add one per service test file
```python
def test_does_not_have_analyst_fields(self) -> None:
    body = json.loads(index.handler({}, _ctx())["body"])
    assert "summary" not in body   # would exist if wrong module loaded
```

```toml
[tool.pytest.ini_options]
addopts = "--import-mode=importlib"
testpaths = ["services"]
```

---

## PYTHON
- Functional-first, PEP 8, 88-char lines, 4-space indent
- Type hints mandatory on all functions (`str | None`, Python 3.10+)
- Prefer comprehensions over `map`/`filter` + lambda
- Immutability: `tuple`, `frozenset`, `dataclass(frozen=True)`
- Specific exceptions, early returns, no bare `except:`
- Data containers: `dataclass` or `NamedTuple`, never plain `class`

Tools: `black .` · `ruff check .` · `mypy src/` · `pytest`

**Flat-layout package discovery** — when `evals/`, `scripts/`, or `tests/` sit next to `app/`:
```toml
[tool.setuptools.packages.find]
include = ["app*"]   # prevents "Multiple top-level packages discovered"
```

---

## AWS SSO / IAM IDENTITY CENTER — DEVELOPER ONBOARDING GUIDE

This section covers the **developer-side** SSO flow — what you do when IT hands you access to a company AWS environment. Admin setup (Identity Center instances, permission sets, user assignments) is out of scope here.

### What IT gives you on day 1
| Item | Example |
|------|---------|
| SSO start URL | `https://acme-corp.awsapps.com/start` |
| SSO region | `us-east-1` (where Identity Center lives) |
| Account ID(s) | `123456789012` |
| Role name(s) | `DeveloperAccess`, `ReadOnlyAccess` |
| Session duration | 8h (set by admin on the permission set) |

### ~/.aws/config — exact format

One `[sso-session]` block is shared across all profiles. One `[profile]` block per account/role combination.

```ini
# ─── SSO SESSION (shared, one per Identity Center instance) ──────────────────
[sso-session acme-corp]
sso_start_url            = https://acme-corp.awsapps.com/start
sso_region               = us-east-1
sso_registration_scopes  = sso:account:access

# ─── DEVELOPER PROFILE — dev account ─────────────────────────────────────────
[profile acme-dev]
sso_session     = acme-corp
sso_account_id  = 123456789012
sso_role_name   = DeveloperAccess
region          = us-east-1
output          = json

# ─── READ-ONLY PROFILE — prod account ────────────────────────────────────────
[profile acme-prod-ro]
sso_session     = acme-corp
sso_account_id  = 999999999999
sso_role_name   = ReadOnlyAccess
region          = us-east-1
output          = json

# ─── INFRA PROFILE — elevated, IaC applies only ──────────────────────────────
[profile acme-infra]
sso_session     = acme-corp
sso_account_id  = 123456789012
sso_role_name   = InfrastructureAdmin
region          = us-east-1
output          = json
```

**Alternative: `aws configure sso` interactive wizard** (generates the same config)
```bash
# Run in cmd.exe or PowerShell (not Git Bash — terminal detection bug on Windows)
aws configure sso --profile acme-dev
# Prompts: SSO start URL → SSO region → browser opens → pick account → pick role → output format
```

### Day 1 setup (run once)

```bash
# 1. Write ~/.aws/config manually (preferred) OR use the wizard above
# 2. Login — opens browser to your IDP (Okta / Azure AD / Google Workspace)
aws sso login --profile acme-dev
#   Attempting to automatically open the SSO authorization page in your default browser.
#   If the browser does not open or you wish to use a different device to authorize this request,
#   open the following URL:
#   https://device.sso.us-east-1.amazonaws.com/
#   Enter the code: XXXX-XXXX
```

One `aws sso login` covers **all profiles sharing the same `[sso-session]`** — you don't need to login per profile.

### Daily use

```bash
# Inline flag — explicit per command
aws sts get-caller-identity --profile acme-dev
aws s3 ls --profile acme-dev

# Environment variable — sets default for the whole shell session
export AWS_PROFILE=acme-dev
aws sts get-caller-identity   # no flag needed

# PowerShell equivalent
$env:AWS_PROFILE = "acme-dev"
aws sts get-caller-identity
```

### How credentials flow (under the hood)

```
Browser login (IDP) → OIDC bearer token  → ~/.aws/sso/cache/<sha1-of-start-url>.json  (8h)
                                                   ↓  (auto-exchanged per role)
                                        STS temp creds → ~/.aws/cli/cache/<hash>.json  (1h, auto-refreshed)
```

Files written to disk:
```
~/.aws/sso/cache/
  ├── <sha1-of-start-url>.json          ← OIDC bearer token (lives for session-duration, default 8h)
  └── botocore-client-id-<region>.json  ← OIDC client registration

~/.aws/cli/cache/
  └── <hash-of-profile>.json            ← STS AssumeRoleWithWebIdentity creds (1h, auto-refreshed)
```

### Token expiry — re-login

```bash
# You'll see one of these errors when the token is expired:
#   Error loading SSO Token: Token for acme-corp does not exist
#   Token has expired and refresh failed

# Fix: just login again (browser → IDP → done in <30s)
aws sso login --profile acme-dev
```

### Logout (invalidate all cached tokens)

```bash
aws sso logout
# Deletes all ~/.aws/sso/cache/*.json — next aws call requires re-login
```

### Discover what accounts/roles you have access to

```bash
# 1. Get the access token from cache
TOKEN=$(cat ~/.aws/sso/cache/*.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['accessToken'])" 2>/dev/null)

# 2. List all accounts assigned to you
aws sso list-accounts \
  --access-token "$TOKEN" \
  --region us-east-1

# 3. List roles for a specific account
aws sso list-account-roles \
  --account-id 123456789012 \
  --access-token "$TOKEN" \
  --region us-east-1
```

### Terraform integration

Terraform picks up SSO credentials automatically when `AWS_PROFILE` is set or `profile` is configured in the provider block. **No changes to Terraform code needed.**

```bash
export AWS_PROFILE=acme-infra
terraform plan    # uses SSO creds transparently
terraform apply
```

Or pin in `provider.tf` (dev only — never hardcode in prod modules):
```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "acme-infra"   # reads from ~/.aws/config SSO profile
}
```

### CI/CD — SSO does NOT work in pipelines

SSO requires an interactive browser session. For CI:
- GitHub Actions → OIDC trust with IAM role (see Terraform OIDC rules above)
- Never put SSO credentials in CI — they expire and require human interaction

### Common errors and fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Token for X does not exist` | Never logged in or tokens deleted | `aws sso login --profile <name>` |
| `Token has expired` | 8h session elapsed | `aws sso login --profile <name>` |
| `InvalidGrantException` | IDP session expired server-side | `aws sso logout` then `aws sso login` |
| `No roles available` | Admin hasn't assigned your user yet | Contact IT/admin |
| `Found xterm-256color` (Windows) | `aws configure sso` in Git Bash | Run in PowerShell or cmd.exe instead |
| `AccessDenied` on a specific service | Permission set doesn't include that action | Request elevated role from admin |

---

## AWS SERVERLESS

### Lambda rules
- Single Responsibility: one Lambda, one concern
- Idempotent: identical requests N times = same result
- Stateless: state in DynamoDB / S3, never in Lambda memory
- Least Privilege: dedicated IAM role per function
- Dead Letter Queue on every async invocation
- Explicit timeout: never leave the 3s default
- X-Ray tracing in production

### Invocation patterns
```
Sync:      API Gateway → Lambda → Response          (max 29s)
Async:     EventBridge / SQS → Lambda → DLQ on fail
Workflow:  Step Functions → Lambda chain             (durable, stateful)
```

### API Gateway
- HTTP API over REST API (unless WAF/caching/usage plans required)
- Always attach Cognito or Lambda authorizer — no open endpoints

---

## AWS MULTI-AGENT ARCHITECTURE

### Three-layer model
```
Layer 1 — Macro Orchestration:  Step Functions (Express Workflows)
Layer 2 — Agent Orchestration:  Bedrock AgentCore + Strands Agents SDK
Layer 3 — Tools:                MCP tools exposed via Lambda
```

### Orchestration patterns
| Pattern | Use case |
|---------|----------|
| Supervisor + Sub-agent | LLM routes dynamically to specialists |
| Workflow / Graph | Deterministic multi-step pipeline |
| Map-Reduce | Parallel fan-out → aggregate |
| A2A Protocol | Heterogeneous agents across frameworks |

- Step Functions for deterministic stages; Express Workflows (<5 min); Standard for auditable pipelines
- Do NOT use Step Functions for dynamic agent reasoning loops — use Bedrock AgentCore

---

## TECH LEAD MINDSET

- Default to managed services over self-hosted
- Serverless-first for variable load; ECS Fargate for steady latency-sensitive load
- Design for failure: every external call has timeout + retry + circuit breaker
- Cost: right-size Lambda memory (128MB–1769MB)

### Code review checklist (infra)
- No hardcoded ARNs, account IDs, or region strings
- IAM policies follow least privilege (no `*` unless justified)
- All resources tagged; sensitive outputs marked `sensitive = true`
- No secrets in state file

### Ops
- Alarms on Lambda error rate, throttles, duration P99
- DLQ with alarm: any message = PagerDuty/SNS alert
- Blue/green via Lambda aliases + traffic shifting
- Document ADRs for non-obvious decisions

---

## NODE.JS / NESTJS
ESM, strict TypeScript, ESLint + Prettier on commit.

```bash
npx @nestjs/cli new project --package-manager npm --skip-git --strict
nest g module name --no-spec
nest g service name --no-spec --flat
nest g resource name --no-spec
```

MCP tool pattern:
```typescript
@Tool({ name: 'x', description: '...', parameters: z.object({ p: z.string() }) })
async myTool({ p }: { p: string }) {
  return { content: [{ type: 'text', text: JSON.stringify(result) }] };
}
```

---

## PLAYWRIGHT
Selectors: `getByRole('button',{name:'Write something...'})` · `getByRole('textbox')` · `getByRole('button',{name:'Post',exact:true})`

Batch: loop urls → `goto(domcontentloaded)` → click Write → `fill(textbox)` → click Post(exact) → `waitForTimeout(2000+rand*3000)`

---

## REACT / NEXT.JS
TypeScript strict, ESLint + Prettier, App Router (Next.js 14+).

### Conventions
- Components: named exports only (except `page.tsx` / `layout.tsx`)
- File structure: feature-based (`/features/auth/`, `/features/dashboard/`)
- State: local → Zustand → React Query. Never Redux unless pre-existing.
- Data fetching: React Query on client; `fetch` with `cache` on server components
- Forms: React Hook Form + Zod
- Styling: Tailwind CSS; no inline styles; no CSS modules unless required
- `next/image` over `<img>`; `next/link` over `<a>` for internal routes

### Performance
- Server Components by default; `"use client"` only when needed
- Dynamic imports for heavy components
- Suspense boundaries around async fetches

### Testing
- Unit: Jest + React Testing Library
- E2E: Playwright (`browser_run_code` only)
- Test files co-located: `Component.test.tsx` next to `Component.tsx`
- Queries: `getByRole` > `getByText` > `getByTestId`

```bash
npx create-next-app@latest project --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
```

### Code review checklist
- No `any` — use `unknown` + type guards
- No prop drilling >2 levels — context or Zustand
- Async errors handled (loading/error states visible)
- Accessible: semantic HTML, ARIA roles, keyboard navigable

---

## .gitignore
`.env` `.env.*` `*.pem` `*.key` `credentials.json` `*.tfstate` `*.tfstate.backup` `.terraform/` `node_modules/` `dist/` `.next/` `build/` `__pycache__/` `.venv/`

---

## LANGCHAIN / LANGGRAPH — PRODUCTION STANDARDS

### Framework selection
| Use case | Framework |
|----------|-----------|
| Linear chains, fixed steps | LCEL |
| Stateful agents, loops, branching | LangGraph |
| Multi-agent with persistence | LangGraph + checkpointer |
| RAG without agent loops | LCEL + retriever |

Never use legacy `LLMChain` / `ConversationalChain`.

### LCEL — core rules
```python
chain = prompt | llm | output_parser

# Always async in production
result = await chain.ainvoke({"input": user_query})
results = await chain.abatch([{"input": q} for q in queries])
async for chunk in chain.astream({"input": query}):
    yield chunk
```

### Structured output — always Pydantic + with_structured_output
```python
class AnalysisResult(BaseModel):
    summary: str = Field(description="One-sentence summary")
    confidence: float = Field(ge=0.0, le=1.0)
    tags: list[str]

structured_llm = llm.with_structured_output(AnalysisResult)
```

Never parse raw LLM text manually.

### LLM JSON coerce validator — unicode-normalizer fix (non-negotiable)
LLMs emit curly quotes and em-dashes that break `json.loads`. Every `field_validator` coercing `str → list/dict` must include:
```python
@field_validator("issues", "tags", mode="before")
@classmethod
def _coerce_json_string(cls, v: Any) -> Any:
    if not isinstance(v, str):
        return v
    try:
        return json.loads(v)
    except json.JSONDecodeError:
        cleaned = (
            v.replace("‘", "'").replace("’", "'")
             .replace("“", '"').replace("”", '"')
             .replace("—", "-").replace("–", "-")
             .replace("…", "...")
        )
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            return []   # never crash the pipeline
```

Apply to **every** model receiving LLM-generated list/dict fields.

### Error handling
```python
@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10) + wait_random(0, 1),
    reraise=True,
)
async def call_llm(chain, inputs: dict) -> dict:
    return await chain.ainvoke(inputs)
```

Retryable: timeouts, 5xx, connection errors. Non-retryable: 4xx, auth failures.

### LangGraph — stateful agents
```python
class AgentState(TypedDict):
    messages: Annotated[list, operator.add]
    context: str

graph = StateGraph(AgentState)
graph.add_node("agent", agent_node)
graph.add_node("tools", tool_node)
graph.set_entry_point("agent")
graph.add_conditional_edges("agent", should_continue)
graph.add_edge("tools", "agent")

# Production: PostgresSaver; dev: MemorySaver
app = graph.compile(checkpointer=PostgresSaver.from_conn_string(DB_URL))

result = await app.ainvoke(
    {"messages": [HumanMessage(content=user_input)]},
    config={"configurable": {"thread_id": session_id}},
)
```

### Checkpointer selection
| Environment | Checkpointer |
|-------------|--------------|
| Dev | `MemorySaver` |
| Prod (PostgreSQL) | `PostgresSaver` |
| Prod (AWS) | `DynamoDBSaver` |
| Prod (MongoDB) | `MongoDBStore` |

### Local LLM — Ollama cost-control switch
Single env var `USE_LOCAL_LLM=true` routes the whole pipeline to Ollama. All agents call `get_llm(role)` — never instantiate `ChatAnthropic` directly.

```python
def get_llm(role: str = "worker", **kwargs: object) -> BaseChatModel:
    if settings.use_local_llm:
        from langchain_ollama import ChatOllama
        return ChatOllama(model=settings.local_llm_model,
                          base_url=settings.local_llm_base_url, **kwargs)
    from langchain_anthropic import ChatAnthropic
    model = settings.supervisor_model if role == "supervisor" else settings.worker_model
    return ChatAnthropic(model=model, api_key=settings.anthropic_api_key, **kwargs)
```

Rules:
- `_DEFAULT_PRICING = (0.0, 0.0)` in cost tracker for local models
- `local_llm_base_url = "http://ollama:11434"` inside Docker, `"http://localhost:11434"` outside
- `USE_LOCAL_LLM` is the only code path that changes — never add `if use_local_llm:` inside agents

### FastAPI SSE — streaming background task to browser
```python
@router.get("/pipeline/runs/{run_id}/stream")
async def stream_logs(run_id: str, request: Request) -> StreamingResponse:
    async def event_generator():
        db = get_db()
        seen_count = 0
        while True:
            if await request.is_disconnected():
                break
            logs = await db.agent_logs.find({"run_id": run_id}, {"_id": 0},
                sort=[("timestamp", 1)]).skip(seen_count).to_list(length=100)
            for log in logs:
                seen_count += 1
                yield f"data: {json.dumps(log, default=str)}\n\n"
            run = await db.pipeline_runs.find_one({"run_id": run_id}, {"status": 1})
            if run and run.get("status") in {"completed", "failed"}:
                yield 'data: {"__done__": true}\n\n'
                break
            await asyncio.sleep(1.5)
    return StreamingResponse(event_generator(), media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})
```

SSE rules:
- `__done__: true` sentinel closes stream — never rely on connection drop
- `X-Accel-Buffering: no` required when Nginx is in front
- `EventSource` has no custom header support — pass auth as query param
- `onerror` fires on drop AND server close — always close + transition state

### Prompt versioning — git-native
Prompts are code. Store as `.txt` in `prompts/`, version in git, gate through eval CI.

```python
# app/prompt_loader.py
_CACHE: dict[str, str] = {p.stem: p.read_text(encoding="utf-8")
                          for p in (_PROMPTS_DIR := Path(__file__).parent.parent / "prompts").glob("*.txt")}

def load_prompt(name: str) -> str:
    try:
        return _CACHE[name]
    except KeyError:
        raise KeyError(f"Prompt '{name}' not found. Available: {sorted(_CACHE.keys())}") from None
```

Rules:
- One file per prompt — never combine system + human
- Template vars use `.format()` syntax: `{title}`, `{content}`
- `load_prompt` raises at startup — fail fast

### LLMOps — 3-layer eval architecture
```
Layer 1 — Score direction    ~$0.002/case  Haiku   CI gate: block PR on fail
Layer 2 — Batch regression   ~$0.04 total  Haiku   Catches calibration drift
Layer 3 — LLM-as-judge       ~$0.005/case  Sonnet  Nightly only (eval_deep marker)
```

Rules:
- Curated dataset 20–200 cases per agent in `evals/datasets/` as JSONL
- CI gate runs Layer 1+2 only (`-m "not eval_deep"`) — under 5 min, under $0.05
- `autouse` mock_db fixture in evals conftest — evals must never depend on real DB
- Path filter in eval workflow: `backend/app/agents/**`, `backend/prompts/**`, `backend/evals/**`
- Gate threshold: score_direction accuracy >= 75%

### Model selection by role
| Role | Model tier |
|------|-----------|
| Supervisor / orchestrator | Claude Sonnet / GPT-4o |
| Specialist workers | Claude Haiku / GPT-4o-mini |
| Embedding | text-embedding-3-small |
| Eval judge | GPT-4o |

Always parameterize model names — never hardcode inline.

### Code review checklist (LangChain/LangGraph)
- No legacy `LLMChain` / `ConversationChain`
- Structured output via `.with_structured_output(PydanticModel)` — no raw text parsing
- Async methods in async contexts (`.ainvoke`, `.astream`) — no blocking `.invoke` in FastAPI
- Each LangGraph node is a pure function — no side effects beyond returning new state
- Thread IDs are user/session scoped — never reused across users
- Checkpointer is production-grade (not `MemorySaver`)
- LangSmith tracing enabled and project name set per environment
- All prompts in `prompts/` — none hardcoded in agent files
- `get_llm(role)` factory used everywhere — no direct `ChatAnthropic` instantiation

---

## README STANDARD — PORTFOLIO-GRADE TEMPLATE (non-negotiable)

Every new project README must follow the structure below. This template is derived from `medium-agent-factory` — a production LLMOps project with a validated, portfolio-grade README. Never generate a minimal README. Never generate one section without the others.

### Required sections in order

1. **Centered header block** (HTML `<div align="center">`)
   - Project title as `# H1`
   - Badge row: CI badge, language/framework badges, license badge — all on one line using `[![label](shield-url)](link)` syntax
   - One-sentence tagline in bold describing what the project does and its measurable outcome
   - Links line: `[Live Demo](url) | Backend hosted on Platform | [View Source](url)`

2. **`## The Problem`**
   - 2–4 paragraphs. Open with a specific, painful scenario — something any developer would recognize. Name the exact failure mode (suspiciously round statistics, no sources, word count 1,062 not 1,300). End with a rhetorical question that the project answers. No bullet points here — prose only. The problem section is a narrative hook, not a feature list.

3. **`## Live Demo`** (if deployed)
   - URL + platform note. Include cold-start warning for free-tier services.

4. **`## How It Works — The Story Arc`**
   - Three `### Act N — Title` subsections. Each act is 1–3 paragraphs covering one generation of the architecture: what it was, what insight changed it, what it became. No bullet points — prose only. End with a **validation run table** (post | words | score | eligible | revisions).

5. **`## Architecture`**
   - Two named `### SubSection` blocks, each with a fenced `mermaid` flowchart (`flowchart TD`). First diagram: full pipeline end-to-end. Second diagram: the core quality/eval sub-system.

6. **`## Quality Gates`** (or equivalent decision table)
   - Table: Gate | Config Key | Threshold | What It Blocks. 4+ rows. Config keys must match actual env var names.

7. **`## G-Eval Axes`** (or equivalent rubric table)
   - Formula line: `score = mean(axis1, axis2, ...)`. Table: Axis | 1.0 Description | 0.0 Description. Descriptions are concrete behaviors, not abstract adjectives.

8. **`## Tech Stack`**
   - Two-column table: Layer | Technology. Group by concern (orchestration, LLM, storage, API, frontend, testing, CI/CD, deploy). No prose.

9. **`## LLMOps`**
   - `### 3-Layer Eval Architecture` — table (Layer | Cost | Model | Trigger | Gate) + 2-sentence explanation of CI cost and time budget
   - `### Prompt Versioning` — 1 paragraph + code block showing `prompt_loader.py` pattern
   - `### LangSmith Tracing` — 1 paragraph listing trace metadata fields
   - `### Quality Snapshot Analytics` — 1 paragraph + JSON example + aggregation query

10. **`## Test Suite`**
    - Lead line: `N total — X backend + Y frontend. TDD throughout (Red → Green → Refactor).` Then one sentence about the rule (no `// TODO: add tests`). Directory tree with inline comments (`← what each file tests`). Frontend glob pattern.

11. **`## Quick Start`**
    - `### Prerequisites` list (Python version, Node version, DB, API keys)
    - `### Backend` — bash block: venv, OS-specific activate (Git Bash + macOS/Linux), pip install, cp .env.example, PowerShell Start-Process server start, pytest
    - `### Frontend` — bash block: npm install, cp .env.local.example, npm run dev
    - `### Generate a post` (or equivalent API call) — curl examples for the primary endpoint + stream + secondary endpoint
    - `### Docker` — `docker compose up --build`

12. **`## Alternative LLM Backends`** (if applicable)
    - 1 paragraph on the factory pattern. Bash block with 2+ `USE_X=true` examples. Docker note for base URL.

13. **`## Environment Variables`**
    - Three-column table: Variable | Default | Description. Cover all env vars. Mark required ones with `—` in Default.

14. **`## Skills Demonstrated`**
    - Opening sentence: "This project was built as a portfolio piece demonstrating production-grade [domain] engineering." Table: Skill | Where — `Where` column links to actual file paths (e.g., `backend/app/agents/orchestrator.py`). 8–12 rows. Each skill names the specific technique and standard (e.g., "G-Eval LLM-as-judge (EMNLP 2023)").

15. **`## Project Structure`**
    - Single fenced code block. Two-level tree (no more). Inline `←` comments on key files only. Group: backend/app/agents, backend/app/routers, backend/prompts, backend/evals, frontend/src/components, infra/, .github/workflows/.

16. **`<details><summary>Sprint History</summary>`**
    - Collapsible. Table: Sprint | What Shipped. At least 10 rows. Written in past tense, concrete deliverables ("G-Eval rubric: 4 axes, 0.0–1.0 scale"), not vague ("improved quality").

17. **`## License`**
    - One line: `MIT — see [LICENSE](LICENSE).`

### What makes the README stand out

- **Prose narrative** in The Problem and Story Arc — no bullet lists in those two sections
- **Validation run data** — real numbers from a real run, not placeholders
- **Mermaid diagrams** — two, always, always `flowchart TD`
- **Skills table maps to file paths** — reviewer can click and find the code
- **Sprint history in `<details>`** — shows velocity + learning arc without cluttering the page
- **Config keys match code** — every env var in the table must exist in `config.py` / `.env.example`
- **OS-specific Quick Start** — Git Bash activate AND macOS/Linux activate; PowerShell for background server

### Anti-patterns to avoid
- Generic tagline like "A Python project" — must describe measurable output
- Bullet-list Problem section — kills the narrative hook
- Missing Mermaid diagrams — they are non-negotiable
- `// TODO: add tests` anywhere in test directory tree
- Skills table with vague entries like "Used LangChain" — name the pattern, cite the paper/spec
- Placeholder data like `N/A` or `TBD` in the validation run table — run it first
