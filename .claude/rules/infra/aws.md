---
description: AWS Serverless, Lambda rules, Step Functions, multi-agent architecture, API Gateway, SSO daily use
paths: ["infra/**", "**/*.tf", "services/**"]
---

## AWS SERVERLESS

### Lambda rules (non-negotiable)
- Single Responsibility: one Lambda, one concern
- Idempotent: identical requests N times = same result
- Stateless: state in DynamoDB/S3, never in Lambda memory
- Least Privilege: dedicated IAM role per function
- Dead Letter Queue on every async invocation
- Explicit timeout: never leave the 3s default
- X-Ray tracing in production

### Invocation patterns
```
Sync:      API Gateway → Lambda → Response          (max 29s)
Async:     EventBridge / SQS → Lambda → DLQ on fail
Workflow:  Step Functions → Lambda chain             (durable, stateful)
```

### API Gateway
- HTTP API over REST API (unless WAF/caching/usage plans required)
- Always attach Cognito or Lambda authorizer — no open endpoints

---

## AWS MULTI-AGENT ARCHITECTURE

### Three-layer model
```
Layer 1 — Macro Orchestration:  Step Functions (Express Workflows)
Layer 2 — Agent Orchestration:  Bedrock AgentCore + Strands Agents SDK
Layer 3 — Tools:                MCP tools exposed via Lambda
```

### Orchestration patterns
| Pattern | Use case |
|---------|----------|
| Supervisor + Sub-agent | LLM routes dynamically to specialists |
| Workflow / Graph | Deterministic multi-step pipeline |
| Map-Reduce | Parallel fan-out → aggregate |
| A2A Protocol | Heterogeneous agents across frameworks |

- Step Functions for deterministic stages; Express Workflows (<5 min); Standard for auditable pipelines
- Do NOT use Step Functions for dynamic agent reasoning loops — use Bedrock AgentCore

---

## AWS SSO — DEVELOPER DAILY USE

### ~/.aws/config pattern
```ini
[sso-session acme-corp]
sso_start_url            = https://acme-corp.awsapps.com/start
sso_region               = us-east-1
sso_registration_scopes  = sso:account:access

[profile acme-dev]
sso_session     = acme-corp
sso_account_id  = 123456789012
sso_role_name   = DeveloperAccess
region          = us-east-1
output          = json
```

One `aws sso login --profile acme-dev` covers all profiles sharing the same `[sso-session]`.

### Common errors
| Error | Fix |
|-------|-----|
| `Token for X does not exist` | `aws sso login --profile <name>` |
| `Token has expired` | `aws sso login --profile <name>` |
| `Found xterm-256color` on Windows | Run in PowerShell or cmd.exe, not Git Bash |
| `No roles available` | Contact IT/admin — user not assigned yet |

CI/CD: SSO does NOT work in pipelines — requires interactive browser. Use OIDC trust with IAM role.  
Terraform uses SSO transparently when `AWS_PROFILE` is set.

---

## TECH LEAD MINDSET (ops)
- Alarms on Lambda error rate, throttles, duration P99
- DLQ with alarm: any message = PagerDuty/SNS alert
- Blue/green via Lambda aliases + traffic shifting
- Default to managed services over self-hosted
- Serverless-first for variable load; ECS Fargate for steady latency-sensitive load
- Design for failure: every external call has timeout + retry + circuit breaker
