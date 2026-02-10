# DevSecOps Security Audit

**Date:** 2026-02-09  
**Scope:** Full security audit — PII/egress, authentication, secrets, input validation, storage, network, logging, dependencies, rate limiting.  
**Reference:** `DOCS/claude.md` — DevSecOps Security Audit Role (Universal Prompt).

---

## 1. Egress & PII

### 1.1 Egress checklist

| Egress path | Data sent | Scrubbed? | Bypass / notes |
|-------------|-----------|-----------|----------------|
| **gemini_send.dart** (Firebase `proxyGemini`) | `system`, `user` | ✅ Yes — PRISM scrub + optional correlation-resistant; `isSafeToSend` guard; `SecurityException` if PII remains | `skipTransformation` skips only correlation-resistant layer; scrubbing always runs first |
| **gemini_send.dart** (streaming, direct Gemini URL) | `system`, `user` | ✅ Yes — same PRISM + `isSafeToSend` + `SecurityException` | Same as above |
| **enhanced_lumara_api.dart** → geminiSend | Entry text, CHRONICLE context, system prompt | ✅ Yes — entry abstracted/scrubbed; CHRONICLE scrubbed (lines 738–750); geminiSend scrubs again | Restore via `chronicleReversibleMap` on response only (device) |
| **voice_session_service.dart** → LUMARA handler | Transcript | ✅ Yes — `_prism.scrub(_currentTranscript)` before handler | Restore for TTS with `prismResult.reversibleMap` (local) |
| **voice_journal/gemini_client.dart** | `scrubbedText` only | ✅ Yes — `isSafeToSend(scrubbedText)`; caller must scrub first | Documented: "Input text MUST be scrubbed by PRISM before calling" |
| **lumara_assistant_cubit.dart** → geminiSend | `userMessage`, `systemPrompt` | ✅ Yes — geminiSend scrubs both | — |
| **Chronicle synthesizers** → geminiSend | Journal entry content | ✅ Yes — geminiSend scrubs system + user | — |
| **chronicle/query_router.dart** → geminiSend | Router prompt | ✅ Yes — geminiSend scrubs | — |
| **LumaraShareService** | — | N/A — UnimplementedError in Firebase-only mode | No live egress |
| **lumara_veil_edge_integration.dart** | — | N/A — geminiSend call commented out | Active path uses fallback only |
| **PrivacyGuardrailInterceptor** | system, user | Block-on-PII (no scrub) | Not used in main flow |
| **AssemblyAI / STT** | Audio | N/A — transcript then scrubbed before LUMARA | — |

**Reversible maps:** Local restore only; never in request payloads. `toJsonForRemote` omits `prism_reversible_map`.

### 1.2 PII assertions verified

- All paths to Gemini go through `gemini_send` or a layer that passes scrubbed text; `SecurityException` and `isSafeToSend` not bypassed; correlation-resistant applied only to scrubbed text.
- **FeatureFlags.piiScrubbing** default `true`; if set `false`, raw text could be sent — keep default and document. **skipTransformation** does not skip scrubbing.

### 1.3 Red-team / test gaps

- Add unit test: with mocked Firebase callable, assert payload to proxy contains no raw PII when input has PII (e.g. contains `[EMAIL_1]`-style tokens).

---

## 2. Authentication & Authorization

- **To audit:** Identify Firebase Auth usage, where `currentUser` or ID token is checked before sensitive operations (e.g. subscription, phase history, export). Verify backend/callables enforce identity; document any client-only gates that protect sensitive actions.
- **Key areas:** `lib/services/firebase_auth_service.dart`, auth-gated screens, Firebase callable context (e.g. `proxyGemini`, subscription), Firebase Security Rules and Firestore rules.
- **Phase/subscription access:** `lib/services/phase_history_access_control.dart`, `lib/services/subscription_service.dart` — confirm enforcement is server-side or callable-backed where required.

---

## 3. Secrets & API Key Management

- **Gemini API key:** Not sent from client; `gemini_send.dart` uses Firebase `proxyGemini` callable — key held on backend. Streaming path uses `LumaraAPIConfig` (runtime config); ensure key is not logged or committed.
- **AssemblyAI:** Token via Firebase callable `getAssemblyAIToken`; `lib/services/assemblyai_service.dart` caches with expiry; verify token not logged or exposed in errors.
- **Other:** `lib/arc/chat/config/api_config.dart` — API keys for providers; confirm storage (e.g. secure/preferences) and no print of keys. Env/build-time keys (e.g. `GEMINI_API_KEY` in guardrail) only where necessary and never in repo.
- **To audit:** Grep for hardcoded keys, `String.fromEnvironment` usage, and any log/print of tokens or keys.

---

## 4. Input Validation & Injection

- **Prompt injection:** `test/mira/memory/security_red_team_tests.dart` covers MIRA memory (prompt injection, confidential leakage). LUMARA prompt construction in `lumara_master_prompt.dart`, `enhanced_lumara_api.dart` — user text is scrubbed and/or abstracted before inclusion; verify no unsanitized user content used as instructions.
- **Path traversal / file paths:** Backup, export, import (e.g. `google_drive_settings_view.dart`, `local_backup_settings_view.dart`, MCP/arcx) — verify path sanitization and security-scoped resource usage (iOS/macOS); no user-controlled paths passed unsafely to file APIs.
- **Deep links / URLs:** Any dynamic URLs or schemes from user or config — validate allowlist or sanitize before use.
- **To audit:** Centralize and document prompt-construction points; add tests for prompt injection on LUMARA path if not covered.

---

## 5. Secure Storage & Data at Rest

