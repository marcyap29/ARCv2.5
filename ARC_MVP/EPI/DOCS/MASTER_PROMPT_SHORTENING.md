# Master Prompt Shortening: Two Modes

**Purpose:** How the master prompt is set up, and how to shorten it by having two primary modes: **(1) Perceptive Gemini with context** (default) and **(2) Detailed Analysis** (on demand).  
**Companion to:** [MASTER_PROMPT_CHRONICLE_VECTORIZATION.md](MASTER_PROMPT_CHRONICLE_VECTORIZATION.md), [LUMARA_Vision_Reposition.md](LUMARA_Vision_Reposition.md)

---

## Two primary modes

| Mode | Description |
|------|-------------|
| **1. Perceptive Gemini with context** | Default. Normal conversation; the AI is a perceptive friend who has the user's context (journal, history) when provided. Short prompt. |
| **2. Detailed Analysis** | On demand. Full temporal/phase-aware analysis, pattern surfacing, structured reflection — when the user explicitly asks for it. Uses the full (or expanded) master prompt. |

"Normal conversation" and "perceptive friend" are the same thing: one default mode (perceptive Gemini with context). Detailed Analysis is the second mode, triggered only when requested.

---

## 1. How the Master Prompt Is Set Up

### Entry point

- **File:** `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
- **Size:** ~3,775 lines; the prompt string is ~3,100+ lines (one large template in `getMasterPrompt()`).
- **Chat path:** `LumaraAssistantCubit._buildSystemPrompt()` calls `LumaraMasterPrompt.getMasterPrompt(...)` with control state, `entryText` = user message, optional `baseContext`, then appends `<response_style>` telling LUMARA to be conversational and not surface phase/entry counts.

### Build order (what gets concatenated)

1. **Identity + control state**  
   - "You are LUMARA, the user's Evolving Personal Intelligence (EPI)."  
   - `[LUMARA_CONTROL_STATE]` … JSON … `[/LUMARA_CONTROL_STATE]`  
   - USER PERSONALITY CONFIG / INFERRED PREFERENCES.

2. **Current context + recent entries**  
   - `<current_context>`, `<recent_entries>` (placeholders filled by `injectDateContext()` and callers).

3. **Context section**  
   - `_buildContextSection(...)` — chronicle and/or raw history, plus optional `<lumara_chronicle>`.

4. **Rules (the long middle)**  
   - Temporal context usage, word limit, web access.  
   - LUMARA conversational intelligence (phase, PRISM note, intellectual_honesty).  
   - **Layer 1:** Crisis detection & hard safety.  
   - **Layer 2:** Phase × emotional intensity tone matrix (Recovery/Transition/Discovery/Expansion/Consolidation/Breakthrough × high/med/low).  
   - **Layer 2.5:** Temporal self-awareness (calendar-time, quantified evolution, proactive pattern, privacy honesty, pattern surfacing, CHRONICLE integration, response structure, forbidden patterns, engagement-calibrated).  
   - **Layers 2.6–2.8:** Voice protocol, context retrieval triggers, mode switching.  
   - **Layers 3–5:** User overrides, core response philosophy, PRISM usage, engagement mode adaptation.  
   - Large persona/engagement/forbidden-phrase blocks.  
   - Sentence/word limit repetition.

5. **Constraints section**  
   - `_buildConstraintsSection(controlStateJson)` — word limit, pattern examples, content type, persona-specific instructions (companion/strategist/therapist/challenger).

6. **Current task**  
   - HISTORICAL CONTEXT (if any), CURRENT ENTRY TO RESPOND TO, MODE-SPECIFIC INSTRUCTION, "RESPOND NOW".

So: **one monolithic prompt** is built per request; chat uses the same prompt and then adds a short `<response_style>` to avoid phase/entry-count surfacing.

---

## 2. Can We Remove or Reduce It?

**Yes.** Defaulting to "normal conversation (Gemini) + perceptive friend with context" directly supports shortening:

- **Product alignment:** [LUMARA_Vision_Reposition.md](LUMARA_Vision_Reposition.md) already positions LUMARA as "lifetime personal AI" and "companion" with "full context when you want it"; phases are under the hood. A shorter prompt that leads with "perceptive friend who has context" matches that.
- **Chat already asks for less:** The cubit’s `<response_style>` says: conversational, no phase metadata, no entry counts, "Respond like a trusted friend." So for chat, most of the phase/temporal/pattern detail is already *contradicted* by the tail of the same prompt. A dedicated short prompt would be consistent instead of long prompt + override.
- **Token/latency:** Docs note the full master prompt is ~150k+ chars and is too large for voice (hence separate voice prompts). A shortened "chat default" prompt would reduce tokens and can speed up or stabilize Gemini calls.

So: **shortening is consistent with the reposition and would indeed shorten the master prompt** for the primary path (Mode 1: perceptive Gemini with context).

---

## 3. Detailed Analysis: User asks vs toggle

**Question:** Should the user **ask** for Detailed Analysis in natural language, or should there be a **toggle** to manually set it?

| Approach | Pros | Cons |
|---------|------|------|
| **User asks** (e.g. "Give me a detailed analysis of last month") | No extra UI; works in voice; feels natural; everyone can discover it by asking. | Model might mishear or misinterpret; no explicit "mode" in the UI; harder to show "you're in analysis mode." |
| **Toggle** (e.g. "Detailed analysis" switch or chip in chat) | Explicit, unambiguous; clear which mode is active; power users know where to find it; easy to log/audit. | Extra UI; some users may not discover it; one more thing to explain. |
| **Both** | Toggle for explicit choice; *and* when the user says things like "detailed analysis," "deep dive," "break down my patterns," treat as Detailed Analysis (optionally flip toggle or inject instruction). | Slightly more logic (detect intent vs read toggle). |

**Recommendation: both.**  
- **Primary:** Add a **toggle** (or mode chip) so the user can explicitly choose "Detailed analysis" before or during a turn. Default = perceptive Gemini with context.  
- **Secondary:** When the user *asks* in natural language ("give me a detailed analysis," "break down my patterns," "deep dive on last month"), either (a) set mode to Detailed Analysis for that turn, or (b) inject a one-off instruction so the model uses the full/analysis prompt for that reply.  

That way: clear default (perceptive with context), clear opt-in (toggle), and natural-language requests still work without requiring the user to find the toggle.

---

## 4. What to Keep vs Remove or Compress (Mode 1 prompt)

### Keep (minimal)

- **Identity:** One line: e.g. "You are LUMARA, the user's personal AI. You have access to their context (journal, history) when provided. Respond like a perceptive friend: natural, direct, warm."
- **Control state (compact):** Either the same JSON block (model follows it) or a reduced subset (e.g. safety, response length, web access). Keeps backend-driven behavior without the long prose.
- **Current context + recent entries:** Same as now (date, recent_entries list). Needed for "perceptive friend" grounding.
- **Context section:** Same `_buildContextSection(...)` so CHRONICLE/raw/lumara_chronicle still feed in when available.
- **Crisis (Layer 1):** Keep the crisis protocol verbatim (988, Crisis Text Line, 911, stop conversation after). Non-negotiable.
- **Temporal basics:** 3–5 bullets: use current date for "yesterday"/"last week"; current entry is written today; don’t date it in the past.
- **Word/sentence limits:** One short block: "Respect responseMode.maxWords and responseLength.max_sentences from control state when set; if noWordLimit or max_sentences == -1, no limit."
- **Web access:** One line: "If webAccess.enabled is true, you may use Google Search; same rules in chat and journal."
- **Current task:** Same ending (CURRENT ENTRY, RESPOND NOW).

### Remove or drastically compress

- **Long "LUMARA CONVERSATIONAL INTELLIGENCE" block:** Replace with: "Use phase and context for internal calibration only. Do not name phases or entry counts. Respond like a perceptive friend."
- **Phase × intensity tone matrix (Layer 2):** Remove the full matrix. Optionally keep one sentence: "In crisis or high distress, be maximally gentle; otherwise match tone to the conversation."
- **Layer 2.5 (temporal self-awareness, A–J):** Remove or compress to a few bullets: "When context is provided, use it to ground replies and cite when helpful. Don’t lecture on temporal intelligence; weave it in naturally when relevant."
- **Intellectual honesty:** Keep intent, shorten to 3–5 bullets (when to gently push back vs when to defer to user; cite entries with dates; "both/and" framing).
- **Voice-specific (2.6–2.8):** Not needed in the *chat* prompt; keep in voice-only path.
- **Layers 3–5 and long persona blocks:** Compress to: "Companion by default. Follow personalityConfig and inferredPreferences from control state. Avoid product copy and forbidden phrases from persona."
- **Sentence-limit repetition:** Keep a single, clear block (e.g. "If max_sentences is set, respond in exactly that many sentences; rewrite to fit if over.").

### Resulting shape

- **Short "chat default" prompt:** Identity (1–2 sentences) + control state + current context + recent entries + context section + crisis + temporal bullets + word/sentence + web + (optional) short intellectual-honesty + short persona note + current task.  
- **Rough size:** On the order of a few hundred lines of prompt text instead of 3,100+, which is a large reduction.
- **Mode 2 (Detailed Analysis):** Keep the full master prompt (or a dedicated "analysis" variant) for when the user toggles or asks for detailed analysis.

---

## 5. Implementation Options

### A. Mode flag: "full" vs "chat" master prompt

- Add a parameter to `getMasterPrompt(..., { LumaraPromptVariant variant = LumaraPromptVariant.full })`.
- `LumaraPromptVariant.chat`: build the shortened template (sections above).
- `LumaraPromptVariant.full`: current template (reflection, journal, or when you need full temporal/persona detail).
- In `LumaraAssistantCubit._buildSystemPrompt()`, call `getMasterPrompt(..., variant: LumaraPromptVariant.chat)`.
- Reflection/journal flows keep using `full` (or a dedicated `reflection` variant later).

### B. Separate method: `getMasterPromptChatOnly()`

- New method that builds only the shortened prompt. No change to existing `getMasterPrompt()`.
- Cubit uses `getMasterPromptChatOnly()` for chat; everyone else keeps using `getMasterPrompt()`.
- Easiest to add without touching the big template.

### C. Single shortened prompt for everyone

- Replace the content of `getMasterPrompt()` with the shortened version; move the current long content to a separate asset or "full" builder used only for reflection/journal.
- Biggest change; only do if you want one primary prompt to be the short one everywhere.

Recommendation: **B** for a low-risk first step: chat uses the short prompt for **Mode 1** (perceptive Gemini with context); when the user toggles or asks for **Detailed Analysis**, use the full prompt (or an analysis variant). Then consider **A** if you want reflection to also have an option for a lighter prompt.

---

## 5.1 Implementation (two-mode chat)

The chat path uses **`getMasterPromptChatOnly()`** by default (short prompt). When the user turns on **Detailed Analysis** (caret menu) or the message matches phrases like "detailed analysis" or "deep dive," the cubit uses **`getMasterPrompt()`** for that turn. Reflection (in-chat and journal Reflect) also uses the short prompt by default; the journal toolbar caret menu offers **Response style: Conversation (perceptive)** vs **Detailed analysis**, and the stored choice is passed into `LumaraReflectionOptions.useDetailedAnalysis` so the full prompt is used only when the user selects Detailed analysis.

---

## 6. Summary

| Question | Answer |
|----------|--------|
| What are the two modes? | **(1) Perceptive Gemini with context** — default; normal conversation, perceptive friend. **(2) Detailed Analysis** — on demand when user explicitly asks or toggles. |
| How is the master prompt set up? | Single `getMasterPrompt()` in `lumara_master_prompt.dart` builds one large string: identity + control state + context + long rules (Layers 1–5, persona, limits) + constraints + current task. Chat uses the same and appends `<response_style>`. |
| Should the user ask or use a toggle for Detailed Analysis? | **Both.** Prefer a toggle for explicit mode choice (default = perceptive with context). Also treat natural-language requests ("detailed analysis," "deep dive," "break down my patterns") as Detailed Analysis for that turn. |
| Would shortening the default shorten the master prompt? | Yes. Mode 1 uses a short prompt (few hundred lines). Mode 2 uses the full (or analysis) prompt when toggled or requested. |

Keeping crisis, control state, context section, and a compact "perceptive Gemini with context" identity gives you a short prompt for the default path; full prompt stays available for Detailed Analysis.
