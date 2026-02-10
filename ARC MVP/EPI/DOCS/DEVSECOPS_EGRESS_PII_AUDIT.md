# DevSecOps Security Audit: Egress & PII

**Date:** 2026-02-09  
**Scope:** PII scrubbing before frontier-model egress; egress paths; feature flags; assertions.  
**Reference:** `DOCS/claude.md` — DevSecOps Security Audit Role (Universal Prompt).

---

## 1. Egress & PII Checklist

| Egress path | Data sent | Scrubbed? | Bypass / notes |
|-------------|-----------|-----------|----------------|
| **gemini_send.dart** (Firebase `proxyGemini`) | `system`, `user` | ✅ Yes — PRISM scrub + optional correlation-resistant; `isSafeToSend` guard; `SecurityException` if PII remains | `skipTransformation` skips only correlation-resistant layer; scrubbing always runs first |
| **gemini_send.dart** (streaming, direct Gemini URL) | `system`, `user` | ✅ Yes — same PRISM + `isSafeToSend` + `SecurityException` | Same as above |
| **enhanced_lumara_api.dart** → geminiSend | Entry text, CHRONICLE context, system prompt | ✅ Yes — entry abstracted/scrubbed; CHRONICLE scrubbed (lines 738–750); prompt built from scrubbed vars; geminiSend scrubs again | Restore via `chronicleReversibleMap` on response only (device) |
| **voice_session_service.dart** → LUMARA handler | Transcript | ✅ Yes — `_prism.scrub(_currentTranscript)` before `handler.handleReflectionRequest(userQuery: prismResult.scrubbedText, ...)` | Restore for TTS with `prismResult.reversibleMap` (local) |
| **voice_journal/gemini_client.dart** | `scrubbedText` only | ✅ Yes — `isSafeToSend(scrubbedText)` before use; caller (voice pipeline) must scrub first | Documented: "Input text MUST be scrubbed by PRISM before calling" |
| **lumara_assistant_cubit.dart** → geminiSend | `userMessage`, `systemPrompt` | ✅ Yes — geminiSend scrubs both | — |
| **Chronicle synthesizers** (monthly, yearly, multiyear) → geminiSend | Journal entry content in prompts | ✅ Yes — geminiSend scrubs system + user | Comments state "scrubbed when sent to cloud" (scrubbing inside geminiSend) |
| **chronicle/query_router.dart** → geminiSend | Router prompt | ✅ Yes — geminiSend scrubs | — |
| **LumaraShareService** | — | N/A — throws UnimplementedError in Firebase-only mode | No live egress |
| **lumara_veil_edge_integration.dart** | — | N/A — geminiSend call is commented out | Active path uses fallback only |
| **PrivacyGuardrailInterceptor / geminiSendSecure** | system, user | Block-on-PII (no scrub) | Not used in main flow; main flow uses gemini_send.dart (scrub-then-send) |
| **AssemblyAI / STT** | Audio | N/A — audio sent; transcript returned. Transcript is then scrubbed before any LUMARA send | Voice flow: transcript → PRISM scrub → LUMARA |

**Reversible maps:** Only used for local restore (gemini_send restore, enhanced_lumara restore, voice restore). Never included in `requestData` or any payload to Firebase/cloud. `voice_session` model’s `toJsonForRemote` explicitly omits `prism_reversible_map`.

---

## 2. Security Assertions Verified

- **“PII scrubbing before send”** — Confirmed: every path to Gemini goes through `gemini_send.dart` or through a handler that calls it; geminiSend always runs PRISM scrub first, then optional transformation.
- **“PRISM scrubbing,” “privacy-preserving,” “sanitized”** in comments/docs — Implementation matches: PrismAdapter/PiiScrubber used; scrubbed text sent; restore only on device.
- **`SecurityException` / guardrail** — `gemini_send.dart` (and stream) call `prismAdapter.isSafeToSend(...)` after scrub; if false, throw `SecurityException('SECURITY: PII still detected after PRISM scrubbing')`. Not bypassed.
- **Correlation-resistant transformation** — Applied only to already-scrubbed text (`prismScrubbedText`); never to raw input.

---

## 3. Feature Flags & Bypasses

- **FeatureFlags.piiScrubbing** (`lib/state/feature_flags.dart`): `static const bool piiScrubbing = true`.  
  - **Effect:** When `false`, `PiiScrubber.rivetScrubWithMapping()` returns raw text and empty map (see `lib/services/lumara/pii_scrub.dart` lines 36–42).  
  - **Default:** `true` (safe). Changing requires code/rebuild (no runtime UI).  
  - **Recommendation:** If this is ever made runtime or config-driven, treat as a critical change and require explicit security review; consider failing closed (e.g. block cloud send when flag is false) instead of sending raw text.

- **skipTransformation** — Only skips correlation-resistant transformation; scrubbing always runs. No PII bypass.

- No other flags or settings found that disable scrubbing for frontier-model egress.

---

## 4. Red-Team & Test Coverage

- **Existing:** `test/mira/memory/security_red_team_tests.dart` covers MIRA memory (prompt injection, privacy levels, confidential leakage). It does **not** cover “with PII in input, payload to external API contains no raw PII.”

- **Recommendations:**
  1. **Unit test for gemini_send (or equivalent):** With a mocked Firebase callable (or test double), assert that when `geminiSend(system: s, user: u)` is called with `s`/`u` containing clear PII (e.g. email, phone), the payload passed to the callable does **not** contain the raw PII (e.g. contains `[EMAIL_1]` or similar tokens instead). This validates the scrub-before-send invariant without hitting the real API.
  2. **Optional:** Similar test for streaming path (payload to HTTP client).
  3. Keep red-team tests for memory/retrieval; add a short comment in `security_red_team_tests.dart` that egress PII tests live in the gemini_send / egress test file.

---

## 5. Summary

- **Egress to frontier models:** All current paths go through `gemini_send` (or a layer that passes already-scrubbed text into it). Scrubbing runs before send; reversible maps stay local; `isSafeToSend` + `SecurityException` enforce no residual PII in payload.
- **CHRONICLE and voice:** CHRONICLE context is scrubbed in `enhanced_lumara_api.dart` before being added to the prompt; voice transcript is scrubbed in `voice_session_service.dart` before LUMARA; restore is device-only.
- **Risks:** (1) If `FeatureFlags.piiScrubbing` is ever set to `false` or made configurable, raw text could be sent — keep default `true` and document. (2) No automated test yet that asserts “payload to cloud has no raw PII” for gemini_send; adding it is recommended.
- **Traceability:** This document serves as the “egress and PII” checklist for release/security review. Update it when adding new LLM or external API calls.
