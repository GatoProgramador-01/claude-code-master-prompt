---
name: HCL / Terraform syntax rules learned from real bugs
description: Hard rules for writing correct Terraform HCL — derived from bugs committed during multiagent-aws-infra Week 1
type: feedback
originSessionId: 7b4ec8df-926e-46b2-9927-b2c47f07e647
---
Never place a `lifecycle` block outside a resource. It must be nested inside the resource that owns it:
```hcl
resource "aws_s3_bucket" "state" {
  bucket = "..."
  lifecycle { prevent_destroy = true }  # ← inside
}
# NOT as a free-floating block after the resource
```

Never use commas as attribute separators inside HCL blocks. HCL uses newlines (or semicolons):
```hcl
# WRONG
variable "x" { type = string, description = "..." }

# CORRECT
variable "x" {
  type        = string
  description = "..."
}
```

Never use `filebase64sha256(var.filename)` on a zip that doesn't exist yet. Terraform evaluates file functions at plan-time — if the file is missing, plan fails. Use `data "archive_file"` instead:
```hcl
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.builds/${var.function_name}.zip"
}
resource "aws_lambda_function" "this" {
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
}
```

**Why:** All three bugs were caught only after running python-hcl2 validation or reading error traces. Writing HCL multi-resource files: always close braces before starting the next resource, check attribute syntax matches HCL not JSON.

**How to apply:** Before writing any .tf file with multiple resources, mentally track brace depth. When in doubt, write each resource fully closed before moving to the next.
