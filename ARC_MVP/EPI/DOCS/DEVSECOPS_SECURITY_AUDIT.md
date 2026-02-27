# DevSecOps Security Audit

**Date:** 2026-02-26 (audit run; fixes applied)  
**Scope:** Full security audit — all 20 domains (PII/egress, auth, secrets, input, storage, network, logging, flags, dependencies, rate limit, errors, session, crypto, retention, compliance, permissions, sensitive UI, build/CI, audit trail, deep links).  
**Intent:** Maximize security, minimize leakage, ensure users are protected.  
**Reference:** `DOCS/claude.md` — DevSecOps Security Audit Role (Universal Prompt).

---

## 1. Egress & PII

### 1.1 Egress checklist

| Egress path | Data sent | Scrubbed? | Bypass / notes |
|-------------|-----------|-----------|----------------|
| **gemini_send.dart** (Firebase `proxyGemini`) | `system`, `user` | ✅ Yes — PRISM scrub + optional correlation-resistant; `isSafeToSend` guard; `SecurityException` if PII remains | `skipTransformation` skips only correlation-resistant layer; scrubbing always runs first |
| **gemini_send.dart** (streaming, direct Gemini URL) | `system`, `user` | ✅ Yes — same PRISM + `isSafeToSend` + `SecurityException` | ⚠️ **Streaming path uses client-side API key in URL** (no proxy); key not logged but exposed in process. Prefer proxy for streaming when available. |
| **enhanced_lumara_api.dart** → geminiSend | Entry text, CHRONICLE context, system prompt | ✅ Yes — entry abstracted/scrubbed; CHRONICLE scrubbed (lines 857–868); geminiSend scrubs again | Restore via `chronicleReversibleMap` on response only (device) |
| **voice_session_service.dart** → LUMARA handler | Transcript | ✅ Yes — `_prism.scrub(_currentTranscript)` before handler | Restore for TTS with `prismResult.reversibleMap` (local) |
| **voice_journal/gemini_client.dart** | `scrubbedText` only | ✅ Yes — `isSafeToSend(scrubbedText)`; caller must scrub first | Documented: "Input text MUST be scrubbed by PRISM before calling" |
| **lumara_assistant_cubit.dart** → geminiSend | `userMessage`, `systemPrompt` | ✅ Yes — geminiSend scrubs both | — |
| **Chronicle synthesizers** → geminiSend | Journal entry content | ✅ Yes — geminiSend scrubs system + user | — |
| **chronicle/query_router.dart** → geminiSend | Router prompt | ✅ Yes — geminiSend scrubs | — |
| **LumaraInlineApi** (generatePromptedReflection, generateSofterReflection, generateDeeperReflection) | Entry text → EnhancedLumaraApi | ✅ Yes — **FIXED 2026-02-19:** All three paths now pass scrubbed text to `_enhancedApi.generatePromptedReflection`. Previously `generateSofterReflection` and `generateDeeperReflection` passed raw `entryText`; now use `PiiScrubber.rivetScrub(entryText)` and pass result | — |
| **LumaraShareService** | — | N/A — UnimplementedError in Firebase-only mode | No live egress |
| **lumara_veil_edge_integration.dart** | — | N/A — geminiSend call commented out | Active path uses fallback only |
| **PrivacyGuardrailInterceptor** | system, user | Block-on-PII (no scrub) | Not used in main flow |
| **AssemblyAI / STT** | Audio | N/A — transcript then scrubbed before LUMARA | — |
| **lumara_cloud_generate.dart** (Groq direct path) | system, user | ✅ Yes — **FIXED 2026-02-26:** PRISM scrub + `isSafeToSend` before `GroqService`; PII restore on response. When signed in, uses `lumaraSend` (already scrubbed). | Direct Groq path (API key, not proxy) now scrubs before send |
| **intelligence_summary_generator.dart** | Entries, annotations, CHRONICLE, patterns | ✅ Yes — **FIXED 2026-02-26:** PRISM scrub + `isSafeToSend` before Groq; PII restore on response | Was bypassing scrubbing; now scrubs synthesis prompt |
| **bug_report_dialog.dart** | description, userId, userEmail | ✅ Yes — **FIXED 2026-02-26:** Description scrubbed via `PiiScrubber.rivetScrub` before send and local storage | userId/email retained for support follow-up |

**Reversible maps:** Local restore only; never in request payloads. `VoiceConversationTurn.toRemoteJson()` and `VoiceSession.toRemoteJson()` omit `prism_reversible_map`; local JSON may include it for restore only — ensure backup/export flows that sync to cloud use remote serialization.

### 1.2 PII assertions verified

- All paths to Gemini go through `gemini_send` or a layer that passes scrubbed text; `SecurityException` and `isSafeToSend` not bypassed; correlation-resistant applied only to scrubbed text.
- **FeatureFlags.piiScrubbing** default `true`; if set `false`, `PiiScrubber.rivetScrubWithMapping` returns raw text — **any code path using PiiScrubber when flag is off could send PII.** Keep default `true`; do not expose a UI to disable; document that changing it is unsafe.
- **LumaraInlineApi** PII leak fixed: `generateSofterReflection` and `generateDeeperReflection` now pass scrubbed text to the enhanced API.

