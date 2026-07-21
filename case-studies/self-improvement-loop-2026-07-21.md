# Case Study: La Máquina que se Repara Sola — 24 Horas con el Self-Improvement Loop

**Fecha:** 2026-07-21  
**Repo:** https://github.com/GatoProgramador-01/medium-agent-factory  
**Sprint:** 27 — `feat/self-improvement-loop` → master  
**Stack:** LangGraph · Python · pytest · MongoDB · DeepSeek v4 · Claude Sonnet/Haiku

---

## El Experimento

Después de construir un pipeline de generación de posts para Medium, la pregunta fue inevitable:
¿puede el sistema detectar sus propios fallos y corregirse solo?

Inspirado en el paper *Darwin Gödel Machine* (arxiv:2604.10508), se construyó un loop de auto-mejora en un solo sprint:

```
pipeline run → slop_judge_node → gap_patch_generator → auto_patch_detector → rerun
```

**Safety cap:** máximo 2 ciclos. El paper dice que las mejoras plateauan en el ciclo 2.  
**Convergencia:** `ai_slop_passed=True AND truth_enforcer_passed=True AND gap_count=0`

El loop corrió 5 veces en 24 horas. Encontró 9 bugs antes de llegar al ciclo 2.

---

## Los 9 Bugs (en orden de aparición)

### Bug 1 — Silent NULL Gates (run 1)
**Síntoma:** `improvement_report` muestra `ai_slop_passed=null`, `truth_enforcer_passed=null`  
**Causa:** El return dict de `run_pipeline()` no incluía 3 keys: `ai_slop_passed`, `truth_enforcer_passed`, `slop_gap_report`. El loop siempre recibía `None`. El check `is True` nunca disparaba.  
**Fix:** 3 líneas en `pipeline_runner.py`. 20 min para diagnosticar.

### Bug 2 — Grammar Correction Crash (run 1)
**Síntoma:** `"Failed to parse GrammarReport from completion []. Got: 1 validation error"`  
**Causa:** El LLM devuelve `[]` cuando no encuentra errores. `with_structured_output(GrammarReport)` intenta validar `[]` como un dict de GrammarReport → `ValidationError`.  
**Fix:** Branch `isinstance(report_result, list)` → `GrammarReport(corrections=report_result)`.  
**Nota:** No bloqueante (el nodo captura la excepción y devuelve Layer 1 solo).

### Bug 3 — pytest Not Found (run 2)
**Síntoma:** `Patch rejected: "No module named pytest"`  
**Causa:** `auto_patch_detector.py` usaba `["python", "-m", "pytest", ...]`. En entornos Windows con `uv`, `"python"` no está en `PATH`. `uv` maneja su propio Python.  
**Fix:** Reemplazado por `sys.executable`.  
**Nota:** El mismo problema que atrapa a todo dev Windows al menos una vez.

### Bug 4 — Unicode Crash en el Printer (run 2)
**Síntoma:** `UnicodeEncodeError: 'charmap' codec can't encode characters in position 0-17`  
**Causa:** `_print_report` usaba `U+2500` box-drawing chars (`─────────────────`). La consola Windows usa `cp1252`, que no tiene box-drawing.  
**Fix:** Reemplazados con dashes ASCII (`------------------`).

### Bug 5 — LangSmith 429 Noise (proactivo)
**Síntoma:** `"Monthly unique traces usage limit exceeded"` flooding logs en cada llamada LLM.  
**Causa:** `LANGCHAIN_TRACING_V2=true` en `.env`, cuota mensual agotada.  
**Fix:** `LANGCHAIN_TRACING_V2=false` en `.env` + supresión del logger Python en `main.py` Y `pipeline_runner.py` (dos entry points — ambos necesarios).

### Bug 6 — Runs Muriendo al Cerrar Shell (runs 1-3)
**Síntoma:** Los procesos en background mueren cuando la sesión compacta o cierra.  
**Causa:** Jobs con `&` reciben `SIGHUP` cuando su shell padre termina.  
**Fix:** `nohup ... > log 2>&1 &` en todos los lanzamientos del loop.

### Bug 7 — Test Content Roundtrip Mismatch (run 3)
**Síntoma:** `Patch rejected. Test: "Expected forbidden word not caught: 'that was only the first step'"`  
**Causa:** `_gen_forbidden_word_test` seteaba `post.content = pattern_text` (la oración de ejemplo). Pero la palabra a detectar era `suggested_entry = "that was only the first step"` (sin "change"). La palabra no estaba en el contenido. El detector no puede detectar lo que no está ahí. El test fallaba.  
**Fix:** `post.content = "Here is AI slop: {word}. It should be caught."` — el contenido ahora contiene la palabra exacta.

### Bug 8 — Apostrophe SyntaxError en Tests Generados (run 4 Cycle 1)
**Síntoma:** `SyntaxError: unterminated string literal at line 1022`  
`assert any("i didn't count" in w for w in words), f"Expected ... "i didn't count""`  
**Causa:** `_gen_forbidden_word_test` usaba `{word!r}` en el mensaje de error. `repr("i didn't count")` → `"i didn't count"` (con doble-quote). Insertado en un f-string con doble-quote → terminación prematura del string.  
**Fix:** Removido `!r`, usar `{word}` directamente.  
**Antes:** `f"Expected forbidden word not caught: {word!r}"`  
**Después:** `"Expected forbidden word not caught: {word}"`

