# LUMARA Dual-Chronicle Architecture – Complete Implementation Guide

**CRITICAL ARCHITECTURAL PRINCIPLE: User's Chronicle is SACRED. System NEVER writes to it automatically.**

---

## WHEN TO ACTIVATE THE AGENTIC LOOP

**TRIGGER: Every time the user creates biographical content in ANY modality**

The agentic loop is how LUMARA learns. It activates whenever the user generates biographical signal, regardless of modality.

### Activation by Modality

**REFLECT (Highest Priority)**
- Activate on every reflection save/completion
- Richest biographical signal
- User is already in processing mode (interrupts welcome)
- Most explicit causal chains and pattern statements
- Best source for high-confidence inferences

**CHAT**
- Activate on every user message
- User seeking contextual response
- Gap analysis informs answer quality
- Patterns from reflections inform chat responses

**VOICE**
- Activate after transcription confirmed/edited
- Stream-of-consciousness richness
- Similar to reflect in depth
- Captures unplanned insights

**DO NOT ACTIVATE:**
- Background processing (VEIL, phase detection)
- Settings changes
- UI navigation
- Export/import operations

---

## Why Reflections Are Primary

**User reflection:**
```
"I'm frustrated with work again. This is the third time this month.
It always seems to happen after meetings with Sarah. I think it's
because I don't feel heard when I bring up ideas."
```

**Gap analysis finds:**
- Pattern: Work frustration (recurring, monthly frequency)
- Causal chain: Meetings with Sarah → not feeling heard → frustration
- Relationship: Sarah (negative interaction pattern)
- Trigger: Bringing up ideas

**Without loop:** Entry stored but system doesn't actively learn  
**With loop:** Inferences created, might interrupt: "What specifically about those meetings makes you feel unheard? Is it that ideas are dismissed, or that they're not acknowledged?"

**User value:** Deeper self-reflection, pattern recognition aided

---

## Architecture Overview

### Activation Points (EPI / Dart)

| Modality | When to activate | Wire in |
|----------|------------------|--------|
| **Reflect** | Every reflection save/completion | Journal/reflect save handler (after saving entry to User Chronicle) |
| **Chat** | Every user chat message | LUMARA chat message handler (e.g. LumaraAssistantCubit or API path) |
| **Voice** | After transcription confirmed/edited | Voice handler when user confirms/saves the transcription as entry |

Call `AgenticLoopOrchestrator.execute(userId, content, context)` with `context.modality` set to `AgenticModality.reflect`, `AgenticModality.chat`, or `AgenticModality.voice`. On interrupt, show question (deepening in reflect/voice, clarifying in chat); on user reply call `continueAfterInterrupt(...)`.

### File Structure (this repo)

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

Modality handlers (Reflect, Chat, Voice) live in the app layer that handles each modality; they call the orchestrator and pass `AgenticContext(modality: AgenticModality.reflect | .chat | .voice, ...)`.

---

## Data Models

### User Chronicle (SACRED)

- **UserEntry:** User-authored only; `type`: chat | reflect | voice; `authoredBy: 'user'`.
- **UserAnnotation:** User-approved only; `provenance.userApproved: true`, `approvedAt`; source lumara_gap_fill | lumara_inference.
- System never writes to User Chronicle without explicit user action.

### LUMARA Chronicle (Learning Space)

- **Inferences:** Causal chains, patterns, relationships, values.
- **Gaps:** Identified gaps, uncertainties, pending questions.
- **GapFillEvent:** Trigger (originalContent, modality, identifiedGap), process, extractedSignal, updates, recordedAt, promotableToAnnotation, promotedToAnnotation.
- System writes here during the loop; promotions are offered, not auto-added.

(See `lib/chronicle/dual/models/chronicle_models.dart` for Dart types.)

---

## Interrupt Decision (Modality-Aware)

Implemented in `lib/chronicle/dual/intelligence/interrupt/interrupt_decision_engine.dart`:

- **Reflect:** More permissive (deepening opportunity). Interrupt if high-severity gap and readiness > 0.3. Questions framed as deepening.
- **Voice:** Similar to reflect; readiness threshold 0.35.
- **Chat:** Standard criteria. Do not interrupt when seekingType == 'Reflection' (venting) or in Recovery with readiness < 0.4. Interrupt value threshold 0.6. Questions framed as clarification for better answer.

---

## Implementation: Wiring the Loop

### Reflect handler (primary)

When the user saves/completes a journal or reflection entry:

1. Save the entry to User Chronicle (user-authored) if not already saved by existing journal flow.
2. Build `AgenticContext(modality: AgenticModality.reflect, currentPhase: ..., readinessScore: ..., seekingType: 'Reflection')`.
3. Call `AgenticLoopOrchestrator.execute(userId, reflectionContent, context)`.
4. If result is `interrupt`: show "deepening opportunity" with `result.question`; on user reply call `continueAfterInterrupt(userId, originalContext, result.question!, userResponse, result.gapId!)`.
5. If result is `response`: show acknowledgment / synthesis.

### Chat handler

When the user sends a LUMARA chat message:

1. Build `AgenticContext(modality: AgenticModality.chat, ...)` (include phase, readiness, seeking from classifier).
2. Call `execute(userId, message, context)`.
3. If interrupt: show clarifying question; on reply call `continueAfterInterrupt(...)`.
4. If response: show answer.

### Voice handler

When the user confirms/edits voice transcription and it is saved as an entry:

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

## Testing

- **Reflect activates loop:** From reflect save handler, call execute with reflection content; assert orchestrator executed with modality reflect.
- **Chat activates loop:** From chat handler, call execute with message; assert modality chat.
- **Voice activates loop:** From voice handler, call execute with transcription; assert modality voice.
- **Interrupt more permissive in reflect:** Same gaps and readiness; reflect context → interrupt true; chat context → interrupt false when readiness low or venting.

---

## Summary

**ACTIVATION POINTS:** Reflect handler (on save), Chat message handler, Voice handler (on transcription confirmed).

**THE LOOP:** 7 steps for all modalities; modality in `AgenticContext`; interrupt logic modality-aware.

**SACRED RULE:** User Chronicle only user-authored entries and user-approved annotations; LUMARA Chronicle updated by the loop; promotions offered, not auto-added.

**Code:** `lib/chronicle/dual/`; see `DOCS/LUMARA_DUAL_CHRONICLE_WHEN_TO_ACTIVATE.md` for when-to-activate summary and `DOCS/LUMARA_DUAL_CHRONICLE_IMPLEMENTATION.md` for implementation status.
