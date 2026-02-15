# Narrative Intelligence Paper vs EPI Repo — Architecture Comparison

**Reference:** Narrative_Intelligence.pdf (Narrative Intelligence: A Framework for Lifelong, Evolving Intelligence Systems — Marc Yap, January 2025, Version 3.0)  
**Repo:** EPI (Evolving Personal Intelligence) — Architecture v3.3.x  
**Last comparison:** February 2026

---

## Paper–Repo Architecture Alignment (Goal: Paper Matches Repo)

**To ensure the overall architecture of the paper matches the repo**, the paper should state the five modules as:

1. **LUMARA** — Integrative Intelligence Layer (and user-facing interface)  
2. **PRISM** — Multimodal Perception & Analysis (includes the Developmental Phase Engine, **ATLAS**)  
3. **CHRONICLE** — Longitudinal Memory and Vector Layer  
4. **AURORA** — Circadian Orchestration Layer  
5. **ECHO** — Response Control and Privacy Layer  

RIVET and SENTINEL operate **within ATLAS**; in the repo, ATLAS is implemented **inside the PRISM module** (`lib/prism/atlas/`). The PDF v3.0 lists ATLAS as a separate top-level module; aligning the paper with the repo means naming PRISM as the second module and specifying that ATLAS (with RIVET and SENTINEL) is the phase engine within PRISM. Ready-to-use §2 text for the paper is in **`DOCS/NARRATIVE_INTELLIGENCE_PAPER_ARCHITECTURE_SECTION.md`**.

---

## Executive Summary

The EPI codebase **largely implements** the five-module Narrative Intelligence architecture (LUMARA, PRISM, CHRONICLE, AURORA, ECHO; ATLAS within PRISM) with RIVET and SENTINEL. Major gaps are: **AURORA is a stub** in the orchestrator (circadian/sleep/reflection windows exist but do not yet govern response timing or synthesis), **CHRONICLE Layer 0** is not explicitly scoped to a "30–90 day" raw window in the paper’s sense, **compression targets** differ from the paper’s "50–75%", and **readiness** in the repo is RIVET-derived (ALIGN/TRACE) rather than the paper’s formula (valence, activity, thematic consistency, longitudinal baseline). Below are aligned areas, gaps, and concrete recommendations with file/location hints.

---

## 1. Module-by-Module Alignment

### 1.1 LUMARA (Integrative Intelligence Layer)

| Paper | Repo | Status |
|-------|------|--------|
| Center of system; coordinates CHRONICLE, ATLAS, AURORA | LUMARA Orchestrator coordinates ARC, ATLAS, CHRONICLE, AURORA | ✅ Aligned |
| Fuses signals into trajectory-conditioned master prompt | `LumaraControlStateBuilder` + master prompt build trajectory context | ✅ Aligned |
| Processed through ECHO before LLM | ECHO/PRISM in pipeline before Groq/Gemini | ✅ Aligned |

**Where:** `lib/lumara/` (orchestrator), `lib/arc/chat/services/enhanced_lumara_api.dart`, `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`, `lib/arc/chat/services/lumara_control_state_builder.dart`.

---

### 1.2 CHRONICLE (Longitudinal Memory and Vector Layer)

| Paper | Repo | Status |
|-------|------|--------|
| Layer 0 — Raw recent events (30–90 days) | Layer 0 = raw entries; retention is tier-based (30/90/365 days), not a fixed 30–90 day *scope* for queries | ⚠️ Partial |
| Layer 1 — Monthly synthesis (3–5 dominant themes) | Monthly synthesizer; themes in synthesis | ✅ Aligned |
| Layer 2 — Yearly developmental arcs | Yearly aggregations | ✅ Aligned |
| Layer 3 — Multi-year biographical essence | Multi-year aggregations | ✅ Aligned |
| 50–75% compression preserving semantic signal | Monthly ~10–20%, yearly ~5–10%, multi-year ~1–2% of source (more aggressive) | ⚠️ Different |
| Semantic vectorization; embeddings in Chronicle Index | On-device TFLite Universal Sentence Encoder; `ChronicleIndexBuilder`, `ChronicleIndexStorage` | ✅ Aligned |
| Three-stage retrieval: exact → cosine → fuzzy | `ThreeStageMatcher`, `PatternQueryRouter` | ✅ Aligned |

