# DevSecOps Security Audit

**Date:** 2026-02-09 (audit run)  
**Scope:** Full security audit — all 20 domains (PII/egress, auth, secrets, input, storage, network, logging, flags, dependencies, rate limit, errors, session, crypto, retention, compliance, permissions, sensitive UI, build/CI, audit trail, deep links).  
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

- **Verified:** Firebase Auth is the identity provider. `FirebaseAuthService` (`lib/services/firebase_auth_service.dart`) provides `currentUser`, `getIdToken(forceRefresh)`, `signOut`, and token refresh listener. Sensitive screens (LUMARA, subscription, chronicle, home) use `currentUser`/`uid` for gating.
- **Backend enforcement:** Firebase callables **require auth** — in `functions/index.js`, `proxyGemini`, `getAssemblyAIToken`, `getUserSubscription`, `createCheckoutSession`, and others check `if (!request.auth)` and throw `HttpsError("unauthenticated", ...)`. UID and email are taken from `request.auth`; no client-only gate for these operations.
- **Phase/subscription access:** Subscription tier and AssemblyAI eligibility are determined server-side (getUserSubscription, getAssemblyAIToken). Phase history and export use `currentUser?.uid` on client; any backend that serves per-user data should also validate auth (callables do).
- **To audit:** Firestore Security Rules (if used for user data) and any REST endpoints; ensure no sensitive action is protected only by client checks.

---

## 3. Secrets & API Key Management

- **Gemini API key:** Not sent from client for main path; `gemini_send.dart` uses Firebase `proxyGemini`; key is in Firebase secrets (`GEMINI_API_KEY`). Streaming path uses `LumaraAPIConfig`; `gemini_send` logs only `apiKey.isNotEmpty`, not the key itself.
- **Backend secrets:** `functions/index.js` uses `defineSecret` for `GEMINI_API_KEY`, `ASSEMBLYAI_API_KEY`, `STRIPE_*`; keys not in repo.
- **AssemblyAI:** Token via callable `getAssemblyAIToken` (auth required); `lib/services/assemblyai_service.dart` caches with expiry. **Finding:** `assemblyai_provider.dart` logs token length and substring (`_token.substring(0, 10)`); reduce or remove in production.
- **API config:** `lib/arc/chat/config/api_config.dart` uses masked key in debug (`$maskedKey`); no raw key in logs. Storage is runtime/preferences; confirm no commit of saved keys.
- **WisprFlow:** Logs URI and auth message with `replaceAll(_config.apiKey, '***')` — key redacted in logs.
- **To audit:** Ensure no token substring or raw key in production logs; review `subscription_management_view` token preview (length + substring) for production build.

---

## 4. Input Validation & Injection

- **Prompt injection:** `test/mira/memory/security_red_team_tests.dart` covers MIRA memory (prompt injection, confidential leakage). LUMARA prompt construction in `lumara_master_prompt.dart`, `enhanced_lumara_api.dart` — user text is scrubbed and/or abstracted before inclusion; verify no unsanitized user content used as instructions.
- **Path traversal / file paths:** Backup, export, import (e.g. `google_drive_settings_view.dart`, `local_backup_settings_view.dart`, MCP/arcx) — verify path sanitization and security-scoped resource usage (iOS/macOS); no user-controlled paths passed unsafely to file APIs.
- **Deep links / URLs:** Any dynamic URLs or schemes from user or config — validate allowlist or sanitize before use.
- **To audit:** Centralize and document prompt-construction points; add tests for prompt injection on LUMARA path if not covered.

---

## 5. Secure Storage & Data at Rest

- **Reversible PII maps:** Never persisted to cloud or backups; `toJsonForRemote` excludes them; local only.
- **Secure storage in use:** `flutter_secure_storage` (pubspec) used in `lib/prism/processors/crypto/enhanced_encryption.dart`, `at_rest_encryption.dart`, and `lib/arc/core/private_notes_storage.dart`; iOS Keychain/Secure Enclave via `ARCXCrypto.swift` for device-bound keys. Sensitive keys and private notes use platform secure storage.
- **Export/backup:** Exported content may include user text; exports are device/user-scoped. ARCX export supports password-based encryption; reversible maps not included in remote/sync payloads.
- **To audit:** Full inventory of Hive/SharedPreferences keys that hold tokens or PII; ensure no reversible map or API key in export/sync formats.

