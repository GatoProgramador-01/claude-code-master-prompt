---
description: New Python microservice project checklist — hexagonal architecture, import discipline, LangGraph Studio, CI/CD from day 1
paths: ["pyproject.toml", "setup.py", "setup.cfg", "**/ARCHITECTURE.md", "**/docs/**"]
---

## NEW PYTHON PROJECT — BOOTSTRAP CHECKLIST

When creating or scaffolding ANY new Python microservice (FastAPI, LangGraph, or plain CLI), apply all of the following on the FIRST commit. Retrofitting these later costs a full sprint.

### 1. Package structure — hexagonal from day 1

```
src/<package>/
├── domain/              # zero external imports — pure Python
│   ├── __init__.py
│   ├── models.py        # all Pydantic models + TypedDicts
│   └── ports.py         # Protocol ABCs for every adapter boundary
├── infrastructure/      # concrete adapters implementing ports
│   ├── __init__.py
│   └── <adapter>.py     # one file per external system (mongo, redis, http, llm)
├── application/         # orchestration — use cases, LangGraph nodes
│   ├── __init__.py
│   └── nodes/           # if using LangGraph
├── cli.py               # thin entrypoint — all imports at top
└── pipeline.py          # graph builder — if using LangGraph
```

**Domain layer invariant:** `grep -r "import fastapi\|import motor\|import langchain\|import requests" src/<package>/domain/` must return zero results.

### 2. Import discipline — enforced from line 1

ALL imports at module top level. Zero exceptions (except optional-dep guards).

```python
# CORRECT — module top level
import json
from .domain.models import ProfileData
from .infrastructure.mongo import mongo_db

def main() -> None:
    data = json.loads(...)
```

```python
# WRONG — never allowed
def main() -> None:
    import json                          # ← violation
    from .models import ProfileData      # ← violation
```

**Only allowed exception:** optional-dependency guard in infrastructure adapters:
```python
try:
    import pymongo
    _HAS_PYMONGO = True
except ImportError:
    _HAS_PYMONGO = False
```

### 3. LangGraph projects — always set up Studio

Create all three files on first commit:

**`langgraph.json`** (repo root):
```json
{
  "dependencies": ["."],
  "graphs": {
    "<graph_name>": "./src/<package>/pipeline.py:build_pipeline"
  },
  "env": ".env"
}
```

**`scripts/langgraph_dev.py`** (Windows launcher — pathspec 1.1.1 CLI bug workaround):
```python
import sys, types
_re2 = types.ModuleType("pathspec._backends.re2.base")
_re2.re2_error = Exception
sys.modules["pathspec._backends.re2.base"] = _re2
import os; os.environ.setdefault("PYTHONIOENCODING", "utf-8")
from langgraph_cli.cli import cli
sys.argv = ["langgraph", "dev", "--no-browser"]
cli()
```

**`docs/graph.png`** — generate after pipeline is built:
```python
uv run python -c "
from src.<package>.pipeline import build_pipeline
open('docs/graph.png','wb').write(build_pipeline().get_graph().draw_mermaid_png())
"
```

Launch Studio: `uv run python scripts/langgraph_dev.py`
Then open: `https://smith.langchain.com/studio/?baseUrl=http://127.0.0.1:2024`

**Add to `[project.optional-dependencies]` or `[dependency-groups]`:**
```toml
[dependency-groups]
dev = ["langgraph-cli[inmem]>=0.4"]
```

### 4. GitHub Actions CI — first commit

Never wait until Sprint 2. Wire CI on day 1. Minimum viable workflow (`.github/workflows/ci.yml`):

```yaml
name: CI
on:
  push:
    branches: [master, "feat/**"]
  pull_request:
    branches: [master]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - run: uv sync --frozen --extra dev
      - run: uv run python -m pytest tests/ -q --tb=short
        env:
          DEEPSEEK_API_KEY: sk-ci-placeholder
          MONGODB_URI: ""
```

Key CI gotchas:
- `uv sync --frozen --extra dev` (not `--frozen` alone) — needed to include `[project.optional-dependencies]`
- `npm install` + Node.js 24 (not `npm ci` + Node 20) — Windows lock file omits Linux WASM packages

### 5. pyproject.toml non-negotiables

```toml
[tool.setuptools.packages.find]
where = ["src"]
include = ["<package>*"]  # prevents "Multiple top-level packages" when evals/ sits next to src/

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.ruff.lint]
select = ["E", "F", "I"]

[tool.black]
line-length = 88
target-version = ["py311"]
```

### 6. Self-check before first commit

```
[ ] src/<package>/domain/ exists with models.py + ports.py
[ ] src/<package>/infrastructure/ exists (even if empty)
[ ] Zero imports inside functions anywhere in src/
[ ] langgraph.json exists (if LangGraph project)
[ ] scripts/langgraph_dev.py exists (if LangGraph project)
[ ] .github/workflows/ci.yml exists
[ ] pyproject.toml has [tool.setuptools.packages.find] include block
[ ] .gitignore includes: .env, .venv/, __pycache__/, cache.json, *_profile.json
```

### Why this matters

Retrofitting hexagonal architecture from a flat module layout costs a full sprint:
- 5 parallel agents over 2 waves
- 2 failing tests from broken patch paths
- Full re-import audit
- Backward-compat shims required to avoid breaking tests

Cost of doing it right from day 1: 30 minutes. Cost of retrofitting: 1 sprint day.
