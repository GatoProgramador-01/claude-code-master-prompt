---
name: multiagent-aws-infra project state
description: Estado actual del proyecto de arquitectura multi-agente en AWS — semanas completadas, stack, próximos pasos
type: project
originSessionId: 9bb25a47-faf6-4939-baf6-bd541ec11796
---
Repo privado: https://github.com/JavierCollipal/multiagent-aws-infra
Working directory: C:\Users\lanitaEmperadora\multiagent-aws-infra
Branch: master

## Stack implementado (5 semanas)

**Layer 1 — Macro Orchestration (Week 3)**
- `services/orchestrator/` — Lambda entry point; enruta a Step Functions (AWS) o pipeline local (CI)
- `services/orchestrator/pipeline.py` — simulador local de Step Functions
- `infra/modules/step-functions/` + `infra/envs/dev/main.tf` — Express Workflow: FetchData → AnalyseData

**Layer 2 — Agent Orchestration (Week 4)**
- `services/supervisor/` — Lambda con Strands SDK; USE_BEDROCK=true → Strands Agent + Claude Haiku; USE_BEDROCK=false → ejecución local directa

**Layer 3 — Specialist Agents / Tools**
- `services/agent-data/` — fetcher (5 records stub, docstring = MCP tool description)
- `services/agent-analyst/` — analyser; USE_BEDROCK=true → bedrock-runtime invoke_model con Claude Haiku

**Observability (Week 5)**
- `infra/modules/observability/` — SNS alerts topic + 4 alarm types per Lambda:
  errors, throttles, P99 duration (threshold = 80% of timeout), DLQ depth > 0
- CloudWatch dashboard: invocations/errors/throttles row + p50/p99 duration row
- `alert_email` variable in dev env (optional SNS email subscription)
- Lambda module now outputs `dlq_name` (needed for SQS CloudWatch dimension)
- 26/26 HCL files valid · 56/56 tests passing

**Bootstrap prompt**
- `scripts/bootstrap-prompt.md` — OS-aware Claude master prompt for clean installs
  Covers: Windows/macOS/Ubuntu/Fedora/Arch — git, gh CLI + auth, AWS CLI v2,
  AWS credentials (IAM user, SSO, named profiles), CI/CD OIDC note, final checklist

**API Gateway routes:**
- POST /invoke → orchestrator → Step Functions pipeline
- POST /supervise → supervisor (Strands Agent)
- GET /health → orchestrator

**Tests: 56/56 passing, 26/26 HCL files valid**

## Comandos clave
```bash
python -m pytest services/ -v --tb=short   # correr todos los tests
python scripts/validate_hcl.py             # validar HCL sin Terraform instalado
```

## Próximos pasos
- Conectar con AWS real: `terraform init` + `terraform apply` en infra/envs/dev (requiere credenciales AWS)
- Instalar strands-agents en supervisor: `pip install strands-agents` y probar con USE_BEDROCK=true real
- Week 6 ideas: blue/green Lambda aliases + CodeDeploy traffic shifting, or real AWS deploy

**Why:** Proyecto de estudio práctico de arquitectura multi-agente AWS para evolucionar a Tech Lead + DevOps.
**How to apply:** Al retomar, leer este archivo y correr los tests para verificar estado antes de continuar.
