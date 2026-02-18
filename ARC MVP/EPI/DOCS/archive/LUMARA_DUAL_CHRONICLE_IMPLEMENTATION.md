> **ARCHIVED.** Superseded by `DOCS/LUMARA_DUAL_CHRONICLE_GUIDE.md`. Kept for history.

# LUMARA Dual-Chronicle Architecture – Implementation Summary

This document summarizes the **implemented** dual-chronicle architecture in this codebase.

**When to activate the loop:** Activate the agentic loop **every time the user creates biographical content in any modality** (reflect save, chat message, voice entry after confirmation). Do **not** activate for background processing (VEIL, phase detection), settings, UI navigation, or export/import. See **`DOCS/LUMARA_DUAL_CHRONICLE_GUIDE.md`**.

## Critical principle

**THE USER'S CHRONICLE IS SACRED.**  
The system never writes to the User Chronicle without explicit user approval. No synthetic entries, no automatic injections, no hidden additions.

---

## Implemented components

### 1. Data models (`lib/chronicle/dual/models/chronicle_models.dart`)

- **User Chronicle:** `UserEntry`, `UserAnnotation`, `UserAnnotationProvenance`, `EmotionalSignals`, `UserEntryType`, `UserEntryModality`, `AnnotationSource`
- **LUMARA Chronicle:** `Gap`, `GapType`, `GapSeverity`, `GapFillStrategy`, `GapFillEvent`, `GapFillEventTrigger`, `GapFillEventProcess`, `GapFillEventUpdates`, `BiographicalSignal`, `CausalChain`, `Pattern`, `RelationshipModel`, `Provenance`, `ProvenanceSourceEntry`, and supporting signal types (`CausalChainSignal`, `PatternSignal`, `RelationshipSignal`, `ValueSignal`)

### 2. Storage (`lib/chronicle/dual/storage/chronicle_storage.dart`)

- **ChronicleStorage:** File-based storage with:
  - User data under `user-data/chronicle/{userId}/`
  - LUMARA data under `lumara-data/chronicle/{userId}/`
- Supports optional `testBaseDirectory` for tests (no writes to app documents in tests).

### 3. Repositories

- **UserChronicleRepository** (`lib/chronicle/dual/repositories/user_chronicle_repository.dart`)
  - `addEntry(userId, entry)` – **enforces** `authoredBy == 'user'`; throws `SacredChronicleViolation` otherwise
  - `addAnnotation(userId, annotation)` – **enforces** `provenance.userApproved == true`; throws otherwise
  - `queryLayer0`, `loadEntries`, `loadAnnotations`, `deleteEntry`, `deleteAnnotation`
  - No method for synthetic or system-authored entries

- **LumaraChronicleRepository** (`lib/chronicle/dual/repositories/lumara_chronicle_repository.dart`)
  - Gap-fill events: `addGapFillEvent`, `getGapFillEvent`, `updateGapFillEvent`, `loadGapFillEvents`
  - Gaps: `addGap`, `getGap`, `updateGap`, `loadGaps`
  - Inferences: `addCausalChain`, `addPattern`, `addRelationship`, `loadCausalChains`, `loadPatterns`, `loadRelationships`, `queryInferences`, `updateCausalChain`, `updatePattern`, `updateRelationship`

### 4. Gap analysis (Phase 2)

- **GapAnalyzer** (`lib/chronicle/dual/intelligence/gap/gap_analyzer.dart`)
  - `analyze(query, userChronicleResults, lumaraIntelligence)` → `GapAnalysisResult`
  - Uses `RequiredKnowledgeExtractor` and `CurrentKnowledgeAssessor` (read-only on both chronicles)
- **GapClassifier** (`lib/chronicle/dual/intelligence/gap/gap_classifier.dart`)
  - `classify(gaps, userId)` → `ClassifiedGaps` (searchable / clarification / inferrable)

### 5. Interrupt and clarification (Phase 4)

- **InterruptDecisionEngine** (`lib/chronicle/dual/intelligence/interrupt/interrupt_decision_engine.dart`)
  - `shouldInterrupt(context, classifiedGaps)` → `InterruptDecision` (question + gapId when interrupting)
  - **Modality-aware:** Pass `AgenticContext(modality: AgenticModality.reflect | .chat | .voice)`. Reflect/voice: more permissive (deepening); chat: standard (avoid venting, low readiness).
  - **AgenticModality** and **AgenticContext** defined in same file.
- **ClarificationProcessor** (`lib/chronicle/dual/intelligence/interrupt/clarification_processor.dart`)
  - `processClarification(userId, originalQuery, clarifyingQuestion, userResponse, gapId)`
  - Writes **only** to LUMARA Chronicle (gap-fill event, inferences, gap status)
  - Calls `PromotionService.offerPromotion` when promotable; **does not** write to User Chronicle

