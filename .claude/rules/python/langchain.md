---
description: LangChain/LangGraph production rules — structured output, async, get_llm factory, JSON coerce fix, Motor typing, eval architecture
paths: ["**/agents/**", "**/chains/**", "**/prompts/**", "**/langgraph/**", "**/evals/**"]
---

## LANGCHAIN / LANGGRAPH

### Framework selection
| Use case | Framework |
|----------|-----------|
| Linear chains, fixed steps | LCEL |
| Stateful agents, loops, branching | LangGraph |
| Multi-agent with persistence | LangGraph + checkpointer |
| RAG without agent loops | LCEL + retriever |

Never use legacy `LLMChain` / `ConversationalChain`.

### Structured output — always Pydantic, never raw text parsing
```python
class Result(BaseModel):
    summary: str = Field(description="One-sentence summary")
    confidence: float = Field(ge=0.0, le=1.0)
    tags: list[str]

structured_llm = llm.with_structured_output(Result)
result = await structured_llm.ainvoke({"input": user_query})
```

### LLM JSON coerce — unicode-normalizer (non-negotiable)
LLMs emit curly quotes and em-dashes that break `json.loads`. Every `field_validator` coercing `str → list/dict`:
```python
@field_validator("issues", "tags", mode="before")
@classmethod
def _coerce_json_string(cls, v: Any) -> Any:
    if not isinstance(v, str):
        return v
    try:
        return json.loads(v)
    except json.JSONDecodeError:
        cleaned = (
            v.replace("‘", "'").replace("’", "'")
             .replace("“", '"').replace("”", '"')
             .replace("—", "-").replace("–", "-")
        )
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            return []   # never crash the pipeline
```

### get_llm(role) factory — never instantiate ChatAnthropic directly
```python
def get_llm(role: str = "worker", **kwargs: object) -> BaseChatModel:
    if settings.use_local_llm:
        from langchain_ollama import ChatOllama
        return ChatOllama(model=settings.local_llm_model,
                          base_url=settings.local_llm_base_url, **kwargs)
    from langchain_anthropic import ChatAnthropic
    model = settings.supervisor_model if role == "supervisor" else settings.worker_model
    return ChatAnthropic(model=model, api_key=settings.anthropic_api_key, **kwargs)  # type: ignore[call-arg]
```

`local_llm_base_url = "http://ollama:11434"` inside Docker, `"http://localhost:11434"` outside.

### Motor client — mypy strict mode
```python
_client: AsyncIOMotorClient[Any] | None = None
return cast(list[dict[str, Any]], await cursor.to_list(length=limit))
return cast(dict[str, Any], await db.posts.find_one({"run_id": run_id}))
```

Unused `# type: ignore[code]` are errors — use bare `# type: ignore` when codes differ across Python versions.

### Checkpointer selection
| Environment | Checkpointer |
|-------------|--------------|
| Dev | `MemorySaver` |
| Prod (PostgreSQL) | `PostgresSaver` |
| Prod (AWS) | `DynamoDBSaver` |
| Prod (MongoDB) | `MongoDBStore` |

Never ship `MemorySaver` to production.

### FastAPI SSE streaming
```python
@router.get("/runs/{run_id}/stream")
async def stream_logs(run_id: str, request: Request) -> StreamingResponse:
    async def event_generator():
        seen = 0
        while True:
            if await request.is_disconnected():
                break
            logs = await db.agent_logs.find(
                {"run_id": run_id}, {"_id": 0}, sort=[("timestamp", 1)]
            ).skip(seen).to_list(length=100)
            for log in logs:
                seen += 1
                yield f"data: {json.dumps(log, default=str)}\n\n"
            run = await db.pipeline_runs.find_one({"run_id": run_id}, {"status": 1})
            if run and run.get("status") in {"completed", "failed"}:
                yield 'data: {"__done__": true}\n\n'
                break
            await asyncio.sleep(1.5)
    return StreamingResponse(event_generator(), media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})
```

Rules: `__done__` sentinel closes stream | `X-Accel-Buffering: no` required behind Nginx | auth via query param (EventSource has no custom headers)

### Prompt versioning
Prompts in `prompts/` as `.txt` files. One file per prompt. Template vars: `{title}`, `{content}`.  
Never hardcode in agent files. `load_prompt` raises `KeyError` at startup — fail fast.

### 3-layer eval architecture
```
Layer 1 — Score direction    ~$0.002/case  haiku   CI gate: block PR on fail (≥75% accuracy)
Layer 2 — Batch regression   ~$0.04 total  haiku   Catches calibration drift
Layer 3 — LLM-as-judge       ~$0.005/case  sonnet  Nightly only (eval_deep marker)
```
CI runs Layer 1+2 only (`-m "not eval_deep"`). Dataset: 20–200 cases per agent in `evals/datasets/` as JSONL.  
`autouse` mock_db fixture in evals conftest — evals must never hit real DB.

### Model selection by role
| Role | Model |
|------|-------|
| Supervisor / orchestrator | Claude Sonnet |
| Specialist workers | Claude Haiku |
| Embedding | text-embedding-3-small |
| Eval judge | Claude Sonnet |

### Code review checklist
- No legacy `LLMChain` / `ConversationChain`
- Structured output via `.with_structured_output(PydanticModel)` — no raw text parsing
- `ainvoke`/`astream` in async contexts — no blocking `.invoke` in FastAPI handlers
- Each LangGraph node is a pure function — no side effects beyond returning new state
- Thread IDs are user/session scoped — never reused across users
- Checkpointer is production-grade in prod (not `MemorySaver`)
- All prompts in `prompts/` — none hardcoded in agent files
- `get_llm(role)` everywhere — no direct `ChatAnthropic` instantiation
- LangSmith tracing enabled and project name set per environment