**Gaps / recommendations**

- **Layer 0 time scope (30–90 days):**  
  - **Add:** When building "recent raw" context for LUMARA, optionally restrict Layer 0 to the last 30–90 days (configurable or tier-based) so behavior matches the paper’s "raw recent events (30–90 days)".  
  - **Where:** `lib/chronicle/query/context_builder.dart`, `lib/chronicle/storage/layer0_repository.dart` (e.g. `getEntriesForUser` with optional `maxAgeDays` or use existing retention/cadence).

- **Compression (50–75%):**  
  - Paper: "controlled compression (50–75%) while preserving semantic signal."  
  - Repo: `ChronicleLayer.targetCompressionRatio` and synthesizers aim for ~10–20% (monthly), ~5–10% (yearly), ~1–2% (multiyear).  
  - **Optional:** If product should match the paper, add a config or doc that interprets "50–75%" (e.g. "retain 50–75% of semantic content" or "compress to 25–50% size") and align `targetCompressionRatio` / prompts in `lib/chronicle/synthesis/` (e.g. `monthly_synthesizer.dart`, `yearly_synthesizer.dart`, `multiyear_synthesizer.dart`) and `lib/chronicle/models/chronicle_layer.dart`.

---

### 1.3 ATLAS (Developmental Phase Engine)

| Paper | Repo | Status |
|-------|------|--------|
| Phases: Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough | Same six phases (e.g. `PhaseLabel`, phase names in UI) | ✅ Aligned |
| Phase = argmax over confidence | `PhaseInferenceService`: `PhaseScoring.getHighestScoringPhase(phaseScores)` | ✅ Aligned |
| confidence = f(readiness, stress, behavioral signals) | Phase scores from keyword/emotion/text; readiness is separate (RIVET) | ⚠️ Different |
| Readiness 0–100 from emotional valence, activity, thematic consistency, longitudinal baseline | Readiness 0–100 from RIVET ALIGN/TRACE in control state; health in `PhaseRatingService` | ⚠️ Different |

**Gaps / recommendations**

- **Readiness formula:**  
  - Paper: readiness on 0–100 from "emotional valence, activity levels, thematic consistency, and longitudinal baseline comparison."  
  - Repo: readiness from RIVET (ALIGN/TRACE) and used for response calibration; phase inference uses keyword/emotion/text, not this readiness.  
  - **Optional:** To align with paper, either: (1) document that "readiness" in EPI is evidence-alignment (RIVET) and map it to the paper’s "readiness" for response conditioning, or (2) add a separate readiness score from valence/activity/thematic/baseline (e.g. in PRISM/ATLAS) and feed it into control state and/or phase confidence.  
  - **Where:** `lib/arc/chat/services/lumara_control_state_builder.dart` (readiness), `lib/prism/atlas/phase/phase_scoring.dart`, `lib/prism/atlas/phase/phase_inference_service.dart`; optional new `lib/prism/atlas/readiness/` or extension in `phase_scoring.dart`.

---

### 1.4 RIVET (Evidence-Gated Transitions)

| Paper | Repo | Status |
|-------|------|--------|
| ALIGN_t = (1−β)ALIGN_{t−1} + β s_t | Same EMA in `RIVET_ARCHITECTURE.md` and RIVET implementation | ✅ Aligned |
| TRACE_t = 1 − e^{−Σe_i/K} | Same in RIVET docs and code | ✅ Aligned |
| Transitions only when alignment, cumulative evidence, sustained duration | RIVET gate and sustain logic | ✅ Aligned |

