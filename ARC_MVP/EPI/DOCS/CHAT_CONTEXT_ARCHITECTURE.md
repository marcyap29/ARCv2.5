# LUMARA Chat Context Architecture

## Summary (Updated)

**Chat now ALWAYS uses the Enhanced API** (Path A). Path B (ArcLLM/ArcPrompts) has been removed—it produced generic answers. Chat gets ChronicleContextBuilder synthesized context and LumaraMasterPrompt, same as Reflection.

---

## Chat Flow (Single Path)

### Enhanced API — ChronicleContextBuilder + LumaraMasterPrompt
**When:** Always (Path B removed)

**Context:**
- **ChronicleContextBuilder** — Query router → intent detection → `buildContext()` with **CHRONICLE layers** (monthly, yearly, multiyear aggregations)
- **LumaraOrchestrator** (if `FeatureFlags.useOrchestrator`) — CHRONICLE + ATLAS + AURORA subsystems
- **LumaraMasterPrompt** with `chronicleContext`, `lumaraChronicleContext`

**Result:** Rich synthesized context (patterns, themes, causal chains from aggregated layers). Uses the full Reflection pipeline.

**Chat requests (`entryType.chat`)** force the full pipeline—factual/conversational fast paths are skipped so chat always gets ChronicleContextBuilder.

---

## Reflection Flow (for comparison)

**Context:**
- **ChronicleContextBuilder** — `_contextBuilder.buildContext(userId, queryPlan)` with monthly/yearly/multiyear layers
- **QueryPlan** from `_queryRouter.route()` — intent, layers to load, date filters
- **LumaraMasterPrompt** with `chronicleContext`, `chronicleLayers`, `lumaraChronicleContext`

**Result:** Synthesized summaries (e.g. "February themes: X, Y, Z"), not just raw entry excerpts.

---

## Key Differences (Chat vs Journal Reflection)

Chat and journal Reflection now use the **same context pipeline** (ChronicleContextBuilder + LumaraMasterPrompt). Both get synthesized CHRONICLE context. The main difference is entryType (chat vs journal) and any mode-specific options.

---

## Direct Factual/Math Answers

LumaraMasterPrompt.getMasterPromptChatOnly includes a **DIRECT FACTUAL / MATH ANSWERS** section: when the user asks a direct factual or calculation question (e.g. "What is the volume of a 5g object with density 2g/cm³?"), LUMARA gives the direct answer first in 1–2 sentences, without wrapping in reflection or generic framing.

---

## Status Messages

**Reflection:** Gets `onProgress` callbacks from enhanced API: "Preparing context...", "Analyzing your journal history...", "Calling cloud API...", "Streaming…"

**Chat (ArcLLM path):** Has `_emitStep`: "Loading journal context…", "Retrieved X memory nodes", "Scrubbing PII and sending to AI…", "Response received — linking X memory sources…"

To match Reflection, add more granular steps in the ArcLLM path (e.g. "Searching CHRONICLE…", "Analyzing context…").
