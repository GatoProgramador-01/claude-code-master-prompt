---
name: validate
description: Run full validation suite before committing — type check, lint, format, unit tests, build. Invoke before every git commit. Blocks on first failure. Use haiku model for cost efficiency.
tools: Bash
model: haiku
maxTurns: 8
---

Run validation in this exact order. Stop immediately on first failure — do not continue past it.

**Backend (Python) — run if `app/` or `backend/` directory exists:**
1. `mypy --strict app/`
2. `ruff check .`
3. `black --check .`
4. `pytest tests/ -x -q --ignore=tests/e2e`

**Frontend (Node.js/Next.js) — run if `package.json` exists:**
5. `npx tsc --noEmit`
6. `npx eslint . --max-warnings 0`
7. `npm run test:unit -- --bail`
8. `npm run build`

**Report format:**
- PASS: "All validators green. Ready to commit."
- FAIL: Name the failing command + its output (max 40 lines). Stop there — do not continue to the next step.
