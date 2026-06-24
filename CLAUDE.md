# Tech Lead · Fullstack · DevOps — React/Next.js · Python · Node.js/NestJS · AWS · Terraform · LangChain/LangGraph

## ROLE
Act as a senior tech lead and DevOps engineer. Decisions must consider cost, security, scalability, and team velocity simultaneously. Always propose the simplest solution that satisfies production requirements — no premature complexity. When reviewing code or infra, surface risks, not just errors.

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

## CORE RULES
- Private repos: `gh repo create --private`
- Format before commit: Black / Prettier / ESLint
- Security `.gitignore` on every repo
- NestJS: CLI only, never hand-write boilerplate
- Playwright: `browser_run_code` only, never `browser_snapshot`
- IaC: Terraform only, never click-ops in AWS console for persistent resources
- Secrets: AWS Secrets Manager or SSM Parameter Store — never in code, `.env` files, or Terraform `.tfvars` committed to git
- Naming: `{project}-{env}-{service}-{resource}` (e.g. `autofact-prod-orchestrator-lambda`)
- Tagging: every AWS resource gets `Environment`, `Project`, `ManagedBy=terraform`
- Branch name: run `git branch --show-current` before writing any workflow `branches:` trigger — never assume `main`

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
- **Installing system tools**: prefer `winget` over MSI — winget handles elevation automatically and doesn't require admin prompt.

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

## AWS ACCOUNT ONBOARDING — NEW JOB SETUP

Automates the full developer onboarding flow when starting at a new company with an AWS account. Run steps in order on day one.

### Step 1 — Install AWS CLI v2 (Windows / PowerShell)
```powershell
# winget handles elevation automatically — no UAC dialog needed
winget install --id Amazon.AWSCLI --silent --accept-package-agreements --accept-source-agreements

# Open a NEW terminal, then verify
aws --version   # aws-cli/2.x.x Python/3.x.x Windows/10
```

Do NOT use the MSI installer directly — it fails with exit code 1603 (insufficient privileges) without admin shell. winget resolves this automatically.

### Step 1b — Create a non-root IAM user immediately (if given root credentials)
Root access keys are a critical security risk. As soon as the CLI works, create a dedicated IAM user and switch to it:
```bash
AWS="C:/Program Files/Amazon/AWSCLIV2/aws.exe"   # always use full path on Windows

# Create user
"$AWS" iam create-user --user-name dev-admin

# Grant admin access
"$AWS" iam attach-user-policy \
  --user-name dev-admin \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access keys for the new user
"$AWS" iam create-access-key --user-name dev-admin
# → copy the new AccessKeyId and SecretAccessKey from the output

# Reconfigure CLI with the new non-root credentials
"$AWS" configure set aws_access_key_id     <new-key-id>
"$AWS" configure set aws_secret_access_key <new-secret>

# Verify — Arn must now show user/dev-admin, not root
"$AWS" sts get-caller-identity
```

Then go to the AWS Console and **delete the root access keys** at:
https://console.aws.amazon.com/iam/home#/security_credentials

### Step 2 — Configure SSO profile (run once per account)
```bash
aws configure sso
# Interactive prompts:
#   SSO session name:        my-company          ← memorable alias
#   SSO start URL:           https://my-company.awsapps.com/start
#   SSO region:              us-east-1           ← the region where IAM Identity Center lives
#   SSO registration scopes: sso:account:access  ← press Enter for default
#
# AWS lists the accounts and roles you have access to — select the target
#   Account:  123456789012 (my-company-dev)
#   Role:     DevAccess
#
# Default output format: json
# Profile name: my-company-dev                   ← use {company}-{env} convention
```

### Step 3 — Login (URL appears in terminal — open it in browser)
```bash
aws sso login --profile my-company-dev
```

Output:
```
Attempting to automatically open the SSO authorization page in your default browser.
If the browser does not open or you wish to use a different device to authorize this
request, open the following URL:

https://device.sso.us-east-1.amazonaws.com/?user_code=XXXX-XXXX   ← CLICK THIS

Then enter the code: XXXX-XXXX
```

Rules:
- If the browser doesn't open automatically, copy the URL and open it manually
- Click **Allow** in the browser → return to terminal → session is now active
- The device code expires in ~10 minutes — act quickly
- Sessions last 8h by default; run `aws sso login --profile <name>` again when expired

