---
description: HCL and Terraform production rules — lifecycle, archive_file, OIDC, remote state, prevent_destroy
paths: ["**/*.tf", "**/*.tfvars", "infra/**"]
---

## HCL / TERRAFORM

### lifecycle MUST be inside the resource block
```hcl
resource "aws_s3_bucket" "state" {
  bucket = "..."
  lifecycle { prevent_destroy = true }   # inside, never floating at file level
}
```

### Lambda packaging — always archive_file, never filebase64sha256
```hcl
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.builds/${var.function_name}.zip"
  excludes    = ["tests", "__pycache__", "*.pyc", ".venv"]
}
resource "aws_lambda_function" "this" {
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
}
```

### Non-negotiable policies
- Remote state: S3 + DynamoDB locking — separate state per environment
- Credentials: OIDC trust (GitHub Actions ↔ IAM Role) — never static access keys in CI
- Module versioning: pin exact tag in prod (`?ref=v1.2.0`), allow `~>` patch in dev
- `prevent_destroy = true` on stateful resources (DynamoDB, RDS, S3 state bucket)
- Always run in order: `terraform fmt` → `terraform validate` → `terraform plan` → gate → `terraform apply`
- No hardcoded ARNs, account IDs, or region strings — use variables or data sources
- IAM: least privilege — no `*` action or resource unless explicitly justified in a comment
- All resources tagged; sensitive outputs marked `sensitive = true`
- No secrets in state file

### Repo structure
```
infra/
├── modules/          ← lambda/, step-functions/, api-gateway/, bedrock-agent/
├── envs/dev/         ← main.tf · variables.tf · backend.tf
└── envs/prod/
```
