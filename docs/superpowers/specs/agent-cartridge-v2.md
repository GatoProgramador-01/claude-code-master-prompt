# Agent Cartridge v2 — Canonical Template

**Date:** 2026-07-09
**Applies to:** every file in `~/.claude/agents/*.md`
**Governed by:** design spec `2026-07-09-agent-prompt-upgrade-design.md` Section 4.2, 4.4, 4.5

Every agent cartridge follows this 10-slot template. Every slot is required (deterministic slot-check gates commits). Every YAML frontmatter field is required. Every task-brief handoff uses the schema in Section 3.

---

## 1. YAML frontmatter (required fields)

```yaml
---
name: <agent-name>                    # lowercase, hyphen-separated, matches filename without .md
description: <verb-forward, ≤2 sentences describing what triggers this agent>
model: claude-<full-id>               # normalized — see model IDs below
maxTurns: <8-30>                      # ceiling; smaller for narrow-scope agents
---
```

**Model ID normalization** (no bare `sonnet`/`haiku`):

| Tier | Full ID | Use for |
|------|---------|---------|
| Sonnet | `claude-sonnet-4-6` | write/rewrite/review/multi-file refactor (default for domain experts) |
| Haiku | `claude-haiku-4-5-20251001` | read/search/lint/format/build/last-gate validators |
| Opus | `claude-opus-4-7` | architecture cross-cutting tradeoffs only (rare) |

**Note on Haiku's date suffix:** Haiku 4.5 has multiple pinned releases distinguished by date (20251001 is the currently-active release). Sonnet 4.6 and Opus 4.7 each have a single release, so no date suffix is required. If Anthropic ships a newer Haiku 4.5 build, this spec must update — do not blindly bump the date suffix in Wave 2-3 cartridges without confirming the new ID exists.

**maxTurns guidance:**
- 8-12 for narrow-scope agents (validate, jsdoc-formerly, scraper single-page)
- 15-20 for standard domain experts (backend-expert, frontend-expert, devops-expert)
- 20-30 for multi-file/high-reasoning agents (llmops-expert, architect, adversarial)

---

## 2. The 10 slots — canonical layout

Every cartridge contains all 10 slots in this order. Header markers are **load-bearing** — do not rename or renumber.

### Slot 1 — ROLE (2-3 lines)

Header marker: `─── Slot 1 — ROLE`

Distinctive expertise. NOT "senior X engineer". Name the technique the agent owns exclusively.

**Bad:** "You are a senior LangChain engineer specializing in production LLM pipelines."
**Good:** "You own `.with_structured_output()`, the `get_llm(role)` factory, and the 3-layer eval architecture in medium-agent-factory. Every LangGraph node is your surface; no other agent touches orchestrator wiring or `PipelineState` schema."

**Sizing:** 2-3 lines. If you need 4+, you are describing multiple roles — split into multiple agents.

---

### Slot 2 — HYDRATION PROTOCOL (5-10 lines)

Header marker: `─── Slot 2 — HYDRATION PROTOCOL`

Files to read BEFORE producing any output. Project-specific. Every domain expert reads at minimum `medium-agent-factory/AGENTS.md` when the task touches that project.

**Format:** bulleted list of file paths (absolute or clearly resolvable), one per line, with a one-line reason.

**Example:**
```
Before responding, read (in order):
- `~/.claude/agents/README.md` — current 13-agent roster + boundaries
- The task-brief handoff YAML delivered with your invocation
- `medium-agent-factory/AGENTS.md` — pipeline nodes + state schema + prompt inventory
- `medium-agent-factory/backend/app/orchestrator.py` (top 60 lines) — PipelineState TypedDict
- `~/.claude/rules/python/langchain.md` — auto-loads on **/agents/**, verify anyway
```

**Rationale (Anthropic prompt engineering guide):** cold-start prompting sacrifices measured accuracy by ~15-20%. Hydration is not optional.

**Sizing:** 5-10 lines. If you need 12+, the agent is doing too much — see Slot 8 escalation.

---

### Slot 3 — TRIGGER HEURISTICS (5-10 lines)

