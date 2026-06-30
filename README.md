<div align="center">

# Claude Code Master Prompt

[![Maintained](https://img.shields.io/badge/maintained-yes-green.svg?style=flat-square)]() [![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/) [![Node](https://img.shields.io/badge/Node.js-24-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org/) [![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)](https://aws.amazon.com/) [![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://www.terraform.io/) [![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

**A production Claude Code operating prompt — the CLAUDE.md master configuration used across real projects. Enforces parallel agents, a Group of Experts system, TDD, Docker-first dev, and cost-aware model routing on every session.**

[View CLAUDE.md](CLAUDE.md) | [Author](https://github.com/GatoProgramador-01)

</div>

---

## What This Is

This repository contains the `CLAUDE.md` file that acts as a persistent system prompt for every Claude Code session. Place it in your home directory (`~/CLAUDE.md`) and Claude Code loads it automatically — turning every session into one that behaves like a senior tech lead with a full supporting team.

The file is the product of real production failures across multiple projects: tests that passed locally and crashed Docker, Terraform configs that failed `validate` before a single resource was created, LangGraph agents that broke on 3% of production traffic. Every rule in it was written in response to a specific, documented mistake.

The current version introduces the **Group of Experts** system: 14 specialized agents, each with a defined domain and model tier, replacing the older single-agent-plus-utilities pattern.

---

## Key Features

- **Parallel agents by default** — minimum 3 agents per task, default target 5, max 8 simultaneous. Single-agent responses are the exception, not the default.
- **Group of Experts** — 14 named agents covering every layer of a fullstack + DevOps stack, each with a dedicated `.md` file and model assignment.
- **TDD non-negotiable** — Red → Green → Refactor. Tests written before implementation on every task. Bug fixes start with a failing test.
- **Docker-first** — `docker compose up --build` is the only acceptable way to start services. A pre-commit hook blocks dependency changes until the Docker build passes.
- **Cost routing** — Haiku for read/search/lint (10x cheaper), Sonnet for write/review/refactor, Opus only for cross-cutting architecture tradeoffs.
- **Hooks system** — PostToolUse auto-formats Python and TypeScript, compresses verbose build logs to 200 lines before Claude reads them, blocks force-pushes at the PreToolUse level.
- **Auto-compact policy** — context budget rules that trigger `/compact` with a focused scope string at defined thresholds, preventing silent context loss mid-sprint.
- **Lazy-loaded domain rules** — Terraform, AWS, CI/CD, LangChain, and Python testing rules live in `.claude/rules/` and load only when matching files are touched. Zero per-turn cost when out of scope.

---

## The Group of Experts

14 agents, each with a defined model tier and domain. The Architect routes work to the appropriate experts; the Adversarial agent attacks every design before the Drafter writes a line of code.

| Agent | Model | Domain |
|-------|-------|--------|
| **Architect** | sonnet | Orchestrates the team, decomposes tasks, routes to experts — never codes |
| **frontend-expert** | sonnet | React/Next.js/TS, SSE UI, Zustand, React Query, Jest + RTL |
| **backend-expert** | sonnet | FastAPI/NestJS, Motor DB, Pydantic v2, rate limiting |
| **llmops-expert** | sonnet | LangGraph nodes, structured output, evals, observability |
| **devops-expert** | sonnet | Docker, GitHub Actions, Terraform, Railway/Vercel |
| **researcher** | sonnet | Web research, source verification, grounding facts before pipeline runs |
| **Adversarial** | sonnet | Attacks every design — runs after Architect, before Drafter |
| **Drafter** | haiku | TDD: RED tests first, then implementation |
| **Integrator** | sonnet | Wires orchestrator.py, resolves import conflicts, commits |
| **Analyst** | haiku | Reads logs/DB/tests — no code writing |
| **Validate** | haiku | type/lint/format/test gate before every commit |
| **code-reviewer** | sonnet | Security, cost safety, production-readiness |
| **scraper** | sonnet | HTTP/browser scrapers, anti-bot, ASP.NET/JSF viewstate |
| **jsdoc** | sonnet | Full TSDoc on every exported TypeScript function |

### Standard workflow teams

| Scenario | Team |
|----------|------|
| New pipeline feature | Analyst + Architect (parallel) → Adversarial → llmops-expert + Drafter (parallel) → Validate → Integrator |
| New API endpoint | Architect → backend-expert + Adversarial (parallel) → Validate → commit |
| Frontend feature | frontend-expert + Adversarial (parallel) → Validate → jsdoc → commit |
| Deploy / infra change | devops-expert → Adversarial → Validate → commit |
| Full-stack feature | frontend-expert + backend-expert + Adversarial (all parallel) → Validate → Integrator |
| Debug failing test | Analyst → Adversarial (blind hypothesis) → Validate fix |

---

## How to Use

**Global install — applies to every Claude Code session on this machine:**

```bash
# Copy to home directory (Claude Code checks this location automatically)
curl -o ~/CLAUDE.md \
  https://raw.githubusercontent.com/GatoProgramador-01/claude-code-master-prompt/main/CLAUDE.md

# Or on Windows (PowerShell)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/GatoProgramador-01/claude-code-master-prompt/main/CLAUDE.md" `
  -OutFile "$HOME\CLAUDE.md"
```

**Install the full agent system (recommended):**

```bash
# Clone and copy the full .claude/agents/ directory to your home
git clone https://github.com/GatoProgramador-01/claude-code-master-prompt.git
cp -r claude-code-master-prompt/.claude/agents ~/.claude/
cp -r claude-code-master-prompt/.claude/rules ~/.claude/
```

Each agent in `~/.claude/agents/` is a markdown file that Claude Code loads when you invoke the agent by name. The model tier is set in the frontmatter of each file.

**Project-specific overrides:**

```bash
# Create a project CLAUDE.md that extends the global one
cat > ./CLAUDE.md << 'EOF'
@~/CLAUDE.md

## PROJECT-SPECIFIC OVERRIDES
- Service name prefix: myproject-
- Default AWS region: us-east-1
- Database: PostgreSQL (not MongoDB)
EOF
```

**Full directory layout after install:**

```
~/.claude/
├── CLAUDE.md                      # global rules (~200 lines, every session)
├── agents/
│   ├── architect.md               # sonnet — task decomposition, routes experts
│   ├── frontend-expert.md         # sonnet — React/Next.js specialist
│   ├── backend-expert.md          # sonnet — FastAPI/NestJS specialist
│   ├── llmops-expert.md           # sonnet — LangGraph + evals specialist
│   ├── devops-expert.md           # sonnet — Docker/Terraform/CI specialist
│   ├── researcher.md              # sonnet — web research + grounding
│   ├── adversarial.md             # sonnet — attacks design before drafter codes
│   ├── drafter.md                 # haiku  — TDD RED first, then implements
│   ├── integrator.md              # sonnet — wires orchestrator, commits
│   ├── analyst.md                 # haiku  — read-only diagnostics
│   ├── validate.md                # haiku  — pre-commit type/lint/test gate
│   ├── scraper.md                 # sonnet — HTTP/browser scraping specialist
│   └── jsdoc.md                   # sonnet — TSDoc on TS exports
└── rules/                         # lazy-loaded, zero cost when not in scope
    ├── infra/
    │   ├── terraform.md           # loads on *.tf / infra/**
    │   └── aws.md                 # loads on infra/** / services/**
    ├── cicd/
    │   └── pipeline.md            # loads on .github/**
    └── python/
        ├── langchain.md           # loads on **/agents/** / **/prompts/**
        └── testing.md             # loads on **/tests/** / **/conftest.py
```

---

## Stack Coverage

| Layer | Technologies |
|-------|-------------|
| Frontend | React, Next.js, TypeScript, Zustand, React Query, Jest + RTL, Playwright |
| Backend | Python/FastAPI, Node.js/NestJS, Motor (async MongoDB), Pydantic v2 |
| AI/LLMOps | LangChain, LangGraph, structured output, deepeval/RAGAS evals, LangSmith tracing |
| Infrastructure | AWS (Lambda, Step Functions, Bedrock), Terraform, Docker, GitHub Actions |
| Deploy targets | Railway, Vercel, AWS ECS/Lambda |
| Databases | MongoDB (Motor), PostgreSQL |

---

## What It Prevents

These are rules derived from specific production failures, not general best practices.

| Rule | The Failure That Caused It |
|------|--------------------------|
| Pre-commit Docker build gate blocks commits when `pyproject.toml` or `Dockerfile` changes | A package added to source code but not to `pyproject.toml` passed all unit tests (native environment had it globally) and crashed Docker at deploy time with `ModuleNotFoundError` |
| Minimum 5 parallel agents for independent tasks | Three independent file updates ran sequentially, burning 40+ minutes of wall time on work that could have completed in 12 |
| `npm install` not `npm ci`; Node.js 24 required | `npm ci` on a Windows-generated lockfile failed in Linux CI with `Missing: @emnapi/runtime from lock file` — no hint in the error that the lockfile is the root cause |
| Motor singleton must be reset with synchronous PyMongo in E2E conftest | pytest-asyncio creates a new event loop per test; Motor binds at connection time; every E2E test after the first raised `Event loop is closed` |
| Unicode-normalizer fallback in every Pydantic str→list validator | A LangGraph agent returned JSON with curly quotes; `json.loads` raised `JSONDecodeError`; worked in every unit test, failed on 3% of production traffic |
| `git branch --show-current` before writing any `branches:` trigger | A workflow written with `branches: [main]` was committed to a repo whose default branch was `master`; the CI job never fired |
| `ruff select` must live in `[tool.ruff.lint]`, not `[tool.ruff]` | ruff >= 0.8 silently ignores `select` under `[tool.ruff]`; the linter appeared to run but enforced nothing |
| CLAUDE.md must stay under 200 lines with domain rules lazy-loaded | The CLAUDE.md grew to 1,300 lines, loading every turn regardless of the task; a React component fix paid the full token cost of the Terraform HCL guide |
| PostToolUse hook on Bash compresses verbose build output before Claude reads it | A failing CI job dumped 8,000 lines of Maven build log into context; Claude spent the entire context budget on log parsing instead of fixing the root cause |
| Adversarial agent runs before Drafter writes code | A LangGraph node returned structured output without validating the schema against actual LLM behavior; the Adversarial agent would have caught the missing fallback validator before any code was written |

---

## The Auto-Compact Policy

Context budget management is explicit and rule-driven, not left to judgment:

- **Over 60% context used at a post-commit boundary** → compact immediately with a focused scope: `/compact Focus on <project> Sprint <N> — <next task>`
- **Over 75% context mid-sprint** → compact now, no exceptions: `/compact Focus on current file changes only`
- **Under 60%** → continue; no compact needed

Always use a scoped compact with a focus argument. A blind `/compact` discards too much sprint state. After compacting, verify CLAUDE.md and memory are loaded, then run `git log --oneline -3` to reorient.

---

## Codex Adversarial Review

The Codex CLI plugin (`openai/codex-plugin-cc`) runs a second model family against every sprint — catching blind spots that same-model review misses. Install once, then follow the mandatory cadence on every sprint.

**Install:**

```bash
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

**Mandatory cadence (non-negotiable):**

- Sprint start: `/codex:rescue --background` fires before writing a line of code
- After every commit: `/codex:adversarial-review --fresh --background`
- When stuck >5 min: delegate immediately to `/codex:rescue`
- Sprint 31+: Codex implements ONE node per sprint (not just reviews)

Always use `--background` — never block the session waiting for Codex. Claude and Codex work in parallel; the session does not pause.

---

## Sprint Status UI

Every sprint prints a live status tree — before agents launch (showing the plan) and rebuilt after each completion wave (showing progress). It is the single visual that makes parallel agent work scannable.

**Format:**

```
😸 Sprint N — activo [3/6 completados]
├── ✅ copy_editor_node.py  [████████] done    — score cap: penalties>0.30
├── ✅ test_sme_reviewer    [████████] done    — 15 RED→GREEN tests
├── 🔄 sme_reviewer_node   [░░░░░░░░] running — implement SME check
├── 🔄 integrator          [░░░░░░░░] running — wire sme_review_check
├── 🔄 validate            [░░░░░░░░] queued  — full test suite gate
└── 🔍 Codex              [░░░░░░░░] running — adversarial Sprint 31
```

**Rules:**

- `😸` header only — ONE per tree, never in rows
- `[████████]` done ✅ · `[░░░░░░░░]` running or queued 🔄 · `[████████]` failed ❌
- `[N/M completados]` counter updates after each completion wave
- Codex always gets the bottom `🔍` row — makes cross-provider review a first-class citizen
- Row description ≤ 40 chars, columns right-padded for alignment
- Print tree BEFORE launching agents (it's the sprint plan) AND rebuild after each wave

**Why it works:**
Binary bars give the one metric that matters — running vs finished — without reading descriptions. The `[N/M]` counter shows sprint velocity at a glance. Printing the tree before any agent fires forces decomposition before execution.

---

<details>
<summary><strong>Sprint History</strong></summary>

| Sprint | What Shipped |
|--------|-------------|
| Foundation | Core role definition (tech lead + DevOps); TDD Red→Green→Refactor rule; Python conventions; initial `.gitignore` security rules |
| Terraform hardening | HCL attribute syntax rule; `lifecycle` block inside resource; `archive_file` over `filebase64sha256`; `prevent_destroy` on stateful resources |
| GitHub Actions safety | Branch name verification; `mapfile` vs pipe-while subshell bug; OIDC trust over static access keys |
| CI/CD pipeline template | Complete 5-job structure; Motor + pytest-asyncio event loop fix; `ruff select` under `[tool.ruff.lint]` |
| Frontend CI hardening | `npm install` over `npm ci`; Node 24 requirement; `.eslintrc.json` existence check; `tsconfig.json` exclude block; clipboard spy ordering |
| LangChain/LangGraph standards | No legacy `LLMChain`; `.with_structured_output(PydanticModel)`; unicode-normalizer fallback validator; `get_llm(role)` factory pattern |
| LLMOps architecture | 3-layer eval (score direction / batch regression / LLM-as-judge); CI gate under $0.05; prompt versioning in `prompts/`; LangSmith tracing |
| Parallel agents | Default 5-agent parallelism; worktree isolation; `maxTurns` hard caps; delegation prompt 300-token cap; result summary discipline |
| Token efficiency | Model-per-role routing table; never use `inherit`; CLAUDE.md 200-line target; lazy domain rules in `.claude/rules/` |
| Docker-first local dev | `docker compose up --build` as default; pre-commit Docker build gate; `.worktreeinclude` for env distribution |
| Code modification discipline | Pre-touch diagnostics checklist; locate all references before rename; validation order; tests disprove, not confirm |
| Hooks system | `PreToolUse` force-push block; `PostToolUse` auto-formatter; `Notification` Windows idle alert; `Stop` post-turn test execution |
| AWS SSO + serverless | Day-1 SSO guide; 3-layer multi-agent model; Lambda single-responsibility + DLQ + X-Ray; HTTP API over REST API |
| README standard | 16-section portfolio-grade template; prose-only Problem + Act sections; two Mermaid diagrams; sprint history in `<details>` |
| Modular rules + scraper specialist | CLAUDE.md reduced from 1,300 → 120 lines (80%); 5 domain rule files with `paths:` lazy-loading; `validate` agent (haiku/8 turns) + `scraper` agent (sonnet/20 turns); PostToolUse build-log compression hook |
| Web researcher hardening | Tavily `_run_search` 5-query fan-out with `search_depth="advanced"`; module-level `TavilyClient` import guard; URL normalization + dedup; `SOURCE URLS` block injected into brief |
| Sources + citations auto-append | Deterministic `## Sources` section auto-appended in `content_generation_node`; `post_processor.py` merges duplicate Sources sections and deduplicates by URL |
| Revision analytics | `quality_snapshots` MongoDB collection; `/api/analytics/revision-cycles` endpoint; `RevisionCyclesPanel` frontend table with score/word-count color-coding |
| Adversarial agent framework | Dedicated `adversarial.md` agent attacks every design before drafter codes; `architect.md` decomposes; minimum 3 agents per task enforced |
| Medium 2026 + Codex plugin | Boost Nomination Program; publication-first strategy; Codex CLI plugin (`openai/codex-plugin-cc`) — `/codex:adversarial-review`, `/codex:rescue` |
| Group of Experts system | 14 specialized agents (frontend-expert, backend-expert, llmops-expert, devops-expert, researcher, code-reviewer added); auto-compact policy with context thresholds; scoped `/compact` rules |

</details>

---

## License

MIT — see [LICENSE](LICENSE).
