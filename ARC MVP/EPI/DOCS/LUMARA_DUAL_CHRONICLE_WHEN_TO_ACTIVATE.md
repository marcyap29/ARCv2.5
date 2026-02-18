# LUMARA Dual-Chronicle Architecture - When to Activate (FINAL CORRECTED)

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

**Example user reflection:**
```
"I'm frustrated with work again. This is the third time this month. It always seems to happen after meetings with Sarah. I think it's because I don't feel heard when I bring up ideas."
```

**Gap analysis can find:** Pattern (work frustration, recurring), causal chain (meetings with Sarah → not feeling heard → frustration), relationship (Sarah, negative pattern), trigger (bringing up ideas). With the loop, LUMARA can learn and optionally interrupt with a deepening question (e.g. what specifically makes you feel unheard?). Without the loop, the entry is stored but the system doesn't actively learn. Reflections are the highest-priority activation point; chat and voice also activate so learning is consistent across modalities.

---

## Integration Points (Dart/Flutter)

**Reflect:** When the user saves/completes a journal/reflection entry, after saving to User Chronicle, call `AgenticLoopOrchestrator.execute(userId, reflectionContent, context)` with `modality: 'reflect'`. On interrupt, offer a “deepening opportunity”; on user reply, call `continueAfterInterrupt(...)`.

**Chat:** When the user sends a LUMARA chat message, call `execute(userId, message, context)` with `modality: 'chat'`. On interrupt show clarifying question; on reply call `continueAfterInterrupt(...)`.

**Voice:** When the user confirms/edits a voice transcription and it is saved as an entry, call `execute(userId, transcription, context)` with `modality: 'voice'`. Same interrupt/continue pattern as reflect.

**Where to wire (EPI):** Reflect handler (journal save/completion), chat message handler (e.g. LumaraAssistantCubit or service that sends user messages), and voice handler (after transcription confirmed). Do **not** run the loop for VEIL, phase detection, settings, UI navigation, or export/import.

---

## Core Separation Rule

**User's Chronicle**
- Contains ONLY: User-authored entries + User-approved annotations
- System NEVER writes here without explicit user approval

**LUMARA's Chronicle**
- Contains: Inferences, gaps, gap-fill events, provenance
- System writes here freely during learning
- User can promote valuable insights to timeline (optional)

---

## WHEN Questions Answered

### Q: When does the agentic loop run?
**A:** On every creation of biographical content: reflection save, chat message, voice entry (after confirmation).

### Q: When does it NOT run?
**A:** Background processing (VEIL, phase detection), settings changes, UI navigation, export/import operations.

### Q: When do I interrupt the user?
**A:** Modality-aware. In **reflect/voice**: more permissive (deepening opportunity). In **chat**: standard criteria (e.g. not when venting, not in Recovery with low readiness, value above threshold). See full guide for InterruptDecisionEngine logic.

### Q: When does User Chronicle get modified?
**A:** ONLY when: user creates an entry (chat/reflect/voice), user approves a promotion (“Add to Timeline”), user edits/deletes entry or annotation.

### Q: When does LUMARA Chronicle get modified?
**A:** During every agentic loop execution (Step 6) and when clarifications are processed.

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
Steps 1–7 (query, consult, analyze, classify, fill, update LUMARA, synthesize)
       ↓
[If interrupt] → Show question (deepening or clarifying by modality)
       ↓
[User responds] → continueAfterInterrupt() → resume Steps 6–7
       ↓
Return response / acknowledgment
```

---

## Documentation Summary

**WHERE to activate:** Reflect handler (on save), Chat message handler, Voice handler (on transcription confirmed).

**WHEN to activate:** Every time the user creates biographical content in any modality (reflect, chat, voice).

**WHAT it does:** 7-step loop; modality-aware interrupt (more permissive in reflect/voice).

**WHERE it writes:** LUMARA Chronicle only (never User Chronicle automatically).

**Full implementation guide:** `DOCS/LUMARA_DUAL_CHRONICLE_COMPLETE_GUIDE.md`.  
**Code:** `lib/chronicle/dual/intelligence/agentic_loop_orchestrator.dart`.  
**Modality:** Pass `AgenticContext(modality: AgenticModality.reflect | .chat | .voice, ...)` so interrupt logic is modality-aware (reflect/voice more permissive, chat standard).
