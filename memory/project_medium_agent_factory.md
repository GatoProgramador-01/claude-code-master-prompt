---
name: medium-agent-factory project
description: Multi-agent LLM content pipeline — LangGraph + FastAPI + Next.js + MongoDB. All 4 LLMOps weeks complete. CI/CD wired. Deploy pending real tokens.
type: project
originSessionId: 4e386939-ea33-4152-8408-d3930d2b200e
---
Repo: `GatoProgramador-01/medium-agent-factory` (private)
Local path: `C:\Users\lanitaEmperadora\medium-agent-factory`
Branch: master

**Why:** Generic LLM content generation pipeline used as LLMOps study vehicle. Demonstrates eval-in-CI, Ollama local switch, SSE streaming, prompt versioning, retries, CI/CD to Railway + Vercel.

**Stack:**
- LangGraph orchestrator (StateGraph with revision loop)
- DeepSeek V3 (`deepseek-chat`) for all roles — `USE_DEEPSEEK=true`, Ollama disabled
- FastAPI + Motor (async MongoDB) backend
- Next.js 15 frontend with Recharts analytics
- Docker Compose with local MongoDB 7 + Ollama (opt-in profile, not currently used)

**4 LLMOps weeks complete:**
- Week 1: Eval pipeline — `evals/` with 3-layer tests, LangSmith, `eval.yml` CI gate (path-filtered)
- Week 2: Ollama local switch — `get_llm(role)` factory, `USE_LOCAL_LLM=true`, SSE streaming replaces polling
- Week 3: Prompt versioning — `backend/prompts/*.txt`, `prompt_loader.py` with fail-fast cache
- Week 4: LangChain retry + tenacity — `retry.py` with `with_langchain_retry()` + `@retryable_llm_call`

**Pipeline:**
```
custom_topic → content_generation → quality_analysis
  → revision loop (max 2x, Haiku→Sonnet escalation) → finalize → END
```

**CI/CD (GitHub Actions):**
- `ci.yml` — ruff+black+mypy on backend; tsc+eslint+next build on frontend; docker build on PRs
- `eval.yml` — path-filtered (agents/ + prompts/ + evals/), runs Layer 1+2 evals, blocks PR on fail
- `deploy.yml` — builds+pushes to GHCR, deploys backend→Railway, frontend→Vercel on master push

**GitHub Actions secrets set:**
- `ANTHROPIC_API_KEY` ✓ real
- `LANGCHAIN_API_KEY` ✓ real
- `RAILWAY_TOKEN` — mock placeholder (replace when creating Railway project)
- `VERCEL_TOKEN` — mock placeholder (replace when creating Vercel project)

**GitHub Actions variables set:**
- `NEXT_PUBLIC_API_URL` = `https://medium-agent-factory-production.up.railway.app` (mock)
- `BACKEND_URL` = same (mock)
- `FRONTEND_URL` = `https://medium-agent-factory.vercel.app` (mock)
- `VERCEL_ORG_ID` — mock placeholder
- `VERCEL_PROJECT_ID` — mock placeholder

**TODO — production deploy (when ready):**
1. MongoDB Atlas: create free M0 cluster → get `MONGODB_URI` → set as Railway env var
2. Railway: create project → service `backend` → set env vars (ANTHROPIC_API_KEY, MONGODB_URI, LANGCHAIN_API_KEY) → get real RAILWAY_TOKEN → update GitHub secret
3. Vercel: import frontend → set NEXT_PUBLIC_API_URL → get real VERCEL_TOKEN + ORG_ID + PROJECT_ID → update GitHub secrets/variables
4. After linking: `BACKEND_URL` and `FRONTEND_URL` variables will have real Railway/Vercel URLs

**API endpoints:**
- `POST /pipeline/run` — trigger async, requires `custom_topic: str`
- `GET /pipeline/runs/{run_id}/stream` — SSE live log stream (`__done__` sentinel)
- `GET /posts` — list generated posts
- Full CRUD on runs, posts, logs

**How to apply:** This is a complete production-grade LLMOps demo project. When discussing deploy, refer to the TODO steps above. When discussing architecture, all 4 LLMOps patterns are already implemented.
