---
name: GitHub Actions common bugs — branch names and bash subshell
description: Two recurring bugs in GitHub Actions workflows found in multiagent-aws-infra
type: feedback
originSessionId: 7b4ec8df-926e-46b2-9927-b2c47f07e647
---
**Rule 1 — Always verify actual branch name before writing workflow triggers.**
Run `git branch --show-current` before writing any `branches:` in a workflow. Never assume `main` — the repo might use `master` or a custom name.
```yaml
# WRONG (assumed)
on:
  push:
    branches: [main]

# CORRECT (verified)
on:
  push:
    branches: [master]
```

**Rule 2 — Never assign to a bash array inside a piped `while` loop.**
Piped commands run in a subshell. Variables set inside don't survive to the outer shell.
```bash
# BUG: ENVS always stays empty
ENVS=()
some_command | while read line; do ENVS+=("$line"); done
echo "${#ENVS[@]}"  # always 0

# CORRECT: use process substitution (no subshell)
mapfile -t ENVS < <(some_command)
echo "${#ENVS[@]}"  # correct count
```

**Why:** In multiagent-aws-infra, the change detection job always defaulted to `["dev"]` regardless of what changed — the array was always empty because it was populated inside a pipe subshell. Both bugs mean CI never runs correctly without human intervention.

**How to apply:** On every new workflow file: (1) grep for `branches:` and verify against `git branch`, (2) grep for `while read` and check if it's inside a pipe — if yes, rewrite with `mapfile`.
