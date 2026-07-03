---
name: session-autopilot
description: "Session audit and handoff skill — invoke this ALWAYS when: the user mentions '90%', 'high usage', 'running out of context', 'almost full', 'context limit', 'compact', 'session limit', or 'we're getting long'; OR when context is visibly ≥ 85% full; OR before any /compact command. Runs 3 parallel haiku agents to extract accomplishments, token costs, and avoidable errors, then writes a structured audit log to MongoDB session_logs and recommends an exact /compact focus string. Don't wait for the user to ask — if context feels long or they signal it at all, trigger this skill proactively."
---

# Session Autopilot — Context Close Audit

The context window is approaching its limit (or the user has signalled it). Run this skill now to capture everything important before compaction or session end.

## Trigger conditions (any one is sufficient)
- User mentions: "90%", "high usage", "running out of context", "almost full", "context limit", "getting long", "compact", "session limit", "context is filling up"
- System context usage ≥ 85%
- About to run `/compact` for any reason
- User asks to "save what we've done" or "log this session"

## What this skill does

1. Launches 3 parallel agents (haiku — cost-efficient reads)
2. Synthesizes their output into a structured session log
3. Writes the log to MongoDB `session_logs` collection via MCP
4. Prints a compact sprint status tree
5. Recommends a `/compact` focus string

---

## STEP 1 — Launch 3 parallel agents simultaneously

### Agent A: Session Analyst (haiku)
**Task:** Read git state and conversation context to extract accomplishments and next steps.

```
Read git log --oneline -10 from current repo.
Read git diff --stat HEAD to see what changed this session.
From conversation context, extract:
  - Sprint number and name
  - List of things completed (✅)
  - List of things in progress or blocked (🔄/❌)
  - Explicit next steps the user or Claude mentioned
  - Current test count (before → after delta if visible)
Report in under 150 words. Format as JSON with keys:
  sprint, accomplishments[], in_progress[], next_steps[], test_delta, files_changed[]
```

### Agent B: Token Auditor (haiku)
**Task:** Query MongoDB for token usage from this session's agent runs.

```
Use mcp__mongodb__find on collection "agent_runs" in the project database.
Filter: {"run_id": <most recent run_id visible in context>}
If no run_id visible, get the last 20 documents sorted by timestamp desc.
Aggregate:
  - total_tokens across all documents
  - breakdown by agent_name: {agent_name: total_tokens}
  - most expensive agent (highest token count)
  - estimated cost: total_tokens * 0.00000025 (Haiku rate) or * 0.000003 (Sonnet rate)
If MongoDB not available or no data, report: {"status": "unavailable"}
Report as JSON with keys:
  total_tokens, by_agent{}, most_expensive_agent, estimated_cost_usd, run_ids_found[]
```

### Agent C: Error Auditor (haiku)
**Task:** Scan conversation context for errors, misdiagnoses, and avoidable waste.

```
Read the conversation history visible in context.
Identify:
  1. ERRORS ENCOUNTERED: things that failed (exceptions, test failures, wrong assumptions)
  2. AVOIDABLE ERRORS: errors that could have been prevented
     - Missing package that was in pyproject.toml but not installed
     - Wrong root cause diagnosis (spent time on X, real cause was Y)
     - Polling loop instead of Monitor tool
     - Sequential work that could have been parallel
     - Config already set but not loaded (env var issues)
  3. RESOLVED: which errors were eventually fixed
For each avoidable error: note what the correct first move should have been.
Report as JSON with keys:
  errors_encountered[{type, description, resolved}],
  avoidable_errors[{error, cause, correct_first_move}],
  time_wasted_estimate (rough: "~2 exchanges", "~5 exchanges", etc.)
```

---

## STEP 2 — Synthesize and write to MongoDB

After all 3 agents return, synthesize their output and write ONE document to MongoDB:

**Collection:** `session_logs`  
**Database:** use whatever database the project uses (check settings or `medium_agent_factory` for this project)

