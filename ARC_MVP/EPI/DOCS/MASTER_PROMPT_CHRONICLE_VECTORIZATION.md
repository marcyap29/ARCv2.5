# Master Prompt, CHRONICLE, and Vectorization: Detailed View

**Purpose:** Single reference for how the LUMARA master prompt is built, what it contains, and how it integrates with CHRONICLE (temporal aggregations) and vectorization (pattern index).  
**Audience:** Developers, Claude instances, and implementers working on LUMARA, CHRONICLE, or prompt orchestration.  
**Last updated:** February 2026

---

## 1. Overview

LUMARA’s behavior is driven by a **unified master prompt** that is built once per request. That prompt is the single source of truth for personality, safety, tone, and response boundaries. **CHRONICLE** supplies temporal and pattern context (aggregations and, when used, vector-backed pattern index). The **master prompt** injects that context in a mode-dependent way and tells the model how to use it.

- **Master prompt:** `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` — identity, control state, rules, and placeholders for context.
- **Control state:** Built by `LumaraControlStateBuilder`; JSON injected into the prompt; not modified by the model.
- **CHRONICLE:** Hierarchical memory (Layer 0 → 1 → 2 → 3); supplies aggregation text and optional pattern-index text.
- **Vectorization:** On-device embeddings and cross-temporal pattern index; used for “pattern” queries and merged into CHRONICLE context when applicable.

---

## 2. What Is In the Master Prompt

The master prompt is a long string built by `LumaraMasterPrompt.getMasterPrompt()` (or, for split payloads, `getMasterPromptSystemOnly()` plus `buildMasterUserMessage()`). It contains the following in order.

### 2.1 Identity and control state block

- **Identity:** “You are LUMARA, the user’s Evolving Personal Intelligence (EPI).”
- **Control state:** A single block that the model must treat as authoritative and not modify:

```text
[LUMARA_CONTROL_STATE]
<control state JSON>
[/LUMARA_CONTROL_STATE]
```

The control state JSON is produced by `LumaraControlStateBuilder.buildControlState()` and includes (among others):

| Section       | Source / meaning |
|---------------|-------------------|
| `atlas`       | Phase, readinessScore, sentinelAlert (ATLAS + Safety Sentinel) |
| `veil`        | sophisticationLevel, timeOfDay, usagePattern, health (VEIL + rhythm) |
| `favorites`  | favoritesProfile, count (Top 40 reinforced signature) |
| `prism`       | prism_activity (multimodal / cognitive context) |
| `therapy`     | therapyMode (ECHO + SAGE) |
| `engagement`  | mode (reflect/explore/integrate), synthesis_allowed, response_length, etc. |
| `responseMode`| targetWords, maxWords, min/maxPatternExamples, useStructuredFormat, noWordLimit, etc. |
| `responseLength` | auto, max_sentences, sentences_per_paragraph (when not auto) |
| `memory`      | similarityThreshold, lookbackYears, maxMatches, crossModalEnabled, therapeuticDepth |
| `webAccess`   | enabled (whether web search is available) |

For journal/reflection, a **simplified** control state is often used (persona, responseMode, engagement, sentinel, responseLength); the full builder is used when building from all subsystems (e.g. orchestrator path).

### 2.2 Current context and recent entries

- **&lt;current_context&gt;**  
  Current date/time (ISO and human-readable).

- **&lt;recent_entries&gt;**  
  List of recent journal entries: date, relative date, title, entry_id. Used for temporal grounding (“yesterday”, “last week”) and citation.

### 2.3 Historical / CHRONICLE context (mode-dependent)

One of three forms, depending on **LumaraPromptMode**:

- **chronicleBacked:** Only CHRONICLE aggregation text (and optional pattern index). Wrapped with instructions to cite layer and period (e.g. “monthly aggregation for January 2025”).
- **rawBacked:** Only raw historical context in `<historical_context>` (past journal entries / base context). Instructions to use raw entries for patterns and to cite dates/IDs.
- **hybrid:** Both `<chronicle_context>` (aggregations) and `<supporting_entries>` (supporting raw entries). Used when drill-down is active.

So “what is in the master prompt” for context is either:
- recent_entries + chronicle block, or  
- recent_entries + historical_context block, or  
- recent_entries + chronicle block + supporting_entries block.

