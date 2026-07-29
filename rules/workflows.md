# Standard Workflow Teams + Parallel Wave Patterns

**Rule scope:** loaded on-demand for sprint planning and multi-agent dispatch decisions.

## Parallel Agents — Group of Experts

**Minimum 3 agents per task. Default target: 5. Max: 8 simultaneous.** Single-agent responses are the exception. Always decompose. Parallel is the default.

### Session kickoff (mandatory — first response of every session)
Launch `adversarial` (read-only diagnostics mode) + `architect` in parallel before writing any code. If the user gives a task directly, decompose it into ≥3 parallel workstreams first. (Note: `analyst` is retired in v2 — its diagnostics duty absorbed into `adversarial` Slot 4.)

### Self-checks (non-negotiable)
- **Before every response:** "Am I about to do this alone? If yes, STOP — decompose into agents first. Even single-file fixes get: implementer + test-writer + validate running simultaneously."
- **Before every wave dispatch:** "Am I dispatching ONE agent when I could dispatch THREE? Scan all remaining tasks. If 3 are independent, all 3 fire in the same wave NOW."

Visible parallel activity (multiple agents running simultaneously) is a hard requirement, not a style preference.

### Agent scope discipline (non-negotiable — failure mode: Sprint 31 2026-07-28)

**Never dispatch "fix N tests" or "fix all failures" to a single agent.** Broad agents spend 30-40 tool calls reading/analyzing before getting cut off mid-report — zero output survives. This is the most expensive mistake possible.

**Correct pattern for test failures:**
1. Run `pytest -x -q` — get the FIRST failure only
2. Read the ONE failing file and its ONE root cause
3. Dispatch ONE scoped agent: "Fix `NameError: name 'post'` in `backend/app/agents/nodes/quality_analysis.py:445`"
4. Commit. Run `pytest -x` again. Repeat per failure class.

**Each agent task brief must name:** the exact file, the exact error message, the exact line range to change. No vague briefs.

### Parallelize vs sequential
- **Parallelize:** research + implementation | multiple module rewrites | audit + test + lint | Adversarial runs alongside every sprint
- **Sequential only:** Task B needs Task A output | two agents writing the same file

## Standard workflow teams

- **New pipeline feature:** adversarial (diagnostics) + architect (parallel) → adversarial (design attack) → writing-plans → parallel-executor → validate → llmops-expert (wires orchestrator)
- **New API endpoint:** architect → backend-expert + adversarial (parallel) → writing-plans → parallel-executor → validate → commit
- **Frontend feature:** frontend-expert + adversarial (parallel) → writing-plans → parallel-executor → validate → commit (TSDoc emitted by frontend-expert itself, Slot 4)
- **Deploy/infra change:** devops-expert → adversarial → writing-plans → parallel-executor → validate → commit
- **Research-backed post:** researcher (grounding) → architect (topic string) → pipeline run
- **Debug failing test:** adversarial (read-only diagnostics) + adversarial (blind hypothesis) → validate fix
- **Full-stack feature:** frontend-expert + backend-expert + adversarial (all parallel) → writing-plans → SDD → validate → llmops-expert (integration)
- **New prompt / eval:** prompt-engineer + eval-writer (parallel) → sme-reviewer → validate → commit

## Parallel Wave pattern — bulk audit + wire

Use when auditing/wiring N independent files (nodes, agents, endpoints) that share state but don't write to the same keys.

```
Wave 1 (parallel — N adversarial agents in read-only mode):
    read all N files → audit report per file
    (production-ready / needs fix / needs redesign + state-key conflicts)

Wave 2 (parallel — N drafter agents):
    RED tests for all N simultaneously (one test file each)

Wave 3 (parallel — N drafter agents):
    implement/fix each independently (conflict-free files only)

Wave 4 (sequential):
    validate all → llmops-expert wires all N in one commit

Documentation track:
    runs throughout Waves 1-4 in parallel — never blocks, never blocked
```

**Trigger:** user says "audit + wire N nodes/files" or selects Option B in a brainstorm.
**State-key conflict resolution:** if Wave 1 reveals two nodes write the same key, wire them sequentially in Wave 4 — don't block the whole wave.
**Max parallel agents per wave:** 5 (model cost cap). Split into sub-waves if N > 5.

## Parallel dispatch — wave rules (non-negotiable)

Before dispatching ANY implementer, `parallel-executor` scans ALL remaining tasks and groups by file overlap into waves. All implementers in a wave fire simultaneously in one message.

Two mandatory patterns:

1. **Multi-task parallel wave:** Tasks 2, 3, 4 touch different files and have no "prerequisite" → all fire in one message, same wave.
2. **Reviewer + next wave overlap:** when Wave N implementers finish, Wave N reviewers AND Wave N+1 implementers fire simultaneously if Wave N+1 has no file overlap with Wave N.

Sequential ONLY when: (a) task brief explicitly says "prerequisite: Task N", or (b) two tasks write the same file.