Header marker: `─── Slot 3 — TRIGGER HEURISTICS`

"When you see X, do Y." Domain-specific decision rules that fire deterministically. NOT generic patterns.

**Bad:** "Follow LangChain best practices."
**Good:**
- When `state` key is `Annotated[list, add]` AND `>1` node writes it → flag concurrency risk in return schema
- When a node is missing `config: RunnableConfig` param → block on it (LangSmith trace propagation)
- When any prompt lacks a word-count target → refuse, escalate to prompt-engineer

**Sizing:** 5-10 lines. Each line is one heuristic. If you have 12+ heuristics, you may be encoding patterns that should live in `.claude/rules/`.

---

### Slot 4 — DOMAIN PATTERNS (20-40 lines of embedded few-shot code)

Header marker: `─── Slot 4 — DOMAIN PATTERNS`

The 2-4 canonical code patterns for this agent's domain, embedded as few-shot examples. Not exhaustive — the agent's job is to internalize these as REFERENCES, not COPY them verbatim.

**Rationale (Anthropic prompt engineering guide + internal patterns from current llmops-expert.md):** embedded few-shot examples measurably outperform prose descriptions ("write a pure LangGraph node") for code generation tasks.

**Format:** fenced code blocks with brief context lines above each.

**Sizing:** 20-40 lines total across all patterns. If a single pattern needs 20+ lines, it belongs in `.claude/rules/` referenced from Slot 2 hydration.

---

### Slot 5 — HANDOFF CONTRACT (5-8 lines)

Header marker: `─── Slot 5 — HANDOFF CONTRACT`

Machine-readable interface to the orchestrator (Architect). Declares:
- **INPUT:** which fields from the task-brief this agent consumes
- **OUTPUT:** which fields of the return-schema this agent produces

Every task-brief and return-schema follows the canonical YAML in Section 3 of this spec.

**Example (backend-expert Slot 5):**
```
INPUT (consumed from task-brief):
  - files_to_read, files_you_will_write, state_keys_you_read, state_keys_you_write
  - success_criteria (test_names + coverage minimums)
  - cost_budget

OUTPUT (return-schema fields populated):
  - files_written, files_modified, tests_added, lint_status
  - codex_findings_addressed, risks, escalations, cost_actual
```

**Sizing:** 5-8 lines. This is a contract, not a narrative — one line per field.

---

### Slot 6 — REVIEW CONTRACT (3-5 lines)

Header marker: `─── Slot 6 — REVIEW CONTRACT`

Declares this agent's Codex plugin interaction mode. Three legal modes plus per-task override:

```yaml
codex_mode: codex-blocking      # for high-blast-radius changes
codex_mode: codex-concurrent    # default for standard changes
codex_mode: codex-skip          # for TSDoc/prose-only edits
```

**Mode selection table:**

| Mode | When | Behavior |
|------|------|----------|
| **codex-blocking** | changes to `orchestrator.py`, auth, secrets, IaC, prod DB schema | agent WAITS for `/codex:adversarial-review --wait` before declaring done |
| **codex-concurrent** | standard code changes (routes, components, nodes, tests) | agent commits, fires `/codex:adversarial-review --fresh --background`, next task starts immediately |
| **codex-skip** | TSDoc emission only, prose-only .md edits, README updates | no Codex review; saves ~$0.03 + 30s per trivial commit |

**Per-task override (added per adversarial finding HIGH-4):** the cartridge's `codex_mode` is the DEFAULT for the agent's primary surface. Any task-brief may override via `codex_mode_override: <mode>`. This lets llmops-expert (default `codex-blocking` for orchestrator work) declare `codex-skip` for a JSONL case addition, and lets frontend-expert (default `codex-concurrent`) declare `codex-blocking` when touching an auth-adjacent route.

**Fallback when Codex is unavailable (added per adversarial finding MEDIUM-3):** if Codex plugin is not installed, auth fails, or rate-limits, `codex-blocking` degrades to `codex-concurrent` AND the agent adds `risks: ["codex-blocking degraded to concurrent — manual review required"]` to its return schema. Never silently skip the review.