Implementation: `_buildContextSection(mode, baseContext, chronicleContext, chronicleLayers, lumaraChronicleContext)` in `lumara_master_prompt.dart` (lines ~3702–3772).

### 2.4 LUMARA CHRONICLE (lumaraChronicleContext)

A separate, optional block **LUMARA CHRONICLE** is supplied via **lumaraChronicleContext**. It contains query-relevant patterns, causal chains, relationships, and user-approved insights. Unlike the mode-dependent chronicle/raw blocks above, **lumaraChronicleContext is appended in all modes** (chronicleBacked, rawBacked, hybrid) when non-empty, so the model can use both CHRONICLE (temporal aggregations) and LUMARA CHRONICLE (inference patterns) together.

- **Source:** When available, **UniversalPromptOptimizer.getChronicleContextForMasterPrompt(userId, userText, useCase, maxChars: 2000)** builds this string (use-case-sized, query-relevant). Fallback: **\_buildLumaraChronicleContext(userId)** in `enhanced_lumara_api.dart` so behavior is unchanged if the optimizer is unavailable.
- **Use cases:** Voice → `PromptUseCase.userVoice` (smaller slice); reflection/chat → `PromptUseCase.userReflect`.
- **Placement:** In `_buildContextSection`, when `lumaraChronicleContext` is non-empty it is appended as `<lumara_chronicle>...</lumara_chronicle>` with instructions to use both CHRONICLE and LUMARA CHRONICLE when reasoning.

See **UNIVERSAL_PROMPT_OPTIMIZATION.md** for the optimizer layer, provider-agnostic strategy, and integration checklist.

### 2.5 Temporal and safety rules

- **CRITICAL: TEMPORAL CONTEXT USAGE** — Use current date for “yesterday”/“last week”; never date the “current entry” in the past; current entry is PRIMARY FOCUS, written TODAY.
- **WORD LIMIT ENFORCEMENT** — Respect `responseMode.maxWords` (or no limit if `noWordLimit` / `max_sentences == -1`).
- **WEB ACCESS** — If `webAccess.enabled` is true, model may use Google Search; same rules in chat and journal.
- **LUMARA CONVERSATIONAL INTELLIGENCE** — Phase, phase stability, emotional intensity, recent patterns, interaction mode, engagement mode.
- **&lt;intellectual_honesty&gt;** — When to push back (factual contradiction with journal, pattern denial, recent-entry contradiction) vs when not (reframing, evolving perspective, ambiguous patterns); “Both/And” technique; cite entries with dates.

### 2.6 Layered behavior (crisis, phase, tone, etc.)

- **LAYER 1:** Crisis detection and hard safety (crisis protocol, 988, Crisis Text Line, 911; do not continue conversation after).
- **LAYER 2:** Phase + intensity calibration (tone matrix by phase × emotional intensity).
- Further layers: persona-specific instructions, engagement discipline, response structure, banned phrases, pattern-recognition rules, etc.

### 2.7 Current task block

- **CURRENT TASK**  
  Optional “HISTORICAL CONTEXT” (same as baseContext when present), then **CURRENT ENTRY TO RESPOND TO (WRITTEN TODAY - &lt;date&gt;)** with the actual entry text.  
  Optional **MODE-SPECIFIC INSTRUCTION** (conversation mode, regenerate, tone, pushback/truth_check, etc.).  
  Ends with “RESPOND NOW” and a short reminder to follow all constraints.

So in one sentence: the master prompt = identity + control state + current/recent context + **context section (chronicle and/or raw)** + temporal/safety/behavior rules + current task (entry + optional instructions).

---

## 3. How CHRONICLE Feeds Into the Master Prompt

CHRONICLE provides **temporal aggregations** (Layer 1 monthly, Layer 2 yearly, Layer 3 multi-year) and optionally **pattern-index** text (vectorization). Both end up in the same “context” that the master prompt injects.

### 3.1 Two entry points for CHRONICLE context

1. **Orchestrator path** (`FeatureFlags.useOrchestrator` true, CHRONICLE initialized, userId set)  
   - `LumaraOrchestrator.execute(userText, userId)` runs.  
   - CHRONICLE subsystem returns a result whose **aggregations** string may include:
     - Pattern index block: `<chronicle_pattern_index>...</chronicle_pattern_index>` (from vectorization).
     - Aggregation context from `ChronicleContextBuilder.buildContext(...)` (from query plan layers).  
   - `enhanced_lumara_api` reads `ctxMap['CHRONICLE']` and optional `chronData['layers']`.  
   - If non-empty, `chronicleContext` and `chronicleLayerNames` are set and `promptMode = LumaraPromptMode.chronicleBacked` (unless hybrid is needed).

