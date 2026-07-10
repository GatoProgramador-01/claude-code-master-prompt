<div align="center">

# Claude Code Master Prompt

[![Maintained](https://img.shields.io/badge/maintained-yes-green.svg?style=flat-square)]() [![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/) [![Node](https://img.shields.io/badge/Node.js-24-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org/) [![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)](https://aws.amazon.com/) [![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://www.terraform.io/) [![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

**A production Claude Code operating prompt — the `CLAUDE.md` master configuration used across real projects. Enforces parallel agents, a 13-agent Group of Experts (cartridge-v2), Superpowers SDD, Codex cross-provider adversarial review, TDD, Docker-first dev, and cost-aware model routing on every session.**

[View CLAUDE.md](CLAUDE.md) · [Agent roster](agents/) · [Rules](rules/) · [Author](https://github.com/GatoProgramador-01)

</div>

---

## What This Is

This repository is the `CLAUDE.md` + `agents/` + `rules/` bundle that acts as a persistent system prompt for every Claude Code session. Installed at `~/CLAUDE.md`, `~/.claude/agents/`, and `~/.claude/rules/`, Claude Code loads it automatically — turning every session into one that behaves like a senior tech lead with a full supporting team.

Every rule was written in response to a specific, documented production failure: tests that passed locally and crashed Docker, Terraform configs that failed `validate` before a single resource was created, LangGraph agents that broke on 3% of production traffic.

The current version is **cartridge-v2**: a thin 107-line router `CLAUDE.md`, thirteen specialized agent cartridges with a 10-slot template + 3-shot positive exemplars, four rules files tracked in-repo and installed via `scripts/install-rules.sh`, and a 24-case meta-eval dataset that scores every cartridge on slot coverage + correctness + cost.

---

## Key Features

- **Parallel agents by default** — minimum 3 per task, target 5, max 8 simultaneous. Solo responses are the exception.
- **13-agent Group of Experts (v2)** — cartridge-v2 template: `ROLE / HYDRATION / TRIGGERS / PATTERNS / HANDOFF / REVIEW / SELF-CRITIQUE / ESCALATION / BOUNDARIES / COST BUDGET`, each cartridge with 3-shot positive exemplars overriding Sonnet training priors.
- **Thin `CLAUDE.md`** — 107 lines of non-negotiable rules + routing pointers; deep guidance lives in on-demand `rules/` files, zero token cost when out of scope.
- **Superpowers SDD** — `superpowers:subagent-driven-development` fires immediately after `writing-plans`. Inline execution is not an option.
- **Codex adversarial review** — `/codex:adversarial-review --wait` (GPT-5.4, cross-provider) runs in the controller after every implementer commit and feeds findings into the `adversarial` reviewer subagent. No merge without Codex.
- **Parallel wave dispatch** — before dispatching ANY implementer, the controller scans all remaining tasks and fires every independent one in the same message.
- **Meta-evals** — 24-case dataset scoring cartridges on 30% slot coverage + 50% correctness + 20% cost, threshold 0.80, 25/25 rubric tests passing.
- **TDD non-negotiable** — Red → Green → Refactor. Failing test before implementation, always.
- **Docker-first** — `docker compose up --build` is the default local dev entrypoint.
- **Cost routing** — Haiku for read/search/lint/format (10× cheaper), Sonnet for write/review/refactor, Opus only for cross-cutting architecture tradeoffs.
- **Hooks** — PostToolUse auto-formats Python/TS, compresses verbose build logs, PreToolUse blocks force-pushes.
- **Auto-compact policy** — `session-autopilot` skill fires at 50% context, writes a MongoDB `session_logs` audit entry, and recommends a scoped `/compact` focus string.
- **Push after every commit** — every commit is immediately followed by `git push origin <branch>`. Pre-push hook failures get `ruff --fix && black`, re-stage, retry — never `--no-verify`.

---

## The Group of Experts (v2 — 13 agents)

The Architect routes; each expert owns a domain and returns bounded output. Codex runs alongside as the cross-provider attacker.

| Agent | Model | Domain |
|-------|-------|--------|
| **architect** | sonnet | Decomposes work into DAG-safe task-briefs, routes to experts, never writes code |
| **llmops-expert** | sonnet | LangGraph nodes, PipelineState, `.with_structured_output()`, `get_llm(role)`, orchestrator.py wiring *(absorbs retired `integrator`)* |
| **backend-expert** | sonnet | FastAPI/NestJS routes, Motor async DB, Pydantic v2, rate limits, auth |
| **frontend-expert** | sonnet | React 19 / Next.js 15 App Router, Zustand + React Query, SSE hooks, Jest + RTL, full TSDoc emission *(absorbs retired `jsdoc`)* |
| **devops-expert** | sonnet | Docker, GitHub Actions, Terraform, Railway/Vercel, secrets |
| **adversarial** | sonnet | Attacks every design, OWASP + secrets scan, read-only diagnostics *(absorbs retired `security-reviewer` + `analyst`)* |
| **validate** | haiku | Pre-commit type/lint/format/test/build gate |
| **researcher** | sonnet | Structured web research, primary-source citation packs, grounding |
| **scraper** | sonnet | HTTP (httpx) + browser (playwright) scraping, ASP.NET forms, anti-bot, soft-block detection |
| **drafter** | haiku | Fallback implementer (no exact expert match) — RED tests first, then implementation |
| **prompt-engineer** | sonnet | *(new v2)* prompt files, prompt versioning, G-Eval rubric authoring, few-shot exemplar injection |
| **eval-writer** | sonnet | *(new v2)* deepeval / RAGAS dataset design, JSONL fixtures, Layer 1/2/3 metric selection |
| **sme-reviewer** | sonnet | *(new v2)* subject-matter review — fact accuracy, LLMOps terminology, Medium audience fit |

The retired v1 cartridges (`analyst`, `integrator`, `jsdoc`, `security-reviewer`) are archived at `~/.claude/agents/archive/2026-07-09-v1/` and remain rollback-recoverable.

### Standard workflow teams

| Scenario | Team |
|----------|------|
| New pipeline node | architect + adversarial (parallel) → writing-plans → SDD (llmops-expert + adversarial) → validate → llmops-expert wires orchestrator |
| New API endpoint | architect → backend-expert + adversarial (parallel) → writing-plans → SDD → validate → commit |
| Frontend feature | frontend-expert + adversarial (parallel) → writing-plans → SDD → validate → commit (TSDoc emitted by frontend-expert itself) |
| Deploy / infra change | devops-expert → adversarial → writing-plans → SDD → validate → commit |
| Full-stack feature | frontend-expert + backend-expert + adversarial (all parallel) → writing-plans → SDD → validate → llmops-expert (integration) |
| New prompt / eval | prompt-engineer + eval-writer (parallel) → sme-reviewer → validate → commit |
| Debug failing test | adversarial (read-only diagnostics) + adversarial (blind hypothesis, parallel) → validate fix |

---

## SDD × Group of Experts Integration

### Per-task routing

| Role | Agent | When |
|------|-------|------|
| Implementer | `drafter` | Fallback — new files with no exact domain match |
| Implementer | `llmops-expert` | LangGraph nodes, PipelineState, orchestrator wiring, evals |
| Implementer | `backend-expert` | FastAPI/NestJS routes, Pydantic models, DB, rate limits |
| Implementer | `frontend-expert` | React/Next.js, TSDoc, RTL tests |
| Implementer | `devops-expert` | Docker, CI, Terraform, deploy configs |
| Implementer | `scraper` | HTTP + browser scrapers |
| Implementer | `prompt-engineer` | Prompt files, rubrics |
| Implementer | `eval-writer` | Datasets, evaluators |
| Review step 1 | `codex:adversarial-review --wait` *(controller)* | After every implementer commit — GPT-5.4 attacks the diff |
| Review step 2 | `adversarial` *(subagent)* | Receives Codex findings; issues spec compliance + code quality verdict |
| Validation | `validate` | type/lint/format/test/build gate before commit |
| SME sanity | `sme-reviewer` | Content pipelines — fact + tone + audience fit |

Dispatching `general-purpose` with a freeform prompt is an explicit failure mode. If no expert matches exactly, `drafter` is the fallback.

### SDD review flow (per task, non-negotiable)

1. Implementer subagent commits and reports.
2. Controller runs `Skill("codex:adversarial-review", "--wait")` in the main session.
3. Controller appends Codex JSON findings (severity, file:line, recommendations) to the reviewer prompt.
4. Controller dispatches `adversarial` subagent with: task brief + implementer report + review package + Codex findings.
5. `adversarial` returns two verdicts: **(1) spec compliance** and **(2) code quality**.
6. If either fails, a fix subagent re-implements and the review loop repeats.

### Parallel dispatch rule (non-negotiable)

Before dispatching ANY implementer, the controller scans ALL remaining tasks. Every task with no file-overlap and no output-dependency is grouped into a single message wave. One-at-a-time dispatch on non-conflicting tasks is a failure.

---

## Cartridge-v2 Template

Every agent cartridge follows a fixed 10-slot layout. This is what makes cartridges evaluatable — the meta-eval scores per-slot coverage automatically.

| Slot | Purpose |
|------|---------|
| 1 · ROLE | Single-sentence identity + hard bans (retired agent names, forbidden tools) |
| 2 · HYDRATION | Files/context the agent MUST read before acting |
| 3 · TRIGGERS | When the controller should route work here |
| 4 · PATTERNS | Canonical implementation shapes + 3-shot positive exemplars |
| 5 · HANDOFF | Structured output contract (what the controller receives back) |
| 6 · REVIEW | What the reviewer checks — the spec compliance surface |
| 7 · SELF-CRITIQUE | Pre-return checklist (scan for banned names, verify handoff shape) |
| 8 · ESCALATION | When to punt to `codex:rescue` or the controller |
| 9 · BOUNDARIES | Explicit non-goals (what this agent does NOT do) |
| 10 · COST BUDGET | Model tier + max-turn ceiling |

**3-shot positive exemplars beat negative prose bans.** Wave 5 field-tested the architect cartridge and found Sonnet training priors overrode 3 defensive layers of "do not route to `integrator`" prose. Wave 6 fix: added three concrete YAML task-brief exemplars (`agent: llmops-expert`) showing the correct output shape. Post-fix: 0/3 misroutings.

---

## How to Use

**Global install — every Claude Code session on this machine:**

```bash
git clone https://github.com/GatoProgramador-01/claude-code-master-prompt.git
cd claude-code-master-prompt

# 1. Router CLAUDE.md
cp CLAUDE.md ~/CLAUDE.md

# 2. 13 agent cartridges
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/

# 3. Rules bundle (workflows, codex-routing, sprint-status, hooks)
bash scripts/install-rules.sh   # copies rules/*.md → ~/.claude/rules/
```

**Install the required plugins:**

```bash
# Superpowers — brainstorm → plan → SDD → TDD → review → finish
/plugin marketplace add obra/superpowers
/plugin install superpowers@superpowers-dev
/reload-plugins

# Codex — GPT-5.4 cross-provider adversarial review + rescue
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

**Project-specific overrides:**

```bash
cat > ./CLAUDE.md << 'EOF'
@~/CLAUDE.md

## PROJECT-SPECIFIC OVERRIDES
- Service name prefix: myproject-
- Default AWS region: us-east-1
- Database: PostgreSQL (not MongoDB)
EOF
```

**Repo layout after install:**

```
~/
├── CLAUDE.md                       # 107-line thin router (every session)
└── .claude/
    ├── agents/
    │   ├── architect.md             # sonnet — orchestrator
    │   ├── llmops-expert.md         # sonnet — LangGraph + orchestrator.py
    │   ├── backend-expert.md        # sonnet — FastAPI + Motor + Pydantic
    │   ├── frontend-expert.md       # sonnet — React/Next.js + TSDoc
    │   ├── devops-expert.md         # sonnet — Docker/Terraform/CI
    │   ├── adversarial.md           # sonnet — attack + OWASP + diagnostics
    │   ├── validate.md              # haiku  — pre-commit gate
    │   ├── researcher.md            # sonnet — web research + grounding
    │   ├── scraper.md               # sonnet — HTTP + browser scraping
    │   ├── drafter.md               # haiku  — fallback implementer, TDD
    │   ├── prompt-engineer.md       # sonnet — prompt files + rubrics
    │   ├── eval-writer.md           # sonnet — datasets + evaluators
    │   ├── sme-reviewer.md          # sonnet — subject-matter review
    │   ├── README.md                # auto-generated roster w/ codex-mode
    │   └── archive/2026-07-09-v1/   # retired v1 cartridges (rollback path)
    └── rules/                       # lazy-loaded, on-demand
        ├── workflows.md              # parallel wave patterns + teams
        ├── codex-routing.md          # SDD × Codex cadence + failure modes
        ├── sprint-status.md          # status tree spec (cat emoji legend)
        └── hooks.md                  # PostToolUse/PreToolUse/Stop hooks
```

---

## Meta-Eval Infrastructure

Cartridges are not "trust the vibe." Every cartridge is scored against a fixed rubric.

- **Dataset:** `docs/evals/dataset.jsonl` — 24 cases (8 each for `llmops-expert`, `backend-expert`, `architect`).
- **Rubric:** 30% slot coverage · 50% correctness · 20% cost efficiency. Pass threshold: 0.80.
- **Machinery:** rubric loader + runner + 25 unit tests (all green) in `docs/evals/`.
- **When to re-run:** on any cartridge edit that touches Slot 1 (ROLE), Slot 4 (PATTERNS), Slot 5 (HANDOFF), or Slot 10 (COST BUDGET).

---

## Stack Coverage

| Layer | Technologies |
|-------|-------------|
| Frontend | React 19, Next.js 15, TypeScript strict, Zustand, React Query, Jest + RTL, Playwright |
| Backend | Python/FastAPI, Node.js/NestJS, Motor (async MongoDB), Pydantic v2 |
| AI / LLMOps | LangChain, LangGraph, structured output, deepeval / RAGAS, LangSmith / Langfuse tracing |
| Infrastructure | AWS (Lambda, Step Functions, Bedrock), Terraform, Docker, GitHub Actions |
| Deploy targets | Railway, Vercel, AWS ECS / Lambda |
| Databases | MongoDB (Motor), PostgreSQL |

---

## What It Prevents

Rules derived from documented production failures, not general best practices.

| Rule | The Failure That Caused It |
|------|--------------------------|
| Pre-commit Docker build gate blocks commits when `pyproject.toml` or `Dockerfile` changes | A package added to source code but not to `pyproject.toml` passed all unit tests (globally installed) and crashed Docker at deploy time with `ModuleNotFoundError` |
| Minimum 5 parallel agents for independent tasks | Three independent file updates ran sequentially, burning 40+ minutes of wall time on work that could have completed in 12 |
| `npm install` not `npm ci`; Node.js 24 required | `npm ci` on a Windows-generated lockfile failed in Linux CI with `Missing: @emnapi/runtime from lock file` — no error hint that the lockfile was the root cause |
| Motor singleton reset with synchronous PyMongo in E2E conftest | pytest-asyncio creates a new event loop per test; Motor binds at connection time; every E2E after the first raised `Event loop is closed` |
| Unicode-normalizer fallback in every Pydantic str→list validator | A LangGraph agent returned JSON with curly quotes; `json.loads` failed on 3% of production traffic, worked in every unit test |
| `git branch --show-current` before writing any `branches:` trigger | Workflow committed with `branches: [main]` to a repo defaulting to `master`; the CI job never fired |
| `ruff select` must live in `[tool.ruff.lint]` | ruff ≥ 0.8 silently ignores `select` under `[tool.ruff]`; the linter appeared to run but enforced nothing |
| CLAUDE.md stays thin, deep rules lazy-loaded | Previous CLAUDE.md grew to 1,300 lines; a React fix paid full token cost of the Terraform HCL guide |
| PostToolUse hook compresses verbose Bash output | A failing CI job dumped 8,000 lines of Maven build log into context; Claude burned the entire budget on log parsing |
| Codex adversarial-review runs in the controller session, not as a subagent | Same-provider, same-model review misses blind spots. GPT-5.4 cross-provider catches design decisions Claude consistently overlooks |
| Parallel dispatch scans ALL remaining tasks before firing any one | Dispatching Task 2, waiting, then Task 3 (no shared files) burned 2× wall time for zero quality benefit |
| 3-shot positive YAML exemplars in architect Slot 4 | 3 layers of prose "do not route to `integrator`" were all overridden by Sonnet training prior; only concrete exemplars showing `agent: llmops-expert` fixed it |

---

## Codex Adversarial Review — mandatory cadence

| Trigger | Command | Flag |
|---------|---------|------|
| Sprint start | `/codex:rescue` | `--background` |
| After every commit | `/codex:adversarial-review --fresh` | `--background` |
| Stuck > 5 min | `/codex:rescue` | delegate immediately |
| Per-task SDD review | `/codex:adversarial-review --wait` | blocking, findings feed reviewer |

Zero Codex calls in a sprint = failed session.

**What Codex returns:**

```json
{
  "verdict": "needs-attention",
  "findings": [
    {
      "file": "app/agents/nodes/humanizer_pass.py",
      "line_start": 100,
      "confidence": 0.92,
      "recommendation": "image guard compares full strings not descriptions — alt-text rewording triggers false positive"
    }
  ]
}
```

---

## Sprint Status Tree

Every sprint prints a live status tree — before agents launch (plan + baseline metrics) and rebuilt after each completion wave.

```
😸 Sprint N — activo
├── 🤖 agentes  — 4 parallel (llmops-expert·backend-expert·adversarial·validate)
├── 🧠 skills   — brainstorming → writing-plans → subagent-driven-development
├── 📊 metrics  — tests 761→833 · TS 0 errors · build ✅
├── ✅ pre_revision.py       — 17 _SLOP_SUBS entries added
├── ✅ humanizer_pass.py     — missing_messiness injection node
├── 🔄 orchestrator.py       — wiring humanizer_pass → fact_check
└── 🔍 Codex (bg)            — adversarial review Sprint N
```

Row order: `🤖 agentes` → `🧠 skills` → `📊 metrics` → per-file rows (`✅/🔄/❌`) → `🔍 Codex` (always last).

Cat emoji legend: `😸` header (one per sprint) · `✅` completed · `🔄` in progress · `❌` failed · `🔍` Codex.

Full spec at `rules/sprint-status.md`.

---

<details>
<summary><strong>Sprint History</strong></summary>

| Sprint | What Shipped |
|--------|-------------|
| Foundation | Tech lead + DevOps role; TDD Red→Green→Refactor; Python conventions; `.gitignore` security |
| Terraform hardening | HCL attribute syntax; `lifecycle` inside resource; `archive_file` over `filebase64sha256`; `prevent_destroy` on stateful resources |
| GitHub Actions safety | Branch verification; `mapfile` vs pipe-while subshell bug; OIDC over static keys |
| CI/CD pipeline template | 5-job structure; Motor + pytest-asyncio event loop fix; `ruff select` under `[tool.ruff.lint]` |
| Frontend CI hardening | `npm install` over `npm ci`; Node 24; `.eslintrc.json` check; `tsconfig.json` exclude; clipboard spy ordering |
| LangChain / LangGraph standards | No legacy `LLMChain`; `.with_structured_output(PydanticModel)`; unicode-normalizer validator; `get_llm(role)` factory |
| LLMOps architecture | 3-layer eval (score direction / batch regression / LLM-as-judge); CI gate under $0.05; prompt versioning; LangSmith |
| Parallel agents | Default 5-agent parallelism; worktree isolation; `maxTurns` caps; 300-token prompt cap |
| Token efficiency | Model-per-role routing; CLAUDE.md 200-line target; lazy `.claude/rules/` |
| Docker-first local dev | `docker compose up --build` default; pre-commit Docker build gate; `.worktreeinclude` env distribution |
| Code modification discipline | Pre-touch checklist; locate all references before rename; tests disprove |
| Hooks system | PreToolUse force-push block; PostToolUse auto-formatter; Windows idle notification; Stop verification gate |
| AWS SSO + serverless | Day-1 SSO guide; 3-layer multi-agent model; Lambda single-responsibility + DLQ + X-Ray |
| README standard | 16-section portfolio template; prose-only Problem section; two Mermaid diagrams; sprint history in `<details>` |
| Modular rules + scraper | CLAUDE.md 1,300 → 120 lines; 5 domain rule files with `paths:` lazy-load; `validate` + `scraper` agents |
| Web researcher hardening | Tavily 5-query fan-out with `search_depth="advanced"`; URL dedup; `SOURCE URLS` injection |
| Sources + citations auto-append | Deterministic `## Sources` in `content_generation_node`; `post_processor.py` merges + dedups |
| Revision analytics | `quality_snapshots` MongoDB collection; `/api/analytics/revision-cycles`; `RevisionCyclesPanel` UI |
| Adversarial framework | Dedicated `adversarial.md` attacks every design; `architect.md` decomposes; 3-agent minimum |
| Medium 2026 + Codex plugin | Boost Nomination Program; publication-first; Codex CLI plugin (`openai/codex-plugin-cc`) — `/codex:adversarial-review`, `/codex:rescue` |
| Group of Experts (v1) | 14 specialized agents added (frontend/backend/llmops/devops/researcher/code-reviewer); auto-compact policy |
| SDD × GoE routing | Per-task routing table; Codex adversarial-review wired into SDD; parallel wave dispatch rule |
| **Cartridge v2 (this sprint)** | 10-slot template; 3-shot positive exemplars; roster consolidated to 13 (integrator→llmops-expert, jsdoc→frontend-expert, security-reviewer+analyst→adversarial); 3 new (prompt-engineer, eval-writer, sme-reviewer); CLAUDE.md 391→107 lines; rules moved to tracked `rules/` + `scripts/install-rules.sh`; 24-case meta-eval dataset + rubric + 25/25 tests; Wave 5 architect retirement-ban regression fixed in Wave 6 via YAML exemplars; retired v1 cartridges archived at `~/.claude/agents/archive/2026-07-09-v1/`; full rollback backup at `~/.claude/agents-backup-v1/` |

</details>

---

## Rollback

The cartridge-v2 atomic swap keeps the previous roster fully recoverable:

```bash
rm -rf ~/.claude/agents/*.md ~/.claude/agents/archive/
cp -r ~/.claude/agents-backup-v1/*.md ~/.claude/agents/
```

Restores the pre-swap v1 state exactly.

---

## License

MIT — see [LICENSE](LICENSE).
