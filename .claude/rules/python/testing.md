---
description: Python multi-service testing rules — unique class names, no __init__.py in tests, importlib ordering, Motor event loop, guard assertions
paths: ["**/tests/**", "**/test_*.py", "**/conftest.py", "pytest.ini", "pyproject.toml"]
---

## PYTHON TESTING — MULTI-SERVICE RULES

### Test class names — always unique per service
```python
# WRONG — collides when pytest discovers across services
class TestHandler: ...

# CORRECT
class TestOrchestratorHandler: ...
class TestAgentDataHandler: ...
```

### `__init__.py` placement
- Add to service source dirs if needed for imports
- NEVER add to `tests/` subdirectories — causes pytest to resolve all `tests.test_handler` to the same module name and silently load the wrong one

### importlib.util — register module in sys.modules BEFORE exec_module
```python
spec = importlib.util.spec_from_file_location("orchestrator.index", path)
mod = importlib.util.module_from_spec(spec)
sys.modules["orchestrator.index"] = mod   # MUST come before exec_module
spec.loader.exec_module(mod)
```

### Guard assertion (add one per service test file)
Proves the correct module was loaded — not a different service with the same class name:
```python
def test_does_not_have_analyst_fields(self) -> None:
    body = json.loads(index.handler({}, _ctx())["body"])
    assert "summary" not in body   # "summary" would exist if wrong module loaded
```

### pytest.ini_options (non-negotiable)
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "module"   # prevents Motor event-loop rebind error
addopts = "--import-mode=importlib"
testpaths = ["tests", "evals"]
markers = [
    "eval_deep: slow LLM-as-judge tests — nightly only",
    "e2e: require real MongoDB",
]
```

### Motor + pytest-asyncio event loop
pytest-asyncio creates a new event loop per test. Motor binds to the loop at first connection.  
Fix: use synchronous PyMongo for cleanup + reset the Motor singleton `_client = None` before each test.  
Full conftest.py pattern → `.claude/rules/cicd/pipeline.md`

### Test philosophy
Tests exist to disprove, not confirm. Write tests that would catch the specific failure mode you're guarding against. A test that always passes proves nothing. Its value is the ability to fail when code is wrong.
