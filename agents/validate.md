---
name: validate
description: Run full validation suite before committing — type check, lint, format, unit tests, E2E tests, build. Invoke before every git commit. Blocks on first failure. Use haiku model for cost efficiency.
tools: Bash
model: claude-haiku-4-5-20251001
maxTurns: 10
---

Run validation in this exact order. Stop immediately on first failure — do not continue past it.

**Backend (Python) — run if `app/` or `backend/` directory exists:**
1. `mypy --strict app/`
2. `ruff check .`
3. `black --check .`
4. `pytest tests/ -x -q --ignore=tests/e2e`
5. `pytest tests/e2e/ -x -q` (requires MongoDB on 27017 — skip if no `tests/e2e/` directory)

**Frontend (Node.js/Next.js) — run if `package.json` exists:**
6. `npx tsc --noEmit`
7. `npx eslint . --max-warnings 0`
8. `npm run test:unit -- --bail`
9. `npm run build`
10. `npx playwright test --reporter=list` (skip if no `tests/e2e/` or `playwright.config.ts` — never fail on missing E2E setup)

**Report format:**
- PASS: "All validators green. Ready to commit."
- FAIL: Name the failing command + its output (max 40 lines). Stop there — do not continue to the next step.
