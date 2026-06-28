# Case Study: JSF Scraper Production Delivery in 2 Days

**Date:** 2026-06-28  
**Repo:** https://github.com/GatoProgramador-01/pj-peru-scraper  
**Context:** Technical interview test for magnar.ai (Chile/LatAm, remote, USD contract)  
**Stack:** TypeScript + axios + cheerio — HTTP only, no browser automation

---

## What Was Delivered

A production-grade HTTP scraper targeting two real Peruvian government JSF portals:
- **OEFA** (PrimeFaces, public — no VPN required)
- **PJ Peru** Superior + Suprema (RichFaces, requires Peruvian VPN)

Built with a 7-layer TypeScript architecture: types → session → JSF protocol → HTML parsers → PDF → scraper orchestration → CLI/parallel runners.

---

## Real Production Metrics

| Run | Result |
|-----|--------|
| OEFA test (100 docs) | 100 docs, 92 PDFs, 3m14s |
| PJ Peru Suprema (20 years, 12 workers) | ~43,750 docs combined (main run + retry), ~73 min |
| PJ Peru Superior districts (34 districts) | 33/34 OK, 998 PDFs, 14 MB JSONL, 15m31s |
| All runs: HTTP 429 events | 0 |

- **53 unit tests**, 0 TypeScript errors, 0 lint errors
- **7 layers** of typed architecture
- **Checkpoint/resume** — interrupted runs resume from last sector
- **Soft-block detection** — novel technique documented below

---

## Key Technical Finding: Soft-Block (Not HTTP 429)

PJ Peru does not return HTTP 429 under load. Instead it returns **HTTP 200 with empty AJAX body** when the JSF ViewState pool is contended (12 parallel workers competing for the same ViewState).

If undetected, this silently truncates the run — the scraper would accept the empty 200 as "no more results" and stop. **This is the real-world equivalent of 429.**

**Solution:** `sectorScraper.ts` counts consecutive empty AJAX pages. At 3 (`CONSECUTIVE_EMPTY_ABORT`), it records a `soft_block_abort` event, saves the checkpoint, and exits cleanly. The retry runner drops to 1 worker, eliminating ViewState contention — speed jumped from ~85 docs/min to ~120 docs/min.

**Verifiable without a real portal:**
```bash
npm run verify:local
# Output includes: "softBlock": { "outcomes": ["warning","warning","abort"], "abortTriggeredAt": "page 3" }
```

---

## Development Stack That Made This Possible in 2 Days

### Codex → Claude Code pipeline

| Tool | Role |
|------|------|
| **Codex** | Structural refactors via written spec files (CODEX-REFACTOR.md) — 7-layer architecture, interface extraction, constants centralization |
| **Claude Code** | Precision work: debugging, JSF protocol comments, README, reviewer simulation, delivery verification |

Key rule: Codex gets a written task file with numbered steps. Claude Code gets interactive context. Neither replaces the developer's judgment — they amplify execution speed.

### Session pattern that worked best
```
parallel Agent calls (research) → implement → dry-run smoke test → Monitor(live run) → commit
```
Result: full iteration cycle in ~30 minutes instead of hours.

---

## What the Reviewer Test Covers (Verifiable by Anyone)

```bash
git clone https://github.com/GatoProgramador-01/pj-peru-scraper
cd pj-peru-scraper
cp .env.example .env
npm ci && npm run ci        # 53 tests pass, typecheck clean — no internet needed
npm run verify:local        # 429 retry + soft-block simulation — no internet needed
npm run scrape:oefa:test100 # 100 real docs + PDFs — public internet, no VPN
```

---

## What This Demonstrates for Future Article

1. **HTTP-only JSF reverse engineering** is achievable without browser automation — and faster and more stable in production
2. **Soft-block detection** as a pattern for portals that don't emit standard rate limit codes
3. **Codex + Claude Code as a two-tool stack**: structural batch work vs. precision interactive work
4. **AI-assisted development at senior level**: the developer directs with technical judgment; the tools execute
5. Real production evidence: 43,750 documents, not a toy scraper

---

## Article Hook (for future use)

> "The portal never returned HTTP 429. It returned HTTP 200 with an empty body — 12 times, silently, until our worker gave up thinking there were no more documents. Here's how we detected it, named it, and built a retry system for something the portal doesn't even document."
