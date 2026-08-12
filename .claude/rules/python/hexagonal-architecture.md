---
description: Hexagonal architecture (Ports & Adapters) for Python microservices — LangGraph pipelines, FastAPI, MongoDB. Import discipline, functional nodes, Protocol ports.
paths: ["**/src/**/*.py", "**/backend/**/*.py", "**/app/**/*.py"]
---

## HEXAGONAL ARCHITECTURE — PYTHON MICROSERVICES (FASTAPI + LANGGRAPH)

### Layer structure (non-negotiable)

```
src/<package>/
├── domain/          # zero external imports — pure Python only
│   ├── models.py    # Pydantic models, TypedDicts
│   ├── ports.py     # Protocol ABCs (interfaces for adapters)
│   └── scoring.py   # pure business logic functions
├── infrastructure/  # concrete adapters — implement ports
│   ├── mongo.py     # MongoDB adapter
│   ├── hiring_cafe.py | fetcher.py  # HTTP adapters
│   └── deepseek.py  # LLM factory + pricing constants
└── application/     # orchestration — nodes, use cases, pipeline
    └── nodes/       # LangGraph nodes
```

### Domain layer rules

- **Zero imports of FastAPI, Motor, LangChain, requests, pymongo** in domain/
- Only stdlib + pydantic allowed
- Pure functions: `def fn(arg) -> result` — no side effects
- Protocol ABCs define what infrastructure must implement:

```python
# domain/ports.py
from typing import Any, Protocol

class ExtractionCache(Protocol):
    def get_extraction(self, job_id: str) -> dict[str, Any] | None: ...
    def save_extraction(self, job_id: str, ...) -> bool: ...

class RawJobStore(Protocol):
    def save_raw_jobs(self, jobs: list[dict[str, Any]]) -> int: ...
```

### Infrastructure layer rules

- Optional-dependency guard (`try: import pymongo`) is ACCEPTED — not a violation
- Singleton pattern (`instance = MyAdapter()`) is fine for stateful clients
- Expose public names (no underscore prefix): `make_llm()`, `PRICE_PROMPT`
- When imported into nodes: `from ..infrastructure.deepseek import make_llm as _make_llm`
  (underscore alias preserves test-patch compatibility)

### LangGraph node rules — functional style

Nodes are pure functions: `state → dict`. Non-negotiable.

```python
# CORRECT — node is a pure function
def score_node(state: MatcherState) -> dict:
    scored = [score_job(e, state["profile"], date.today()) for e in state["extracted_jobs"]]
    return {"scored_jobs": scored, "token_stats": state.get("token_stats", {})}

# WRONG — mutation in place, stateful side effects in node body
def score_node(state):
    state["scored_jobs"] = ...  # never mutate state
```

### Import discipline (non-negotiable)

All imports at module top level. No imports inside functions or conditionals.

```python
# WRONG
def _run(args):
    from .profile import load_profile   # import inside function

# CORRECT
from .profile import load_profile       # top of file

def _run(args):
    profile = load_profile(args.profile)
```

**Exception:** `try: import optional_dep` for optional-dependency guards is accepted.

### Backward-compat shim pattern

When restructuring, keep old paths working via thin re-exports:

```python
# old: src/job_matcher/models.py (now a shim)
from .domain.models import Job, ExtractedJob, ScoredJob, ProfileData, MatcherState
__all__ = ["Job", "ExtractedJob", "ScoredJob", "ProfileData", "MatcherState"]
```

### Test patch discipline after refactor

Patches must target where the name is **used**, not where it is **defined**:

```python
# AFTER moving requests to infrastructure/hiring_cafe.py:
# WRONG — shim module doesn't have 'requests' in its namespace
patch("job_matcher.fetcher.requests.get")

# CORRECT — patch where it's actually used
patch("job_matcher.infrastructure.hiring_cafe.requests.get")
```

If a node imports `from ..infrastructure.mongo import mongo_db`, then patch:
`patch("job_matcher.nodes.extract.mongo_db")` — name is in extract's namespace.

### Functional programming checklist

- [ ] Domain functions are pure (same input → same output, no I/O)
- [ ] Nodes return new dicts — never mutate `state`
- [ ] Side effects (DB, LLM, HTTP) confined to infrastructure layer
- [ ] List comprehensions preferred over for-loops with append
- [ ] No mutable default arguments
- [ ] Constants at module level with UPPER_CASE names