## Skill triggers — mandatory in-session

- **Any sprint start** → `/codex:rescue --background` fires immediately, before Claude writes a line
- **Any sprint start** → `parallel-executor` fires after `writing-plans`, before any code is written. Never use `superpowers:subagent-driven-development` — it forces sequential dispatch and overrides wave-parallel rules.
- **Any commit** → `/codex:adversarial-review --fresh --background` fires before declaring sprint done
- **Context ≥ 50%** → `session-autopilot` fires — writes MongoDB `session_logs` + prints sprint status tree + recommends `/compact` focus

Skills visible on screen = good session. Zero skills used = failed session.

## Superpowers workflow map

Superpowers phases (clarify → worktree → plan → subagent-dev → TDD → code-review → finish-branch) map directly onto the Group of Experts workflow — they complement, never replace, it.

Claude invokes these automatically — user never types them:

- `superpowers:brainstorming` — any new feature/build task, BEFORE architect decomposes
- `superpowers:systematic-debugging` — any bug/test failure, BEFORE proposing fixes
- `superpowers:writing-plans` — multi-sprint feature with a spec, BEFORE touching code
- `parallel-executor` — MANDATORY every sprint, immediately after `writing-plans`, before any code is written — fires all independent tasks simultaneously per wave, reuses SDD scripts (task-brief, review-package, progress ledger) — do NOT use `superpowers:subagent-driven-development` (it forces sequential dispatch)
- `superpowers:executing-plans` — resuming from a written plan across sessions
- `superpowers:test-driven-development` — BEFORE writing implementation code
- `superpowers:verification-before-completion` — BEFORE claiming any work done or committing
- `superpowers:dispatching-parallel-agents` — when 2+ independent tasks exist
- `superpowers:requesting-code-review` — after completing major feature, before merging

## Execution strategy commitment

When the user selects an execution strategy (subagent-driven vs inline), commit to it for the entire sprint. NEVER switch mid-sprint without explicit user approval. If subagents cause permission prompts, fix `~/.claude/settings.json` (ensure `Bash(*)`, `Edit(*)`, `Write(*)` are in `permissions.allow`) — do NOT abandon the strategy.

## Progress ledger discipline

Update `.superpowers/sdd/progress.md` after EVERY task completion. Context compaction destroys in-memory state — the ledger is the only recovery map.

## Model routing

- **haiku** — read / search / lint / format / build — 10× cheaper
- **sonnet** — write / rewrite / review / multi-file refactor
- **opus** — architecture cross-cutting tradeoffs only

## Monitor discipline (non-negotiable)

**Prefer Monitor over Bash `run_in_background` + polling for any background process that emits ongoing status.**

Monitor shows as a live entry in the Claude Code terminal status bar — the user sees it running. That visibility is a feature: it tells the user exactly what Claude is waiting on without any narration.

### When to use Monitor vs Bash run_in_background

| Situation | Tool |
|-----------|------|
| "Tell me when the pipeline finishes" (one event, process exits) | `Bash run_in_background` with `until` loop |
| "Watch a pipeline log and fire on SUCCESS or ERROR" (one terminal event, process keeps running) | `Monitor` with `tail -f log \| grep --line-buffered -E "SUCCESS\|error"` |
| "Emit every ERROR line from a live server" (ongoing, never exits) | `Monitor persistent: true` |

### Auto-arm rule (non-negotiable)

After launching ANY background process via `Start-Process` or `nohup`:
1. Immediately arm a Monitor on its log file
2. Filter must cover BOTH success AND failure paths — silence on crash = invisible failure
3. When Monitor fires, immediately handle the result (audit, commit, launch next step) without waiting for user to prompt

```bash
# Correct pattern
tail -f "$TEMP/pipeline.log" | grep --line-buffered -E "SUCCESS|FINISHED|error|Error|Traceback|failed"
```

Never use `Start-Sleep` or `sleep` as a substitute for Monitor. Never poll in a loop. One Monitor per background job, armed immediately after launch.

### Self-improvement loop Monitor pattern

When launching the self-improvement loop as a background process:
```powershell
Start-Process -NoNewWindow -FilePath ".venv\Scripts\python.exe" `
  -ArgumentList "-m app.scripts.self_improvement_loop --payload ..\loop_payload.json --fast-loop --skip-images" `
  -RedirectStandardOutput "$env:TEMP\loop.log" -RedirectStandardError "$env:TEMP\loop_err.log"
```
Immediately arm:
```bash
tail -f "$TEMP/loop.log" | grep --line-buffered -E "Converged|Max cycles|Report written|balance|ERROR"
```
When Monitor fires on "Report written", read the JSON report and run the post audit automatically.

## Delegation discipline

- Prompts: max 300 tokens — file paths + line ranges, never paste content
- Agents return summaries ≤ 200 tokens
- Batch independent Grep/Read/Glob in one message turn