**Where:** `lib/prism/atlas/rivet/`, `DOCS/RIVET_ARCHITECTURE.md`. No change required for paper alignment.

---

### 1.5 SENTINEL (Temporal Crisis Detection)

| Paper | Repo | Status |
|-------|------|--------|
| Rolling windows: 1-, 3-, 7-, 30-day | `SentinelConfig`: WINDOW_1_DAY, 3, 7, 30 | ✅ Aligned |
| Composite risk: intensity, diversity, thematic fixation, acceleration | Sentinel analyzers and risk detectors (intensity, clustering, etc.) | ✅ Aligned |
| When threshold exceeded → containment and grounding modes | `sentinelAlert` → supportive/therapist mode; prompts use containment/grounding language | ✅ Aligned |

**Where:** `lib/services/sentinel/`, `lib/prism/atlas/sentinel/`, `lib/arc/chat/services/lumara_control_state_builder.dart` (sentinelAlert), `DOCS/SENTINEL_ARCHITECTURE.md`. No structural gaps; optional: explicitly label "containment mode" and "grounding mode" in control state or prompt constants for traceability to the paper.

---

### 1.6 AURORA (Circadian Orchestration)

| Paper | Repo | Status |
|-------|------|--------|
| Regulates timing and pacing of computation and interaction | AURORA subsystem returns empty aggregations (stub) | ❌ Missing |
| Segments active reflection windows | `ActiveWindowDetector` exists under `lib/arc/internal/aurora/` | ⚠️ Not wired to orchestration |
| Protects sleep intervals | `SleepProtectionService` exists | ⚠️ Not wired to orchestration |
| Coordinates restorative synthesis with CHRONICLE aggregation | VEIL scheduler runs synthesis; no AURORA-driven timing | ⚠️ Partial |

**Gaps / recommendations**

- **AURORA as real orchestration (high impact):**  
  - **Add:** Implement AURORA in the LUMARA flow so it:  
    1. **Reflection windows:** Use `ActiveWindowDetector` (and optionally `SleepProtectionService`) to produce a circadian context (e.g. "within_reflection_window", "sleep_protected", "optimal_synthesis_time").  
    2. **Response timing:** Optionally defer or shorten LUMARA responses when outside reflection window or in sleep protection (e.g. in `EnhancedLumaraApi` or the screen that calls it).  
    3. **Synthesis timing:** Pass AURORA context into the VEIL/CHRONICLE scheduler so restorative synthesis runs in preferred windows (e.g. after wake, not during sleep).  
    4. **Prompt context:** Feed AURORA summary (e.g. time-of-day, reflection window, sleep protection) into the master prompt so ECHO/response calibration can use it ("circadian state" in the paper).  
  - **Where:**  
    - `lib/arc/chat/services/aurora_subsystem.dart` — replace stub with real implementation that calls `ActiveWindowDetector`, `SleepProtectionService`, and optionally `CircadianProfileService` (`lib/aurora/services/circadian_profile_service.dart`).  
    - `lib/arc/chat/services/lumara_control_state_builder.dart` — include AURORA block (e.g. from `AuroraSubsystem.query()`) in the same way ATLAS/CHRONICLE are included.  
    - `lib/arc/chat/services/enhanced_lumara_api.dart` — where the master prompt is built, add AURORA context.  
    - `lib/chronicle/scheduling/synthesis_scheduler.dart` or the place that triggers it (e.g. `home_view.dart`) — consider time-of-day or AURORA signal before running heavy synthesis.  
  - **Docs:** Update `DOCS/ARCHITECTURE.md` and `DOCS/NARRATIVE_INTELLIGENCE_WHITE_PAPER.md` to state that AURORA is no longer a stub and how it affects timing and prompts.

---

### 1.7 ECHO (Response Control and Privacy)

