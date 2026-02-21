# BUG-PRISM-001: LumaraInlineApi PII Egress — Unscrubed Text Sent to Cloud LLM

**Version:** 1.0.0 | **Date Logged:** 2026-02-19 | **Status:** Fixed/Verified

---

#### 🐛 **BUG DESCRIPTION**

- **Issue Summary:** `LumaraInlineApi.generateSofterReflection()` and `generateDeeperReflection()` passed raw, unscrubed user text directly to `EnhancedLumaraApi`, bypassing PRISM/PiiScrubber before the cloud LLM call. PII (names, dates, places) in journal entries could be transmitted verbatim to cloud APIs.
- **Affected Components:** `lib/services/lumara/lumara_inline_api.dart`; `EnhancedLumaraApi`; PRISM / PiiScrubber pipeline
- **Reproduction Steps:**
  1. Write a journal entry containing personal names or identifying information.
  2. Trigger a "softer" or "deeper" inline reflection from `LumaraInlineApi`.
  3. Observe that the raw entry text (not scrubbed) was passed to the cloud LLM payload.
- **Expected Behavior:** All journal text sent to cloud APIs must pass through `PrismAdapter`/`PiiScrubber` first; only scrubbed text leaves the device.
- **Actual Behavior:** Raw entry text was forwarded directly, skipping the scrubbing layer.
- **Severity Level:** Critical (privacy violation — PII egress to cloud LLM)
- **First Reported:** 2026-02-19 (DevSecOps audit) | **Reporter:** DevSecOps Security Auditor (DOCS/claude.md)

---

#### 🔧 **FIX IMPLEMENTATION**

- **Fix Summary:** `generateSofterReflection` and `generateDeeperReflection` now pass scrubbed text (via `PrismAdapter`) to `EnhancedLumaraApi` instead of raw user text.
- **Technical Details:** Added PRISM scrub step in both methods before forwarding to `EnhancedLumaraApi`; the scrubbed payload replaces the raw `userText` argument.
- **Files Modified:**
  - `lib/services/lumara/lumara_inline_api.dart` (v3.3.49)
- **Testing Performed:** New test `test/services/egress_pii_and_lumara_inline_test.dart` (added v3.3.50) — verifies egress PII scrubbing (PrismAdapter, PiiScrubber.rivetScrub) and that LumaraInlineApi softer/deeper paths use scrubbed text only. Also addressed in `DEVSECOPS_SECURITY_AUDIT.md`.
- **Fix Applied:** 2026-02-19 | **Implementer:** Security review / DevSecOps (session)

---

#### 🎯 **RESOLUTION ANALYSIS**

- **Root Cause:** Initial implementation of inline reflection shortcuts (`generateSofterReflection`, `generateDeeperReflection`) forwarded the convenience `userText` parameter directly to the LLM API without running the standard PRISM scrub pipeline that the main LUMARA chat path applies.
- **Fix Mechanism:** Both methods now run scrubbing before constructing the API payload, consistent with all other EnhancedLumaraApi call sites.
- **Impact Mitigation:** PII (names, dates, places, phone numbers, etc.) is now token-replaced before any cloud LLM call for inline reflections. Reversible map stays on-device only.
- **Prevention Measures:** 1) Egress tests in `egress_pii_and_lumara_inline_test.dart` act as regression gate. 2) DevSecOps audit checklist in `DEVSECOPS_SECURITY_AUDIT.md` includes inline API egress paths. 3) Any new API call site that forwards user text to cloud must route through `PrismAdapter` or the test suite will catch it.
- **Related Issues:** DevSecOps Security Audit (DOCS/DEVSECOPS_SECURITY_AUDIT.md); PiiScrubber.rivetScrub; PrismAdapter

---

#### 📋 **TRACKING INFORMATION**

- **Bug ID:** BUG-PRISM-001
- **Component Tags:** #lumara #privacy #prism #cloud-functions #critical
- **Version Fixed:** v3.3.49 (fix); v3.3.50 (tests / verified)
- **Verification Status:** ✅ Confirmed fixed — automated egress tests pass
- **Documentation Updated:** 2026-02-20 (this record); DEVSECOPS_SECURITY_AUDIT.md (2026-02-19)
