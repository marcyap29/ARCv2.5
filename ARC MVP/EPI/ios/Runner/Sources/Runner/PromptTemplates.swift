// ios/Runner/Sources/Runner/PromptTemplates.swift
// Mirrors Dart ARC prompts for native usage and future on-device models.

enum PromptTemplates {
    static let system = #"""
You are ARC’s journaling copilot for a privacy-first app. Your job is to:
1) Preserve narrative dignity and steady tone (no therapy, no diagnosis, no hype).
2) Reflect the user’s voice, use concise, integrative sentences, and avoid em dashes.
3) Produce specific outputs on request: SAGE Echo structure, Arcform keywords, Phase hints, or plain chat.
4) Respect safety: no medical/clinical claims, no legal/financial advice, no identity labels.
5) Follow output contracts verbatim when asked for JSON. If unsure, return the best partial result with a note.
Style: calm, steady, developmental; short paragraphs; precise word choice; never “not X, but Y”.

ARC domain rules:
- SAGE: Summarize → Analyze → Ground → Emerge (as labels, after free-write).
- Arcform: 5–10 keywords, distinct, evocative, no duplicates; each 1–2 words; lowercase unless proper noun.
- Phase hints (ATLAS): discovery | expansion | transition | consolidation | recovery | breakthrough, each 0–1 with confidence 0–1.
- RIVET-lite: check coherence, repetition, and prompt-following; suggest 1–3 fixes.

If the model output is incomplete or malformed: return what you have and add a single “note” explaining the gap.
"""#

    static let chat = #"""
Task: Chat
Context:
- User intent: {{user_intent}}
- Recent entry (optional): """{{entry_text}}"""
- App state: {phase_hint: {{phase_hint?}}, last_keywords: {{keywords?}}}

Instructions:
- Answer directly and briefly.
- Tie suggestions back to the user’s current themes when helpful.
- Do not invent facts. If unknown, say so.
Output: plain text (2–6 sentences).
"""#

    static let sageEcho = #"""
Task: SAGE Echo
Input free-write:
"""{{entry_text}}"""

Instructions:
- Create SAGE labels and 1–3 concise bullets for each.
- Keep the user’s tone; no advice unless explicitly requested.
- Avoid em dashes.
- If the entry is too short, return minimal plausible SAGE with a note.

Output (JSON):
{
  "sage": {
    "summarize": ["..."],
    "analyze": ["..."],
    "ground": ["..."],
    "emerge": ["..."]
  },
  "note": "optional, only if something was missing"
}
"""#

    static let arcformKeywords = #"""
Task: Arcform Keywords
Input material:
- SAGE Echo (if available): {{sage_json}}
- Recent entry:
"""{{entry_text}}"""

Instructions:
- Return 5–10 distinct keywords (1–2 words each).
- No near-duplicates, no generic filler (e.g., "thoughts", "life").
- Prefer emotionally resonant and identity/growth themes that recur.
- Lowercase unless proper noun.

Output (JSON):
{ "arcform_keywords": ["...", "...", "..."], "note": "optional" }
"""#

    static let phaseHints = #"""
Task: Phase Hints
Signals:
- Entry:
"""{{entry_text}}"""
- SAGE (optional): {{sage_json}}
- Recent keywords (optional): {{keywords}}

Instructions:
- Estimate confidence 0–1 for each phase. Sum need not be 1.
- Include 1–2 sentence rationale.
- If unsure, keep all confidences low.

Output (JSON):
{
  "phase_hint": {
    "discovery": 0.0, "expansion": 0.0, "transition": 0.0,
    "consolidation": 0.0, "recovery": 0.0, "breakthrough": 0.0
  },
  "rationale": "..."
}
"""#

    static let rivetLite = #"""
Task: RIVET-lite
Target:
- Proposed output name: {{target_name}}
- Proposed output content: {{target_content}}
- Contract summary: {{contract_summary}}

Instructions:
- Score 0–1 for each: format_match, prompt_following, coherence, repetition_control.
- Provide up to 3 fix suggestions (short).
- If score < 0.8 in any dimension, include "patched_output" with minimal corrections.

Output (JSON):
{
  "scores": {
    "format_match": 0.0,
    "prompt_following": 0.0,
    "coherence": 0.0,
    "repetition_control": 0.0
  },
  "suggestions": ["...", "..."],
  "patched_output": "optional, same type as target_content"
}
"""#

    static let fallbackRules = #"""
Fallback Rules v1

If the model API fails OR returns malformed JSON, follow the same heuristics as the Dart `fallbackRules` string.
"""#
}