### 1.3 Red-team / test gaps

- Add unit test: with mocked Firebase callable, assert payload to proxy contains no raw PII when input has PII (e.g. contains `[EMAIL_1]`-style tokens).
- Add test: LumaraInlineApi `generateSofterReflection` / `generateDeeperReflection` with PII in entryText — assert only scrubbed text is passed to EnhancedLumaraApi.

---

## 2. Authentication & Authorization

- **Verified:** Firebase Auth is the identity provider. `FirebaseAuthService` (`lib/services/firebase_auth_service.dart`) provides `currentUser`, `getIdToken(forceRefresh)`, `signOut`, and token refresh listener. Sensitive screens (LUMARA, subscription, chronicle, home) use `currentUser`/`uid` for gating.
- **Backend enforcement:** Firebase callables **require auth** — in `functions/index.js`, `proxyGemini`, `getAssemblyAIToken`, `getUserSubscription`, `createCheckoutSession`, and others check `if (!request.auth)` and throw `HttpsError("unauthenticated", ...)`. UID and email are taken from `request.auth`; no client-only gate for these operations.
- **Phase/subscription access:** Subscription tier and AssemblyAI eligibility are determined server-side (getUserSubscription, getAssemblyAIToken). Phase history and export use `currentUser?.uid` on client; any backend that serves per-user data should also validate auth (callables do).
- **To audit:** Firestore Security Rules (if used for user data) and any REST endpoints; ensure no sensitive action is protected only by client checks.

---

## 3. Secrets & API Key Management

- **Gemini API key:** Non-streaming path uses Firebase `proxyGemini`; key stays in Firebase secrets (`GEMINI_API_KEY`). **Streaming path** (`geminiSendStream`) uses `LumaraAPIConfig` and builds URI with `key=$apiKey` — key is in process memory and in URL; not logged (only `apiKey.isNotEmpty` is logged). **Recommendation:** Prefer a streaming proxy (e.g. Firebase callable that streams) so the key never leaves the backend; or ensure streaming is only used when user has configured a key and accept client-side key for that path.
- **Backend secrets:** `functions/index.js` uses `defineSecret` for `GEMINI_API_KEY`, `ASSEMBLYAI_API_KEY`, `STRIPE_*`; keys not in repo.
- **AssemblyAI:** Token via callable `getAssemblyAIToken` (auth required); `lib/services/assemblyai_service.dart` caches with expiry. **Finding:** `assemblyai_provider.dart` logs token length and substring; reduce or remove in production.
- **API config:** `lib/arc/chat/config/api_config.dart` uses masked key in debug; no raw key in logs. Keys stored in SharedPreferences; ensure no export/backup includes config with keys. `toJson` includes `apiKey` — only persist to secure/local storage.
- **WisprFlow:** Logs URI and auth message with `replaceAll(_config.apiKey, '***')` — key redacted in logs.
- **Recommendation:** Ensure no token substring or raw key in production logs; guard all debugPrint/print that touch secrets with `kReleaseMode` or log level.

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

- **FIXED 2026-02-26:** `llm_bridge_adapter.dart` — logs now guarded with `kDebugMode`; removed response preview (could contain PII); user intent/phase/keywords no longer logged verbatim in production. `bug_report_dialog.dart` — debug prints guarded with `kDebugMode`.
- **Finding — PII in logs:** Several other files may still log user identifiers: `firebase_auth_service.dart`, `subscription_service.dart`, `subscription_management_view.dart`, `unified_transcription_service.dart`. `gemini_send.dart` uses `print()` for DEBUG GEMINI (guarded with `kDebugMode`). **Recommendation:** Continue guarding sensitive logs with `kDebugMode`.
- **Token/keys:** API key is not logged raw; WisprFlow redacts key with `'***'`. AssemblyAI provider logs token substring — reduce for production. api_config uses masked key.
- **Sentry:** Commented out in pubspec (`# sentry_flutter`); when enabled, ensure no PII or full request/response in breadcrumbs or context.
- **Recommendation:** Use release-mode guards or log levels to avoid logging email/UID/token in production; avoid logging request/response bodies; remove or guard `print()` in production for security-sensitive files.

---

## 8. Feature Flags & Bypasses

- **FeatureFlags** (`lib/state/feature_flags.dart`): `piiScrubbing`, `inlineLumara`, `phaseAwareLumara`, `analytics`, `useOrchestrator` — document which affect security; safe defaults (e.g. `piiScrubbing = true`). No runtime UI to disable PII scrubbing found.
- **skipTransformation:** Scrubbing always runs; no PII bypass.
- **To audit:** Any new flags that gate auth, scrubbing, or validation — require safe default and explicit justification for disabling.

---

## 9. Dependencies & Supply Chain

- **Note:** Dart SDK does not ship `dart pub audit`; use `dart pub outdated` and/or external CVE/dependency checks (e.g. Dependabot, Snyk) to track known vulnerabilities. Lockfile (`pubspec.lock`) is committed for reproducible builds.
- **Recommendation:** Run dependency checks periodically; upgrade critical packages when security advisories are published; document key packages (Firebase, cloud_functions, http/io, Hive) and their security posture.

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

