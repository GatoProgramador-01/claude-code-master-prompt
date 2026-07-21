# Self-Improvement Session Protocol

**Rule scope:** loaded when user says "improve based on this session", "update the agents",
or when a session ends with a continue.txt that contains lessons or friction points.

## What a Self-Improvement Session Is

A self-improvement session is a meta-loop that runs at the end of a coding session:

```
session ends
    → session-improver reads artifacts (continue.txt, errors, timing, sprint trees)
    → extracts: friction > 10 min, rule violations, new patterns, token waste
    → produces: structured improvement report (≤ 10 findings, evidence-only)
    → routes to: system-curator for implementation
    → system-curator: edits agents/ or rules/, runs meta-eval, commits + pushes
    → next session starts with the improvement applied
```

This is exactly the Darwin Gödel Machine pattern applied to the agent system itself.

## Trigger Conditions

Launch a self-improvement session when:
- Session produced a continue.txt with a "LESSONS" or "WHAT WENT WRONG" section
- The same mistake appeared in the session 2+ times
- A bug was fixed that an existing rule or checklist should have caught
- Token spend exceeded $1.00 in a session (check via session-autopilot output)
- User explicitly requests it

**How to invoke:**

```
Agent("session-improver", prompt="Read continue.txt at <path>. Analyze for friction,
rule violations, token waste. Produce improvement report and route to system-curator.")
```

## What Counts as a Valid Finding

A finding is valid ONLY if it has:
1. A specific incident (exact error, timing data, or quoted text from the session)
2. A concrete fix (which file, which slot or section, what text to add/change)
3. A recurrence prevention mechanism (how the fix stops the same thing happening again)

**NOT valid:**
- "Claude should be more careful with Unicode" — no incident, no fix location
- "We should use asyncio more" — no specific missed opportunity cited

**VALID:**
- "Bug 4: `_print_report` used `─` (U+2500) which cp1252 can't encode. Fix: add to
  `rules/self-improvement.md` — 'All terminal output must use ASCII-only on Windows.
  Never use U+2500, U+2192, or other box-drawing/arrow chars in print() calls.'
  Incident: Windows UnicodeEncodeError run 2 of self-improvement loop 2026-07-21."

## Token Optimization — Available Tools

These tools are safe and verified. Install them when token waste is a documented problem:

### token-optimizer-mcp (ooples)
```json
// .mcp.json
{
  "mcpServers": {
    "token-optimizer": {
      "command": "npx",
      "args": ["-y", "@ooples/token-optimizer-mcp"]
    }
  }
}
```
When to use: session has repeated reads of the same files, or Bash output is not being
compressed by the PostToolUse hook. This MCP server returns diffs on repeated reads
instead of full file content, and caches large payloads.

### claude-context-optimizer (egorfedorov)
```bash
/plugin install context-optimizer@egorfedorov
```
When to use: session token budget >60% before the key work started. Provides heatmaps
showing which context blocks are most expensive, plus budget alerts.

### Context Compression skill (mcpmarket)
When to use: sessions that regularly hit 70%+ context before completing sprint work.
Anchored Iterative Summarization structures history into (session intent, file
modifications, architectural decisions) — keeps the useful signal, drops the noise.

## Rules Derived from Self-Improvement Sessions

Each entry below was added from a specific session finding.

| Rule | Incident |
|------|---------|
| All terminal `print()` output must use ASCII-only characters on Windows. Never use U+2500 (─), U+2192 (→), U+2019 ('), or any box-drawing/arrow chars. | UnicodeEncodeError on cp1252 Windows console, `_print_report` — self-improvement loop 2026-07-21 |
| Never hardcode `"python"` in subprocess calls. Always use `sys.executable`. | `pytest` not found in Windows uv environment — `"python"` not in PATH, only `sys.executable` resolves the managed interpreter — self-improvement loop 2026-07-21 |
| Background pipeline runs must use `nohup ... > log 2>&1 &`. Plain `&` dies on SIGHUP when shell exits. | Loop run 1-3 died when session compacted/closed — self-improvement loop 2026-07-21 |
| In generated test code, never use `{word!r}` in f-strings. `repr()` injects surrounding double-quotes which break string literals. Use `{word}` directly. | `SyntaxError: unterminated string literal` in auto-generated pytest test for word "i didn't count" — gap_patch_generator.py 2026-07-21 |
| When generating test content, the test's `post.content` must contain the exact forbidden word being tested. Using `pattern_text` (the example sentence) fails when `suggested_entry` differs. | Patch rejected: "Expected forbidden word not caught: 'that was only the first step'" — word not in `pattern_text` — gap_patch_generator.py 2026-07-21 |
| Suppress LangSmith logging in ALL entry points when tracing is disabled. `main.py` alone is insufficient — `pipeline_runner.py` is a separate entry point. | 429 quota errors flooded logs from `pipeline_runner.py` even after suppressing in `main.py` — 2026-07-21 |
| Grounding cross-checks that loop over UNVERIFIABLE results must use `asyncio.gather`. Sequential `await` in a for-loop adds N × API latency. | Sequential loop in `fact_check_node` over unverifiable claims — parallelized in f6ac1eb — 2026-07-21 |
| Score degradation guard (`best_score - 0.10`) requires `revisions >= 1`. First revision (0→1) has no protection. A G-Eval=1.0 post with only deterministic failures gets a full prose rewrite. | Post degraded 1.0 → 0.89 after revision — route_after_quality state.py:136 — 2026-07-21 |

## Self-Improvement Session Checklist

Before declaring a self-improvement session complete:
- [ ] session-improver produced a report with ≤ 10 findings, all with incident evidence
- [ ] system-curator implemented HIGH + MEDIUM findings only
- [ ] meta-eval passed (≥ 0.80 all agents, 25/25 tests)
- [ ] changes committed and pushed to master prompt repo
- [ ] new rules added to this file's "Rules Derived" table
- [ ] continue.txt updated (or deleted) if the session is fully closed
