<div align="center">

# Claude Code Master Prompt

[![Maintained](https://img.shields.io/badge/maintained-yes-green.svg?style=flat-square)]() [![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/) [![Node](https://img.shields.io/badge/Node.js-24-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org/) [![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)](https://aws.amazon.com/) [![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://www.terraform.io/) [![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

**A production-grade Claude Code system prompt — modular, lazy-loaded, and token-efficient — that enforces parallel agents, TDD, Docker-first dev, LLMOps standards, and web scraping expertise on every session.**

[View CLAUDE.md](CLAUDE.md) | [Author](https://github.com/GatoProgramador-01)

</div>

---

## The Problem

Every AI coding assistant starts a session the same way: competent, eager, and completely unaware of your team's standards. Ask it to add an endpoint, and it will write the handler first, the test second — or skip the test entirely. Ask it to update a GitHub Actions workflow, and it will assume the branch is `main` without checking, breaking your trigger on the first push. Ask it to write Terraform, and it will sprinkle commas between attribute assignments as if HCL were JSON, generating config that fails on `terraform validate` before a single resource has been created.

The failures compound. A new package gets imported in application code but never added to `pyproject.toml`. The unit tests pass because they run in the native environment where the package was installed globally. The Docker container crashes at startup with a `ModuleNotFoundError`. The deploy breaks at 11pm. A LangChain agent gets wired up using `LLMChain` — a pattern deprecated two major versions ago — because the model's training data skews toward the most-cited examples, not the current API. A Pydantic model parses LLM output by calling `json.loads` directly on the response, and works perfectly until production traffic sends a response with a curly quote where a straight quote was expected, raising a `JSONDecodeError` that no unit test ever triggered.

None of these are exotic edge cases. They are the default behavior of an AI assistant operating without constraints. They are also the exact class of failures that a senior engineer would catch before the code was written — not after it crashed.

Can a single system prompt enforce the discipline of a senior tech lead across every session?

---

## How It Works — The Story Arc

### Act 1 — From Sequential Thinking to Parallel Execution

The most expensive default behavior of any AI assistant is sequential reasoning where none is required. "First I'll update the README, then I'll write the Terraform, then I'll update the CLAUDE.md" — three independent files, three sequential operations, three times the latency. The parallel agents section of this prompt makes that pattern a violation, not a style preference.

The rule is stated without softening: maximum five agents simultaneously, this is the default, not an optimization. The prompt goes further and defines the failure modes explicitly — if you wrote "first I'll do X, then Y" for tasks whose outputs don't depend on each other, you under-parallelized. It also covers the infrastructure needed to make parallelism safe: worktrees give each agent an isolated git checkout so parallel file edits never collide. The `.worktreeinclude` file auto-copies `.env` into each checkout so Docker picks it up correctly.

By the time a session starts, Claude has already internalized the rule: independent tasks fan out, dependent tasks chain, and the right measure of agent selection is not model capability but task type — Haiku for read-only research, Sonnet for implementation, Opus only when Sonnet produces shallow architectural analysis.

### Act 2 — Engineering Constraints, Not Prompt Engineering

The second insight this prompt encodes is that enforcement scales through tooling, not instructions. An instruction to "always run the type checker before finishing" competes with every other instruction in context. A pre-commit hook that blocks the commit when the Docker build fails is physically unbypassable.

The code modification discipline section captures the operational procedure that prevents entire classes of bugs: collect diagnostics before touching anything, locate every reference to a symbol before renaming it, read the config files before writing code that must conform to them. The validation order after every implementation is not a suggestion — type checker, linter, formatter, unit tests, integration tests, in that sequence, with the explicit instruction to fix failures before explaining them.

The pre-commit Docker build gate operationalizes the most common class of deploy-time breakage. When `pyproject.toml` or a `Dockerfile` changes, the commit is blocked until `docker compose build` succeeds. The failure it prevents is specific and documented: a package added to source code but not to the manifest, passing all unit tests because they run in the native environment, crashing the container at startup.

### Act 3 — LLMOps as First-Class Engineering

The third layer is what separates an AI-assisted codebase from a production LLMOps system. Token efficiency is not about saving money — it is about making the right tool call. A Sonnet parent spawning five Haiku workers for file search and grep operations saves 80% on research tasks. An Opus parent spawning workers that inherit the parent model is catastrophically expensive. The model routing table in this prompt is a hard rule: task type maps to model tier, no exceptions, `inherit` is never used.

The LangChain and LangGraph section encodes what every production pipeline eventually discovers. `LLMChain` is deprecated; use LCEL. Raw text parsing breaks on curly quotes; use `.with_structured_output(PydanticModel)`. Blocking `.invoke` in a FastAPI handler deadlocks under load; use `.ainvoke`. The unicode-normalizer validator is present in every Pydantic model that receives LLM-generated list or dict fields — not because it was clever to add, but because its absence caused a production crash on a response nobody tested.

### Act 4 — When the Prompt Becomes the Problem

The prompt that solved the sequential-thinking problem had grown to solve forty others. By the time it enforced LangGraph patterns, CI/CD gotchas, ASP.NET viewstate handling, AWS SSO setup, and a sixteen-section README template, it was 1,300 lines long — loading every turn, for every session, regardless of what was being built. A session spent fixing a React component paid the token cost of the full Terraform HCL guide and the Motor event-loop fix. The tool meant to save tokens had become the largest single token expense in every conversation.

The fix is the same engineering principle applied to the prompt itself: only load what you need. Core behavioral rules stay in `CLAUDE.md` — now 120 lines — while domain-specific knowledge lives in `.claude/rules/<domain>/<topic>.md` files with `paths:` frontmatter that loads them only when a matching file is touched. A session that never opens a `.tf` file never pays for the Terraform guide. A session that never touches `**/agents/**` never loads the LangChain production rules. Five domain rule files covering Terraform, AWS, CI/CD, LangChain, and Python testing now load conditionally — zero cost when out of scope.

The same session introduces two specialist agents: `validate` (haiku, 8 turns) runs the full type/lint/format/test gate before every commit at minimal cost; `scraper` (sonnet, 20 turns) is a production web scraping specialist covering httpx + playwright (Python), puppeteer-extra-plugin-stealth (Node.js), ASP.NET viewstate extraction, retry with tenacity, mandatory sanity checks, and operational continuity rules. A PostToolUse compression hook reduces verbose build logs from 10,000 lines to 200 ERROR/WARN lines before Claude reads them — applying the same "engineering constraint" principle to the I/O layer itself.

---

## Key Sections

| Section | What It Enforces |
|---------|-----------------|
| PARALLEL AGENTS | Maximum 5 concurrent agents; `isolation: worktree` for parallel file edits; Haiku for research, Sonnet for implementation; Router-as-Haiku for mixed workloads (50–80% cost reduction); delegation prompts capped at 300 tokens |
| MODULAR RULES | 120-line core `CLAUDE.md`; domain rules in `.claude/rules/<domain>/` with `paths:` frontmatter load only when matching files touched — zero per-turn cost otherwise |
| WEB SCRAPING | `scraper` agent (sonnet, 20 turns): httpx + playwright (Python), puppeteer-extra-stealth (Node.js), ASP.NET viewstate pattern, retry + sanity checks + `--dry-run` flag for every delivery |
| HOOKS | `PreToolUse` blocks force push; `PostToolUse` auto-formats Python + compresses build logs to 200 ERROR/WARN lines; `Notification` fires Windows desktop alert; `/rewind` restores context after `/clear` |
| TOKEN EFFICIENCY | Model-per-role table; `maxTurns` hard caps (5 explore / 8 leaf / 12–20 implementation); never use `inherit`; prompt cache batching; CLAUDE.md 200-line target |
| CODE MODIFICATION DISCIPLINE | Collect diagnostics before touching code; locate all references before renaming; read config before writing conforming code; validate in sequence (type → lint → format → unit → E2E) |
| LOCAL DEVELOPMENT | `docker compose up --build` is the default; pre-commit Docker build gate blocks dependency/Dockerfile changes until build passes |
| TDD | Red → Green → Refactor is non-negotiable; tests written before implementation; bug fixes require a failing test first |
| CI/CD PIPELINE | 5-job GitHub Actions structure; `npm install` not `npm ci`; `ruff select` in `[tool.ruff.lint]`; Motor singleton reset in E2E conftest; branch name verified before writing workflows |
| LANGCHAIN/LANGGRAPH | No legacy chains; `.with_structured_output(PydanticModel)`; unicode-normalizer fallback in every str→list validator; `get_llm(role)` factory; 3-layer eval with CI gate |
| AWS MULTI-AGENT | 3-layer model (Step Functions → Bedrock AgentCore → MCP/Lambda); Lambda idempotent + stateless + DLQ + X-Ray; OIDC trust in CI |
| README STANDARD | 16-section portfolio-grade structure; prose-only Problem and Act sections; two Mermaid diagrams; skills table maps each technique to a file path |

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

**Install the full modular system (recommended):**

```bash
# Clone and copy the full .claude/ structure to your home directory
git clone https://github.com/GatoProgramador-01/claude-code-master-prompt.git
cp -r claude-code-master-prompt/.claude/agents ~/.claude/
cp -r claude-code-master-prompt/.claude/rules ~/.claude/
```

**Project-specific install — only affects this repository:**

```bash
# Copy to project root (highest priority, overrides global)
curl -o ./.claude/CLAUDE.md \
  https://raw.githubusercontent.com/GatoProgramador-01/claude-code-master-prompt/main/CLAUDE.md
```

**Reference from a project CLAUDE.md (compose with project-specific rules):**

```markdown
<!-- .claude/CLAUDE.md in your project -->
@~/.claude/CLAUDE.md

## PROJECT-SPECIFIC OVERRIDES
- Service name prefix: `myproject-`
- Default AWS region: `us-west-2`
```

Claude Code loads configuration in this priority order:

```
~/.claude/
├── CLAUDE.md                      ← global rules (120 lines, every session)
├── agents/
│   ├── validate.md                ← haiku, 8 turns — pre-commit validator
│   └── scraper.md                 ← sonnet, 20 turns — web scraping specialist
└── rules/                         ← lazy-loaded, zero cost when not in scope
    ├── infra/
    │   ├── terraform.md           ← loads on *.tf / infra/**
    │   └── aws.md                 ← loads on infra/** / services/**
    ├── cicd/
    │   └── pipeline.md            ← loads on .github/**
    └── python/
        ├── langchain.md           ← loads on **/agents/** / **/prompts/**
        └── testing.md             ← loads on **/tests/** / **/conftest.py

project/
└── .claude/
    └── CLAUDE.md                  ← project-specific overrides (highest priority)
```

---

## Rules That Come From Real Failures

| Rule | The Failure That Caused It |
|------|--------------------------|
| Pre-commit Docker build gate blocks commits when `pyproject.toml` or `Dockerfile` changes | A package added to source code but not to `pyproject.toml` passed all unit tests (native environment had it installed globally) and crashed the Docker container at deploy time with `ModuleNotFoundError` |
| Always spawn 5 parallel agents for independent tasks; never sequential | Three independent file updates ran sequentially, burning 40+ minutes of wall time on work that could have completed in 12. The lost time compounds across every session |
| `npm install` not `npm ci`; Node.js version must be 24 | `npm ci` on a Windows-generated lockfile failed in Linux CI with `Missing: @emnapi/runtime from lock file` — the lockfile omits Linux WASM fallback packages. The error message gives no hint that the lockfile is the root cause |
| Motor singleton must be reset with synchronous PyMongo in E2E conftest | pytest-asyncio creates a new event loop per test. Motor binds to the loop at connection time. Every E2E test after the first raised `Event loop is closed`. The fix is synchronous PyMongo for cleanup and `_client = None` to force Motor to re-bind |
| `ruff select` must live in `[tool.ruff.lint]`, not `[tool.ruff]` | ruff >= 0.8 silently ignores `select` under `[tool.ruff]`. The linter appeared to run but enforced nothing. No error, no warning — the rule was simply ignored |
| Unicode-normalizer fallback in every Pydantic str→list validator | A LangGraph agent returned JSON with curly quotes. `json.loads` raised `JSONDecodeError`. The agent worked in every unit test and failed on 3% of production traffic — exactly the case that passes QA |
| Always run `git branch --show-current` before writing any GitHub Actions `branches:` trigger | A workflow written with `branches: [main]` was committed to a repo whose default branch was `master`. The CI job never fired. The bug was invisible because the trigger silently matched nothing |
| `black target-version` must match the CI Python version exactly | `target-version = ["py310"]` with `python-version: "3.11"` caused `black --check` to pass locally and fail in CI. The formatter applies different line-wrapping decisions based on target version |
| CLAUDE.md must stay under 200 lines with domain rules moved to lazy-loaded files | The CLAUDE.md grew to 1,300 lines, loading in full every session turn regardless of the task. A React component fix paid the token cost of the full Terraform guide and the Motor event-loop fix |
| PostToolUse hook on Bash must compress verbose build output before Claude reads it | A failing CI job dumped 8,000 lines of Maven build log into context. Claude spent the entire context budget on log parsing instead of fixing the root cause |

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
| Modular rules + scraper specialist | CLAUDE.md reduced from 1,300 → 120 lines (80%); 5 domain rule files with `paths:` lazy-loading; `validate` agent (haiku/8 turns) + `scraper` agent (sonnet/20 turns) for web scraping; PostToolUse build-log compression hook; `/rewind` and Router-as-Haiku documented |

</details>

---

## License

MIT — see [LICENSE](LICENSE).
