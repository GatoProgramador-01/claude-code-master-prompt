# Adversarial review — cartridge-v2 spec

**Reviewer:** adversarial subagent
**Date:** 2026-07-09
**Target:** `docs/superpowers/specs/agent-cartridge-v2.md` (512 lines)
**Evidence basis:** spec + design doc + usage heatmap + llmops-expert v1 + absence of medium-agent-factory locally

---

## BLOCKER findings

### BLOCKER-1 — Cost-budget enforcement is purely advisory; no hard stop exists

The spec (Section 10, line 228) states: "Enforced by `base.AgentTokenTracker` → MongoDB `agent_runs` collection. When ceiling hit, agent stops, reports partial output + escalation flag."

The medium-agent-factory repo is absent locally, so `base.AgentTokenTracker` cannot be verified directly. However:

- The design doc Section 4.2 (line 175) says the same thing verbatim: "Enforced via `base.AgentTokenTracker`".
- Claude Code sub-agents (`~/.claude/agents/*.md`) are **not** Python processes. They are Claude model invocations launched by the Superpowers SDK. There is no Python runtime for `base.AgentTokenTracker` to execute in. The tracker can only observe after the fact by reading MongoDB — it cannot interrupt a live model call mid-invocation.
- The `maxTurns` YAML field does cap the number of turns, but it is NOT the same as `max_tokens_per_invocation` or `max_usd_per_run`. An agent can exhaust a $0.30 budget in a single 40k-token turn that never exceeds `maxTurns`.

**Result:** Slot 10 creates a false guarantee. Wave 2-3 drafters will write cost budgets they believe are enforced; they are not. A runaway llmops-expert field test can bill $2+ unchecked.

**Fix:** Change Slot 10 spec language from "enforced" to "advisory ceiling — tracked post-hoc via MongoDB `agent_runs`; hard stop requires `maxTurns` + per-turn token limits set at invocation site." Add a note that the only real hard stop available at the Claude Code agent level is `maxTurns`. Remove the false "agent stops" guarantee until an actual interrupt mechanism is wired.

---

### BLOCKER-2 — Slot-check regex rejects valid slot headers for ALL currently defined agents

The spec Section 7 (line 459) defines:

```python
SLOT_MARKER_RE = re.compile(r"^─── Slot (\d+) — [A-Z ]+", re.MULTILINE)
```

The character `─` at position 0 of the pattern is Unicode U+2500 (BOX DRAWINGS LIGHT HORIZONTAL). This is the character used throughout the spec itself.

Attack: Section 10 of the spec (line 509) acknowledges three visually identical characters: U+2500, U+2501, U+2015. But it also omits U+2014 (EM DASH) and U+FF0D (FULLWIDTH HYPHEN-MINUS), both of which Claude models commonly emit when generating markdown. Any Wave 2-3 drafter agent that outputs a slot header using U+2014 (the standard em dash in most LLM outputs) will produce a slot header that the regex silently skips.

Critically, the regex also demands `[A-Z ]+` after the slot number and `—` separator. The slot name `WHAT YOU DO NOT DO` contains only A-Z and spaces, but `HYDRATION PROTOCOL` is also fine. However:
- Slot names with hyphens (e.g., `SELF-CRITIQUE`) fail the `[A-Z ]+` pattern. `SELF-CRITIQUE CHECKLIST` contains a hyphen. The spec's own Section 2 names Slot 7 as `SELF-CRITIQUE CHECKLIST` (line 161). The regex `[A-Z ]+` does NOT match hyphens.
- Therefore the current regex will return only 9 of 10 required slots for any cartridge that uses the spec's own slot names verbatim, causing Wave 5 rubric.py to always report Slot 7 missing.

**Fix:** Change the character class to `[A-Z \-]+` and extend the leading marker match to a character class covering all visually-similar Unicode dashes: `[─━―—–]`. Full corrected pattern:

```python
SLOT_MARKER_RE = re.compile(
    r"^[─━―—–]{3} Slot (\d+) [——–] [A-Z][A-Z \-]+",
    re.MULTILINE
)
```

---

## HIGH findings

### HIGH-1 — Return schema mismatch between design doc and spec: `mypy_status` field is missing from design doc

The spec Section 4 return schema (line 306) includes:
```yaml
mypy_status: clean | dirty    # only for Python surfaces
```

The design doc Section 4.4 return schema (line 239) does NOT include `mypy_status`. It lists only `lint_status`.

Any Architect agent hydrating from the design doc (which it reads per Section 4.4 of its own cartridge) will generate task-briefs whose success criteria omit mypy. Any automated parser of the return schema YAML keyed to the design doc will silently drop `mypy_status`. This is a schema divergence between the spec and its own governing document.

