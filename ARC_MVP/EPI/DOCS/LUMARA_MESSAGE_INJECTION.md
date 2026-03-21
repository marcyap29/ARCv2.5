# LUMARA — Message Injection Behavior

This document defines how mode definition blocks and tags are injected for **Chat** and **Reflection**. Implementation: `lib/arc/chat/prompts/lumara_mode_definition.dart`, `lib/arc/chat/bloc/lumara_assistant_cubit.dart`, `lib/arc/chat/services/enhanced_lumara_api.dart`.

---

## Message Injection Behavior

### On Session Start (first message only) — Apply to Chat and Reflection

Inject the **full three-mode definition block** so the model understands the complete system. This fires **once per session** regardless of which mode is active.

- **Chat:** First message in the conversation (`baseMessages.isEmpty`) → inject full block.
- **Reflection:** Single request per “session” → always inject full block on that request.

### On Every Message

Prepend the **current mode tag only**: `[MODE: Personal]`, `[MODE: Simple]`, or `[MODE: Analysis]`.

### On Mode Switch (mid-session only) — Chat only

When the user **changes mode** mid-session, inject **only the definition for the newly active mode** plus the Action Honesty block. Do **not** re-inject the full three-mode block. This prevents the model from re-encountering tagging rules from other modes.

- **Chat:** `baseMessages.isNotEmpty` and `currentMode != modeDefinitionInjectedForMode` → inject mode-only block for the new mode.
- **Reflection:** N/A (single request per reflection).

---

## Mode-Only Injection Blocks (use on mid-session mode switch)

Authoritative text lives in **`lib/arc/chat/prompts/lumara_mode_definition.dart`** (`_lumaraModeSwitchPersonal`, `_lumaraModeSwitchAnalytical`, `_lumaraModeSwitchDeepAnalytical`).

Summary:

- **Personal** — `[MODE SWITCH: Personal]` — `[FROM YOUR ENTRIES]` (Chronicle recall), `[MY SYNTHESIS]` (reasoning that connects entries to the query), `[GENERAL KNOWLEDGE]` (factual, no personal grounding). See dart file for edge cases.
- **Simple** — `[MODE SWITCH: Simple]` — no journal integration; no provenance tags; end naturally (no “Simple answer” tag line).
- **Analysis** — `[MODE SWITCH: Analysis]` — `[GENERAL KNOWLEDGE]` (established facts), `[MY SYNTHESIS]` (deep reasoning and connections), `[HYPOTHETICAL EXAMPLE]` (speculative/extrapolated).

---

## Summary of Injection Rules

| Trigger       | What to Inject                                                                 |
|---------------|---------------------------------------------------------------------------------|
| Session start | Full three-mode definition block (once)                                        |
| Every message | `[MODE: x]` tag only                                                           |
| Mode switch   | Mode-only block for the newly active mode + Action Honesty only (no full block) |