2. **Legacy path** (no orchestrator, but CHRONICLE initialized)  
   - `ChronicleQueryRouter.route(query, userContext, mode, isVoice)` produces a `QueryPlan`.  
   - If `queryPlan.usesChronicle` and `_contextBuilder != null`:
     - **Voice / skipHeavyProcessing:** Only mini-context is built (`buildMiniContext(userId, layer, period)`), stored in `chronicleMiniContext`; no full `chronicleContext` in the main prompt (mini is used in voice user message).
     - **Text:** `_contextBuilder.buildContext(userId, queryPlan)` returns the aggregation text → `chronicleContext`.  
   - If that string is non-empty, `promptMode` is set to `chronicleBacked` or `hybrid` (if `queryPlan.drillDown`), and `chronicleLayerNames` from `queryPlan.layers`.  
   - If CHRONICLE context is null/empty, fallback is `promptMode = LumaraPromptMode.rawBacked`.

So “chronicle” in the master prompt is literally the string(s) from:
- aggregation context (formatted by `ChronicleContextBuilder`), and  
- when present, pattern index text (from `PatternQueryRouter`), merged in front of aggregation context in the orchestrator/CHRONICLE subsystem.

### 3.2 Where that string is placed in the prompt

- **Single-payload (e.g. chat):** `getMasterPrompt(controlStateJson, entryText: ..., baseContext: ..., chronicleContext: ..., chronicleLayers: ..., mode: ...)` builds the full prompt; `_buildContextSection` inserts the chronicle (and/or raw) block in the middle of the prompt.
- **Split-payload (journal reflection):**  
  - System: `getMasterPromptSystemOnly(controlStateJson, currentDate)` — no entry, no context; placeholder says “See user message below for recent entries, historical context, current entry.”  
  - User: `buildMasterUserMessage(entryText, recentEntries, baseContext, chronicleContext, chronicleLayers, mode, currentDate, modeSpecificInstructions)` — builds `<recent_entries>`, then the same `_buildContextSection(...)` (so chronicle and/or raw), then “CURRENT TASK” and the current entry + mode-specific instructions.

So CHRONICLE’s role is to supply the **chronicleContext** (and optionally **chronicleLayers**) that this shared `_buildContextSection` turns into the block the model sees (e.g. `<chronicle_context>...</chronicle_context>` or the chronicle-only / hybrid variant).

### 3.3 ChronicleContextBuilder (aggregation → prompt text)

- **Input:** userId, `QueryPlan` (layers, speedTarget, drillDown, dateFilter).  
- **Output:** One string for prompt injection.  
- **Behavior:**
  - **instant:** `buildMiniContext(userId, layer, period)` — very short (e.g. 50–100 tokens): themes, phase, key events.
  - **fast:** Single-layer compressed (~2–5k tokens): one layer/period, compressed content, “Drill-down available” if needed.
  - **normal/deep:** `_buildMultiLayerContext` → `_formatAggregationsForPrompt`: `<chronicle_context>`, intro line, per-aggregation “## Layer: period” + content, “Source layers: …”, `</chronicle_context>`.

So the “chronicle” part of the master prompt is this formatted aggregation text (and, when applicable, the pattern index block added upstream).

---

## 4. How Vectorization Fits In (Pattern Index)

Vectorization is used for **semantic pattern matching** across time (e.g. “when did I feel like this before?”, “how does this theme show up over the years?”). It does not replace the master prompt; it adds another kind of context that is merged into the same CHRONICLE slot the master prompt consumes.

### 4.1 Components

- **EmbeddingService** (e.g. `lib/chronicle/embeddings/local_embedding_service.dart`): On-device embeddings (e.g. TFLite Universal Sentence Encoder).  
- **ChronicleIndexBuilder** (`lib/chronicle/index/chronicle_index_builder.dart`):  
  - After monthly synthesis, extracts dominant themes from the synthesis, embeds them, matches to existing theme clusters (or creates new ones).  
  - Maintains a cross-temporal index (theme clusters, appearances, pattern insights).  