- **Reversible PII maps:** Never persisted to cloud or backups; `toJsonForRemote` excludes them; local only.
- **Sensitive persistence:** Hive, SQLite, or file-based storage for tokens, health data, journal — verify use of platform secure storage or encryption where appropriate (e.g. Flutter secure storage for tokens if any).
- **Export/backup:** Exported content may include user text; ensure exports are device/user-scoped and not exposed to other users or services unintentionally.
- **To audit:** List all persistent stores; confirm no reversible maps or API keys in plain text in export/sync payloads.

---

## 6. Network & Transport

- **HTTPS:** Firebase, Gemini (generativelanguage.googleapis.com), AssemblyAI, OpenAI — confirm all outbound use HTTPS. No custom client that disables certificate validation unless documented and justified.
- **gemini_send stream:** Uses `HttpClient` with `postUrl(uri)`; default TLS behavior — verify no badHttpClientCertificate or similar.
- **To audit:** Grep for `badCertificateCallback`, `HttpClient`, and any proxy/certificate overrides.

---

## 7. Logging & Observability

- **Risk:** `print`/`debugPrint` used for debugging (e.g. gemini_send, LUMARA, voice) — may include lengths, flags, or redacted counts; ensure no full user content or PII in logs.
- **To audit:** Grep for `print(` and `debugPrint(` with variable content; ensure no API keys, tokens, or raw PII. Analytics/crash SDK — verify no sensitive payloads attached.
- **Recommendation:** Prefer structured logging with severity and avoid logging request/response bodies; keep PII and tokens out of log messages.

---

## 8. Feature Flags & Bypasses

- **FeatureFlags** (`lib/state/feature_flags.dart`): `piiScrubbing`, `inlineLumara`, `phaseAwareLumara`, `analytics`, `useOrchestrator` — document which affect security; safe defaults (e.g. `piiScrubbing = true`). No runtime UI to disable PII scrubbing found.
- **skipTransformation:** Scrubbing always runs; no PII bypass.
- **To audit:** Any new flags that gate auth, scrubbing, or validation — require safe default and explicit justification for disabling.

---

## 9. Dependencies & Supply Chain

- **To audit:** Run `dart pub audit` (or equivalent) periodically; track known vulnerabilities in dependencies. Lockfile (e.g. `pubspec.lock`) committed for reproducible builds.
- **Key packages:** Firebase, cloud_functions, http/io, Hive, etc. — note versions and any security-related release notes.

---

## 10. Rate Limiting & Abuse

- **Existing:** `gemini_send` accepts `entryId` and `chatId` for per-entry and per-chat usage limits; backend (Firebase callable) can enforce quotas.
- **To audit:** Confirm Firebase `proxyGemini` (and other callables) enforce rate limits or subscription checks server-side; document client-side vs server-side enforcement for LLM and other expensive operations.

---

## 11. Error Handling & Information Disclosure

- **To audit:** Ensure catch blocks and error UI do not expose stack traces, internal paths, API keys, or PII. Grep for `catch`, `rethrow`, and error display; verify production-safe messages. Avoid logging full request/response or sensitive variables in exceptions.

---

## 12. Session & Token Lifecycle

- **To audit:** Firebase Auth session timeout and persistence; logout flow and token invalidation. AssemblyAI (and any other) token cache cleared on logout. Verify refresh logic and that cached credentials are not left in memory or storage after sign-out.

---

## 13. Cryptography

- **To audit:** Any use of encryption, hashing, or encoding for sensitive data. Prefer standard libraries (e.g. PointyCastle, crypto); flag custom or deprecated algorithms. Ensure no “security” that is only base64 or weak encoding.

---

## 14. Data Retention & Deletion

- **To audit:** How long data is retained locally and on backend. User-initiated deletion (account delete, “delete my data”) — verify data and reversible maps are removed or anonymized; backups/exports do not re-expose deleted content. Document retention and deletion behavior.

---

## 15. Compliance & Data Subject Rights

- **To audit:** GDPR/CCPA-style: access, portability (export), deletion, consent, minimization. Privacy policy and in-app privacy settings; opt-out and consent flows. If health or special-category data: explicit consent and extra safeguards. Document compliance touchpoints.

---

## 16. Platform Permissions & Third-Party SDKs

- **To audit:** iOS/Android permissions (manifest/plist) — minimum necessary; document purpose of each sensitive permission. Third-party SDKs (Firebase, analytics, crash, STT): what data they receive; ensure no unintended PII or secrets.

---

## 17. Sensitive UI & Clipboard

- **To audit:** Password/PIN/secret fields masked; sensitive screens protected from screenshots/screen capture (e.g. FLAG_SECURE) where applicable. Clipboard: avoid logging; consider clearing or warning when copying sensitive content.

---

## 18. Build, CI & Environment Separation

- **To audit:** CI config (e.g. GitHub Actions) — no production secrets in repo; use secrets management. Dev/staging vs prod configs — no prod keys in dev. Lockfile and `dart pub audit`; build reproducibility.

---

## 19. Audit Trail & Monitoring

- **To audit:** Whether sensitive actions (full export, account deletion, subscription change) are logged for incident response (without PII). How to detect abuse or anomalies (e.g. LLM call volume). Document audit/monitoring approach.

---

## 20. Deep Links & App Intents

- **To audit:** Deep link and intent handlers; validate and sanitize URL parameters and intent data before use for navigation, backend params, or file paths. Prevent injection or unintended behavior from malicious links.

---

## Summary

- **PII/egress:** Implemented and verified; all frontier-model paths scrub before send; reversible maps local-only; test gap: automated egress PII payload test.
- **Other domains:** Sections 2–20 provide structure and key areas; complete each on next full audit run. Update this document when adding features or before release/security review.
