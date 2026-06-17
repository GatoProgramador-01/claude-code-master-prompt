---
name: Medium API Status & Publishing Research
description: Current state of Medium's API and the only viable programmatic publishing path (June 2025)
type: reference
originSessionId: 18bfd60a-3c9e-4c78-a479-f811224ce799
---
## Medium API is dead for new accounts (researched June 2025)

- **Official API (api.medium.com)** — archived, not recommended. GitHub repo `Medium/medium-api-docs` archived 2023-03-02.
- **Integration tokens** — generation removed for all accounts as of ~Jan 2025. Settings page no longer shows the option for new users.
- **Make.com confirmed (Dec 2024):** "Medium has disabled their API. It only works if you created a token before that date."
- **Unofficial internal API** — `medium.com/_/graphql` is read-only (stats/data). No working write/publish endpoint documented publicly.
- **PyPI libraries:** `medium-api` (v0.6.1) = read-only via RapidAPI. `jupyter-to-medium` = abandoned, needs pre-2025 token. Nothing works for new accounts.

## Only viable path: Python Playwright

**Playwright has a first-class Python SDK** — `pip install playwright` → `from playwright.async_api import async_playwright`. It is NOT JavaScript-only.

The `medium-agent-factory` publisher uses Python Playwright (`playwright>=1.49.0` in pyproject.toml, `playwright install chromium --with-deps` in backend Dockerfile).

## Auth flow (magic-link, headless Docker-compatible)

1. `POST /publisher/start-auth {"email": "..."}` — browser enters email, Medium sends magic link
2. User **copies** (not clicks) the magic-link URL from email
3. `POST /publisher/complete-auth {"magic_url": "..."}` — Playwright opens URL headlessly, saves session cookies to MongoDB `publisher_sessions` collection
4. Session persists across restarts; refreshed after each successful publish

## Future optimisation ideas

- BYOS (bring-your-own-session): user pastes `sid` cookie from browser into `.env` — skip magic-link flow
- Monitor Medium UI changes and update selector fallback lists in `publisher.py`
- If `medium.com/_/api` write endpoints are ever documented, replace Playwright with direct API calls

**How to apply:** Whenever working on medium-agent-factory publisher, default to Python Playwright + MongoDB session. Do not attempt to use Medium's API for new accounts.
