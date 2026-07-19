# Gitflow — Branch Discipline

**Rule scope:** global — applies to every project, every sprint.

> **Note:** This rule file contains the complete gitflow workflow. The legacy `gitflow` skill (at `~/.claude/skills/gitflow/SKILL.md`) is deprecated. Execute all git commands directly per the steps below.

---

## The flow

```
master → feat/<slug> → PR (auto-generated) → immediate merge → master
```

Every sprint lives on a feature branch. Master receives only merge commits from `feat/*`.

---

## Sprint start gate (NON-NEGOTIABLE)

**Before invoking any sprint work**, manually execute the `gitflow open` steps below to create and track the feature branch.

### Steps: `gitflow open <sprint-name>`

**1. Validate state**

```bash
CURRENT=$(git branch --show-current)
```

- If `$CURRENT` starts with `feat/`: print "Already on feature branch $CURRENT — skipping open." and stop.
- If `$CURRENT` != `master`: warn "On branch $CURRENT (not master). Checking out master first." then proceed to sync.

**2. Sync master**

```bash
git checkout master
git pull origin master
```

**3. Slugify the sprint name**

Transform the sprint name using these rules (in order):
- Lowercase all characters
- Replace spaces and `+` with `-`
- Strip all characters not in `[a-z0-9-]` (alphanumeric or hyphen only)
- Collapse any `--` sequences into a single `-`
- Trim leading and trailing `-`
- Truncate to max 40 characters

Examples:
- "Grammar Perfection Node" → `grammar-perfection-node`
- "90 Quality Validation + engagement 1.00" → `90-quality-validation-engagement-100`
- "fact_checker Tavily Timeout Fix" → `fact-checker-tavily-timeout-fix`

**4. Create and check out the feature branch**

```bash
SLUG="<slugified-name>"
git checkout -b "feat/$SLUG"
```

If the branch already exists:
```
Print error: "Branch feat/<SLUG> already exists. Delete it first or use a different sprint name." and stop.
Do NOT force-create (--force).
```

**5. Record in progress ledger**

Create the file and directories if they don't exist:

```bash
mkdir -p .superpowers/sdd
```

Append to `.superpowers/sdd/progress.md`:

```markdown
# <sprint-name> Sprint
# Branch: feat/<slug>
# Base: <git rev-parse HEAD>
```

Capture the base commit SHA with: `git rev-parse HEAD`

**6. Confirm**

Print confirmation message:
```
✓ Sprint branch feat/<SLUG> created from master @ <base-sha-7-chars>
```

Extract the 7-character short SHA with: `git rev-parse --short=7 HEAD`

---

## Sprint close gate (NON-NEGOTIABLE)

**After all sprint tasks are complete and verification passes**, manually execute the `gitflow close` steps below to merge the branch back to master.

### Steps: `gitflow close`

**1. Validate state**

```bash
BRANCH=$(git branch --show-current)
```

- If `$BRANCH` == `master` or does not start with `feat/`: print error "Not on a feature branch. Nothing to close." and stop.

**2. Extract sprint info from progress ledger**

Read `.superpowers/sdd/progress.md`. Find the most recent sprint block by:
- Sprint name: first `# <Name> Sprint` header after the last `---` separator, or at end of file
- Base branch: line with `# Base: <sha>`
- Tasks completed: all lines matching `Task N: complete (...)`
- Test baseline and final: lines matching `Tests: N/N` or `tests baseline: N` and corresponding final count
- Sprint status line: `SPRINT STATUS: ...`

Extract the slug from the current branch name (`git branch --show-current`).

**3. Push the branch**

```bash
BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH"
```

**4. Build PR body**

Generate the PR body from progress ledger data in this format:

```markdown
## <sprint-name>

**Branch:** feat/<slug>
**Tests:** <baseline> → <final> passing

### Completed tasks
<one line per Task N: complete entry from progress ledger>

### Review status
<Final review line from ledger, or "All task reviews: APPROVED">

---
🤖 Generated with [Claude Code](https://claude.ai/code)
```

Example PR body:

```markdown
## Grammar Perfection Node

**Branch:** feat/grammar-perfection-node
**Tests:** 42 → 48 passing

### Completed tasks
Task 1: complete (Grammar Corrector Node)
Task 2: complete (Integration Tests)
Task 3: complete (Documentation)

### Review status
All task reviews: APPROVED

---
🤖 Generated with [Claude Code](https://claude.ai/code)
```

**5. Create PR**

Use `gh` CLI to create the pull request:

```bash
BRANCH=$(git branch --show-current)
gh pr create \
  --title "<sprint-name>" \
  --base master \
  --head "$BRANCH" \
  --body "$(cat <<'EOF'
<PR body from step 4>
EOF
)"
```

**6. Merge immediately**

```bash
BRANCH=$(git branch --show-current)
gh pr merge "$BRANCH" --merge --admin --delete-branch
```

- `--merge` creates a merge commit (not squash or rebase)
- `--admin` bypasses required status checks (allows merge even if CI is pending)
- `--delete-branch` removes the remote branch after merge

**7. Return to master and sync**

```bash
git checkout master
git pull origin master
BRANCH=$(git branch --show-current)
git branch -d "feat/$BRANCH"   # delete local branch (already merged)
```

(Note: substitute `$BRANCH` with the actual branch name if needed.)

**8. Confirm**

Print confirmation message:
```
✓ feat/<slug> merged to master. Branch deleted. You are on master @ <new-head-7-chars>
```

Extract the 7-character short SHA with: `git rev-parse --short=7 HEAD`

---

## Error handling

| Situation | Action |
|---|---|
| `gh` not authenticated | Print "Run: gh auth login" and stop |
| `git push` fails (diverged) | Print "Push failed — run: git pull origin feat/<slug> --rebase" and stop |
| `gh pr create` fails (PR already exists) | Skip create, proceed to merge |
| `gh pr merge` fails (not admin) | Print "gh pr merge failed. Merge manually at: <PR URL>" and stop |
| Branch not deleted after merge | Run `git branch -D feat/<slug>` (force) and warn |

---

## Direct-to-master protection

If `git branch --show-current` returns `master` AND you are about to commit code changes:

1. STOP.
2. Ask the user: "We're on master — should I open a feature branch first?"
3. If yes: run `git checkout -b feat/<slug>` (using the appropriate slugified name) then continue.
4. **Exception:** docs-only commits (CONTINUE.txt updates, spec files, progress ledger housekeeping) may land on master directly.

---

## Self-check before every sprint

- "Am I on master about to start a sprint? → Run `gitflow open <sprint-name>` first."
- "Am I done with all tasks and verification passes? → Run `gitflow close` last."

---

## Branch naming quick reference

| Sprint name | Branch |
|---|---|
| "Grammar Perfection Node" | `feat/grammar-perfection-node` |
| "90 Quality Validation + engagement 1.00" | `feat/90-quality-validation-engagement-100` |
| "fact_checker Tavily Timeout Fix" | `feat/fact-checker-tavily-timeout-fix` |