### 6. Promotion (Phase 5)

- **PromotionService** (`lib/chronicle/dual/services/promotion_service.dart`)
  - `offerPromotion(userId, gapFillEvent)` – stores offer, invokes `onPromotionOffered` callback; **does not** add to User Chronicle
  - `approvePromotion(userId, gapFillEventId)` – **only** path that adds an annotation to User Chronicle (with `userApproved: true`, `approvedAt`)
  - `dismissPromotion(userId, gapFillEventId)` – clears offer; timeline unchanged
  - **PromotionOfferStore** – in-memory pending offers (replaceable with NotificationService/persistence)

### 7. Agentic loop (Phase 7)

- **AgenticLoopOrchestrator** (`lib/chronicle/dual/intelligence/agentic_loop_orchestrator.dart`)
  - `execute(userId, query, context)` – queries User + LUMARA chronicles (read-only), runs gap analysis and classification, may return `interrupt` (question + gapId) or `response` (synthesized content)
  - `continueAfterInterrupt(userId, originalContext, clarifyingQuestion, userResponse, gapId)` – calls `ClarificationProcessor.processClarification`, then synthesizes response; promotion is offered via service, not written to User Chronicle
  - All writes go to LUMARA Chronicle only (gaps updated, gap-fill events); User Chronicle is never modified inside the loop

---

## Not implemented (optional / future)

- **Phase 3 – AdaptiveSearchExecutor:** Multi-layer adaptive search (Layer 1–3) can be added later; loop currently uses only Layer 0 query.
- **Phase 6 – InferenceEditor + CascadeEngine:** User correct/refine/reject of inferences with cascade updates; LUMARA repo already has `updateCausalChain`, `updatePattern`, `updateRelationship` for use by that layer.
- **PromotionNotification UI (implemented):** Settings → CHRONICLE → **Timeline & Learning (Dual Chronicle)** shows pending offers ( "Add to Timeline" / "Dismiss".
- **LumaraService** facade that wraps phase detection, seeking classification, and `AgenticLoopOrchestrator` for chat can be added in the existing LUMARA/chat layer.

---

## Testing

- **Sacred separation tests** (`test/chronicle/dual/sacred_separation_test.dart`):
  - System cannot write non-user-authored entries to User Chronicle
  - Annotations require explicit user approval
  - User-authored entry and user-approved annotation are accepted
  - Gap-fill events are recorded in LUMARA Chronicle only (User Chronicle unchanged after clarification)
  - Promotion creates annotation only on approval
  - Dismissing promotion leaves timeline unchanged
  - User can delete annotation without affecting LUMARA Chronicle

Run:

```bash
flutter test test/chronicle/dual/sacred_separation_test.dart
```

---

## Integration notes

1. **Existing Layer 0:** Current `Layer0Repository` (Hive) and raw journal entries are separate from the dual-chronicle **User Chronicle**. To treat existing journal entries as User entries, either:
   - Bridge: when reading for the agentic loop, merge `Layer0Repository` results with `UserChronicleRepository.queryLayer0`, or
   - Migrate: copy existing entries into `UserChronicleRepository` as `UserEntry` with `authoredBy: 'user'`.

2. **Promotion UI:** Subscribe to `PromotionService.onPromotionOffered` or poll `getPendingOffers(userId)` and show a card with "Add to Timeline" (call `approvePromotion`) and "Dismiss" (call `dismissPromotion`).

3. **Storage paths:** Under app documents: `user-data/chronicle/{userId}/layer0/entries|annotations`, `lumara-data/chronicle/{userId}/gap-fills|gaps|inferences/...`. Use `ChronicleStorage(testBaseDirectory: dir)` in tests to avoid touching real data.

---

## Checklist (from spec)

- [x] User Chronicle has no automatic writes
- [x] No synthetic entry type (rejected via `authoredBy != 'user'`)
- [x] UserChronicleRepository throws on violations
- [x] Annotations require explicit user approval
- [x] Gap-fill events stored in LUMARA Chronicle only
- [x] Promotion offers created; approval creates annotation; dismiss leaves timeline unchanged
- [x] User can delete annotations
- [x] Provenance links (gapFillEventId, userApproved, approvedAt)
- [x] Sacred separation tests passing

You now have a working dual-chronicle core: sacred User Chronicle and LUMARA learning space with promotion as the only path from learning to timeline. See `DOCS/LUMARA_DUAL_CHRONICLE_GUIDE.md` for the consolidated guide.
