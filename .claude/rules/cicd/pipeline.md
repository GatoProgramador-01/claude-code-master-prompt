---
description: FastAPI + Next.js + MongoDB CI/CD — 5-job pipeline, non-obvious gotchas, pre-commit/pre-push split, husky setup
paths: [".github/**", "**/.github/**", ".husky/**", ".pre-commit-config.yaml"]
---

## CI/CD PIPELINE — FASTAPI + NEXT.JS + MONGODB

### 5-job structure (in order)
1. `backend-ci` — ruff · black · mypy · unit tests (no MongoDB service needed)
2. `backend-e2e` — needs `backend-ci`, real MongoDB via `services:`, pytest `tests/e2e/`
3. `frontend-ci` — tsc · next lint · jest unit · next build
4. `frontend-e2e` — needs `frontend-ci`, builds Next.js then runs Playwright
5. `docker-build` — needs all ci+e2e jobs, PRs only, verifies both Dockerfiles compile

### Pre-commit / pre-push / CI split
| Gate | Max time | What runs |
|------|----------|-----------|
| pre-commit | <10s | Format (Black/Prettier), lint (Ruff/ESLint), `tsc --noEmit` |
| pre-push | <90s | Unit tests, build check, mypy |
| CI (PR gate) | Minutes | E2E (Playwright/pytest e2e), security scan, Docker build |

Playwright NEVER runs pre-commit or pre-push — requires running server, too slow.

---

## BACKEND CI — NON-OBVIOUS RULES

### black target-version must match CI Python version
```toml
[tool.black]
line-length = 88
target-version = ["py311"]   # must match setup-python: python-version in ci.yml
```

### ruff select belongs in [tool.ruff.lint] (ruff ≥ 0.8)
```toml
[tool.ruff]
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I"]

[tool.ruff.lint.per-file-ignores]
"evals/*" = ["E501"]
```

### mypy strict with Motor + LangChain
```python
from typing import Any, cast
_client: AsyncIOMotorClient[Any] | None = None
return cast(list[dict[str, Any]], await cursor.to_list(length=limit))
return ChatAnthropic(model=model, **kwargs)  # type: ignore[call-arg]
```
Unused `# type: ignore[code]` are errors — use bare `# type: ignore` when codes differ.

### pyproject.toml key sections
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "module"   # prevents Motor event-loop error
testpaths = ["tests", "evals"]
markers = ["eval_deep: slow nightly", "e2e: require real MongoDB"]

[tool.setuptools.packages.find]
include = ["app*"]   # prevents "Multiple top-level packages" when evals/ sits next to app/
```

---

## BACKEND E2E — MOTOR + PYTEST EVENT LOOP (non-negotiable)

pytest-asyncio creates a new event loop per test. Motor binds to loop at connection time.  
Fix: sync PyMongo cleanup + reset Motor singleton before each test.

```python
# tests/e2e/conftest.py
import os
os.environ.setdefault("MONGODB_DATABASE", "myproject_test")  # BEFORE any app import

import pymongo, pytest
from httpx import ASGITransport, AsyncClient
import app.database as _db_module
from app.config import settings
from app.main import app

@pytest.fixture(autouse=True)
def _clean_and_reset() -> None:
    mongo = pymongo.MongoClient(settings.mongodb_uri)
    db = mongo[settings.mongodb_database]
    db.pipeline_runs.delete_many({})
    db.posts.delete_many({})
    db.agent_runs.delete_many({})
    mongo.close()
    _db_module._client = None   # force Motor to re-bind on current test's loop

@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
```

`MONGODB_DATABASE` must be set BEFORE app is imported — pydantic-settings reads it once at `Settings()`.

---

## FRONTEND CI — NON-OBVIOUS RULES

- **`npm install` not `npm ci`** — Windows lock file omits Linux WASM packages (`@emnapi/runtime`); `npm ci` fails with "Missing from lock file"
- **Node.js 24** — Node 22 has the same lock-file issue
- **`.eslintrc.json` must exist** — `next lint` without config opens interactive prompt and exits 1 in CI: `{ "extends": "next/core-web-vitals" }`
- **`tsconfig.json` must exclude** `"jest.config.ts"`, `"jest.setup.ts"`, `"tests/e2e/**"`, `"src/**/*.test.ts"`, `"src/**/*.test.tsx"`
- **`jest.config.ts`** — use `next/jest.js` with explicit `.js` extension (ESM can't resolve bare `"next/jest"`)
- **Clipboard spy AFTER `userEvent.setup()`** — setup() replaces `navigator.clipboard`; spy set before is replaced and never fires
- **`jest.setup.ts`** — `configurable: true` required on clipboard stub; stub `scrollIntoView`; mock `next/navigation`
- **Playwright `webServer`** — use `npm run start` (not `next dev`); CI must run `next build` before E2E job

### Node.js husky setup
```bash
npm install husky lint-staged --save-dev
npx husky install
npx husky add .husky/pre-commit "npx lint-staged && npx tsc --noEmit"
npx husky add .husky/pre-push "npm run test:unit -- --bail && npm run build"
```

### Python pre-commit setup
```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: ruff
        entry: ruff check --fix
        language: system
        types: [python]
      - id: black
        entry: black
        language: system
        types: [python]
      - id: mypy
        entry: mypy --strict
        language: system
        types: [python]
        pass_filenames: false
```

---

## CI/CD CHECKLIST (generate ALL on first request, never partial)
- [ ] `.github/workflows/ci.yml` — 5 jobs
- [ ] `frontend/.eslintrc.json`
- [ ] `frontend/tsconfig.json` — exclude block (jest.config.ts, jest.setup.ts, tests/e2e/**, *.test.ts/tsx)
- [ ] `frontend/jest.config.ts` — `next/jest.js` with explicit `.js` extension
- [ ] `frontend/jest.setup.ts` — clipboard `configurable: true`, scrollIntoView stub, router mock
- [ ] `backend/pyproject.toml` — target-version, [tool.ruff.lint], asyncio_default_fixture_loop_scope, markers
- [ ] `backend/tests/e2e/conftest.py` — sync PyMongo cleanup + Motor singleton reset
- [ ] Branch name verified with `git branch --show-current`