**Document schema:**
```json
{
  "session_id": "<generate: YYYY-MM-DD-HHMM-project>",
  "project": "<current working directory basename>",
  "date": "<YYYY-MM-DD>",
  "timestamp": "<ISO datetime>",
  "context_usage_pct": 90,
  "sprint": "<from Agent A>",
  "accomplishments": ["<from Agent A>"],
  "in_progress": ["<from Agent A>"],
  "next_steps": ["<from Agent A>"],
  "files_changed": ["<from Agent A>"],
  "test_delta": {"before": 0, "after": 0},
  "errors_encountered": [{"type": "", "description": "", "resolved": true}],
  "avoidable_errors": [{"error": "", "cause": "", "correct_first_move": ""}],
  "token_usage": {
    "total_tokens": 0,
    "by_agent": {},
    "most_expensive_agent": "",
    "estimated_cost_usd": 0.0,
    "note": "pipeline agent_runs only — excludes Claude Code session tokens"
  },
  "compact_focus": "<one-line focus string for /compact>",
  "codex_handoff_file": "<path if exists>"
}
```

Use `mcp__mongodb__insert-many` (with a single-element array) or the available insert tool.

If MongoDB MCP is not connected, write the log to `~/.claude/session_logs/<session_id>.json` instead using the Write tool.

---

## STEP 3 — Print sprint status tree

After writing the log, print the sprint status tree:

```
😸 Session Close — <Sprint name>
├── 🤖 agents run — list unique agents used this session
├── 📊 metrics — tests <before>→<after> · files changed: N
├── ✅ <accomplishment 1>
├── ✅ <accomplishment 2>
├── 🔄 <in progress item>
├── ❌ <blocked item if any>
├── 💸 tokens — ~<total> tokens · ~$<cost> · heaviest: <agent>
├── ⚠️  avoidable — <count> avoidable error(s) this session
└── 🔍 next: <top next step>
```

---

## STEP 4 — Recommend compact focus

Output exactly one line:
```
/compact Focus on <project> <Sprint N> — <next task in one phrase>
```

Example: `/compact Focus on medium-agent-factory Sprint 38 — LangSmith node tracing fix`

---

## Rules

- Run Agents A, B, C in parallel — never sequential
- Never skip the MongoDB write — the audit log IS the deliverable
- If an agent fails, log `{"status": "agent_failed", "error": "..."}` for that section — don't abort
- Keep agent prompts under 200 tokens — they read context, not files
- The compact focus string must be specific enough that a new session can orient in one sentence
- After printing the tree, STOP — do not start new work. The user must decide what comes next.

---

## Evals — verifying the skill works

These are the success criteria. After the skill runs, check:

### 1. MongoDB write happened
```python
# Quick verification via MCP
result = mcp__mongodb__find(collection="session_logs", filter={"session_id": <just-written-id>}, limit=1)
assert len(result) == 1
assert "compact_focus" in result[0]
assert "accomplishments" in result[0]
assert "avoidable_errors" in result[0]
```
Expected: One document written to `session_logs` with all required fields populated.

### 2. Compact focus string format
The output must contain exactly one `/compact Focus on ...` line.

Format: `/compact Focus on <project-name> Sprint <N> — <next-task-in-one-phrase>`

Good: `/compact Focus on medium-agent-factory Sprint 38 — LangSmith node tracing fix`  
Bad: `/compact` (no focus arg) | multiple compact lines | vague "continue work"

### 3. Sprint status tree printed
The tree must include `😸 Session Close — <sprint>` header and at minimum:
- `🤖 agents run` row (lists which agents fired)
- `📊 metrics` row
- At least one `✅` accomplishment row
- `💸 tokens` row
- `🔍 next` row (one specific actionable next step)

### 4. Parallel execution (3 agents fired simultaneously)
The session context should show 3 Agent tool calls launched in the same message turn (not sequentially).

### 5. Fallback to JSON file when MongoDB unavailable
If `mcp__mongodb__find` is not available (no MCP), the skill must write to `~/.claude/session_logs/<session_id>.json` instead. Verify the file exists and has the correct schema.