**Fix:** Add `mypy_status: clean | dirty` to design doc Section 4.4 return schema. Alternatively, add a one-line note in the spec: "This spec supersedes design doc Section 4.4 on the return schema — use spec Section 4 as canonical."

---

### HIGH-2 — Return schema status enum is inconsistent between spec and design doc

The spec Section 4 (line 301) defines:
```yaml
status: completed | blocked | escalated | done_with_concerns
```

The design doc Section 4.4 (line 237) defines:
```yaml
status: completed | blocked | escalated
```

`done_with_concerns` is absent from the design doc. When Architect (hydrating from design doc per its Slot 2) generates a task-brief `review_gate`, it will not anticipate a `done_with_concerns` return from an expert — it has no branch for it. The Architect will either silently treat it as `completed` or crash on an unrecognized enum value.

**Fix:** Add `done_with_concerns` to design doc Section 4.4 OR add an explicit routing rule in the spec: "Architect treats `done_with_concerns` as `completed` but appends `concerns:` field to the next task-brief's `context_notes`."

---

### HIGH-3 — Overlap guard has a live hole: prompts/*.txt that ALSO require a node change

Section 9 boundary table (line 490-496) assigns:
- `llmops-expert` → owns LangGraph nodes, orchestrator.py wiring, PipelineState schema
- `prompt-engineer` → owns `prompts/*.txt` versioning, G-Eval rubric authoring, few-shot exemplar injection

The hole: A task that requires changing a prompt file AND updating the node that loads it (e.g., adding a new `{variable}` to `my_agent_human.txt` requires also updating the `state["new_field"]` read in the corresponding node) belongs to BOTH agents simultaneously. The spec provides no tiebreaker.

The `files_you_MUST_NOT_touch` mechanism partially helps (design doc line 461) but the spec does not encode a rule for which agent gets primacy when a task spans both surfaces. A Wave 2-3 drafter writing llmops-expert's Slot 9 will list "prompt files" as forbidden; a Wave 3 drafter writing prompt-engineer's Slot 9 will list "node wiring" as forbidden. Result: neither agent completes the task; both escalate to architect; architect has no explicit resolution rule.

**Fix:** Add an explicit tiebreaker rule to Section 9: "When a task requires simultaneous change to a prompt file AND the node that reads it, `prompt-engineer` owns the prompt change, `llmops-expert` owns the node change, and the task-brief `depends_on` must sequence them (prompt first, node second). Architect generates two sequential sub-tasks, not one."

---

### HIGH-4 — Reference example in Section 6 (llmops-expert v2 skeleton) violates its own Slot 6 rule

The spec Section 6 skeleton (line 417-421) declares:
```
─── Slot 6 — REVIEW CONTRACT
codex_mode: codex-blocking
Rationale: this agent's surface includes orchestrator.py wiring...
```

The sizing rule for Slot 6 is "3-5 lines" (spec line 158). The skeleton's Slot 6 is 3 lines (mode + rationale sentence). That fits.

However, the spec's Mode selection table (line 146-153) says `codex-blocking` applies when changes touch "orchestrator.py, auth, secrets, IaC, prod DB schema." The skeleton declares `codex-blocking` as the BLANKET mode for llmops-expert — for ALL its tasks, including those that only touch eval datasets or observability decorators. Under this blanket declaration, every TSDoc-only edit, every JSONL case addition, and every `@observe()` decorator addition will also block on Codex. This contradicts the `codex-skip` and `codex-concurrent` rationale that saves "$0.03 + 30s per trivial commit."

The spec should either (a) allow agents to declare mode per-task (not per-agent), or (b) acknowledge that codex-blocking is the safe conservative default and accept the cost. The current structure implies one mode per cartridge, which is too coarse.

**Fix:** Add to Slot 6 spec: "Mode is declared as the DEFAULT for this agent's primary surface. Agents may override per-task by passing `codex_mode_override:` in the task-brief. If absent, the cartridge default applies." This makes the skeleton's blanket `codex-blocking` legible without invalidating it.

---

### HIGH-5 — Slot 4 domain patterns in the skeleton are a placeholder — the self-reference is circular

The spec Section 6 skeleton (line 406):
```
─── Slot 4 — DOMAIN PATTERNS
<20-40 lines of embedded pattern code — pure node, structured output, LLM factory, wiring>
```

This is a literal angle-bracket placeholder. The spec simultaneously states (line 97-100): "embedded few-shot examples measurably outperform prose descriptions for code generation tasks." A Wave 2 drafter reading the spec will see a skeleton with empty Slot 4 and may produce another skeleton-level cartridge, passing the slot-check regex (the marker is present) but failing actual quality.