Every agent MUST declare exactly one default mode. Slot 6 also declares how Codex findings feed back into the agent's NEXT invocation via the task-brief `codex_findings_addressed` field.

**Sizing:** 3-8 lines (allowance for override + fallback lines).

---

### Slot 7 — SELF-CRITIQUE CHECKLIST (5 lines)

Header marker: `─── Slot 7 — SELF-CRITIQUE CHECKLIST`

3-5 questions the agent asks itself before returning output. **One-shot only** — not a loop. Reflexion-paper evidence (Shinn et al., 2023) supports ~10-15% regression reduction on coding tasks with a single self-review pass; looped self-critique produces diminishing returns and cost blowup.

**Format:** numbered checklist. Each item is a concrete verifiable check.

**Example (llmops-expert Slot 7):**
```
Before returning output, verify:
1. Every node is `async def <name>(state, config=None) -> dict`?
2. Does the return dict contain ONLY the keys this node writes (no read-through)?
3. Are all `Annotated[list, operator.add]` state keys documented in PipelineState?
4. Are prompts loaded via `load_prompt()` (never hardcoded)?
5. Is `get_llm(role)` used everywhere (no bare `ChatAnthropic()`)?
```

**Sizing:** 5 lines total. If you have 8+ checks, distinguishing signal from noise gets harder — cut to the top 5.

---

### Slot 8 — ESCALATION TRIGGERS (3-5 lines)

Header marker: `─── Slot 8 — ESCALATION TRIGGERS`

When to hand off to a different expert. Declares:
- **Trigger:** the condition that fires the escalation
- **Target:** the expert receiving the handoff
- **Action:** what target does with the escalation

**Example (backend-expert Slot 8):**
```
Escalate to:
- `devops-expert` when: task requires new env var, Docker layer change, or CI workflow edit
- `llmops-expert` when: task requires modifying a LangGraph node, prompt file, or PipelineState key
- `frontend-expert` when: task requires an API contract change that alters SSE payload shape
- `architect` when: task ambiguity prevents completion (never guess — hand it back up)
```

**Sizing:** 3-5 lines. Each line names one target + one trigger.

---

### Slot 9 — WHAT YOU DO NOT DO (3-5 lines)

Header marker: `─── Slot 9 — WHAT YOU DO NOT DO`

Explicit domain boundaries. Prevents overlap with adjacent experts.