- **Local deletion:** `SettingsCubit.deleteAllData(JournalRepository)` triggers delete of local journal data; reversible maps are device-only and deleted with app data. Chronicle and voice session data are stored locally; ensure "Delete All Data" and any account-deletion flow clear or anonymize all user data and do not leave reversible maps in backups.
- **Backend:** If Firestore or other backend stores user data, ensure account deletion or "delete my data" removes or anonymizes it; exports/backups must not re-expose deleted content.
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

- **Secrets:** Production API keys live in Firebase secrets (functions) and client-side in LumaraAPIConfig (user-configured); no hardcoded prod keys in repo. `String.fromEnvironment('GEMINI_API_KEY')` and similar used for optional/dev paths; ensure dev/staging config does not use prod keys.
- **Lockfile:** `pubspec.lock` present; dependencies pinned for reproducibility.
- **CI:** No GitHub Actions workflows found in repo; when CI is added, use secrets manager for any keys; never commit production secrets. Run dependency checks (e.g. `dart pub outdated`, Dependabot) periodically.

---

## 19. Audit Trail & Monitoring

- **To audit:** Whether sensitive actions (full export, account deletion, subscription change) are logged for incident response (without PII). How to detect abuse or anomalies (e.g. LLM call volume). Document audit/monitoring approach.

---

## 20. Deep Links & App Intents

- **Current use:** “Deeplink” in codebase refers to **internal** app navigation (e.g. `patterns://` in insight cards; `deeplinkAnchor` for in-app routing). No external deep-link or intent handler was found (no `getInitialLink`/`uriLink` in lib). Android manifest has no custom intent-filter for external URLs.
- **To audit:** If external deep links or intents are added, validate and sanitize URL/intent data before use for navigation or backend params; use allowlist for schemes/hosts.

---

## Summary

- **PII/egress:** Implemented and verified; all frontier-model paths scrub before send; reversible maps local-only. **Fixed:** LumaraInlineApi, lumara_cloud_generate (Groq direct path), intelligence_summary_generator, bug_report_dialog. Streaming path uses client-side API key — prefer proxy when possible.
- **Auth:** Backend callables enforce `request.auth`; signOut clears subscription and AssemblyAI caches; token refresh and dispose in place.
- **Secrets:** Gemini key in Firebase secrets for non-streaming path; streaming uses LumaraAPIConfig. AssemblyAI via callable; API config masks keys in logs. Recommendation: mask or disable token substring and email/UID in production logs.
- **Storage/crypto:** Flutter secure storage and Keychain/Secure Enclave used for sensitive data; no reversible maps in remote/backup payloads; `toRemoteJson()` correctly omits prism maps.
- **Network:** No certificate validation disabled found.
- **Session:** Logout clears token caches; ID token refresh and subscription cleanup verified.
- **Rate limiting:** Client passes entryId/chatId; backend returns tier/limits; proxyGemini does not yet enforce rate limit in code — recommend adding or documenting where enforced.
- **Deep links:** Internal only (patterns://); no external handler found.
- **User protection:** Safe defaults (piiScrubbing = true); no UI to disable scrubbing; guard logs in production; LumaraInlineApi PII fix applied. Sections 4, 14, 15, 17, 19 remain “to audit” for next run (input validation detail, data retention/deletion flows, compliance touchpoints, sensitive UI/clipboard, audit trail). Update this document when adding features or before release/security review.

---

## Open Risks & Action Items (prioritized for user protection)

| Priority | Item | Action |
|----------|------|--------|
| High | LumaraInlineApi PII leak | **Done** — generateSofterReflection and generateDeeperReflection now pass scrubbed text. |
| High | lumara_cloud_generate Groq path | **Done 2026-02-26** — PRISM scrub + isSafeToSend before GroqService; PII restore on response. |
| High | Intelligence summary PII egress | **Done 2026-02-26** — PrismAdapter scrub before Groq; PII restore on response. |
| Medium | Bug report PII | **Done 2026-02-26** — Description scrubbed with PiiScrubber before send and local storage. |
| Medium | llm_bridge_adapter logging | **Done 2026-02-26** — Logs guarded with kDebugMode; response preview removed. |
| Medium | Streaming path API key | Documented in `geminiSendStream` doc comment; prefer non-streaming proxy when possible. |
| Medium | Production logging | **Done** — gemini_send, firebase_auth_service, subscription_service, assemblyai_service guard print/debugPrint with `kDebugMode`. |
| Medium | Rate limiting | **Done** — proxyGroq enforces free-tier daily limit (50/day) via Firestore `lumaraDailyUsage`. |
| Low | Egress payload test | **Done** — `test/services/egress_pii_and_lumara_inline_test.dart`: PrismAdapter and PiiScrubber egress tests. |
| Low | LumaraInlineApi test | **Done** — same file: rivetScrub used for softer/deeper reflection removes PII. |
| Low | Dependency checks | Use dart pub outdated and/or Dependabot/Snyk; no dart pub audit in SDK. |
