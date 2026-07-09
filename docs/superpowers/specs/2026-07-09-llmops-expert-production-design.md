# Design: llmops-expert — Production Eval Depth (deepeval)

**Date:** 2026-07-09  
**Sprint:** llmops-expert production standard  
**Status:** Approved

## Problem

The `llmops-expert` agent description mentions deepeval/RAGAS but the agent body has no deepeval patterns. When dispatched on eval tasks, it produces guesswork:
- Can't choose the right metric for a given scenario
- Doesn't know how to map `PipelineState` keys to `LLMTestCase` fields
- Can't distinguish `assert_test()` (CI-blocking) from `evaluate()` (logging)
- Has no dataset discipline rules — agents add cases arbitrarily

The existing 3-layer skeleton (table + pytest marks) is correct and stays unchanged. This sprint adds the deepeval knowledge block that makes the skeleton actionable.

## Scope

**In:** deepeval metric selection, `LLMTestCase` construction from pipeline state, `assert_test()` vs `evaluate()`, dataset discipline rules, `maxTurns` bump to 30.

**Out:** RAGAS (not relevant to pure generation pipelines), LangSmith dataset management, Langfuse scoring, custom `BaseMetric` authoring guide.

## Changes

### 1. New `## Deepeval patterns` section in `llmops-expert.md`

Added immediately after the existing `## Eval architecture (3-layer)` section. Four subsections:

#### 1a. Metric selection table

| Scenario | Metric | Model tier |
|----------|--------|------------|
| Score a rubric (tone, depth, structure) | `GEval(criteria=..., evaluation_steps=[...])` | Sonnet |
| Detect factual hallucinations | `HallucinationMetric(threshold=0.5)` | Sonnet |
| Check output stays on topic | `AnswerRelevancyMetric(threshold=0.7)` | Haiku |
| Domain rule (word count, format gate) | `BaseMetric` subclass — pure Python | None |

**Hard rule:** Sonnet-backed metrics (`GEval`, `HallucinationMetric`) never appear in Layer 1 or Layer 2 CI gates. They belong in Layer 3 (`@pytest.mark.eval_deep`) only. Layer 1/2 use Haiku metrics or pure-Python `BaseMetric`.

#### 1b. `LLMTestCase` construction from `PipelineState`

```python
from deepeval.test_case import LLMTestCase

case = LLMTestCase(
    input=state["topic"],                        # user intent / prompt
    actual_output=state["draft_content"],        # what the pipeline produced
    expected_output=dataset_row.get("expected"), # optional golden answer
    context=[state["research_summary"]],         # grounding (required for HallucinationMetric)
    retrieval_context=None,                      # RAG only — always None in generation pipelines
)
```

`context` = what the LLM had access to when generating. Required for `HallucinationMetric`. `retrieval_context` is RAGAS territory — leave `None` for all non-RAG pipelines.

#### 1c. `assert_test()` vs `evaluate()`

```python
# Layer 1 / Layer 2 — CI gate, raises on failure, blocks PR
# Only Haiku-backed or pure-Python metrics here (AnswerRelevancyMetric uses Haiku)
from deepeval import assert_test
assert_test(test_case, [AnswerRelevancyMetric(threshold=0.7)])

# Layer 3 / production monitoring — never raises, logs scores
from deepeval import evaluate
results = evaluate([test_case], [GEval(criteria="depth", evaluation_steps=[...])])
# write results to MongoDB:
for r in results.test_results:
    await db.agent_runs.insert_one({
        "run_id": state["run_id"],
        "metric": r.name,
        "score": r.score,
        "passed": r.success,
    })
```

Never use `assert_test()` with Sonnet-backed metrics in CI — unbounded cost and timeout risk on large datasets.

#### 1d. Dataset discipline — 4 rules

1. **Minimum 20 cases per metric** before it gates a PR. Fewer = too noisy, too many false positives.
2. **JSONL schema** — always include `tags` for regression filtering:
   ```jsonl
   {"input": {"topic": "...", "research_summary": "..."}, "expected": {"score_above": 0.7}, "tags": ["edge_case", "long_form"]}
   ```
3. **Capture before fixing** — when a node produces a production failure, add it to the dataset *before* writing the fix. A fix without the dataset case is untested regression surface.
4. **Layer 3 dataset size: practical cap ~200 cases per suite** — weekly runs tolerate this; beyond 200, split into domain-tagged sub-suites. Layer 1/2 datasets stay under 50 cases to keep CI under 30 seconds.

### 2. `maxTurns` bump: 20 → 30

Eval tasks involve writing test datasets, running suites, reading results, and fixing issues. 20 turns is insufficient for a full eval implementation loop.

## Files Changed

| File | Change |
|------|--------|
| `~/.claude/agents/llmops-expert.md` | Add `## Deepeval patterns` section + bump `maxTurns` |
| `agents/llmops-expert.md` (master prompt mirror) | Same change |

## Acceptance Criteria

- Agent dispatched on "add deepeval to quality node" produces correct metric selection without being told which metric to use
- Agent uses `assert_test()` for Layer 1/2 and `evaluate()` + MongoDB write for Layer 3 without prompting
- Agent constructs `LLMTestCase` with correct field mapping from `PipelineState`
- Agent warns when Sonnet metric appears in Layer 1/2
- No existing sections removed or restructured
