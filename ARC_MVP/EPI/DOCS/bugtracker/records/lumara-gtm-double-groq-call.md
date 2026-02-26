# GTMSessionFetcher "was already running" — Concurrent proxyGroq Calls

**Document Version:** 1.0.0  
**Last Updated:** 2026-02-24  
**Change Summary:** Initial record.  
**Source:** Runtime log analysis — session Feb 24 2026.

---

### BUG-LUMARA-GTM-001: GTMSessionFetcher duplicate proxyGroq call warning

**Version:** 1.1.0 | **Date Logged:** 2026-02-24 | **Status:** Fixed

#### 🐛 **BUG DESCRIPTION**
- **Issue Summary:** iOS logs show `GTMSessionFetcher (proxyGroq) was already running` after the user sends a chat message. The warning fires after the agentic loop completes and just before (or concurrent with) the main LLM response arriving. The assistant response IS successfully added — no data loss — but the duplicate-call warning indicates two simultaneous or closely spaced proxyGroq HTTP connections.
- **Affected Components:**
  - `lib/arc/chat/bloc/lumara_assistant_cubit.dart` — `sendMessage` flow
  - `lib/arc/chat/services/enhanced_lumara_api.dart` — reflection call chain
  - `lib/services/groq_send.dart` — `proxyGroq` callable
  - iOS GTMSessionFetcher (underlying Firebase Functions HTTP client)
- **Reproduction Steps:**
  1. Open app (signed in), network suffers a brief TCP error (`error 0:50`).
  2. Send a short message (e.g., "Test") via LUMARA chat.
  3. Observe `GTMSessionFetcher ... proxyGroq was already running` in device logs.
  4. Assistant response still arrives and is displayed.
- **Expected Behavior:** A single proxyGroq HTTP call per user message; no GTMSessionFetcher warning.
- **Actual Behavior:** Two proxyGroq calls land close enough together that the iOS HTTP library complains about reuse.
- **Severity Level:** Medium — cosmetic in most cases; but the duplicate call wastes quota and could return a mismatched response in edge cases.
- **First Reported:** 2026-02-24 | **Reporter:** User (runtime log)

#### 🔧 **FIX IMPLEMENTATION**

**Fix 1 (Applied):** Close the `savePendingInput` race window in `sendMessage`.

- **Root cause (partial):** `_savePendingInput` was called at line ~693, well after `isProcessing: true` was emitted at line ~549. Although Dart is single-threaded, the many `await` calls between those two points (crisis check, session creation, etc.) created a theoretical window where `resubmitPendingInput` could observe a pending input while `isProcessing` was still `false`, triggering a second `sendMessage`.
- **Fix:** Moved `_savePendingInput` to immediately after the `emit(isProcessing: true)` line, with no async gap between the guard check and the save. The duplicate call at the original location was removed.
- **Files Modified:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

**Fix 2 (Applied 2026-02-24):** Keyword pre-filter skips LLM classification for non-agent messages.

- **Root cause (primary / confirmed):** `_tryChatAgentPath` (line ~744) always called `classifyIntent`, which internally invokes `groqSend` (via `generateWithLumaraCloud` → `proxyGroq`) for LLM-based intent classification. For messages that are clearly not research/writing tasks, this classification fires a proxyGroq call that is immediately followed by the main `_arcLLM.chat()` proxyGroq call. After a TCP failure leaves a GTMSessionFetcher instance in a dirty state, the second sequential call triggers the "already running" iOS warning.
- **Fix:** Added a fast keyword pre-filter at the top of `_tryChatAgentPath`. If the message is ≤15 chars or contains none of the agent trigger keywords (`research`, `write `, `draft `, `article`, `essay`, `report`, `search for`, `find information`, `look up`, `summarize`, `compile`), the function returns `false` immediately without invoking the LLM classifier. This eliminates the extra `groqSend` call for the overwhelming majority of conversational messages.
- **Files Modified:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart` (`_tryChatAgentPath`)
- **Status:** Applied.

#### 🎯 **RESOLUTION ANALYSIS**
- **Root Cause Summary:**
  1. (Minor / theoretical) `_savePendingInput` was called too late in `sendMessage`, leaving a window where `resubmitPendingInput` could observe a pending input while `isProcessing=false`. → Fixed.
  2. (Primary / confirmed pattern) `_tryChatAgentPath` uses `groqSend` for intent classification and the main response path also uses `groqSend`, producing two back-to-back `proxyGroq` calls. After a TCP error the previous GTMSessionFetcher connection may not have fully closed, causing the "already running" warning on the second call. → Tracked.
- **Impact Mitigation:** Fix 1 prevents the resubmit race. The GTMSessionFetcher warning is documented in `FIREBASE.md` as "usually transient" and does not prevent the response from arriving.
- **Fix 3 (Applied 2026-02-24):** Retry on `[firebase_functions/internal]` in `groq_send.dart`.
  - When `groqSend` catches an exception whose message contains `firebase_functions/internal`, `INTERNAL`, or `already running`, it waits 2.5s and retries once before rethrowing. This allows the GTMSessionFetcher from a prior call to release before the retry.
- **Prevention Measures:**
  - Never call `_savePendingInput` before `isProcessing: true` is emitted.
  - Audit all code paths in `sendMessage` that invoke `groqSend` to ensure at most one `proxyGroq` call is in-flight per user message.
- **Related Issues / References:**
  - `FIREBASE.md` §"Common proxyGroq Issues" — GTMSessionFetcher warning note
  - Previous fix: `maxAttempts = 1` in `sendMessage` retry loop (prevents outer-loop retries from causing concurrent calls)

#### 📋 **TRACKING INFORMATION**
- **Bug ID:** BUG-LUMARA-GTM-001
- **Component Tags:** #lumara_chat #groq #firebase #ios #networking #gtm_session_fetcher
- **Version Fixed:** 2026-02-24 session (Fix 1 + Fix 2)
- **Verification Status:** Both fixes applied; awaiting runtime confirmation
- **Documentation Updated:** 2026-02-24