**Example (llmops-expert Slot 9):**
```
You do NOT:
- Write FastAPI route handlers (that is backend-expert)
- Write React components or Playwright tests (that is frontend-expert)
- Modify Docker/CI/CD (that is devops-expert)
- Author `prompts/*.txt` versioning or G-Eval rubrics (that is prompt-engineer)
- Build `evals/datasets/*.jsonl` datasets (that is eval-writer)
```

**Sizing:** 3-5 lines. Each line lists one forbidden surface + the correct owner.

---

### Slot 10 — COST BUDGET (2-4 lines)

Header marker: `─── Slot 10 — COST BUDGET`

**Advisory ceiling — the ONLY hard stop at the Claude Code agent level is `maxTurns` in the YAML frontmatter.** Slot 10 values are observed post-hoc via MongoDB `agent_runs` (Python instrumentation on the invocation site), NOT enforced mid-invocation. Claude Code sub-agents are model invocations launched by the Superpowers SDK, not Python processes — no runtime exists for `AgentTokenTracker` to interrupt from.

```yaml
cost_budget:
  max_tokens_per_invocation: <int>       # advisory; log-when-exceeded
  max_llm_calls: <int>                   # advisory
  max_usd_per_run: <float>               # advisory
```

To make a budget genuinely bounded, tune `maxTurns` conservatively — that IS a hard turn cap. Field-test drivers (Wave 5.4) that need $2 budgets should set `maxTurns: 60` explicitly and set `max_usd_per_run: 2.00` as a post-hoc watermark for the MongoDB alert.

**Sizing tier examples:**

| Agent tier | max_tokens | max_llm_calls | max_usd |
|-----------|-----------|---------------|---------|
| **Narrow-scope validators** (validate, jsdoc-formerly) | 8,000 | 2 | 0.05 |
| **Standard domain experts** (backend, frontend, devops) | 20,000 | 8 | 0.15 |
| **High-reasoning experts** (llmops, architect, adversarial) | 40,000 | 15 | 0.30 |
| **Field-test drivers** (llmops-expert on medium-factory field test) | 100,000 | 60 | 2.00 |

**Sizing (of Slot 10 itself):** 2-4 lines.

---

## 3. Handoff schema — task-brief (Architect → Expert)

Every task dispatched to an agent uses this YAML schema. Verbatim from design spec Section 4.4.

```yaml
task_id: sprint-<name>-task-<N>-<M>      # dash-separated integers (design doc canonical format)
agent: <agent-name>                      # matches ~/.claude/agents/<name>.md
depends_on: [<task_id>, ...]             # [] = parallel-eligible

files_to_read:                            # hydration files THIS task requires
  - <path>

files_you_will_write:                     # exclusive claim — DAG safety
  - <path>

files_you_MUST_NOT_touch:                 # blast-radius fence
  - <path>

state_keys_you_read: [<key>, ...]         # PipelineState fields consumed
state_keys_you_write: [<key>, ...]        # PipelineState fields produced

success_criteria:
  - <bulleted testable criterion>

cost_budget:
  max_tokens: <int>                       # advisory — see Slot 10 spec
  max_llm_calls: <int>                    # advisory
  max_usd: <float>                        # advisory

review_gate: [codex_adversarial, adversarial_subagent, ...]

codex_mode_override: <optional>           # overrides cartridge default per HIGH-4

context_notes: |
  <optional prose — max 150 tokens; anything not in files_to_read>
```

**Task ID format (locked per adversarial MEDIUM-2):** `sprint-<name>-task-<N>-<M>` — all integers, dash-separated. Example: `sprint-cartridge-v2-task-2-1`. This matches the design doc's canonical form and eliminates the `N.M` vs `N-M` divergence.

**Parallel-safety DAG rule:** two experts run in parallel iff all three hold:
1. `files_you_will_write` sets are disjoint
2. `state_keys_you_write` sets are disjoint
3. Neither `depends_on` the other

Otherwise sequential. Architect computes the DAG once, dispatches waves.

---

## 4. Handoff schema — return (Expert → Architect)

Every agent returns this YAML shape. Verbatim from design spec Section 4.4.

```yaml
task_id: <same as task-brief>
status: completed | blocked | escalated | done_with_concerns

files_written: [<path>, ...]
files_modified: [<path>, ...]
state_keys_added: [<key>, ...]
tests_added: [<test_name>, ...]

lint_status: clean | dirty
mypy_status: clean | dirty                # only for Python surfaces
build_status: clean | dirty | not_applicable

codex_findings_addressed: [<finding_id>, ...]   # format: "<file>:<line>:<severity>"

risks: [<one-line risk>, ...]

escalations:
  - target: <agent-name>
    reason: <one-line>
    action_required: <one-line>

cost_actual:
  tokens_in: <int>
  tokens_out: <int>
  usd: <float>

concerns: |
  <optional — only present when status = done_with_concerns>
```

**Finding-ID format (locked per adversarial LOW-2):** `<file>:<line>:<severity>` — e.g. `backend/app/orchestrator.py:88:HIGH`. Makes the Codex feedback loop machine-matchable across invocations.

**Status enum resolution (added per adversarial HIGH-2):** `done_with_concerns` is a legal terminal status. Architect treats it as `completed` for DAG advancement but MUST append the return-schema `concerns:` field into the NEXT task-brief's `context_notes` for the same agent OR into the reviewer's prompt. Design doc Section 4.4 supersedes here — this spec is canonical.

**Return schema canonical (added per adversarial HIGH-1):** this spec Section 4 is the canonical return schema. If it diverges from design doc Section 4.4 (e.g., `mypy_status`), this spec wins. Wave 4.1 CLAUDE.md rewrite will add a one-line pointer directing agents to this spec.

---

## 5. Codex-mode declarations — three worked examples

### Example A — codex-blocking (llmops-expert on orchestrator.py change)

```
─── Slot 6 — REVIEW CONTRACT
codex_mode: codex-blocking

Rationale: this task modifies backend/app/orchestrator.py, which is the
LangGraph state-machine seam. State-key collisions here are silent runtime
regressions. Agent MUST invoke `/codex:adversarial-review --wait` before
declaring done. Codex findings feed back via task-brief.codex_findings_addressed
on the next invocation.
```

### Example B — codex-concurrent (backend-expert on new route)

```
─── Slot 6 — REVIEW CONTRACT
codex_mode: codex-concurrent

Standard change surface (new FastAPI route + Pydantic model + tests).
Agent commits, then fires `/codex:adversarial-review --fresh --background`
without waiting. Any findings route to the next task-brief for this agent
via codex_findings_addressed. Non-blocking.
```

### Example C — codex-skip (frontend-expert on TSDoc-only edit)

```
─── Slot 6 — REVIEW CONTRACT
codex_mode: codex-skip

Docs-only edit (TSDoc emission on already-shipped exports). No behavior
change, no code paths touched. Skipping Codex saves ~$0.03 + 30s per
commit. If the edit inadvertently changes runtime behavior, the pre-commit
lint hook catches it before commit lands.
```

---

## 6. Reference example — llmops-expert v2 skeleton (all 10 slots)

This is a **skeleton** showing structure — Wave 2 Task 2.1 produces the full cartridge with populated code patterns.

```markdown
---
name: llmops-expert
description: LangGraph/LangChain/LLMOps specialist. Use for pipeline node design, state machines, structured output, eval architecture, LangSmith/Langfuse observability, prompt versioning, and cost optimization. Owns `get_llm(role)`, `.with_structured_output()`, and orchestrator.py wiring (absorbed from integrator).
model: claude-sonnet-4-6
maxTurns: 30
---

─── Slot 1 — ROLE
You own `.with_structured_output()`, the `get_llm(role)` factory, the 3-layer
eval architecture, and (as of Wave 0 verdict 2026-07-09) all `orchestrator.py`
wiring for medium-agent-factory. No other agent touches PipelineState schema
or LangGraph edge definitions.

─── Slot 2 — HYDRATION PROTOCOL
Before responding, read (in order):
- `~/.claude/agents/README.md` — current 13-agent roster + boundaries
- Delivered task-brief handoff YAML
- `medium-agent-factory/AGENTS.md` — pipeline nodes + state schema + prompts
- `medium-agent-factory/backend/app/orchestrator.py` (top 60 lines) — PipelineState TypedDict
- `~/.claude/rules/python/langchain.md` — auto-loaded on **/agents/**, verify anyway

─── Slot 3 — TRIGGER HEURISTICS
- state key `Annotated[list, add]` written by >1 node → flag concurrency in return-schema.risks
- node missing `config: RunnableConfig` param → block on it (LangSmith trace propagation)
- prompt without word-count target → refuse; escalate to prompt-engineer
- new node without RED test → refuse; escalate to eval-writer for dataset case
- `MemorySaver` in prod code path → BLOCKER

─── Slot 4 — DOMAIN PATTERNS
<20-40 lines of embedded pattern code — pure node, structured output, LLM factory, wiring>

─── Slot 5 — HANDOFF CONTRACT
INPUT (consumed):
  files_to_read, files_you_will_write, files_you_MUST_NOT_touch,
  state_keys_you_read, state_keys_you_write, success_criteria, cost_budget,
  review_gate, codex_mode_override, context_notes

OUTPUT (return-schema fields populated):
  files_written, files_modified, state_keys_added, tests_added,
  lint_status, mypy_status, build_status, codex_findings_addressed,
  risks, escalations, cost_actual, concerns (if done_with_concerns)

─── Slot 6 — REVIEW CONTRACT
codex_mode: codex-blocking      # DEFAULT for this agent's primary surface

Rationale: this agent's primary surface includes orchestrator.py wiring
(highest blast radius). Every orchestrator-touching commit awaits Codex.
For non-orchestrator work (eval JSONL cases, @observe decorators, docstrings),
the task-brief SHOULD set `codex_mode_override: codex-concurrent` or
`codex-skip` per spec Section 6 override rule. If Codex is unavailable,
degrade to codex-concurrent and add manual-review-required to risks.

─── Slot 7 — SELF-CRITIQUE CHECKLIST
Before returning output, verify:
1. Every node is `async def <name>(state, config=None) -> dict`?
2. Return dict contains ONLY the keys this node writes (no read-through)?
3. All `Annotated[list, operator.add]` state keys documented?
4. Prompts loaded via `load_prompt()` (never hardcoded)?
5. `get_llm(role)` used everywhere (no bare `ChatAnthropic()`)?

─── Slot 8 — ESCALATION TRIGGERS
Escalate to:
- `prompt-engineer` when: new prompt file needs versioning or G-Eval rubric
- `eval-writer` when: new agent lands without an evals/datasets JSONL case
- `sme-reviewer` when: task requires content-quality judgment on generated posts
- `backend-expert` when: task requires FastAPI route or Motor query changes
- `devops-expert` when: task requires new env var or CI workflow change
- `architect` when: task ambiguity prevents completion

─── Slot 9 — WHAT YOU DO NOT DO
- Write FastAPI route handlers (backend-expert)
- Write React components or SSE UI (frontend-expert)
- Configure Docker/CI/CD (devops-expert)
- Author `prompts/*.txt` versioning or G-Eval rubrics (prompt-engineer)
- Build `evals/datasets/*.jsonl` (eval-writer)
- Author content-quality judgments — tone, factual accuracy, Medium audience fit (sme-reviewer)

─── Slot 10 — COST BUDGET
cost_budget:
  max_tokens_per_invocation: 40000
  max_llm_calls: 15
  max_usd_per_run: 0.30
```

---

## 7. Slot-check enforcement (used by Wave 5 rubric.py)

The following regex identifies each slot marker deterministically. It handles Unicode variance in the box-drawing character AND slot names containing hyphens (e.g., `SELF-CRITIQUE`):

```python
SLOT_MARKER_RE = re.compile(
    r"^[─━―—–]{3} Slot (\d+) [——–\-] [A-Z][A-Z \-]+",
    re.MULTILINE,
)
REQUIRED_SLOTS = set(range(1, 11))
```

Character-class notes:
- Leading marker `[─━―—–]{3}`: covers U+2500, U+2501, U+2015, U+2014, U+2013 — LLMs commonly emit any of these as visually-identical horizontal bars
- Separator `[——–\-]`: covers em-dash U+2014, en-dash U+2013, hyphen-minus `-`
- Name char class `[A-Z \-]+`: includes hyphen so `SELF-CRITIQUE CHECKLIST` matches (Slot 7)

A cartridge passes header-only slot-check iff all 10 numbered markers are present.

**Content check (added per adversarial finding HIGH-5):** slot-check ALSO verifies minimum content per slot to prevent header-only ceremonial passes:

| Slot | Min content check |
|------|-------------------|
| Slot 4 (DOMAIN PATTERNS) | at least one fenced code block ` ```python ` or ` ```typescript ` of ≥ 5 lines |
| Slot 7 (SELF-CRITIQUE) | at least 3 numbered list items (`^[1-9]\.`) |
| Slot 8 (ESCALATION) | at least 2 lines mentioning agent names from the roster |
| Slot 9 (WHAT YOU DO NOT DO) | at least 3 bullet lines |
| All others | at least 2 non-blank lines below the header |

Wave 5 `rubric.py --slot-check <path>` exits 0 on PASS, 1 on FAIL with list of failing slot numbers and reason (missing header vs failed content check).

Until Wave 5 lands, the manual check is:
```bash
grep -Pc "^[─━―—–]{3} Slot [0-9]" ~/.claude-agents-v2/agents/<name>.md
# expected: 10
```

---

## 8. Size envelopes (per-cartridge line targets)

| Role | Line target |
|------|-------------|
| Narrow-scope validators (validate, scraper) | 100-160 |
| Standard domain experts (backend, frontend, devops, adversarial) | 120-180 |
| High-reasoning experts (llmops, prompt-engineer) | 140-200 |
| **architect** | 160-240 (justified — Slot 4 hosts routing table for 13 agents + task-brief example; extracting to README.md is the alternative per Wave 4.2) |
| Sme-reviewer, eval-writer | 120-180 |

Verified per-file with `wc -l`. Files outside the envelope require justification in Wave 3 gate review.

**Design doc / spec reconciliation (per adversarial MEDIUM-4):** design doc Section 4.2 states "120-180 lines per agent" as a single range. This spec's Section 8 supersedes with the tiered envelopes above. Wave 4.1 CLAUDE.md rewrite will point to this spec Section 8 for line envelopes.

---

## 9. Overlap-guard for new agents (prompt-engineer / eval-writer / llmops-expert)

Design spec Section 8 flags this as HIGH-likelihood risk. Boundary enforcement:

| Agent | Owns exclusively | Escalates to |
|-------|-----------------|--------------|
| **llmops-expert** | LangGraph nodes, orchestrator.py wiring, PipelineState schema | prompt-engineer for prompt files; eval-writer for datasets; sme-reviewer for content-quality judgments |
| **prompt-engineer** | `prompts/*.txt` versioning, G-Eval rubric authoring, few-shot exemplar injection | llmops-expert for node wiring; eval-writer for dataset cases; sme-reviewer for tone/fact review of generated content |
| **eval-writer** | `evals/datasets/*.jsonl`, deepeval Layer 1/2/3, dataset regression, metric selection | llmops-expert for pipeline state; prompt-engineer for prompt rewrites; sme-reviewer for factual-accuracy metrics |
| **sme-reviewer** | Fact accuracy, tone drift, LLMOps-domain terminology, Medium audience fit on generated posts | llmops-expert for pipeline node changes; prompt-engineer for prompt tone rewrites; eval-writer for coding the review as a metric |

Every agent's Slot 9 explicitly names all three peers — this is a hard requirement for the Wave 3 review gate.

### 9.1 Cross-surface tiebreaker rule (added per adversarial HIGH-3)

When a task requires simultaneous change to a prompt file AND the node that reads it (e.g., adding `{new_var}` to `my_agent_human.txt` also requires updating `state["new_field"]` in the corresponding node), Architect MUST split the task into TWO sequential sub-tasks, not one:

```
task_id: sprint-X-task-N-1
  agent: prompt-engineer
  owns: the prompts/*.txt edit
  depends_on: []

task_id: sprint-X-task-N-2
  agent: llmops-expert
  owns: the node change reading the new variable
  depends_on: [sprint-X-task-N-1]
```

Neither agent's `files_you_MUST_NOT_touch` needs to change — the sequencing enforces the boundary. Same rule applies to prompt + eval-dataset cross-surface changes (prompt-engineer first, eval-writer second).

---

## 10. Adversarial review anchors — questions to attack

For Task 1.2 adversarial reviewer, focus attention on:

1. **Slot 5 handoff-contract completeness** — does the schema in Section 3+4 cover every case Wave 2/3 tasks need? Any missing return field?
2. **Slot 6 Codex-mode selection** — is the three-mode taxonomy sufficient? Any case that fits none of the three (or fits two)?
3. **Slot 10 cost-budget enforcement** — is `AgentTokenTracker` actually wired to enforce the ceiling, or is it advisory-only? If advisory, is that safe?
4. **Overlap-guard sufficiency** — does Section 9 prevent silent duplication when prompt-engineer + llmops-expert both look at a prompts/*.txt change?
5. **Model-ID normalization** — will old-style `sonnet` / `haiku` values in existing cartridges cause silent routing errors when Wave 4.2 auto-generates README.md?
6. **Slot-check regex** — does Section 7's regex handle Unicode variance in the `─` marker (there are three visually identical characters: U+2500, U+2501, U+2015)?
7. **Size envelope for architect** — is the 140-200 line target enough given architect's Slot 4 needs a routing table for 13 agents?

Rate every finding: **BLOCKER | HIGH | MEDIUM | LOW**. Zero BLOCKERs required to proceed to Wave 2.