- **ThreeStagePatternMatcher:** Exact → cosine (embedding) → fuzzy.  
- **PatternQueryRouter** (`lib/chronicle/query/pattern_query_router.dart`):  
  - Classifies intent (pattern vs arc vs resolution vs other).  
  - For pattern-like queries: embed query theme → match against index → build a **pattern response** string (recurrence type, trigger, phase correlation, duration, resolution, confidence, theme variations, prediction).  
  - Returns `QueryResponse.pattern(..., response: response)` or `needsStandardChronicle`.

### 4.2 Where vectorization meets the prompt

- **ChronicleSubsystem** (orchestrator path):  
  - For intents such as `patternAnalysis`, `developmentalArc`, `historicalParallel`, it optionally calls `_patternQueryRouter.routeQuery(userId, query)`.  
  - If the result is pattern recognition with non-empty `response`, that string is stored as `patternContext`.  
  - Then:
    - If the query plan does **not** use CHRONICLE layers, the subsystem returns `aggregations: '<chronicle_pattern_index>\n' + patternContext + '\n</chronicle_pattern_index>'`.  
    - If the plan **does** use CHRONICLE, `contextString` is built with `_contextBuilder.buildContext(...)`; then `fullContext = '<chronicle_pattern_index>\n' + patternContext + '\n</chronicle_pattern_index>\n\n' + contextString`.  
  - So the same “CHRONICLE” result that the API puts in `chronicleContext` can contain both pattern-index and aggregation text.

- **Direct path (no orchestrator):**  
  - In `enhanced_lumara_api`, the pattern query router is only used when the orchestrator is used (CHRONICLE subsystem runs it). So in legacy path, vectorization is not currently applied in the same way; context is aggregation-only from `_contextBuilder.buildContext`.

So **vectorization** = on-device embeddings + index + PatternQueryRouter. Its **output** is a text block that is either the only CHRONICLE content (pattern-only) or is prepended to aggregation content. That combined string is what the master prompt sees as **chronicleContext** (and possibly under a `<chronicle_pattern_index>` wrapper in the XML).

---

## 5. End-to-End Flow (Prompt + CHRONICLE + Vectorization)

1. **Request** (e.g. journal reflection) with `userText`, `userId`, options, `skipHeavyProcessing` (voice), etc.  
2. **Control state**  
   - Built (full or simplified) via `LumaraControlStateBuilder.buildControlState(userId, prismActivity, chronoContext, ...)` or equivalent.  
3. **CHRONICLE / context**  
   - **Orchestrator:** Execute orchestrator → CHRONICLE subsystem runs query router + optional pattern router → context builder (if plan uses layers) → merged string (pattern + aggregations) → `chronicleContext` (+ `chronicleLayerNames`), `promptMode` set.  
   - **Legacy:** Query router → plan → if usesChronicle, context builder → `chronicleContext`; else raw; voice may only get mini-context.  
4. **Base context (raw)**  
   - If mode is rawBacked or hybrid, build `baseContext` from recent journal entries (and optionally drill-down supporting entries).  
5. **LUMARA CHRONICLE (lumaraChronicleContext)**  
   - **Enhanced LUMARA API:** For reflection/voice, call `UniversalPromptOptimizer.getChronicleContextForMasterPrompt(userId, request.userText, useCase, maxChars: 2000)`; on null/empty or on exception, fall back to `_buildLumaraChronicleContext(userId)`. This string is passed as `lumaraChronicleContext` into the master prompt and appended in all modes (see §2.4).  
6. **Master prompt build**  
   - **Split payload (typical for reflection):**  
     - System: `getMasterPromptSystemOnly(controlStateJson, now)`.  
     - User: `buildMasterUserMessage(entryText, recentEntries, baseContext, chronicleContext, chronicleLayers, lumaraChronicleContext, mode, currentDate, modeSpecificInstructions)`.  
   - Inside that, `_buildContextSection(mode, baseContext, chronicleContext, chronicleLayers, lumaraChronicleContext)` injects the chronicle/raw block and appends the LUMARA CHRONICLE block when present.  
7. **Optional injections**  
   - Mode-specific instructions (conversation mode, regenerate, tone).  
   - ATLAS/AURORA context (orchestrator).  
   - truth_check block (ChronicleContradictionChecker) when user claim contradicts journal.  
