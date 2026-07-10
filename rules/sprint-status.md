# Sprint Status Reporting

**Rule scope:** loaded on-demand when a session is about to print a sprint status tree.

## Rule

Every sprint gets a status tree — always, before launching agents and after each completion wave.

## Format

```
😸 Sprint N — activo
├── 🤖 agentes  — N parallel (agent1·agent2·agent3·...)
├── 🧠 skills   — skill1 → skill2 → skill3
├── 📊 metrics  — tests X→Y · TS 0 errors · build ✅
├── ✅ file.py          — one-line summary of what was done
├── 🔄 pending_agent    — brief task description
└── 🔍 Codex (bg)      — adversarial review scope
```

## Row order (fixed — always in this sequence)

1. **🤖 agentes** — how many running and which ones (real-time signal)
2. **🧠 skills** — Superpowers skills fired this sprint in order
3. **📊 metrics** — test delta (before → after), TS error count, build status
4. **✅ / 🔄 / ❌** — one row per file or agent worked on
5. **🔍 Codex** — always last

## Cat emoji legend

- **😸** — header only (ONE per sprint tree, nowhere else)
- **✅** — completed
- **🔄** — in progress / waiting
- **❌** — failed / blocked
- **🔍** — Codex adversarial (always last row)

## Rules

- Print tree BEFORE launching agents (shows plan — metrics row shows baseline)
- Rebuild tree after each completion wave (metrics row updates with deltas)
- ONE 😸 on the sprint header only — the rest use ✅ / 🔄 / ❌ / 🔍
- 🤖 / 🧠 / 📊 rows always present — use "—" if not yet known
- One line per agent/file, description ≤ 50 chars
- Codex always gets its own 🔍 row at the bottom

## User confirmation

Format was explicitly confirmed excellent by user on 2026-06-30. Use it verbatim — never invent a different tree layout.
