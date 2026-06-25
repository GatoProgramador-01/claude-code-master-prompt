<div align="center">

# Claude Code Master Prompt

**A battle-tested `CLAUDE.md` that turns Claude Code into a senior Tech Lead, DevOps engineer, and LLMOps practitioner — from the first message.**

[![Last Commit](https://img.shields.io/github/last-commit/GatoProgramador-01/claude-code-master-prompt?style=flat-square)](https://github.com/GatoProgramador-01/claude-code-master-prompt/commits/main)
[![CLAUDE.md size](https://img.shields.io/github/size/GatoProgramador-01/claude-code-master-prompt/CLAUDE.md?style=flat-square&label=CLAUDE.md)](https://github.com/GatoProgramador-01/claude-code-master-prompt/blob/main/CLAUDE.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

[![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Next.js](https://img.shields.io/badge/Next.js-000000?style=flat-square&logo=nextdotjs&logoColor=white)](https://nextjs.org/)
[![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![LangChain](https://img.shields.io/badge/LangChain-1C3C3C?style=flat-square&logo=langchain&logoColor=white)](https://www.langchain.com/)

</div>

---

## The problem

Claude Code out of the box is powerful. But without structure, it:

- writes tests **after** the implementation, or not at all
- commits secrets in `.env` files
- uses deprecated LangChain patterns (`LLMChain`, `ConversationChain`)
- writes Terraform HCL with syntax errors (commas in attribute blocks, floating `lifecycle`)
- assumes `main` branch without checking — breaks GitHub Actions
- ignores Windows shell quirks that silently break builds
- ships Lambda functions without DLQs, X-Ray, or explicit timeouts

**The fix is a single file.**

---

## What this is

A `CLAUDE.md` — the instruction set Claude Code loads before every session. Every rule in it was discovered through a **real production failure**, not documentation. Drop it in your home directory and Claude Code instantly operates like a senior engineer who has already made every mistake once.

```
You type: "add a new endpoint to list users"

Claude without this:
  writes the handler, maybe adds a test at the end

Claude with this CLAUDE.md:
  1. writes the failing pytest test first          ← Red
  2. writes the minimal FastAPI handler             ← Green
  3. cleans up, adds type hints, checks mypy       ← Refactor
  4. verifies no secrets, no bare except:
  5. flags what CI jobs need updating
```

---

## Install

### Global — applies to every Claude Code session on this machine

```bash
curl -o ~/CLAUDE.md \
  https://raw.githubusercontent.com/GatoProgramador-01/claude-code-master-prompt/main/CLAUDE.md
```

### Per project — only affects this repo

```bash
curl -o ./CLAUDE.md \
  https://raw.githubusercontent.com/GatoProgramador-01/claude-code-master-prompt/main/CLAUDE.md
```

Claude Code loads `CLAUDE.md` from (highest priority first):

```
./CLAUDE.md           project root
~/CLAUDE.md           home directory  ← recommended global install
~/.claude/CLAUDE.md   Claude config dir
```

---

## What's covered

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       CLAUDE CODE + MASTER PROMPT                       │
├───────────────────┬─────────────────────────────────────────────────────┤
│  METHODOLOGY      │  TDD (Red → Green → Refactor) — non-negotiable      │
├───────────────────┼─────────────────────────────────────────────────────┤
│  BACKEND          │  FastAPI · Python 3.10+ · pytest · mypy · ruff      │
│                   │  Motor (async MongoDB) · pydantic v2 · httpx        │
├───────────────────┼─────────────────────────────────────────────────────┤
│  FRONTEND         │  Next.js 14+ App Router · React Query · Zod         │
│                   │  Tailwind · React Testing Library · Playwright E2E  │
├───────────────────┼─────────────────────────────────────────────────────┤
│  API SERVER       │  NestJS · ESM · strict TypeScript · MCP tools       │
├───────────────────┼─────────────────────────────────────────────────────┤
│  AI / AGENTS      │  LangChain LCEL · LangGraph stateful agents         │
│                   │  Ollama local switch · SSE streaming · LLMOps       │
│                   │  3-layer eval architecture · prompt versioning       │
├───────────────────┼─────────────────────────────────────────────────────┤
│  INFRA (IaC)      │  Terraform · AWS Lambda · Step Functions            │
│                   │  API Gateway · Bedrock AgentCore · S3 · DynamoDB    │
│                   │  OIDC GitHub → IAM · remote state bootstrap         │
├───────────────────┼─────────────────────────────────────────────────────┤
│  CI/CD            │  5-job GitHub Actions pipeline · ruff/black/mypy    │
│                   │  pytest E2E with real MongoDB · Playwright CI        │
│                   │  Docker build validation                             │
├───────────────────┼─────────────────────────────────────────────────────┤
│  ONBOARDING       │  AWS SSO / IAM Identity Center day-1 guide          │
│                   │  Terraform state bootstrap automation                │
│                   │  Windows 10 CLI gotchas (Git Bash + PowerShell)     │
└───────────────────┴─────────────────────────────────────────────────────┘
```

---

## Rules that ship with it

<details>
<summary><strong>TDD — enforced on every change</strong></summary>

```
New endpoint    →  write pytest test  →  run (red)  →  write handler    →  run (green)  →  refactor
New component   →  write RTL test     →  run (red)  →  write component  →  run (green)  →  refactor
Bug fix         →  write failing test that reproduces the bug, then fix the code
```

No `// TODO: add tests`. Tests exist at the same commit as the code or the PR doesn't merge.

</details>

<details>
<summary><strong>Terraform — HCL syntax rules (from real CI failures)</strong></summary>

```hcl
# WRONG — commas don't exist in HCL attribute blocks
variable "x" { type = string, description = "..." }

# CORRECT — newlines only
variable "x" {
  type        = string
  description = "..."
}
```

```hcl
# WRONG — filebase64sha256 on a pre-built zip misses source changes
source_code_hash = filebase64sha256(var.zip_path)

# CORRECT — archive_file builds the zip from source during plan
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.builds/${var.function_name}.zip"
}
resource "aws_lambda_function" "this" {
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
}
```

```hcl
# WRONG — lifecycle block floating at file level is invalid HCL
lifecycle { prevent_destroy = true }

resource "aws_s3_bucket" "state" { ... }

# CORRECT — lifecycle is always inside the resource block
resource "aws_s3_bucket" "state" {
  bucket    = "..."
  lifecycle { prevent_destroy = true }
}
```

</details>

<details>
<summary><strong>CI/CD — things that break silently in GitHub Actions</strong></summary>

| Problem | What breaks | The fix |
|---------|-------------|---------|
| `npm ci` on Windows lock file | `Missing: @emnapi/runtime from lock file` | Use `npm install` + Node 24 |
| `next lint` without `.eslintrc.json` | Opens interactive prompt → exits 1 in CI | Always create `{ "extends": "next/core-web-vitals" }` |
| pytest-asyncio + Motor (async MongoDB) | `Event loop is closed` on every E2E test | Sync PyMongo cleanup + reset Motor singleton before each test |
| `ruff select` in `[tool.ruff]` | Silently ignored in ruff ≥ 0.8 | Move to `[tool.ruff.lint]` |
| `black target-version` mismatch | Format passes locally, fails in CI | Must match `setup-python: python-version` exactly |
| Bash `while read` inside a pipe | All array assignments lost (subshell scope) | Use `mapfile -t ENVS < <(some_cmd)` |
| `git branch` assumed `main` | Workflow only fires on `master`, or vice versa | Always run `git branch --show-current` before writing `branches:` |

</details>

<details>
<summary><strong>LangChain / LangGraph — production patterns</strong></summary>

```python
# NEVER — deprecated chains
from langchain.chains import LLMChain, ConversationalRetrievalChain

# ALWAYS — LCEL + structured output via Pydantic
class AnalysisResult(BaseModel):
    summary: str = Field(description="One-sentence summary")
    confidence: float = Field(ge=0.0, le=1.0)
    tags: list[str]

chain = prompt | llm.with_structured_output(AnalysisResult)
result = await chain.ainvoke({"input": text})   # always async in FastAPI
```

LLMs emit curly quotes (`"`) and em-dashes (`—`) that silently break `json.loads`. Every Pydantic model that receives LLM-generated list/dict fields includes the unicode-normalizer fallback validator — preventing a class of crashes that never shows up in unit tests but always happens in production.

**LLMOps eval architecture** (3 layers):
```
Layer 1 — Score direction    ~$0.002/case   Haiku    CI gate: blocks the PR
Layer 2 — Batch regression   ~$0.04 total   Haiku    Catches calibration drift
Layer 3 — LLM-as-judge       ~$0.005/case   Sonnet   Nightly only
```

</details>

<details>
<summary><strong>AWS multi-agent architecture</strong></summary>

```
Layer 1 — Macro Orchestration   Step Functions (Express Workflows)
Layer 2 — Agent Orchestration   Bedrock AgentCore + Strands Agents SDK
Layer 3 — Tools                 MCP tools exposed via Lambda
```

| Pattern | When to use |
|---------|-------------|
| Supervisor + Sub-agent | LLM routes dynamically to specialists |
| Workflow / Graph | Deterministic multi-step pipeline |
| Map-Reduce | Parallel fan-out → aggregate result |
| A2A Protocol | Heterogeneous agents across frameworks |

Rule: Step Functions for deterministic stages. Never Step Functions for dynamic agent reasoning loops — that's what Bedrock AgentCore is for.

</details>

<details>
<summary><strong>AWS SSO — developer onboarding baked in</strong></summary>

The prompt includes a complete guide for day one at a new company with AWS access:

```bash
# IT gives you: start URL · SSO region · account ID · role name

# 1. Write ~/.aws/config
[sso-session acme-corp]
sso_start_url   = https://acme-corp.awsapps.com/start
sso_region      = us-east-1

[profile acme-dev]
sso_session     = acme-corp
sso_account_id  = 123456789012
sso_role_name   = DeveloperAccess
region          = us-east-1

# 2. Login (opens browser → IDP → done)
aws sso login --profile acme-dev

# 3. Verify
aws sts get-caller-identity --profile acme-dev

# 4. Bootstrap Terraform state (run once per fresh account)
aws s3api create-bucket --bucket myproject-dev-terraform-state-123456789012 ...
aws dynamodb create-table --table-name myproject-dev-terraform-lock ...
```

Also covers: token expiry, logout, account/role discovery, Terraform integration, CI/CD warning (SSO requires a browser — never use it in pipelines).

</details>

---

## How it fits into Claude Code

```
┌──────────────────────────────────────────────────────────────────────┐
│  Layer          │  What it holds                                      │
├─────────────────┼─────────────────────────────────────────────────────┤
│  Memory         │  Who you are · your preferences · project context   │
│  CLAUDE.md      │  Rules applied to every session          ← this     │
│  Skills         │  On-demand workflows (/review, /simplify, ...)      │
│  Hooks          │  Shell commands that fire on events (auto-format)   │
└──────────────────────────────────────────────────────────────────────┘
```

Claude Code has four persistence layers. This repo covers the most impactful one: the **rules layer** — the set of decisions Claude makes automatically before you type a word.

---

## Skills (slash commands)

| Command | What it does |
|---------|-------------|
| `/init` | Scans the repo, generates a project-specific `CLAUDE.md` |
| `/review` | Full code review of current branch diff — or `/review 42` for a GitHub PR |
| `/security-review` | OWASP Top 10 audit of staged changes — run before pushing auth/API code |
| `/simplify` | Audits changed code for duplication and unnecessary complexity, then fixes it |
| `/claude-api` | Workflow for Anthropic SDK apps — caching, tool use, model migration |
| `/update-config` | Edits `settings.json` to wire up hooks for automatic formatting on commit |
| `/fewer-permission-prompts` | Reads session transcripts, builds an allowlist to cut daily approval friction |
| `/loop` | Runs a prompt or command on a recurring interval |
| `/schedule` | Creates scheduled remote agents that persist between sessions |

---

## Repo structure

```
claude-code-master-prompt/
├── CLAUDE.md                      ← install this globally
├── SKILLS.md                      ← slash command reference card
├── SECURITY_BEST_PRACTICES.md     ← security checklist for production code
├── bootstrap-prompt.md            ← OS-aware machine setup (git, gh, AWS CLI)
├── OPTIMIZATION_INVESTIGATION.md  ← prompt token / latency analysis
├── .env.example                   ← environment variable reference
└── memory/                        ← persistent memory files Claude writes to
```

---

## Built with this prompt

Projects developed end-to-end using this `CLAUDE.md` as the AI pair programmer's instruction set:

### [medium-agent-factory](https://github.com/GatoProgramador-01/medium-agent-factory)

A LangGraph multi-agent pipeline that researches, writes, fact-checks, and iteratively revises Medium posts until every quality gate passes.

```
306 tests (248 backend + 58 frontend) · TDD throughout · 41 sprints
```

| What it demonstrates | Technology |
|---------------------|-----------|
| Stateful multi-agent orchestration | LangGraph (StateGraph + conditional edges) |
| LLM-as-judge evaluation | G-Eval 4-axis rubric (EMNLP 2023) |
| Parallel async fact-checking | Tavily claim extraction + verification |
| 3-layer quality architecture | Deterministic (Python) + LLM rubric + config gates |
| SSE streaming | FastAPI → Next.js EventSource |
| LLMOps | Eval-in-CI, prompt versioning, LangSmith tracing |
| Multi-model cost switching | Anthropic / DeepSeek / Ollama — single factory fn |
| AWS IaC | Terraform: App Runner + ECS Fargate options |
| CI/CD | 5-job GitHub Actions + Railway/Vercel deploy |

---

## Who this is for

- **Full-stack developers** on Next.js + FastAPI + MongoDB who want Claude to enforce their team's standards automatically
- **DevOps / Platform engineers** who write Terraform and GitHub Actions and want HCL syntax errors caught before they happen
- **AI engineers** building LangChain / LangGraph pipelines who want LLMOps patterns baked into their AI pair programmer
- **Developers onboarding to AWS** who want a day-one SSO and Terraform bootstrap guide embedded in their tooling

---

## Contributing

This prompt evolves through **real production failures**. If you hit a new bug that belongs in the rule set, open a PR with:

1. What broke in production or CI
2. The exact error message
3. The rule that would have prevented it

Bug-driven rules only — no speculative "best practices."

---

<div align="center">

Built with [Claude Code](https://claude.ai/code) · Powered by [Anthropic](https://anthropic.com)

</div>