### Bug 9 — Unicode Arrow en Print Report (run 4)
**Síntoma:** `UnicodeEncodeError: 'charmap' can't encode '→'`  
**Causa:** El Bug 4 arregló `─` pero se olvidó `→` (U+2192) en los strings de `patch_info`.  
**Fix:** `→` reemplazado por `->`.

---

## Lo que la Máquina Logró

**Run 4 Cycle 0 — Primer Auto-Heal Exitoso:**
- Gaps detectados: 2
- Patch: 0 palabras, 2 patrones regex
- Pytest: 45 passed en 3.64s ✓
- Merge: `feat/auto-heal-20260721-160645` → master (`bcb9d34`)
- Efecto: `ai_slop_passed` fue `False → True` en Cycle 1

**Run 4 Cycle 1 — Patch Rechazado (Bug 8):**
- Gaps detectados: 1 (`"I didn't count"`)
- `ai_slop_passed: True` ← mejora real del ciclo anterior
- `truth_enforcer_passed: False` ← gate separado, otra causa raíz

**Estado Final:**
- 1 patch aplicado (2 patrones regex en `ai_slop_detector.py`)
- `ai_slop_passed: True` ← mejora real
- `truth_enforcer_passed: still False` ← el loop agotó balance antes de resolverlo
- DeepSeek v4 balance agotado en run 5 → hard blocker

---

## Timing Real (datos de MongoDB)

```
Run 3 Cycle 0:  25 min  (05:23 → 05:48 UTC)  [normal]
Run 4 Cycle 0:  10h 6m  (06:00 → 16:06 UTC)  [ANOMALOUS — Tavily/revision hang]
Run 4 Cycle 1:  20 min  (16:06 → 16:26 UTC)  [normal]
Run 5 Cycle 0:  22 min  (16:05 → 16:27 UTC)  [normal — murió en slop_judge 402]
```

Tiempo normal con `--skip-images`: 20-25 min.  
Peor caso con 4 ciclos de revisión + Tavily delays: 2-4 horas.  
El run de 10h: hang one-off (probablemente Tavily timeout + revision loop atascado).

---

## Lo que el Paper No Dice

> *arxiv:2604.10508 dice "self-repair gains plateau at cycle 2."*  
> *No dice "vas a pasar el ciclo 0 peleando con tu generador de tests."*

Los bugs no estaban en la capa LLM. Estaban en el scaffolding:
- Python `repr` insertando doble-quotes en f-strings
- Windows `cp1252` rechazando Unicode que Linux traga en silencio
- Diferencias de `PATH` entre Python interactivo y `uv`-managed
- `pattern_text ≠ suggested_entry` en el roundtrip del patch

**La máquina que se parchea sola necesitó una máquina (Claude Code) para parchear a la máquina.**  
Meta hasta el fondo.

---

## Descubrimiento No Planeado: Score Degradation en Revisión

Durante la sesión se observó un patrón preocupante: posts con G-Eval=1.0 bajaban a 0.89 después de la primera revisión.

**Causa raíz confirmada** (MongoDB + `state.py` lines 108-150):

1. Post con `score=1.0` y `ai_slop_passed=False` (solo fallas determinísticas)
2. `route_after_quality`: `passed=False` → fast-path bloqueado
3. Guard de degradación (`best_score - 0.10`) requiere `revisions >= 1` → sin protección en ciclo 0→1
4. Default: `return "revision"` → LLM reescribe toda la prosa
5. La reescritura arregla el slop pero baja el score a 0.89

Un post perfecto con fallos determinísticos (detectable por regex) no debería pasar por revisión LLM completa. Ese es el próximo sprint.

---

## Lecciones para el Sistema de Agentes

**Lo que funcionó:**
- Wave-parallel dispatch (4 agentes simultáneos en Sprint 23 que habilitó esto)
- Aislamiento de worktrees: los 4 agentes tocaron archivos distintos, cero conflictos
- pytest como gate de seguridad: evitó que patrones rotos llegaran a master
- nohup + MongoDB logging: único modo de observar runs de 10+ horas sin perder estado

**Lo que falló:**
- `repr()` en generadores de código — regla nueva: nunca usar `!r` en f-strings que se insertan en código generado
- Unicode en Windows — regla nueva: toda salida de terminal usa ASCII exclusivamente
- `sys.executable` en Windows con `uv` — regla nueva: nunca hardcodear `"python"` en subprocesos
- Roundtrip test/content mismatch — regla nueva: el contenido del test siempre contiene la word exacta a detectar

**Insight de arquitectura:**  
El self-improvement loop es la forma más honesta de evaluar un pipeline de generación. No el G-Eval score. No los tests unitarios. Sino si el sistema puede detectar sus propios fallos y sobrevivir el proceso de parcharse a sí mismo.

---

## Archivos del Sprint

```
backend/app/scripts/
  self_improvement_loop.py    — meta-orchestrator CLI (max 2 ciclos)
  gap_patch_generator.py      — SloppyGapReport → DetectorPatch
  auto_patch_detector.py      — AST insert → pytest gate → git merge/revert

backend/app/agents/
  nodes/slop_judge_node.py    — compara ai_slop_check vs. draft final
  models/slop_models.py       — SloppyGap, SloppyGapReport, DetectorPatch, PatchResult

README.md                     — Act 5 + Sprint 27 + Mermaid diagram del loop
article-self-improvement-loop-session.txt  — semilla para artículo Medium
article-ctx-grounding.txt                  — semilla para artículo sobre grounding
```

---

*Próximo sprint: Optimización de pipeline — fix score degradation en `route_after_quality`, revisión constrained en lugar de reescritura completa cuando score ≥ 0.95 con fallas solo determinísticas.*
