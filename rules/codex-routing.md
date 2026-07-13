# Codex Plugin — Adversarial Cross-Provider Review

**Rule scope:** loaded on-demand whenever a session needs the full Codex cadence, failure-mode catalogue, or parallel-executor × Codex routing detail.

## Install / auth
```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```
Auth confirmed active: jcollipal1212@gmail.com, ChatGPT, codex-cli 0.142.3.

## Mandatory cadence (non-negotiable)

| Trigger | Command | Flag |
|---------|---------|------|
| Start of sprint | `/codex:rescue` | `--background` (fires before Claude writes a line) |
| After every commit | `/codex:adversarial-review --fresh` | `--background` |
| Stuck > 5 min | `/codex:rescue` | delegate immediately, do not keep trying alone |
| Default flag on ALL Codex calls | `--background` | never block session waiting for Codex |

**Self-check every sprint:** "Did I run Codex this sprint?" — no = incomplete sprint. Zero Codex = failed session.

## Failure modes to avoid

- **Declaring a sprint done without `/codex:adversarial-review`** → silent regressions shipped.
- **Fixing bugs alone for > 5 min without `/codex:rescue`** → wasted context on a solvable problem.
- **Running Codex at the very end only** → Codex finds nothing useful because all decisions are locked.

## parallel-executor × Codex per-task routing (non-negotiable)

Within `parallel-executor`, every implementer and reviewer MUST use the correct expert. `general-purpose` loses domain expertise and skips the structured review contract.

| Role | Agent / Skill | When |
|------|---------------|------|
| Implementer | `drafter` | New Python files, TDD, new agents/nodes/prompt files |
| Implementer | `llmops-expert` | LangGraph nodes, LLMOps patterns, structured output, orchestrator wiring, PipelineState |
| Implementer | `backend-expert` | FastAPI routes, Pydantic, Motor, rate limits, auth |
| Implementer | `frontend-expert` | React/Next.js/TS, App Router, RTL tests, TSDoc |
| Implementer | `devops-expert` | Docker, GitHub Actions, Railway/Vercel, Terraform |
| Implementer | `prompt-engineer` | Prompt files, prompt versioning, G-Eval rubrics |
| Implementer | `eval-writer` | Eval datasets, deepeval/RAGAS wiring |
| Implementer | `scraper` | HTTP/browser scrapers, anti-bot, ASP.NET forms |
| Review step 1 | `codex:adversarial-review --wait` (controller) | After implementer commits |
| Review step 2 | `adversarial` (subagent) | Receives Codex findings + issues spec compliance + code-quality verdict |
| Validation | `validate` | pytest / tsc / lint / build gate before commit |
| Diagnostics | `adversarial` (read-only mode) | Logs, DB, test output, git history |
| Research | `researcher` | Web research, primary sources, fact grounding |
| SME sanity | `sme-reviewer` | Product/legal/compliance review |
| **Default fallback** | `drafter` | No exact match — never use `general-purpose` |

**Self-check before every `Agent()` call:** "Am I about to use `general-purpose`? If yes, STOP — pick the correct expert."

Each `subagent_type` value must exactly match an agent filename in `~/.claude/agents/<name>.md` (no `.md` extension). If the name isn't in that directory, use `drafter`.

## parallel-executor review flow (non-negotiable)

1. Controller runs `Skill("codex:adversarial-review", "--wait")` immediately after the implementer commits.
2. Controller appends Codex findings (severity, file:line, recommendations) to the task reviewer prompt.
3. Controller dispatches `adversarial` subagent with: task brief + implementer report + review package + Codex findings.
4. `adversarial` subagent issues two verdicts: (1) spec compliance and (2) code quality.

## Template trap

The parallel-executor `implementer-prompt.md` template contains `[AGENT_TYPE]` — always replace it with the `subagent_type` from the routing table above. `Agent(model="sonnet")` with no `subagent_type` silently routes to `general-purpose` and is equally wrong. **This file is the authoritative routing source.** Plugin updates can overwrite `implementer-prompt.md` and restore a bad default.

## Codex mode taxonomy (per cartridge) — self-review dimension, NOT parallel-executor gate

**⚠️ Do NOT read `codex_mode` as an override on the parallel-executor blocking gate.** The parallel-executor controller ALWAYS runs `codex:adversarial-review --wait` after every implementer commit, regardless of the implementer cartridge's declared `codex_mode`. Findings feed the `adversarial` subagent's task-review verdict, which the controller waits on before dispatching the next implementer. There is no path where a cartridge downgrades this gate.

`codex_mode` describes what the AGENT does with Codex output during its OWN work, not what the parallel-executor controller does after the agent finishes:

- **codex-blocking** — This agent expects to consult Codex mid-task on high-risk decisions (orchestration wiring, IaC, secrets). Used by `llmops-expert`, `devops-expert`.
- **codex-concurrent** — This agent produces standard implementation code; Codex runs in parallel and the agent folds findings into its own self-review before returning. Used by `backend-expert`, `frontend-expert`, `adversarial`, `scraper`, `drafter`, `prompt-engineer`, `eval-writer`.
- **codex-skip** — This agent does not produce code that needs Codex review (architect designs only, validate is the final gate, researcher writes prose, sme-reviewer is itself a review agent). Used by `architect`, `validate`, `researcher`, `sme-reviewer`.

**The parallel-executor merge gate is always Codex `--wait` + `adversarial` subagent verdict, no exceptions.**
