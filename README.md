<div align="center">

# Claude Code Master Prompt

[![Maintained](https://img.shields.io/badge/maintained-yes-green.svg?style=flat-square)]() [![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/) [![Node](https://img.shields.io/badge/Node.js-24-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org/) [![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)](https://aws.amazon.com/) [![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://www.terraform.io/) [![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

**A production-grade Claude Code system prompt that turns Claude into a senior tech lead — enforcing parallel agents, TDD, token efficiency, Docker-first dev, and LLMOps standards on every session.**

[View CLAUDE.md](CLAUDE.md) | [Author](https://github.com/GatoProgramador-01)

</div>

---

## The Problem

Every AI coding assistant starts a session the same way: competent, eager, and completely unaware of your team's standards. Ask it to add an endpoint, and it will write the handler first, the test second — or skip the test entirely. Ask it to update a GitHub Actions workflow, and it will assume the branch is `main` without checking, breaking your trigger on the first push. Ask it to write Terraform, and it will sprinkle commas between attribute assignments as if HCL were JSON, generating config that fails on `terraform validate` before a single resource has been created.

The failures compound. A new package gets imported in application code but never added to `pyproject.toml`. The unit tests pass because they run in the native environment where the package was installed globally. The Docker container crashes at startup with a `ModuleNotFoundError`. The deploy breaks at 11pm. A LangChain agent gets wired up using `LLMChain` — a pattern deprecated two major versions ago — because the model's training data skews toward the most-cited examples, not the current API. A Pydantic model parses LLM output by calling `json.loads` directly on the response, and works perfectly until production traffic sends a response with a curly quote where a straight quote was expected, raising a `JSONDecodeError` that no unit test ever triggered.

None of these are exotic edge cases. They are the default behavior of an AI assistant operating without constraints. They are also the exact class of failures that a senior engineer would catch before the code was written — not after it crashed.

Can a single system prompt enforce the discipline of a senior tech lead across every session?

---

## What It Does

### Act 1 — From Sequential Thinking to Parallel Execution

The most expensive default behavior of any AI assistant is sequential reasoning where none is required. "First I'll update the README, then I'll write the Terraform, then I'll update the CLAUDE.md" — three independent files, three sequential operations, three times the latency. The parallel agents section of this prompt makes that pattern a violation, not a style preference.

The rule is stated without softening: maximum five agents simultaneously, this is the default, not an optimization. The prompt goes further and defines the failure modes explicitly — if you wrote "first I'll do X, then Y" for tasks whose outputs don't depend on each other, you under-parallelized. It also covers the infrastructure needed to make parallelism safe: worktrees give each agent an isolated git checkout so parallel file edits never collide. The `.worktreeinclude` file auto-copies `.env` into each checkout so Docker picks it up correctly.

By the time a session starts, Claude has already internalized the rule: independent tasks fan out, dependent tasks chain, and the right measure of agent selection is not model capability but task type — Haiku for read-only research, Sonnet for implementation, Opus only when Sonnet produces shallow architectural analysis.

### Act 2 — Engineering Constraints, Not Prompt Engineering

The second insight this prompt encodes is that enforcement scales through tooling, not instructions. An instruction to "always run the type checker before finishing" competes with every other instruction in context. A pre-commit hook that blocks the commit when the Docker build fails is physically unbypassable.

The code modification discipline section captures the operational procedure that prevents entire classes of bugs: collect diagnostics before touching anything, locate every reference to a symbol before renaming it, read the config files before writing code that must conform to them. The validation order after every implementation is not a suggestion — type checker, linter, formatter, unit tests, integration tests, in that sequence, with the explicit instruction to fix failures before explaining them.

The pre-commit Docker build gate operationalizes the most common class of deploy-time breakage. When `pyproject.toml` or a `Dockerfile` changes, the commit is blocked until `docker compose build` succeeds. The failure it prevents is specific and documented: a package added to source code but not to the manifest, passing all unit tests because they run in the native environment, crashing the container at startup.

The hooks section shows how to wire all of this into Claude Code's event system — `PreToolUse` to block force pushes, `PostToolUse` to auto-format Python files the moment they are written, `Stop` to run tests after every turn.

### Act 3 — LLMOps as First-Class Engineering

The third layer is what separates an AI-assisted codebase from a production LLMOps system. Token efficiency is not about saving money — it is about making the right tool call. A Sonnet parent spawning five Haiku workers for file search and grep operations saves 80% on research tasks. An Opus parent spawning workers that inherit the parent model is catastrophically expensive. The model routing table in this prompt is a hard rule: task type maps to model tier, no exceptions, `inherit` is never used.

The LangChain and LangGraph section encodes what every production pipeline eventually discovers. `LLMChain` is deprecated; use LCEL. Raw text parsing breaks on curly quotes; use `.with_structured_output(PydanticModel)`. Blocking `.invoke` in a FastAPI handler deadlocks under load; use `.ainvoke`. The unicode-normalizer validator is present in every Pydantic model that receives LLM-generated list or dict fields — not because it was clever to add, but because its absence caused a production crash on a response nobody tested.

The README standard section completes the loop. Every project built with this prompt produces a portfolio-grade README: prose narrative in the problem section, Mermaid architecture diagrams, a skills table that maps each technique to a file path the reviewer can click, a sprint history in a collapsible block that shows learning velocity, and a validation run table with real numbers from a real run.

---

## Key Sections

| Section | What It Enforces |
|---------|-----------------|
| PARALLEL AGENTS | Maximum 5 concurrent agents; `isolation: worktree` for parallel file edits; Haiku for research, Sonnet for implementation; delegation prompts capped at 300 tokens; agents return summaries, never raw file contents |
| HOOKS | `PreToolUse` blocks force push and commits with failing Docker builds; `PostToolUse` auto-formats Python on write; `Notification` fires a Windows desktop alert when Claude is idle; `Stop` runs tests after every turn |
| TOKEN EFFICIENCY | Model-per-role table (Haiku/Sonnet/Opus) with explicit rationale; `maxTurns` hard caps per agent type (5 for explore, 8 for leaf workers, 12–20 for implementation); CLAUDE.md 200-line size target with domain rules in `.claude/rules/` loaded only when matching files are touched |
| CODE MODIFICATION DISCIPLINE | Collect diagnostics before touching code; locate all references before renaming; read config files before writing conforming code; run type checker → linter → formatter → unit tests → E2E in sequence; never finish while diagnostics remain |
| LOCAL DEVELOPMENT | `docker compose up --build` is the default answer to "start the project"; pre-commit hook blocks commits when dependency or Dockerfile changes fail `docker compose build`; never use raw `uvicorn` or `npm run dev` for local development |
| TDD | Red → Green → Refactor is non-negotiable; tests written before implementation; no `// TODO: add tests` committed; bug fixes require a failing test that reproduces the bug before the fix is written |
| CI/CD PIPELINE | 5-job GitHub Actions structure (backend-ci, backend-e2e, frontend-ci, frontend-e2e, docker-build); `npm install` not `npm ci` on Node 24; `ruff select` in `[tool.ruff.lint]`; Motor singleton reset with synchronous PyMongo in E2E conftest; branch name verified with `git branch --show-current` before any workflow is written |
| LANGCHAIN/LANGGRAPH | No legacy chains; structured output via `.with_structured_output(PydanticModel)`; unicode-normalizer fallback in every Pydantic str→list validator; `get_llm(role)` factory used everywhere; 3-layer eval architecture with CI gate on Layer 1+2; prompts stored as `.txt` files, versioned in git |
| README STANDARD | 17-section portfolio-grade structure; prose-only Problem and Act sections; two Mermaid `flowchart TD` diagrams; skills table maps each technique to a clickable file path; sprint history in collapsible block; validation run data must be real numbers, never placeholders |

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

<!-- Add rules that apply only to this repository below this line -->
- Service name prefix: `myproject-`
- Default AWS region: `us-west-2`
```

Claude Code loads `CLAUDE.md` files in this priority order:

```
project/
├── .claude/
│   ├── CLAUDE.md          ← project-specific rules (highest priority)
│   ├── settings.json      ← hooks configuration
│   ├── agents/            ← custom agent definitions
│   │   └── code-reviewer.md
│   ├── skills/            ← slash command definitions
│   │   └── deploy/SKILL.md
│   └── rules/             ← lazy-loaded domain rules (paths: frontmatter)
│       ├── python/typing.md
│       └── terraform/naming.md
~/CLAUDE.md                ← global rules (loaded in every session)
```

---

## Capabilities Demonstrated

| Capability | Evidence |
|-----------|---------|
| Parallel agent orchestration | 5 concurrent agents, non-overlapping files, `isolation: worktree` per agent — detailed in [PARALLEL AGENTS](CLAUDE.md#parallel-agents--default-operating-mode-non-negotiable) |
| Token cost engineering | Model-per-role routing table with explicit rationale; `maxTurns` hard caps; 200-line CLAUDE.md size target with lazy domain rules — detailed in [TOKEN EFFICIENCY](CLAUDE.md#token-efficiency--sub-agent-configuration-non-negotiable) |
| Pre-commit safety gates | Docker build gate on dependency/Dockerfile changes; force-push block via `PreToolUse` hook — detailed in [LOCAL DEVELOPMENT](CLAUDE.md#local-development--docker-first-non-negotiable) |
| CI/CD pipeline authoring | 5-job GitHub Actions structure for FastAPI + Next.js + MongoDB with all silent failure modes documented and fixed — detailed in [CI/CD PIPELINE](CLAUDE.md#cicd-pipeline--fastapi--nextjs--mongodb) |
| LangGraph stateful agents | `StateGraph` with `TypedDict` state, `PostgresSaver` checkpointer, conditional edges, `get_llm(role)` factory — detailed in [LANGCHAIN/LANGGRAPH](CLAUDE.md#langchain--langgraph--production-standards) |
| LLMOps eval architecture | 3-layer evaluation (score direction → batch regression → LLM-as-judge); CI gate on Layer 1+2 under 5 min and $0.05; JSONL curated datasets — detailed in [LLMOps](CLAUDE.md#llmops--3-layer-eval-architecture) |
| IaC correctness enforcement | HCL attribute syntax, `lifecycle` placement, `archive_file` for Lambda packaging, OIDC trust instead of static keys — detailed in [HCL/TERRAFORM](CLAUDE.md#hcl--terraform--syntax-rules-non-negotiable) |
| Hook-driven automation | `PostToolUse` auto-formatter, `PreToolUse` safety guards, `Notification` desktop alert, `Stop` test runner — with exit code semantics documented — detailed in [HOOKS](CLAUDE.md#hooks--automation--safety) |
| AWS multi-agent architecture | 3-layer model (Step Functions → Bedrock AgentCore → MCP/Lambda); pattern selection table; DLQ, X-Ray, least privilege enforced per Lambda — detailed in [AWS MULTI-AGENT](CLAUDE.md#aws-multi-agent-architecture) |
| Portfolio-grade README standard | 17-section template with prose narrative, Mermaid diagrams, skills-to-file-path table, sprint history — detailed in [README STANDARD](CLAUDE.md#readme-standard--portfolio-grade-template-non-negotiable) |

---

## Rules That Come From Real Failures

| Rule | The Failure That Caused It |
|------|--------------------------|
| Pre-commit Docker build gate blocks commits when `pyproject.toml` or `Dockerfile` changes | A package added to source code but not to `pyproject.toml` passed all unit tests (native environment had it installed globally) and crashed the Docker container at deploy time with `ModuleNotFoundError` — a class of failure that never appears in CI until the container runs |
| Always spawn 5 parallel agents for independent tasks; never sequential | Three independent file updates (README, Terraform infra, CLAUDE.md) ran sequentially, burning 40+ minutes of wall time on work that could have completed in 12. The lost time compounds across every session |
| `npm install` not `npm ci`; Node.js version must be 24 | `npm ci` on a Windows-generated lockfile failed in Linux CI with `Missing: @emnapi/runtime from lock file` — the lockfile omits Linux WASM fallback packages. Node 22 exhibits the same behavior. The error message gives no hint that the lockfile is the root cause |
| Motor singleton must be reset with synchronous PyMongo in E2E conftest | pytest-asyncio creates a new event loop per test. Motor binds to the loop at connection time. Every E2E test after the first raised `Event loop is closed`. The fix is synchronous PyMongo for cleanup and `_client = None` to force Motor to re-bind on the current test's loop |
| `ruff select` must live in `[tool.ruff.lint]`, not `[tool.ruff]` | ruff >= 0.8 silently ignores `select` under `[tool.ruff]`. The linter appeared to run but enforced nothing. No error, no warning — the rule was simply ignored until a code review caught a pattern that should have been rejected |
| Unicode-normalizer fallback in every Pydantic str→list validator | A LangGraph agent returned JSON with curly quotes and an em-dash in a field. `json.loads` raised `JSONDecodeError`. The agent worked in every unit test (which used straight quotes in fixtures) and failed on 3% of production traffic — exactly the case that passes QA |
| Always run `git branch --show-current` before writing any GitHub Actions `branches:` trigger | A workflow written with `branches: [main]` was committed to a repo whose default branch was `master`. The CI job never fired. The bug was invisible because the `on: push` trigger silently matched nothing |
| `black target-version` must match the CI Python version exactly | `target-version = ["py310"]` with `python-version: "3.11"` in the CI matrix caused `black --check` to pass locally and fail in CI. The formatter applies different line-wrapping decisions based on target version |

---

<details>
<summary><strong>Sprint History</strong></summary>

| Sprint | What Shipped |
|--------|-------------|
| Foundation | Core role definition (tech lead + DevOps); TDD Red→Green→Refactor rule; Python conventions (PEP 8, type hints, `dataclass`); initial `.gitignore` security rules |
| Terraform hardening | HCL attribute syntax rule (newlines, not commas); `lifecycle` block placement inside resource; `archive_file` over `filebase64sha256` for Lambda packaging; `prevent_destroy` on stateful resources |
| GitHub Actions safety | Branch name verification rule (`git branch --show-current` before writing `branches:`); `mapfile` vs pipe-while subshell bug documented; OIDC trust over static access keys for CI credentials |
| CI/CD pipeline template | Complete 5-job structure (backend-ci, backend-e2e, frontend-ci, frontend-e2e, docker-build); Motor + pytest-asyncio event loop fix (sync PyMongo cleanup + Motor singleton reset); `ruff select` under `[tool.ruff.lint]` |
| Frontend CI hardening | `npm install` over `npm ci` rule; Node 24 requirement; `.eslintrc.json` must exist for `next lint`; `tsconfig.json` exclude block for jest files; clipboard spy ordering after `userEvent.setup()` |
| LangChain/LangGraph standards | No legacy `LLMChain`/`ConversationChain`; `.with_structured_output(PydanticModel)`; unicode-normalizer fallback validator for every str→list field; tenacity retry with jitter; `get_llm(role)` factory pattern |
| LLMOps architecture | 3-layer eval structure (score direction / batch regression / LLM-as-judge); CI gate on Layer 1+2 under $0.05; prompt versioning in `prompts/` as `.txt` files; LangSmith tracing setup; `autouse` mock_db in eval conftest |
| Parallel agents | Default 5-agent parallelism rule; worktree isolation for parallel file edits; `maxTurns` hard caps per agent type; delegation prompt 300-token cap; result summary discipline (agents return summaries, not raw content) |
| Token efficiency | Model-per-role routing table with rationale; never use `inherit`; CLAUDE.md 200-line size target; lazy domain rules in `.claude/rules/` with `paths:` frontmatter; prompt cache TTL extension with `ENABLE_PROMPT_CACHING_1H=1` |
| Docker-first local development | `docker compose up --build` as the mandatory local dev standard; pre-commit Docker build gate for dependency/Dockerfile changes; `.worktreeinclude` for env file distribution to worktrees |
| Code modification discipline | Pre-touch diagnostics checklist; locate all references before rename; read config before writing conforming code; validation order (type checker → linter → formatter → unit → E2E); tests disprove, not confirm |
| Hooks system | `PreToolUse` force-push block; `PostToolUse` auto-formatter for Python; `Notification` Windows idle desktop alert; `Stop` event for post-turn test execution; exit code semantics documented |
| AWS SSO onboarding | Complete day-1 SSO guide; `~/.aws/config` exact format with `sso-session` block; credential flow diagram; token expiry error table; `aws configure sso` in PowerShell not Git Bash (Windows terminal detection bug) |
| AWS multi-agent architecture | 3-layer model (Step Functions → Bedrock AgentCore → MCP/Lambda); pattern selection table; Lambda single responsibility, DLQ, X-Ray, explicit timeout rules; HTTP API over REST API default |
| README standard | 17-section portfolio-grade template; prose-only Problem and Act sections; two Mermaid `flowchart TD` diagrams required; skills table must link to file paths; sprint history in `<details>`; anti-pattern list |

</details>

---

## License

MIT — see [LICENSE](LICENSE).
