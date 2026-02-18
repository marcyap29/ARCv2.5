# LUMARA Dual-Chronicle Architecture – Complete Guide

**CRITICAL ARCHITECTURAL PRINCIPLE: User's Chronicle is SACRED. System NEVER writes to it automatically.**

This guide merges when-to-activate, architecture, wiring, implementation status, and testing. Supersedes: `LUMARA_DUAL_CHRONICLE_COMPLETE_GUIDE.md`, `LUMARA_DUAL_CHRONICLE_WHEN_TO_ACTIVATE.md`, `LUMARA_DUAL_CHRONICLE_IMPLEMENTATION.md` (archived).

---

## When to Activate the Agentic Loop

**TRIGGER: Every time the user creates biographical content in ANY modality.**

The agentic loop is how LUMARA learns. It activates whenever the user generates biographical signal, regardless of modality.

### Activation by Modality

| Modality | When to activate | Wire in |
|----------|------------------|--------|
| **Reflect** (highest priority) | Every reflection save/completion | Journal/reflect save handler (after saving entry to User Chronicle) |
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
│   ├── user_chronicle_repository.dart
│   └── lumara_chronicle_repository.dart
├── storage/chronicle_storage.dart
├── services/
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

**User Chronicle (SACRED)**  
- **UserEntry:** User-authored only; `type`: chat | reflect | voice; `authoredBy: 'user'`.  
- **UserAnnotation:** User-approved only; `provenance.userApproved: true`, `approvedAt`; source lumara_gap_fill | lumara_inference.  
- System never writes to User Chronicle without explicit user action.

**LUMARA Chronicle (Learning Space)**  
- **Inferences:** Causal chains, patterns, relationships, values.  
- **Gaps:** Identified gaps, uncertainties, pending questions.  
- **GapFillEvent:** Trigger, process, extractedSignal, updates, recordedAt, promotableToAnnotation, promotedToAnnotation.  
- System writes here during the loop; promotions are offered, not auto-added.

(See `lib/chronicle/dual/models/chronicle_models.dart` for Dart types.)

### Interrupt Decision (Modality-Aware)

Implemented in `lib/chronicle/dual/intelligence/interrupt/interrupt_decision_engine.dart`:

- **Reflect:** More permissive (deepening opportunity). Interrupt if high-severity gap and readiness > 0.3. Questions framed as deepening.
- **Voice:** Similar to reflect; readiness threshold 0.35.
- **Chat:** Standard criteria. Do not interrupt when seekingType == 'Reflection' (venting) or in Recovery with readiness < 0.4. Interrupt value threshold 0.6. Questions framed as clarification.

---

## Wiring the Loop

### Reflect handler (primary)

1. Save the entry to User Chronicle (user-authored) if not already saved by existing journal flow.  
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

1. Save to User Chronicle (user-authored) if not already.  
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
Save to User Chronicle if new entry (reflect/voice)
       ↓
AgenticLoopOrchestrator.execute(userId, content, { modality, ... })
       ↓
Steps 1–7 (query User Chronicle, consult LUMARA, gap analysis, classify, fill, update LUMARA, synthesize)
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

- **Data models** (`chronicle_models.dart`): User Chronicle (UserEntry, UserAnnotation, provenance); LUMARA (Gap, GapFillEvent, inferences, signal types).  
- **Storage** (`chronicle_storage.dart`): User data under `user-data/chronicle/{userId}/`; LUMARA under `lumara-data/chronicle/{userId}/`; optional `testBaseDirectory` for tests.  
- **UserChronicleRepository:** Enforces `authoredBy == 'user'` and `provenance.userApproved == true`; throws `SacredChronicleViolation` otherwise.  
- **LumaraChronicleRepository:** Gap-fill events, gaps, inferences (add/update/load).  
- **GapAnalyzer / GapClassifier:** Analyze and classify gaps (searchable / clarification / inferrable).  
- **InterruptDecisionEngine / ClarificationProcessor:** Modality-aware interrupt; clarification writes only to LUMARA Chronicle.  
- **PromotionService:** `offerPromotion` (callback, no User Chronicle write); `approvePromotion` (only path that adds annotation to User Chronicle); `dismissPromotion`.  
- **AgenticLoopOrchestrator:** `execute`, `continueAfterInterrupt`; all writes to LUMARA Chronicle only.  
- **Promotion UI:** Settings → CHRONICLE → Timeline & Learning (Dual Chronicle) shows pending offers ("Add to Timeline" / "Dismiss").

### Not implemented (optional / future)

- **Phase 3 – AdaptiveSearchExecutor:** Multi-layer adaptive search (Layer 1–3); loop currently uses only Layer 0 query.  
- **Phase 6 – InferenceEditor + CascadeEngine:** User correct/refine/reject of inferences; LUMARA repo has `updateCausalChain`, `updatePattern`, `updateRelationship` for that layer.  
- **LumaraService** facade wrapping phase detection, seeking classification, and orchestrator for chat.

### Integration notes

1. **Existing Layer 0:** Current `Layer0Repository` (Hive) is separate from dual-chronicle User Chronicle. Either bridge (merge at read time) or migrate entries into `UserChronicleRepository` as `UserEntry` with `authoredBy: 'user'`.  
2. **Promotion UI:** Subscribe to `PromotionService.onPromotionOffered` or poll `getPendingOffers(userId)`; "Add to Timeline" → `approvePromotion`, "Dismiss" → `dismissPromotion`.  
3. **Storage paths:** `user-data/chronicle/{userId}/layer0/entries|annotations`, `lumara-data/chronicle/{userId}/gap-fills|gaps|inferences/...`. Use `ChronicleStorage(testBaseDirectory: dir)` in tests.

---

## Testing

- **Sacred separation** (`test/chronicle/dual/sacred_separation_test.dart`): No system writes to User Chronicle; annotations require approval; gap-fill only in LUMARA; promotion only on approval; dismiss leaves timeline unchanged; user can delete annotation.  
  Run: `flutter test test/chronicle/dual/sacred_separation_test.dart`  
- **Loop activation:** From reflect save, chat handler, voice handler, call `execute` with correct modality; assert orchestrator ran with that modality.  
- **Interrupt modality:** Same gaps/readiness; reflect context → interrupt true; chat context → interrupt false when venting or low readiness.

---

## When Q&A

- **When does the loop run?** On every creation of biographical content: reflection save, chat message, voice entry (after confirmation).  
- **When does it NOT run?** Background processing (VEIL, phase detection), settings, UI navigation, export/import.  
- **When do we interrupt?** Modality-aware: reflect/voice more permissive (deepening); chat standard (no venting, readiness/value thresholds).  
- **When does User Chronicle change?** Only: user creates entry, user approves promotion ("Add to Timeline"), user edits/deletes entry or annotation.  
- **When does LUMARA Chronicle change?** During every agentic loop execution (Step 6) and when clarifications are processed.

---

## Checklist (from spec)

- [x] User Chronicle has no automatic writes  
- [x] No synthetic entry type (rejected via `authoredBy != 'user'`)  
- [x] UserChronicleRepository throws on violations  
- [x] Annotations require explicit user approval  
- [x] Gap-fill events stored in LUMARA Chronicle only  
- [x] Promotion offers created; approval creates annotation; dismiss leaves timeline unchanged  
- [x] User can delete annotations  
- [x] Provenance (gapFillEventId, userApproved, approvedAt)  
- [x] Sacred separation tests passing  

**Code:** `lib/chronicle/dual/`; core loop: `lib/chronicle/dual/intelligence/agentic_loop_orchestrator.dart`.
