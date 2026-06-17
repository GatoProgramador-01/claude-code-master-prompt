---
name: LLMOps Production Study
description: Tools, patterns and interview narrative for LLM production deployment — what the user is actively studying to land an LLM job
type: reference
originSessionId: 4e386939-ea33-4152-8408-d3930d2b200e
---
## The 5 domains an LLM engineer must master

### 1. Evaluation in CI (highest priority)
Gate every PR with LLM evals — the #1 differentiator in interviews.

**Tools:**
- `langsmith evaluate()` — LangSmith native, supports online evals + datasets
- `deepeval` — pytest-native, works locally, good for RAG and structured output
- `RAGAS` — RAG-specific: faithfulness, answer_relevancy, context_precision

**Pattern:**
```
PR opened → unit tests → integration tests → eval gate (deepeval/langsmith)
  eval score >= threshold → pass
  eval score < threshold → block merge
```

**Portfolio target:** `evals/` folder in medium-agent-factory with 20 curated QualityAnalyzer test cases, wired into GitHub Actions CI.

---

### 2. Model serving
**Local (learn first):**
- **Ollama** — `ollama pull llama3.2` + `ollama serve` → OpenAI-compatible API on :11434
- `ChatOllama` from `langchain_ollama`; point `base_url` at it

**Production-grade:**
| Tool | When |
|------|------|
| vLLM | High-throughput GPU, OpenAI-compatible |
| TGI (HuggingFace) | Quantized models, Docker-native |
| Ollama | Local dev / small team |
| AWS Bedrock | Managed, already known |
| SageMaker endpoint | When you own fine-tuned model |

**Key:** every serious team uses an OpenAI-compatible endpoint internally — swap `base_url`, rest of code unchanged.

---

### 3. Observability (LLM-specific)
Beyond CloudWatch, track per LLM call:
- latency (TTFT + total), token usage + cost, model version, prompt hash, eval score (online), user feedback

**Tools:**
- **LangSmith** — online evals, datasets, feedback tagging
- **Langfuse** — open-source, self-hostable Docker, good portfolio piece
- **OpenTelemetry** — if team already has Grafana/Datadog

**Portfolio target:** Add Langfuse to medium-agent-factory Docker Compose. Replace AgentTokenTracker with Langfuse traces. Tag every run with `agent_name`, `model`, `session_id`.

---

### 4. Prompt versioning + A/B testing
**Pattern:**
```
prompts/ dir with semver tags  →  prompt change = new eval run
LangSmith Hub: hub.pull("org/prompt:v2.1")  ← pinned version in prod
A/B test: PROMPT_VERSION env var, 10%/90% traffic split
```

**Portfolio target:** `PROMPT_VERSION` env var + LangSmith Hub or `prompts/` dir. Eval gate on prompt changes in CI.

---

### 5. Local production stack (Docker Compose)
```yaml
services:
  ollama:        # model server, OpenAI-compatible :11434
  langfuse:      # observability dashboard :3000
  postgres:      # LangGraph checkpointer + Langfuse DB
  app:           # FastAPI backend
    OPENAI_BASE_URL: http://ollama:11434/v1  # drop-in swap
```

Being able to demo this fully local in an interview is a major differentiator.

---

## Interview narrative
> "Every merge goes through an eval gate — 20 curated test cases run against the QualityAnalyzer using deepeval. If correctness drops below 80%, the PR is blocked. In production I track per-agent token cost and latency through Langfuse, and instrument the revision loop to pinpoint quality regressions. For local deployment I run the full stack in Docker Compose with Ollama as model server and PostgreSQL as LangGraph checkpointer."

This covers: CI/CD, evals, observability, cost tracking, production serving.