8. **API call**  
   - System prompt + user message sent to LLM (e.g. Groq/Gemini).  
   - Model sees control state, recent entries, **chronicle and/or raw context**, current entry, and all behavioral rules in one coherent prompt.

---

## 6. Code Flow: Building the Prompt with CHRONICLE

### 6.1 Control state (used by master prompt)

```dart
// lumara_control_state_builder.dart
final controlStateJson = await LumaraControlStateBuilder.buildControlState(
  userId: userId,
  prismActivity: prismActivity,
  chronoContext: chronoContext,
  userMessage: request.userText,
  maxWords: responseMode.maxWords,
  userIntent: detectedUserIntent,
  isVoiceMode: skipHeavyProcessing,
  isWrittenConversation: !skipHeavyProcessing && (reflection/chat),
);
// Result: JSON string with atlas, veil, favorites, prism, therapy, engagement, responseMode, memory, webAccess, etc.
```

### 6.2 CHRONICLE context (orchestrator path)

```dart
// enhanced_lumara_api.dart (orchestrator)
final orchResult = await _orchestrator!.execute(request.userText, userId: userId, entryId: entryId);
chronicleContext = orchResult.toContextMap()['CHRONICLE'];  // includes <chronicle_pattern_index> if from vectorizer
chronicleLayerNames = orchResult.getSubsystemData('CHRONICLE')?['layers'];
if (chronicleContext != null && chronicleContext.isNotEmpty) {
  promptMode = LumaraPromptMode.chronicleBacked;
}
```

### 6.3 CHRONICLE context (legacy path: query router + context builder)

```dart
// enhanced_lumara_api.dart (legacy)
queryPlan = await _queryRouter!.route(
  query: request.userText,
  userContext: { 'userId': userId, 'currentPhase': request.phaseHint?.name },
  mode: engagementMode,
  isVoice: skipHeavyProcessing,
);
if (queryPlan.usesChronicle && _contextBuilder != null) {
  chronicleContext = await _contextBuilder!.buildContext(userId: userId, queryPlan: queryPlan);
  if (chronicleContext != null && chronicleContext.isNotEmpty) {
    promptMode = queryPlan.drillDown ? LumaraPromptMode.hybrid : LumaraPromptMode.chronicleBacked;
    chronicleLayerNames = queryPlan.layers.map((l) => l.displayName).toList();
  }
}
```

### 6.4 Pattern index (vectorization) merged in CHRONICLE subsystem

```dart
// chronicle_subsystem.dart
if (_patternQueryRouter != null && intent is patternAnalysis|developmentalArc|historicalParallel) {
  final patternResponse = await _patternQueryRouter!.routeQuery(userId: intent.userId!, query: intent.rawQuery);
  if (patternResponse.type == QueryType.patternRecognition && patternResponse.response.isNotEmpty) {
    patternContext = patternResponse.response;
  }
}
// ... build contextString from _contextBuilder.buildContext(...) ...
var fullContext = contextString ?? '';
if (patternContext != null && patternContext.isNotEmpty) {
  fullContext = '<chronicle_pattern_index>\n$patternContext\n</chronicle_pattern_index>\n\n$fullContext';
}
return SubsystemResult(data: { 'aggregations': fullContext, 'layers': layerNames, ... });
```

### 6.5 Master prompt (split payload: system + user)

```dart
// enhanced_lumara_api.dart
systemPrompt = LumaraMasterPrompt.getMasterPromptSystemOnly(simplifiedControlStateJson, now);
userPromptForApi = LumaraMasterPrompt.buildMasterUserMessage(
  entryText: request.userText,
  recentEntries: recentEntries,
  baseContext: baseContext,
  chronicleContext: chronicleContext,   // CHRONICLE aggregation (+ optional pattern index) text
  chronicleLayers: chronicleLayerNames,
  mode: promptMode,                    // chronicleBacked | rawBacked | hybrid
  currentDate: now,
  modeSpecificInstructions: modeSpecificInstructions,
);
// Then: call LLM with systemPrompt + userPromptForApi
```

### 6.6 Context section inside the prompt (chronicle vs raw)

