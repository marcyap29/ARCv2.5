# LUMARA Dual-CHRONICLE Architecture – Complete Guide

**CHRONICLE** = **C**hronological **R**ecall **O**ptimization via **N**ative **I**mitation of **C**onsolidated **L**ongitudinal **E**xperience (same acronym for both the user's and LUMARA's stores).

**The user's CHRONICLE (layers 0–3) is SACRED.** It is never modified by LUMARA under any circumstances. It holds summarization from the user's entries. There is no separate "User Chronicle" store. **LUMARA CHRONICLE** is the single sandbox: LUMARA has full access to user entries and the user's CHRONICLE (read-only), performs inference and gap analysis, and stores everything it learns in LUMARA CHRONICLE. LUMARA can use its own prior comments (in reflections and chats) to speed inference and relationship context.

This guide merges when-to-activate, architecture, wiring, implementation status, and testing. Supersedes: `LUMARA_DUAL_CHRONICLE_COMPLETE_GUIDE.md`, `LUMARA_DUAL_CHRONICLE_WHEN_TO_ACTIVATE.md`, `LUMARA_DUAL_CHRONICLE_IMPLEMENTATION.md` (archived).

---

## When to Activate the Agentic Loop

**TRIGGER: Every time the user creates biographical content in ANY modality.**

The agentic loop is how LUMARA learns. It activates whenever the user generates biographical signal, regardless of modality.

### Activation by Modality

| Modality | When to activate | Wire in |
|----------|------------------|--------|
| **Reflect** (highest priority) | Every reflection save/completion | Journal/reflect save handler (after saving entry to CHRONICLE) |
| **Chat** | Every user chat message | LUMARA chat message handler (e.g. LumaraAssistantCubit or API path) |
| **Voice** | After transcription confirmed/edited | Voice handler when user confirms/saves the transcription as entry |

**REFLECT:** Richest biographical signal; user already in processing mode (interrupts welcome); best source for high-confidence inferences.  
**CHAT:** Gap analysis informs answer quality; patterns from reflections inform chat responses.  
**VOICE:** Stream-of-consciousness richness; similar to reflect in depth; captures unplanned insights.

**DO NOT ACTIVATE:** Background processing (VEIL, phase detection), settings changes, UI navigation, export/import operations.

Call `AgenticLoopOrchestrator.execute(userId, content, context)` with `context.modality` set to `AgenticModality.reflect`, `AgenticModality.chat`, or `AgenticModality.voice`. On interrupt, show question (deepening in reflect/voice, clarifying in chat); on user reply call `continueAfterInterrupt(...)`.

### Why Reflections Are Primary

**Example user reflection:**
```
"I'm frustrated with work again. This is the third time this month. It always seems to happen after meetings with Sarah. I think it's because I don't feel heard when I bring up ideas."
```

**Gap analysis finds:** Pattern (work frustration, recurring), causal chain (meetings with Sarah → not feeling heard → frustration), relationship (Sarah, negative pattern), trigger (bringing up ideas). With the loop, LUMARA can learn and optionally interrupt with a deepening question. Without the loop, the entry is stored but the system doesn't actively learn.

---

## Architecture Overview

### File Structure

```
lib/chronicle/dual/
├── models/chronicle_models.dart
├── repositories/
│   └── lumara_chronicle_repository.dart
├── storage/chronicle_storage.dart
├── services/
│   ├── chronicle_query_adapter.dart   ← CHRONICLE Layer0 + LUMARA promoted
│   ├── lumara_comments_loader.dart    ← Optional prior LUMARA comments
│   ├── promotion_service.dart
│   └── dual_chronicle_services.dart
└── intelligence/
    ├── agentic_loop_orchestrator.dart   ← Core 7-step loop
    ├── gap/
    │   ├── gap_analyzer.dart
    │   └── gap_classifier.dart
    └── interrupt/
        ├── interrupt_decision_engine.dart  ← Modality-aware
        └── clarification_processor.dart
```

Modality handlers (Reflect, Chat, Voice) live in the app layer; they call the orchestrator and pass `AgenticContext(modality: AgenticModality.reflect | .chat | .voice, ...)`.

### Data Models

