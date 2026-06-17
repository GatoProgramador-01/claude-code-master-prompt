---
name: medium-agent-factory deploy TODO
description: Step-by-step checklist to deploy medium-agent-factory to Railway + Vercel + MongoDB Atlas (cheap production stack)
type: project
originSessionId: 4e386939-ea33-4152-8408-d3930d2b200e
---
All mock secrets/variables are already set in GitHub Actions. Only 4 values need to be replaced with real ones.

**Why:** User wants cheap production deploy (~$0–5/month). Railway for backend Docker, Vercel free tier for Next.js, MongoDB Atlas free M0 for database.

**How to apply:** When user says they're ready to deploy, walk through these steps in order.

---

## Step 1 — MongoDB Atlas (free M0)

1. Go to cloud.mongodb.com → Create account → Create free cluster (M0, any region)
2. Database Access → Add user → username + password (save these)
3. Network Access → Add IP → Allow from anywhere (`0.0.0.0/0`) for Railway
4. Connect → Compass → copy connection string:
   `mongodb+srv://<user>:<pass>@cluster0.xxxxx.mongodb.net/medium_agent_factory`
5. Save this as `MONGODB_URI` — needed in Railway step

---

## Step 2 — Railway (backend, ~$5/month)

1. railway.app → Login with GitHub
2. New Project → Deploy from GitHub repo → select `GatoProgramador-01/medium-agent-factory`
3. Railway auto-detects `backend/Dockerfile` — set root directory to `backend`
4. Service Settings → Variables → add all:
   ```
   ANTHROPIC_API_KEY=sk-ant-api03-...  (from .env)
   MONGODB_URI=mongodb+srv://...       (from Step 1)
   LANGCHAIN_API_KEY=lsv2_pt_...      (from .env)
   LANGCHAIN_TRACING_V2=true
   LANGCHAIN_PROJECT=medium-agent-factory-prod
   ENVIRONMENT=production
   ```
5. Settings → Networking → Generate Domain (copy this URL — it's BACKEND_URL)
6. Account Settings → Tokens → Create token → copy it
7. Update GitHub secrets:
   ```bash
   gh secret set RAILWAY_TOKEN --body "the_real_token"
   ```
8. Update GitHub variable:
   ```bash
   gh variable set BACKEND_URL --body "https://your-service.up.railway.app"
   gh variable set NEXT_PUBLIC_API_URL --body "https://your-service.up.railway.app"
   ```

---

## Step 3 — Vercel (frontend, free)

1. vercel.com → Login with GitHub
2. New Project → Import `GatoProgramador-01/medium-agent-factory`
3. Set Root Directory to `frontend`
4. Environment Variables → add:
   ```
   NEXT_PUBLIC_API_URL=https://your-railway-service.up.railway.app
   ```
5. Deploy → copy the Vercel URL (it's FRONTEND_URL)
6. Account Settings → Tokens → Create token → copy it
7. Project Settings → General → copy Project ID
8. Account Settings → General → copy Team ID (or personal account ID = VERCEL_ORG_ID)
9. Update GitHub:
   ```bash
   gh secret set VERCEL_TOKEN --body "the_real_token"
   gh variable set VERCEL_ORG_ID --body "the_real_org_id"
   gh variable set VERCEL_PROJECT_ID --body "the_real_project_id"
   gh variable set FRONTEND_URL --body "https://your-project.vercel.app"
   ```

---

## Step 4 — Trigger deploy

```bash
git commit --allow-empty -m "chore: trigger production deploy"
git push origin master
```

GitHub Actions `deploy.yml` runs automatically on push to master.
Watch it at: github.com/GatoProgramador-01/medium-agent-factory/actions

---

## Current state of GitHub Actions config

**Secrets:**
- `ANTHROPIC_API_KEY` ✓ real
- `LANGCHAIN_API_KEY` ✓ real
- `RAILWAY_TOKEN` — mock, replace in Step 2
- `VERCEL_TOKEN` — mock, replace in Step 3

**Variables:**
- `NEXT_PUBLIC_API_URL` — mock URL, replace in Step 2+3
- `BACKEND_URL` — mock URL, replace in Step 2
- `FRONTEND_URL` — mock URL, replace in Step 3
- `VERCEL_ORG_ID` — mock, replace in Step 3
- `VERCEL_PROJECT_ID` — mock, replace in Step 3