```dart
// lumara_master_prompt.dart - _buildContextSection
switch (mode) {
  case LumaraPromptMode.chronicleBacked:
    return '$chronicleContext\n\n**CHRONICLE Mode:** Using pre-synthesized temporal aggregations from ${chronicleLayers?.join(', ')}...';
  case LumaraPromptMode.rawBacked:
    return '<historical_context>\n$baseContext\n</historical_context>\n\n**Raw Entry Mode:** ...';
  case LumaraPromptMode.hybrid:
    return '<chronicle_context>\n$chronicleContext\n</chronicle_context>\n\n<supporting_entries>\n$baseContext\n</supporting_entries>\n\n**Hybrid Mode:** ...';
}
```

---

## 7. Code References (Key Files and Symbols)

| Concern | File | Symbol / behavior |
|--------|------|-------------------|
| Master prompt build | `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` | `getMasterPrompt`, `getMasterPromptSystemOnly`, `buildMasterUserMessage`, `_buildContextSection` |
| Control state | `lib/arc/chat/services/lumara_control_state_builder.dart` | `buildControlState` |
| CHRONICLE context string | `lib/chronicle/query/context_builder.dart` | `ChronicleContextBuilder.buildContext`, `buildMiniContext`, `_formatAggregationsForPrompt` |
| Query routing (layers, speed) | `lib/chronicle/query/query_router.dart` | `ChronicleQueryRouter.route`, `QueryPlan` |
| Pattern (vector) query | `lib/chronicle/query/pattern_query_router.dart` | `PatternQueryRouter.routeQuery` |
| Index (vectorization) | `lib/chronicle/index/chronicle_index_builder.dart` | `ChronicleIndexBuilder`, `updateIndexAfterSynthesis` |
| Embeddings | `lib/chronicle/embeddings/` | `EmbeddingService`, local embedding service |
| Merging pattern + aggregations | `lib/lumara/subsystems/chronicle_subsystem.dart` | `ChronicleSubsystem.query` (patternContext + fullContext) |
| Using context in API | `lib/arc/chat/services/enhanced_lumara_api.dart` | CHRONICLE/orchestrator block (~662–805), baseContext (~825–868), lumaraChronicleContext (~992–1019, optimizer + fallback), prompt build (~1097–1172) |
| LUMARA CHRONICLE (optimizer) | `lib/arc/chat/prompt_optimization/universal_prompt_optimizer.dart` | `getChronicleContextForMasterPrompt` |
| Chat (full prompt) | `lib/arc/chat/bloc/lumara_assistant_cubit.dart` | `_buildSystemPrompt` → `LumaraMasterPrompt.getMasterPrompt` |

---

## 8. Summary

- **Master prompt** = identity + **control state JSON** + current/recent context + **context section** (chronicle and/or raw, plus optional **LUMARA CHRONICLE**) + safety/tone/behavior rules + current task (entry + optional instructions).  
- **CHRONICLE** = temporal aggregations (Layer 1/2/3) formatted by `ChronicleContextBuilder`; that string (and optional pattern block) is **chronicleContext** fed into the master prompt.  
- **LUMARA CHRONICLE** = **lumaraChronicleContext**: query-relevant patterns, causal chains, relationships, approved insights. Built by `UniversalPromptOptimizer.getChronicleContextForMasterPrompt` (or legacy `_buildLumaraChronicleContext`); appended in **all** modes via `_buildContextSection`. See **UNIVERSAL_PROMPT_OPTIMIZATION.md**.  
- **Vectorization** = on-device embeddings + cross-temporal pattern index + `PatternQueryRouter`; its output is a text block that is merged with aggregation context in the CHRONICLE subsystem and then passed as part of **chronicleContext** (or as the only CHRONICLE content for pattern-only plans).  
- **Modes** (chronicleBacked / rawBacked / hybrid) decide whether the prompt sees only CHRONICLE, only raw, or both; **lumaraChronicleContext** is appended in all modes when present.

This document should be read together with **UNIVERSAL_PROMPT_OPTIMIZATION.md** (optimizer and LUMARA CHRONICLE integration), `CHRONICLE_PROMPT_REFERENCE.md`, `CHRONICLE_CONTEXT_FOR_CLAUDE.md` (if present), and `PROMPT_REFERENCES.md` §16 (Master Prompt Architecture) for full detail on CHRONICLE layers, token targets, and prompt structure.