**CHRONICLE (user's chronicle, layers 0–3)**  
- User content lives in CHRONICLE: Layer 0 raw entries (Hive), then monthly/yearly/multi-year aggregations.  
- **ChronicleQueryAdapter** exposes Layer 0 entries and "annotations" (promoted gap-fill events from LUMARA CHRONICLE) in the same shape as before. No separate User Chronicle store.

**LUMARA CHRONICLE (single sandbox)**  
- **Inferences:** Causal chains, patterns, relationships, values.  
- **Gaps:** Identified gaps, uncertainties, pending questions.  
- **GapFillEvent:** Trigger, process, extractedSignal, updates, recordedAt, promotableToAnnotation, promotedToAnnotation.  
- System writes here during the loop. When the user approves a promotion ("Add to Timeline"), only LUMARA CHRONICLE is updated (promotedToAnnotation); approved insights are read via ChronicleQueryAdapter.loadAnnotations().

(See `lib/chronicle/dual/models/chronicle_models.dart` for Dart types.)

### Interrupt Decision (Modality-Aware)

Implemented in `lib/chronicle/dual/intelligence/interrupt/interrupt_decision_engine.dart`:

- **Reflect:** More permissive (deepening opportunity). Interrupt if high-severity gap and readiness > 0.3. Questions framed as deepening.
- **Voice:** Similar to reflect; readiness threshold 0.35.
- **Chat:** Standard criteria. Do not interrupt when seekingType == 'Reflection' (venting) or in Recovery with readiness < 0.4. Interrupt value threshold 0.6. Questions framed as clarification.

---

## Wiring the Loop

### Reflect handler (primary)

1. Save the entry (existing journal flow populates CHRONICLE Layer 0 via Layer0Populator).  
2. Build `AgenticContext(modality: AgenticModality.reflect, currentPhase: ..., readinessScore: ..., seekingType: 'Reflection')`.  
3. Call `AgenticLoopOrchestrator.execute(userId, reflectionContent, context)`.  
4. If result is `interrupt`: show "deepening opportunity" with `result.question`; on user reply call `continueAfterInterrupt(userId, originalContext, result.question!, userResponse, result.gapId!)`.  
5. If result is `response`: show acknowledgment / synthesis.

### Chat handler

1. Build `AgenticContext(modality: AgenticModality.chat, ...)` (include phase, readiness, seeking from classifier).  
2. Call `execute(userId, message, context)`.  
3. If interrupt: show clarifying question; on reply call `continueAfterInterrupt(...)`.  
4. If response: show answer.

### Voice handler

1. Save entry (CHRONICLE Layer 0) if not already.  
2. Build `AgenticContext(modality: AgenticModality.voice, ...)`.  
3. Call `execute(userId, transcription, context)`.  
4. Same interrupt/continue pattern as reflect (deepening opportunity).

---

## Flow Diagram

```
User creates biographical content (reflect save / chat message / voice entry)
       ↓
Modality handler (Reflect / Chat / Voice)  ← ACTIVATION POINT
       ↓
Save to CHRONICLE if new entry (reflect/voice)
       ↓
AgenticLoopOrchestrator.execute(userId, content, { modality, ... })
       ↓
Steps 1–7 (query CHRONICLE, consult LUMARA, gap analysis, classify, fill, update LUMARA, synthesize)
       ↓
[If interrupt] → Modality-aware question (deepening or clarifying)
       ↓
[User responds] → continueAfterInterrupt() → process clarification, resume Steps 6–7
       ↓
Return response / acknowledgment
```

---

## Implementation Status

### Implemented

- **Data models** (`chronicle_models.dart`): CHRONICLE/adapter (UserEntry, UserAnnotation, provenance); LUMARA (Gap, GapFillEvent, inferences, signal types).  
- **Storage** (`chronicle_storage.dart`): User data under `user-data/chronicle/{userId}/`; LUMARA under `lumara-data/chronicle/{userId}/`; optional `testBaseDirectory` for tests.  
- **ChronicleQueryAdapter:** Reads entries from the user's CHRONICLE Layer 0 and annotations from LUMARA CHRONICLE (promoted gap-fill events).  
- **LumaraChronicleRepository:** Gap-fill events, gaps, inferences (add/update/load).  
- **GapAnalyzer / GapClassifier:** Analyze and classify gaps (searchable / clarification / inferrable).  
- **InterruptDecisionEngine / ClarificationProcessor:** Modality-aware interrupt; clarification writes only to LUMARA CHRONICLE.
- **PromotionService:** `offerPromotion` (callback); `approvePromotion` (only path that marks promotion in LUMARA CHRONICLE); `dismissPromotion`.
- **AgenticLoopOrchestrator:** `execute`, `continueAfterInterrupt`; all writes to LUMARA CHRONICLE only (user's CHRONICLE is never written to).
- **Promotion UI:** Settings → CHRONICLE → LUMARA Analysis shows pending offers ("Add to Timeline" / "Dismiss").
- **Intelligence Summary (Layer 3):** Readable synthesis from the user's CHRONICLE + LUMARA CHRONICLE. Settings → CHRONICLE → LUMARA Analysis → Intelligence Summary (card below "When learning runs"). Regenerates on demand and automatically after backup/import.

### Intelligence Summary – what’s needed

To run and get a **full** Intelligence Summary (not just the short stats fallback):

1. **Groq API key** – Set in Settings → LUMARA → API & providers. The generator uses the same Groq config as LUMARA chat/reflection.
2. **Dual Chronicle data** – The summary is built from:
   - **User's CHRONICLE (SACRED):** entries (Layer 0 Hive) and user-approved annotations (read from LUMARA CHRONICLE promoted events). Populated when you reflect or chat; approved insights shown via LUMARA CHRONICLE. Never modified by LUMARA.
   - **LUMARA CHRONICLE:** patterns, causal chains, relationships, gap-fill events. Populated by the agentic loop when you reflect/chat/voice.

**Note:** Monthly and yearly “Chronicle Summaries” (CHRONICLE Layers 1–2) are a **different** system (View CHRONICLE Layers). The Intelligence Summary does **not** read those; it uses only the Dual Chronicle (User + LUMARA) data above. If nothing meaningful is generated, check: (1) Groq key is set and valid, (2) you have Timeline (Dual Chronicle) entries from reflecting/chatting, and/or (3) after a backup restore, run “Generate Summary” once data is loaded.

**When it runs:** On-demand (tap Generate/Regenerate), and automatically when entries are loaded from a saved backup (import complete).

### Not implemented (optional / future)

- **Phase 3 – AdaptiveSearchExecutor:** Multi-layer adaptive search (Layer 1–3); loop currently uses only Layer 0 query.  
- **Phase 6 – InferenceEditor + CascadeEngine:** User correct/refine/reject of inferences; LUMARA repo has `updateCausalChain`, `updatePattern`, `updateRelationship` for that layer.  
- **LumaraService** facade wrapping phase detection, seeking classification, and orchestrator for chat.

### Integration notes

1. **User's CHRONICLE Layer 0:** `Layer0Repository` (Hive) is the source for user entries. `ChronicleQueryAdapter` maps Layer 0 entries to `UserEntry` and reads promoted annotations from LUMARA CHRONICLE.  
2. **Promotion UI:** Subscribe to `PromotionService.onPromotionOffered` or poll `getPendingOffers(userId)`; "Add to Timeline" → `approvePromotion`, "Dismiss" → `dismissPromotion`.  
3. **Storage paths:** `user-data/chronicle/{userId}/layer0/entries|annotations`, `lumara-data/chronicle/{userId}/gap-fills|gaps|inferences/...`. Use `ChronicleStorage(testBaseDirectory: dir)` in tests.

---

## Testing

- **Sacred separation** (`test/chronicle/dual/sacred_separation_test.dart`): User's CHRONICLE is SACRED (never modified by LUMARA); approved insights only in LUMARA CHRONICLE; gap-fill only in LUMARA CHRONICLE; promotion only on approval; dismiss leaves list unchanged.  
  Run: `flutter test test/chronicle/dual/sacred_separation_test.dart`  
- **Loop activation:** From reflect save, chat handler, voice handler, call `execute` with correct modality; assert orchestrator ran with that modality.  
- **Interrupt modality:** Same gaps/readiness; reflect context → interrupt true; chat context → interrupt false when venting or low readiness.

---

## When Q&A

- **When does the loop run?** On every creation of biographical content: reflection save, chat message, voice entry (after confirmation).  
- **When does it NOT run?** Background processing (VEIL, phase detection), settings, UI navigation, export/import.  
- **When do we interrupt?** Modality-aware: reflect/voice more permissive (deepening); chat standard (no venting, readiness/value thresholds).  
- **When does the timeline/approved list change?** User creates entry (user's CHRONICLE); user approves promotion ("Add to Timeline") updates LUMARA CHRONICLE only; user can dismiss offers.
- **When does LUMARA CHRONICLE change?** During every agentic loop execution (Step 6) and when clarifications are processed.

---

## Checklist (from spec)

- [x] User's CHRONICLE (layers 0–3) is SACRED; no separate User Chronicle store  
- [x] User's CHRONICLE is SACRED (never modified by LUMARA)
- [x] Approved insights stored only in LUMARA CHRONICLE (promotedToAnnotation)
- [x] Gap-fill events stored in LUMARA CHRONICLE only
- [x] Promotion offers created; approval updates LUMARA CHRONICLE only; dismiss leaves list unchanged
- [x] Provenance (gapFillEventId, userApproved, approvedAt)  
- [x] LUMARA comments (reflections + chats) can be loaded for inference context (optional)  
- [x] Sacred separation tests passing  

**Code:** `lib/chronicle/dual/`; core loop: `lib/chronicle/dual/intelligence/agentic_loop_orchestrator.dart`.

### Migration

If you had data in the legacy `user-data/chronicle/` store (separate User Chronicle), it is no longer read. User content is now sourced from the user's CHRONICLE (Layer 0). Approved insights are read from LUMARA CHRONICLE (promoted gap-fill events). To migrate legacy annotations: run a one-time script that reads any existing `layer0/annotations` JSON files and creates corresponding promoted gap-fill events in LUMARA CHRONICLE, or treat legacy data as read-only and rely on new promotions going forward.