---

## 6. Network & Transport

- **Verified:** No `badCertificateCallback`, `HttpOverrides`, or `allowBadCertificates` found in the repo. Default TLS/certificate validation is used.
- **gemini_send stream:** Uses `HttpClient.postUrl(uri)` with HTTPS URI; no certificate override.
- **Firebase / callables:** Use HTTPS. AssemblyAI and other SDKs use their own clients; assume HTTPS by default.
- **To audit:** Periodically confirm new HTTP client usage does not disable certificate validation.

---

## 7. Logging & Observability

- **Finding — PII in logs:** Several files log user identifiers or tokens: `firebase_auth_service.dart` and `subscription_service.dart` log email and UID in debugPrint; `subscription_management_view.dart` logs email and token length/preview; `unified_transcription_service.dart` logs currentUser email. These are acceptable for debug but **should be disabled or masked in production** (e.g. kReleaseMode or log level).
- **Token/keys:** API key is not logged raw; WisprFlow redacts key with `'***'`. AssemblyAI provider logs token substring — reduce for production. api_config uses masked key.
- **Sentry:** Commented out in pubspec (`# sentry_flutter`); when enabled, ensure no PII or full request/response in breadcrumbs or context.
- **Recommendation:** Use release-mode guards or log levels to avoid logging email/UID/token in production; avoid logging request/response bodies.

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

- **Client:** `gemini_send` passes `entryId` and `chatId` to `proxyGemini` for per-entry and per-chat usage tracking; backend can enforce quotas.
- **Backend:** `getUserSubscription` returns `dailyLumaraLimit` (e.g. 50 for free) and `lumaraThrottled`/`phaseHistoryRestricted`; enforcement of these limits is in app/callable logic. `proxyGemini` itself does not implement rate limiting in the audited snippet — it only checks auth.
- **To audit:** Implement or confirm server-side rate limit/throttle in `proxyGemini` (or a wrapper) for free-tier users; document where limits are enforced (client vs callable vs Firestore rules).

---

## 11. Error Handling & Information Disclosure

- **Backend:** `proxyGemini` catch rethrows `HttpsError("internal", error.message)` — backend may expose generic error message to client; avoid including stack traces or secrets in `error.message`.
- **Client:** Widespread use of `catch (e)` and `rethrow` (e.g. rivet_sweep_service, phase_analysis_view, mcp_import_screen). Error display to users should show generic/safe messages, not `e.toString()` which can contain stack traces or paths.
- **To audit:** Audit UI error paths (SnackBar, AlertDialog) to ensure they do not show raw exception; ensure no catch block logs full request/response or PII.

---

## 12. Session & Token Lifecycle

- **Verified:** `FirebaseAuthService.signOut()` (and force sign-out path): calls `GoogleSignIn.signOut()`, `auth.signOut()`, `SubscriptionService.instance.clearCache()`, and `AssemblyAIService.instance.clearCache()`. Token caches are cleared on logout.
- **Token refresh:** ID token refresh listener (`idTokenChanges`) and `refreshTokenIfNeeded()`; tokens refreshed for callables via `getIdToken(forceRefresh)`.
- **Dispose:** `_idTokenSubscription` cancelled in `dispose()` to avoid leaks.
- **To audit:** Confirm no other token or credential caches (e.g. LumaraAPIConfig saved keys) that persist after sign-out; consider clearing on logout if they are user-scoped.

---

## 13. Cryptography

- **Verified:** `crypto` and `cryptography` packages in pubspec; `lib/prism/processors/crypto/` and `lib/arc/core/private_notes_storage.dart` use `FlutterSecureStorage` (Keychain/Keystore). Native `ARCXCrypto.swift` uses Secure Enclave when available, fallback to Keychain; AES/key handling is device-bound. ARCX export supports password-based encryption. No custom or weak crypto observed; standard platform and Dart libraries used.
- **To audit:** If any new crypto is added, use standard libs and document algorithm/key size; avoid base64-only “encryption.”

---

## 14. Data Retention & Deletion

