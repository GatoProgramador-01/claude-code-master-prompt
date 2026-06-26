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

### Model per role — always set explicitly in agent frontmatter

| Role | `model:` | Reason |
|------|----------|--------|
| File search, grep, lint, format, build check | `haiku` | 10× cheaper than Sonnet; no reasoning required |
| Code review, test writing, implementation | `sonnet` | Daily default — balanced reasoning and cost |
| Architecture decisions, complex tradeoffs | `opus` | Rare; only when Sonnet falls short |

Never rely on `inherit` (copies parent model). An Opus parent spawning 5 Haiku workers saves ~80% on research tasks.

### maxTurns per agent type (mandatory)
```yaml
maxTurns: 6    # research / explore — return findings fast
maxTurns: 8    # leaf workers — deterministic tasks (lint, build, test)
maxTurns: 15   # implementation agents — need iteration cycles
maxTurns: 12   # coordinator agents — spawn and collect sub-agents
```

### Context rules
- Sub-agents receive **only their delegation prompt** — NOT the parent's conversation history. Write delegation prompts of 200–500 tokens max. Never paste full conversation.
- **Explore / Plan agents skip CLAUDE.md entirely** — use them for all read-only searches (cheapest option).
- Parent sees **only the final summary** from each sub-agent. A sub-agent doing 50K tokens of work returns a ~200 token summary to parent. Use `background: true` to prevent even that from blocking.
- `context: fork` gives the sub-agent the full parent conversation — use only when the sub-agent genuinely needs it (rare).

### Tool call efficiency
- Always pass `head_limit: 20` to Grep — prevents 100+ match returns that bloat context 90%.
- `allowed-tools` in agent frontmatter = **security + focus only**, does NOT reduce token count (tool schemas still load).
- Batch independent Read / Grep / Glob calls in one message (latency savings, marginal token savings).

### Prompt cache management
- **Never switch models mid-session** — invalidates the entire prompt cache (full recompute on next turn).
- Run `/compact` at task boundaries, not mid-task. Preserves system + project cache layer.
- Order CLAUDE.md: stable rules first (architecture, style) → volatile info last (sprint goals, blockers).
- Batch related queries in one session instead of multiple sessions: ~87% token savings on cache reads.
- API key users: set `ENABLE_PROMPT_CACHING_1H=1` to extend TTL from 5 min to 1 hour.

### CLAUDE.md size target
This file targets **200 lines**. Extended domain rules live in `.claude/rules/<domain>/<topic>.md` with `paths:` frontmatter — they load **only when a matching file is read**, costing zero tokens otherwise.

| Rule type | Where it lives | When it loads |
|-----------|---------------|---------------|
| Core cross-cutting rules | Root `CLAUDE.md` | Every turn |
| Language/framework rules | `.claude/rules/<domain>/*.md` with `paths:` | Only when matching file is read |
| Repeatable workflows | `.claude/skills/<name>/SKILL.md` | Only when `/skill` invoked |
| Reusable agent behaviors | `.claude/agents/<name>.md` | Only when agent is spawned |

**`@file` imports in CLAUDE.md are NOT lazy** — they expand at load time and add to per-turn cost.  
Rules in `.claude/rules/` **without** `paths:` load unconditionally at session start (same as CLAUDE.md).

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