| Paper | Repo | Status |
|-------|------|--------|
| On-device PII scrubbing | PRISM PII scrubbing (e.g. PrismAdapter, PiiScrubber) | ✅ Aligned |
| Correlation-resistant alias rotation | Correlation-resistant transformation (rotating aliases) | ✅ Aligned |
| Structured semantic abstraction | Semantic summarization / abstraction for cloud | ✅ Aligned |
| Response calibration by phase, longitudinal context, circadian | Phase and longitudinal context in control state; circadian minimal (AURORA stub) | ⚠️ Circadian pending AURORA |

**Where:** `lib/echo/`, `lib/arc/internal/echo/`, `DOCS/ECHO_AND_PRISM_PRIVACY_ARCHITECTURE.md`. Once AURORA is implemented, ensure ECHO/control state uses AURORA’s circadian output for response calibration (tone/pacing/depth) as in the paper.

---

## 2. Summary of Recommended Additions

| Priority | Item | Where to add / change |
|----------|-----|------------------------|
| High | AURORA orchestration: wire circadian, reflection windows, sleep protection into LUMARA timing and prompts | `aurora_subsystem.dart`, `lumara_control_state_builder.dart`, `enhanced_lumara_api.dart`, synthesis trigger (e.g. `home_view.dart`) |
| Medium | Layer 0 optional 30–90 day scope for "recent raw" context | `context_builder.dart`, `layer0_repository.dart` |
| Medium | Document or align compression with paper "50–75%" | `chronicle_layer.dart`, `monthly_synthesizer.dart` (and yearly/multiyear), or DOCS |
| Low | Readiness: document RIVET-based definition or add valence/activity/thematic readiness | `lumara_control_state_builder.dart`, optional `prism/atlas/readiness/`, DOCS |
| Low | Explicit "containment" / "grounding" mode labels when SENTINEL triggers | Control state or prompt constants in `lumara_master_prompt.dart` / `lumara_control_state_builder.dart` |

---

## 3. Traceability: Paper Sections → Repo

- **§2 System Architecture, §2.1 Hierarchy:** LUMARA orchestrator, CHRONICLE, ATLAS, AURORA, ECHO — `ARCHITECTURE.md`, `LUMARA_COMPLETE.md`, `lumara/` and `arc/chat/services/` (orchestration and subsystems).  
- **§3 ATLAS:** `lib/prism/atlas/`, `phase_inference_service.dart`, `phase_scoring.dart`, RIVET/SENTINEL under PRISM.  
- **§4 CHRONICLE:** `lib/chronicle/` (synthesis, query, embeddings, index, storage), `lib/chronicle/models/chronicle_layer.dart`.  
- **§5 RIVET and SENTINEL:** `lib/prism/atlas/rivet/`, `lib/prism/atlas/sentinel/`, `lib/services/sentinel/`, `RIVET_ARCHITECTURE.md`, `SENTINEL_ARCHITECTURE.md`.  
- **§6 AURORA:** `lib/aurora/`, `lib/arc/internal/aurora/` — implement orchestration in `aurora_subsystem.dart` and wire into control state and API.  
- **§7 ECHO:** `lib/echo/`, `lib/arc/internal/echo/`, `ECHO_AND_PRISM_PRIVACY_ARCHITECTURE.md`.  
- **§8 Ethical Framework (memory sovereign, revisable):** CHRONICLE edit/export/import and user controls — already present; can be called out in DOCS.

---

**Conclusion:** The repo matches the Narrative Intelligence paper in most areas once the paper’s §2 is aligned to the repo’s five modules (LUMARA, PRISM, CHRONICLE, AURORA, ECHO with ATLAS inside PRISM)—use `NARRATIVE_INTELLIGENCE_PAPER_ARCHITECTURE_SECTION.md` for the paper text. The main implementation gap is **AURORA as an active orchestration layer** (circadian, reflection windows, sleep protection driving timing and prompts). The other differences (Layer 0 window, compression, readiness formula) are configurable or documentation refinements. Implementing the AURORA subsystem and wiring it into the LUMARA control state and synthesis flow will bring behavior in line with the paper’s description of circadian orchestration.
