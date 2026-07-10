# Wave 6 — Architect Cartridge Tuning (retired-agent regression fix)

**Date:** 2026-07-10 (post-restart, cartridge-v2 atomic swap in effect)
**Root cause:** Wave 5 field tests found the architect subagent overrode the retirement ban 4/4 times, routing `orchestrator.py` wiring to the retired `integrator` agent despite three defensive layers (Slot 1 HARD BAN, Slot 4 retirement table, Slot 7 self-critique). Sonnet's training prior on "integrator wires orchestrator.py" was stronger than any negative rule the cartridge could carry.

## Wave 6 fix — 3-shot positive exemplars

Added a new block to `architect.md` Slot 4 immediately after the retirement table: three concrete YAML task-brief exemplars showing the CORRECT `agent:` value for the three most common misroutings.

Exemplar A — orchestrator.py wiring → `llmops-expert` (not `integrator`)
Exemplar B — TSDoc emission → `frontend-expert` (not `jsdoc`)
Exemplar C — read-only diagnostics → `adversarial` (not `analyst`)

Plus a verification clause: "every task-brief you emit must have `agent:` set to one of exactly these 13 strings and NOTHING ELSE" followed by the exhaustive list.

**Rationale:** LLMs pattern-match YAML shapes stronger than they follow prose bans. A concrete "when input=X, output looks like this" example overrides the training prior because the LLM sees the correct token in the same position it would otherwise emit `integrator`.

## Field-test verification

3 tests run on the patched cartridge — all clean.

| Test | Task | Expected owners | Actual owners | Pass |
|------|------|-----------------|---------------|------|
| Wave 6-1 | new LangGraph node `deep_research_node` after `research_node` | node → llmops-expert, wiring → llmops-expert, review → adversarial | llmops-expert, llmops-expert, adversarial | ✅ |
| Wave 6-2 | investigate flaky `test_content_generator` in CI | diag → adversarial, fix-plan → llmops-expert | adversarial, adversarial (2 parallel), llmops-expert | ✅ |
| Wave 6-3 | TSDoc emission + security audit on 2 TS files | tsdoc → frontend-expert, security → adversarial | frontend-expert, adversarial | ✅ |

**Zero retired-agent misroutings across 3 tests.** The regression documented in `2026-07-09-wave5-gate.md` is resolved.

## Cartridge state

`~/.claude/agents/architect.md`: 226 lines (was 185 pre-fix, +41 lines for exemplar block)
Also mirrored to `~/.claude-agents-v2/agents/architect.md` staging so re-swaps preserve the fix.

## Wave 6 gate

**OPEN.** No known regressions. The full 13-agent v2 roster is production-ready.

## Sprint total (final)

- Waves 0-6: 28 planned tasks + 5 Codex fix iterations + 1 field-test fix + 1 Wave 6 tuning = **35 items landed**
- Codex verdicts: 2× needs-attention (fixed inline) + 1× APPROVE (ship)
- Field tests: 4 iterations across 2 architect variants — first 4 caught the regression, next 3 confirmed the fix
- All commits pushed to `main` (claude-code-master-prompt) and `master` (medium-agent-factory)

## What's live right now

- Thin 107-line CLAUDE.md
- 13 v2 cartridges at `~/.claude/agents/` — including 3 NEW (prompt-engineer, eval-writer, sme-reviewer)
- 4 retired v1 cartridges archived at `~/.claude/agents/archive/2026-07-09-v1/`
- 4 rules files tracked in `rules/` + installed at `~/.claude/rules/`
- Auto-gen roster README with codex-mode taxonomy
- 24-case meta-eval dataset + 25/25 passing rubric tests
- Wave 5 field-test regression: RESOLVED

## Rollback (still available)

```bash
rm -rf ~/.claude/agents/*.md ~/.claude/agents/archive/
cp -r ~/.claude/agents-backup-v1/*.md ~/.claude/agents/
```

Restores the pre-swap v1 state exactly.
