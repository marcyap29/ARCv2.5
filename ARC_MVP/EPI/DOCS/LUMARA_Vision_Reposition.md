# LUMARA Vision: Reposition (February 2026)

**Status:** Reflects repo changes and product reposition as of February 2026.  
**Companion to:** [LUMARA_Vision.md](LUMARA_Vision.md) (original full vision, investment, and technical depth).

---

## Executive Summary

**LUMARA is your lifetime personal AI:** frontier-level answers with full context when you want it, and privacy by design. Your data stays on your device; nothing is shared without your say. We lead with **companion** and **context on your terms**, not with phases or developmental UI.

**Reposition in one line:**  
*From "Phase-Aware AI agent" → **"Lifetime personal AI with Gemini-level answering and full context, private by design."***

---

## The Reposition: What Changed

### Before (Phase-Forward)

- Welcome and UI emphasized phases (Discovery, Transition, etc.).
- Phase tab on home; phase scope chip in settings; phase window and phase timeline on the LUMARA main page.
- Onboarding included phase quiz and phase reveal.
- Timeline entries showed phase tags.

### After (Companion + Full Context)

- **User-facing story:** Personal AI that knows you, keeps your data local, and uses your journal/history only when you want.
- **Phases:** Still power response calibration and intelligence under the hood (ATLAS, regimes, RIVET). No phase window, phase timeline, or phase tags in the main UI.
- **Home:** LUMARA + Conversations only (no Phase tab).
- **Onboarding:** Intro → Capabilities → complete. No phase quiz in the default path; copy focuses on privacy, full context, and frontier capability.
- **Timeline:** Entries show **format/source** (CHAT, Voice, Reflection, Import (Drive), etc.), not phase.
- **Chat welcome:** Companion framing; context “when you want it.”

This aligns the product with **companion** positioning and makes “lifetime personal AI” the primary message.

---

## Product Experience (Current State)

### Onboarding

**Screen 1 — First impression**

- **Headline:** “Frontier AI that actually knows you — and keeps it that way.”
- **Subheadline:** Powered by the same models behind the best AI. Your data stays on your device, encrypted, never used to train anything. Context activates only when you ask for it.
- **Three lines:** Your data lives on your device; Frontier model capability; Full context when you want it, nothing shared without your say.
- **Primary action:** “Get started.”
- **Fine print:** No account required to explore; context features unlock after your first journal entry.

**Screen 2 — What makes LUMARA different**

- **Headline:** “Most AI forgets you the moment you close the app.”
- **Subheadline:** LUMARA remembers — but only when you want it to. Your journal, your patterns, your history. Available on demand. Private by design.
- **Three pillars:**
  1. **Full context, on your terms.** Bring journal and history into any conversation with one tap — or don’t. LUMARA waits; it never assumes.
  2. **Your data never leaves without you.** Everything on device; sensitive details scrubbed before anything reaches the cloud. Encrypted at rest. Yours completely.
  3. **Frontier capability, no compromises.** Same models as the best AI; privacy doesn’t mean settling for less.
- **Actions:** “See how it works” (primary), “Jump in →” (secondary).

Default path: Intro → Capabilities → complete (no phase quiz in the main flow).

### LUMARA Main Page (Unified Feed)

- **Greeting** and **header actions** (e.g. calendar, settings).
- **Communication actions:** Chat | Reflect | Voice.
- **Feed:** Date dividers and entry cards (journal, saved conversations, voice memos, reflections). No phase preview card and no phase timeline/Gantt.
- **Timeline (Conversations):** Entries show **format/source** (CHAT, Voice, Reflection, Import) and a neutral “Context” dialog where relevant; no phase chips or phase window.

### Chat

- **Welcome:** “Hello! I’m LUMARA, your personal AI. I can help with what you need, when you need it — and when you want, I can use your journal and history for more personal answers. What would you like to know?”
- **Default persona:** Companion. Context use is opt-in / on demand in the framing.

---

## Technical Truth: Phases Under the Hood

Phases are **not removed** from the system; they are **de-emphasized in the UI** and used for intelligence and calibration:

- **ATLAS / phase regimes:** Still analyze journal and temporal data to infer developmental state.
- **RIVET / SENTINEL:** Still used for transition detection and pattern recognition.
- **Response calibration:** LUMARA can still use phase context to tailor tone and depth; this is internal, not surfaced as “your phase” in the main experience.
- **Backend and prompts:** Phase-related logic remains in prompts and services for response quality; wording in user-facing prompts avoids “Phase tab” and leads with context and companion.

So: **Phase-Aware is becoming the agent** — the system is still phase-aware; the **positioning** is “lifetime personal AI with full context and privacy.”

---

## Differentiators (Reposition Framing)

| Dimension | Message |
|----------|---------|
| **Context** | Full context when you want it — journal and history on demand; session-level opt-in, relevance-based suggestions, “use when relevant” preference. |
| **Privacy** | Data on device; scrubbing before cloud; encrypted at rest; nothing shared without your say. |
| **Capability** | Frontier models (e.g. Gemini-level); no compromise for privacy. |
| **Relationship** | Companion by default; personal AI that “actually knows you” over time. |

---

## Context UX (Beyond “User Asks Every Time”)

- **Session-level opt-in:** Turn on “use my context” for this conversation.
- **Relevance-based suggestions:** “This might be more helpful with your journal context — use it?”
- **“Use when relevant” preference:** Let LUMARA suggest when to pull in context instead of asking every time.

(Implementation can follow these directions as features are built.)

---

## What Success Looks Like (Reposition)

- Users describe LUMARA as **“the AI that actually knows me”** and **“private by design.”**
- Onboarding clearly communicates **full context + privacy + frontier capability.**
- No confusion from phase-first UI; **companion and control** are the main story.
- Timeline and feed feel **content- and source-oriented** (CHAT, Voice, Reflection, Import), not phase-oriented.
- Phases continue to improve answers behind the scenes without dominating the product narrative.

---

## Design Validation (February 2026)

**User impact:** This version of LUMARA (v3.3.59) is possibly the most powerful and helpful instance designed to date. It has done more in recent answers to serve as a viable thinking partner than any other iteration. That outcome validates the reposition — companion-first framing, dual prompt mode (Conversation / Detailed Analysis), personality onboarding, GPT-OSS 120B primary, and phase de-emphasis — as delivering on the "lifetime personal AI" promise.

**Process applied (Feb 2026):** Code consolidation, bug tracking, and DevSecOps prompts have been applied to this iteration — see CODE_SIMPLIFIER_*, bugtracker/ (including BUGTRACKER_TRIAGE_BACKLOG, static-analysis-findings-feb-2026), and DEVSECOPS_SECURITY_AUDIT.md.

---

## Document History

- **February 2026:** Initial version; reflects removal of phase window and phase timeline from LUMARA main page, onboarding copy and flow, timeline format/source labels, welcome message, and companion-first reposition. Phases documented as background capability. Design validation note added (v3.3.59 thinking-partner impact).

---

*LUMARA Vision Reposition — February 2026*