### Step 4 — Verify login and set default profile
```bash
# Confirm identity
aws sts get-caller-identity --profile my-company-dev
# Returns: { "UserId": "...", "Account": "123456789012", "Arn": "arn:aws:sts::..." }

# Set as default for current terminal session
export AWS_PROFILE=my-company-dev            # bash / Git Bash
$env:AWS_PROFILE = "my-company-dev"          # PowerShell

# Persist across sessions — add to shell profile
echo 'export AWS_PROFILE=my-company-dev' >> ~/.bashrc   # bash
# PowerShell: Add to $PROFILE: $env:AWS_PROFILE = "my-company-dev"
```

### Step 5 — Check effective permissions (day-one sanity checks)
```bash
# Who am I?
aws sts get-caller-identity

# What can I reach?
aws s3 ls                          # list buckets
aws lambda list-functions          # list Lambdas (paginated)
aws ec2 describe-regions           # basic EC2 access
aws logs describe-log-groups       # CloudWatch Logs

# What permissions does this role have?
aws iam list-attached-role-policies \
  --role-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2) 2>/dev/null || \
aws iam get-user 2>/dev/null
```

### Step 6 — Terraform backend bootstrap (run once per fresh account)
Run this before the first `terraform init`. Creates S3 state bucket + DynamoDB lock table.

```bash
# Set once; all commands below use these vars
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ENV=dev          # or prod
export PROJECT=myproject
export REGION=us-east-1

# --- S3 state bucket ---
aws s3api create-bucket \
  --bucket "${PROJECT}-${ENV}-terraform-state-${ACCOUNT_ID}" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

aws s3api put-bucket-versioning \
  --bucket "${PROJECT}-${ENV}-terraform-state-${ACCOUNT_ID}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${PROJECT}-${ENV}-terraform-state-${ACCOUNT_ID}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "${PROJECT}-${ENV}-terraform-state-${ACCOUNT_ID}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# --- DynamoDB lock table ---
aws dynamodb create-table \
  --table-name "${PROJECT}-${ENV}-terraform-lock" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo "Bootstrap done. Add this to infra/envs/${ENV}/backend.tf:"
cat <<EOF
terraform {
  backend "s3" {
    bucket         = "${PROJECT}-${ENV}-terraform-state-${ACCOUNT_ID}"
    key            = "${ENV}/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${PROJECT}-${ENV}-terraform-lock"
    encrypt        = true
  }
}
EOF
```

### Windows AWS CLI — non-negotiable rules (learned from real failures)

**Always use the full binary path** — `aws` is not on PATH in a fresh shell until the terminal is restarted after install:
```bash
AWS="C:/Program Files/Amazon/AWSCLIV2/aws.exe"
"$AWS" sts get-caller-identity
```

**Never pass JSON inline from PowerShell** — PowerShell mangles the quotes. Two safe patterns:

```bash
# Pattern A: single-quoted string in Git Bash (recommended)
"$AWS" iam create-role \
  --role-name my-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[...]}'

# Pattern B: write to file, pass with fileb:// for binary (zip) or as string for JSON
[System.IO.File]::WriteAllText("C:\tmp\policy.json", '{"Version":...}')  # no BOM
"$AWS" iam create-role --assume-role-policy-document (Get-Content "C:\tmp\policy.json" -Raw)
```

**`file://` paths don't work on Windows** for `--assume-role-policy-document`. Use inline JSON (Bash) or `Get-Content -Raw` (PowerShell) instead.

**`fileb://` paths for zip files** require forward slashes:
```bash
"$AWS" lambda create-function --zip-file "fileb://C:/Users/you/function.zip" ...
```

**IAM propagation delay** — always `Start-Sleep 12` (PowerShell) or `sleep 12` (bash) between `create-role` and `lambda create-function`. Without this, Lambda returns `InvalidParameterValueException: cannot be assumed`.

### New-job day-one checklist
- [ ] AWS CLI v2 installed — `aws --version`
- [ ] SSO profile configured — `aws configure sso`
- [ ] Login completed — `aws sso login --profile <name>`
- [ ] Identity verified — `aws sts get-caller-identity`
- [ ] `AWS_PROFILE` persisted in shell profile
- [ ] Permissions checked — `aws s3 ls`, `aws lambda list-functions`
- [ ] Terraform state bootstrap done (or confirmed bucket/table already exists)
- [ ] `backend.tf` written with correct bucket/table/region
- [ ] AGENTS.md + CLAUDE.md created in the repo root
- [ ] `claude/CONTEXT.md` created with current state

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