- **To audit:** How long data is retained locally and on backend. User-initiated deletion (account delete, “delete my data”) — verify data and reversible maps are removed or anonymized; backups/exports do not re-expose deleted content. Document retention and deletion behavior.

---

## 15. Compliance & Data Subject Rights

- **To audit:** GDPR/CCPA-style: access, portability (export), deletion, consent, minimization. Privacy policy and in-app privacy settings; opt-out and consent flows. If health or special-category data: explicit consent and extra safeguards. Document compliance touchpoints.

---

## 16. Platform Permissions & Third-Party SDKs

- **Android:** `android/app/src/main/AndroidManifest.xml` — no explicit RECORD_AUDIO, READ_EXTERNAL_STORAGE, etc. in the base manifest; LAUNCHER and PROCESS_TEXT (for share). Permissions may be added by plugins (e.g. speech_to_text, record, image_picker, health). Document plugin-added permissions and ensure minimum necessary.
- **Third-party:** Firebase (auth, Firestore, callables) — receives auth UID/email on server; client sends scrubbed payloads to proxyGemini. AssemblyAI receives audio via backend/token flow. Sentry commented out. No analytics SDK found in pubspec that would receive PII; ensure any added SDK does not get raw PII.
- **To audit:** Review iOS Info.plist and plugin-generated permissions; document each sensitive permission and its feature.

---

## 17. Sensitive UI & Clipboard

- **To audit:** Password/PIN/secret fields masked; sensitive screens protected from screenshots/screen capture (e.g. FLAG_SECURE) where applicable. Clipboard: avoid logging; consider clearing or warning when copying sensitive content.

---

## 18. Build, CI & Environment Separation

- **Secrets:** Production API keys live in Firebase secrets (functions) and client-side in LumaraAPIConfig (user-configured); no hardcoded prod keys in repo. `String.fromEnvironment('GEMINI_API_KEY')` used only in echo guardrail (optional path).
- **Lockfile:** `pubspec.lock` present; dependencies pinned for reproducibility.
- **To audit:** Run `dart pub audit` periodically; if CI exists (e.g. GitHub Actions), ensure secrets are in CI secrets manager, not in repo. Verify dev/staging Firebase project or config does not use prod keys.

---

## 19. Audit Trail & Monitoring

- **To audit:** Whether sensitive actions (full export, account deletion, subscription change) are logged for incident response (without PII). How to detect abuse or anomalies (e.g. LLM call volume). Document audit/monitoring approach.

---

## 20. Deep Links & App Intents

- **Current use:** “Deeplink” in codebase refers to **internal** app navigation (e.g. `patterns://` in insight cards; `deeplinkAnchor` for in-app routing). No external deep-link or intent handler was found (no `getInitialLink`/`uriLink` in lib). Android manifest has no custom intent-filter for external URLs.
- **To audit:** If external deep links or intents are added, validate and sanitize URL/intent data before use for navigation or backend params; use allowlist for schemes/hosts.

---

## Summary

- **PII/egress:** Implemented and verified; all frontier-model paths scrub before send; reversible maps local-only; test gap: automated egress PII payload test.
- **Auth:** Backend callables enforce `request.auth`; signOut clears subscription and AssemblyAI caches; token refresh and dispose in place.
- **Secrets:** Gemini key in Firebase secrets; AssemblyAI via callable; API config masks keys in logs. Finding: token substring and email/UID in debug logs — mask or disable in production.
- **Storage/crypto:** Flutter secure storage and Keychain/Secure Enclave used for sensitive data; no reversible maps in cloud/backup.
- **Network:** No certificate validation disabled found.
- **Session:** Logout clears token caches; ID token refresh and subscription cleanup verified.
- **Rate limiting:** Client passes entryId/chatId; backend returns tier/limits; proxyGemini does not yet enforce rate limit in code — recommend adding or documenting where enforced.
- **Deep links:** Internal only (patterns://); no external handler found.
- **Remaining:** Sections 4, 14, 15, 17, 19 remain “to audit” for next run (input validation detail, data retention/deletion flows, compliance touchpoints, sensitive UI/clipboard, audit trail). Update this document when adding features or before release/security review.
