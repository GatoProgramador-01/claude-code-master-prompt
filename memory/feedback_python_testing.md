---
name: Python pytest isolation rules — multimodule Lambda testing
description: Patterns learned from false-positive bugs when testing multiple Lambda services with same-named test files
type: feedback
originSessionId: 7b4ec8df-926e-46b2-9927-b2c47f07e647
---
**Rule 1 — Never use `TestHandler` as class name when multiple test files coexist.**
Use service-specific names: `TestOrchestratorHandler`, `TestAgentDataHandler`, `TestAgentAnalystHandler`.
Reason: pytest can cache and reuse a `TestHandler` class from service A when importing service B's test file — producing false positives that pass with wrong assertions.

**Rule 2 — Never put `__init__.py` in `tests/` subdirectories.**
`__init__.py` in test dirs makes pytest treat them as packages with the same module name (`tests.test_handler`). The first one wins in `sys.modules`, all others get the cached version. Remove `__init__.py` from test dirs; keep them only in service source dirs if needed.

**Rule 3 — Always add a guard test that asserts the module identity.**
```python
def test_does_not_have_analyst_fields(self) -> None:
    body = json.loads(index.handler({}, _ctx())["body"])
    assert "summary" not in body  # would exist if wrong module loaded
```
This catches the false-positive silently-passing-wrong-module bug immediately.

**Rule 4 — When loading a module with `importlib.util.spec_from_file_location`, always register in `sys.modules` BEFORE `exec_module`.**
```python
sys.modules[name] = mod   # ← must come before exec_module
spec.loader.exec_module(mod)
```
Reason: `@dataclass` decorator calls `sys.modules.get(cls.__module__)` internally. If the module isn't registered yet, it returns `None` and raises `AttributeError: 'NoneType' has no attribute '__dict__'`.

**Rule 5 — Use unique module names per service in `spec_from_file_location`.**
```python
spec = importlib.util.spec_from_file_location("orchestrator.index", path)   # unique
spec = importlib.util.spec_from_file_location("agent_data.index", path)     # unique
```
Never use a generic name like `"index"` — it gets cached and reused across services.

**Why:** In multiagent-aws-infra Week 1, agent-data ran 7 analyst tests and all passed — a silent false positive. The `test_does_not_have_analyst_fields` guard would have caught this immediately.

**How to apply:** Every time a new Lambda service gets a test file, apply all 5 rules before writing the first test.