The slot-check regex (Section 7) only verifies the HEADER is present, not that the slot has content. There is no content-length or code-block count check in rubric.py (which doesn't exist yet). Until Wave 5, the manual check (`grep -c "^─── Slot"`) also only checks headers.

**Fix:** Add a minimum-content rule to Section 7: "Slot 4 passes slot-check iff it contains at least one fenced code block (` ```python `) of at least 5 lines. Slot 7 passes iff it contains at least 3 numbered list items." Update the rubric.py spec to include these content checks alongside the header regex.

---

## MEDIUM findings

### MEDIUM-1 — Slot 5 handoff contract missing `review_gate` field on INPUT side

The task-brief schema (spec Section 3, line 279) includes:
```yaml
review_gate: [codex_adversarial, adversarial_subagent, ...]
```

But the Slot 5 example (spec line 118-128) lists only:
```
INPUT:  files_to_read, files_you_will_write, state_keys_you_read, state_keys_you_write,
        success_criteria, cost_budget
```

`review_gate` is absent from the Slot 5 INPUT declaration. This means an expert reading its own Slot 5 does not know it must honor the `review_gate` instructions. If `review_gate: [codex_adversarial]` is in the task-brief but the agent's Slot 5 doesn't list it as a consumed INPUT field, the agent may ignore the gate.

**Fix:** Add `review_gate` to the Slot 5 INPUT field list in the spec's example (line 121) and in the llmops-expert skeleton (line 410). This makes gate compliance a declared contract, not an implicit expectation.

---

### MEDIUM-2 — `depends_on` field format is inconsistent between spec and design doc

Spec Section 3 (line 256): `task_id: sprint-<name>-task-<N.M>` — uses dot notation `N.M`.
Design doc Section 4.4 (line 213): `task_id: sprint-N-task-M` — uses bare integer `M`.

An Architect generating task IDs from the design doc format produces `sprint-1-task-2`. An expert returning `task_id: sprint-1-task-2` and another task's `depends_on: [sprint-seo-task-1.2]` (spec format) will never match — the DAG resolver will never find the dependency, treating all tasks as parallel-eligible even when they are not.

**Fix:** Pick one format and enforce it in both documents. Recommend the design doc format (`sprint-N-task-M`) as it is simpler. Amend spec Section 3 line 255.

---

### MEDIUM-3 — Codex-mode has no fallback when Codex plugin is unavailable

Section 5 (worked examples, lines 332-368) and Section 9 overlap-guard both assume Codex is available. The `codex-blocking` mode says "agent WAITS for `/codex:adversarial-review --wait` before declaring done." If Codex plugin is not installed, not authenticated, or rate-limited, the agent has no specified fallback:
- Does it declare itself `blocked`?
- Does it degrade to `codex-concurrent`?
- Does it fail the entire sprint?

The design doc Section 8 Risks table (line 456) mentions "Codex rate-limits on the big diff" with mitigation "Split diff into 3 chunks" — but says nothing about plugin unavailability.

**Fix:** Add to Slot 6 spec: "If Codex is unavailable (plugin not installed, auth failure, rate limit), `codex-blocking` degrades to `codex-concurrent` AND the agent adds `risks: ["codex-blocking degraded to concurrent — manual review required"]` to its return schema. Never silently skip the review."

---

### MEDIUM-4 — Size envelope contradiction: design doc says 120-180, spec says 140-200 for high-reasoning agents

Design doc Section 4.2 (line 133): "Target: 120-180 lines per agent."
Spec Section 8 (line 478-479): High-reasoning experts target "140-200" lines.

The spec is the governing document (it post-dates the design doc), but Wave 2-3 drafters hydrate BOTH documents. A drafter reading design doc first will target 120-180; reading spec first will target 140-200. For llmops-expert with a 268-line v1 and a Slot 4 that needs 20-40 lines of code, the 120-line lower bound in the design doc is too tight.

**Fix:** Amend design doc Section 4.2 line 133 to match spec Section 8 exactly: "Target: 100-200 lines per agent, tiered by scope per cartridge-v2 spec Section 8." Remove the 120-180 single-range claim.

---

### MEDIUM-5 — llmops-expert v2 skeleton Slot 9 omits `sme-reviewer` as a distinct boundary

The v2 skeleton (spec line 439-443) lists five DO NOT DO items:
- FastAPI route handlers (backend-expert)
- React components or SSE UI (frontend-expert)
- Docker/CI/CD (devops-expert)
- `prompts/*.txt` versioning or G-Eval rubrics (prompt-engineer)
- `evals/datasets/*.jsonl` (eval-writer)

`sme-reviewer` is absent. The llmops-expert owns the eval architecture (deepeval layers, metric selection), which overlaps with sme-reviewer's "fact/tone review" scope. A task asking llmops-expert to tune a G-Eval rubric for factual accuracy could equally be routed to sme-reviewer. Since sme-reviewer is new (Wave 3), its boundary isn't in the skeleton — but it should be, because the overlap is the highest-likelihood live confusion.

**Fix:** Add to llmops-expert Slot 9: "Do NOT author content-quality judgments (tone, factual accuracy, Medium audience fit) — that is sme-reviewer." And add `sme-reviewer` as a named escalation target in Slot 8.

---

### MEDIUM-6 — Architect line envelope is genuinely infeasible at 140-200 lines

Spec Section 8 (line 478): architect targets "140-200 lines."

Architect's required content:
- YAML frontmatter: ~6 lines
- Slot 1 ROLE: 2-3 lines
- Slot 2 HYDRATION: 5-10 lines (reads more files than any other agent)
- Slot 3 TRIGGER HEURISTICS: 5-10 lines
- Slot 4 DOMAIN PATTERNS: **routing table for 13 agents** = at minimum 15 lines + 1 task-brief example ≈ 25-30 lines. This alone is 20-40 lines per spec requirements.
- Slot 5 HANDOFF CONTRACT: 5-8 lines
- Slot 6 REVIEW CONTRACT: 3-5 lines
- Slot 7 SELF-CRITIQUE: 5 lines
- Slot 8 ESCALATION: 3-5 lines
- Slot 9 WHAT YOU DO NOT DO: 3-5 lines
- Slot 10 COST BUDGET: 2-4 lines

Minimum sum: 6+2+5+5+25+5+3+5+3+3+2 = **64 lines of slot content**, plus slot headers (10 × 1 line = 10), section dividers, and blank lines (≈ 30). Minimum realistic total: ~104 lines. With a proper routing table and one task-brief example, 170-220 lines is more realistic. 200 is a soft ceiling that will be breached legitimately.

**Fix:** Raise architect's line target to 160-240 lines in Section 8. This is not scope creep — it is arithmetic. Alternatively, move the 13-agent routing table to a separate `~/.claude/agents/README.md` (design doc already plans this in Wave 4.2) and have architect's Slot 4 reference the file rather than embed the table, keeping architect within 140-200 by referencing rather than duplicating.

---

## LOW findings

### LOW-1 — Haiku model ID in spec is inconsistent with normalization table

Spec Section 1 model table (line 27): `claude-haiku-4-5-20251001`

The normalization instruction says "no bare `sonnet`/`haiku`" and provides full IDs. However `claude-haiku-4-5-20251001` includes a date suffix (`20251001`) while `claude-sonnet-4-6` and `claude-opus-4-7` do not. This inconsistency means a Wave 2-3 drafter may copy the Haiku ID verbatim for a validator agent and get an API error if the date-suffixed model has been superseded or the suffix format changes. The CLAUDE.md system reminder also lists `claude-haiku-4-5-20251001` — this is consistent but the inconsistent suffix pattern across tiers is a latent error source.

**Fix:** Document WHY Haiku requires a date suffix (it has multiple `-4-5` releases distinguished by date) while Sonnet/Opus do not. Add a one-line note in Section 1: "Haiku requires the date suffix to pin the exact release; Sonnet/Opus currently have only one release per version."

---

### LOW-2 — `codex_findings_addressed` field has no schema for the finding IDs it references

The return schema (spec Section 4, line 312): `codex_findings_addressed: [<finding_id>, ...]`

No spec section defines what a `finding_id` looks like. Codex output format is not normalized — it typically produces natural-language findings without machine-readable IDs. An agent populating this field will invent IDs (`finding-1`, `file.py:42`, free-form strings) that cannot be matched cross-invocation.

**Fix:** Define `finding_id` format: `<file>:<line>:<severity>` (e.g., `backend/app/orchestrator.py:88:HIGH`). Add this to Section 4 as a sub-schema note. This makes the feedback loop machine-readable rather than decorative.

---

### LOW-3 — `context_notes` field in task-brief is optional prose with no size cap

Spec Section 3 (line 281): `context_notes: | <optional prose>`. No size limit stated.

A verbose Architect could write 500 tokens of context_notes, defeating the "Prompts: max 300 tokens" delegation discipline from CLAUDE.md. The task-brief becomes a second CLAUDE.md per task.

**Fix:** Add `# max 150 tokens` inline comment to the `context_notes` field in Section 3, matching the 300-token-per-agent-prompt rule from CLAUDE.md. Flag violations as HIGH in Wave 5 rubric.py.

---

### LOW-4 — Slot 5 of the reference skeleton lists `files_modified` as absent from OUTPUT but spec Section 4 includes it

The skeleton Slot 5 OUTPUT (spec line 413-415):
```
files_written, state_keys_added, tests_added, lint_status, mypy_status,
codex_findings_addressed, risks, escalations, cost_actual
```

The return schema (spec Section 4, line 303) lists both `files_written` AND `files_modified` as separate fields. The skeleton omits `files_modified` from its OUTPUT declaration. An Architect parsing the skeleton's Slot 5 to know what the expert will return will not see `files_modified`, potentially misidentifying which files were changed (as opposed to newly created).

**Fix:** Add `files_modified` to the skeleton Slot 5 OUTPUT list (spec line 413).

---

## Explicit anchor verdicts

**Anchor 1 — Slot 5 handoff-contract completeness:**
PARTIAL FAIL. The task-brief schema is complete. The return schema is nearly complete. Two issues: (a) `review_gate` is not listed as a consumed INPUT in Slot 5 examples, meaning agents may not honor it — MEDIUM severity. (b) `files_modified` is absent from the skeleton Slot 5 OUTPUT — LOW severity. No BLOCKER, but both must be fixed before Wave 2 drafters write live cartridges.

**Anchor 2 — Codex-mode taxonomy:**
PARTIAL FAIL. The three-mode taxonomy is logically sufficient for the declared use cases. Two gaps: (a) no fallback behavior when Codex is unavailable — MEDIUM severity. (b) the taxonomy is declared per-agent cartridge, not per-task, making it too coarse for agents like llmops-expert whose surface ranges from TSDoc to orchestrator.py wiring — HIGH severity. The spec needs a `codex_mode_override` mechanism in the task-brief.

**Anchor 3 — Cost-budget enforcement:**
BLOCKER. `AgentTokenTracker` is described as a hard stop but Claude Code agents are model invocations, not Python processes. The tracker is observational at best, advisory at worst. The only real ceiling is `maxTurns`. This is a false guarantee that will produce billing surprises on field tests.

**Anchor 4 — Overlap-guard sufficiency:**
PARTIAL FAIL. The llmops-expert / prompt-engineer / eval-writer triangle is addressed in Section 9 with explicit Slot 9 naming. However, the cross-surface task (prompt file + node change simultaneously) has no tiebreaker rule — HIGH severity. Additionally, `sme-reviewer` is missing from llmops-expert's Slot 9, creating a live confusion boundary — MEDIUM severity.

**Anchor 5 — Model-ID normalization:**
PASS WITH CAVEAT. The spec table provides full IDs and explicitly bans bare names. The Haiku ID date-suffix inconsistency is LOW severity and cosmetic. Wave 4.2 README auto-generation will parse YAML frontmatter and render whatever ID is present — no silent routing error, only an API error if the ID is wrong. The caveat is that the date-suffix pattern is undocumented, making it a copy-error trap for Wave 2-3 drafters.

**Anchor 6 — Slot-check regex Unicode:**
BLOCKER. The regex pattern `[A-Z ]+` rejects Slot 7 (`SELF-CRITIQUE CHECKLIST`) because the hyphen is not in the character class. This means rubric.py will always report Slot 7 as missing even for perfectly-formed cartridges, causing Wave 5 gates to fail across all 13 agents. The Unicode dash variant issue is a secondary problem (also real) but the hyphen issue is the more immediate blocker.

**Anchor 7 — Architect line envelope:**
FAIL. The 140-200 line target is arithmetically infeasible given the spec's own Slot 4 requirements (routing table for 13 agents + task-brief example) plus all 10 mandatory slots. Minimum realistic count is 170-220 lines; a properly documented architect cartridge lands at ~200-240. The fix is either raising the ceiling to 240 or extracting the routing table to `README.md` and having Slot 4 reference it.

---

## Verdict for gate

**BLOCKED**

Two BLOCKER findings must be resolved before Wave 2 proceeds:

1. **BLOCKER-1** (cost enforcement false guarantee) — fix spec language, do not ship false safety claim to 13 agent drafters
2. **BLOCKER-2** (slot-check regex rejects Slot 7) — fix regex before Wave 5 rubric.py is written against it; if Wave 5 is built on the broken regex, all 13 cartridges fail gate regardless of quality

All HIGH findings should be resolved in the same Task 1.3 revision pass — they represent schema divergences that will cause Architect-Expert handoff failures in Wave 2 if unaddressed.
