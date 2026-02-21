# BUG-CHRONICLE-001: CHRONICLE Yearly Layer Routing Returns Empty Context Early in Year

**Version:** 1.0.0 | **Date Logged:** 2026-02-20 | **Status:** Fixed/Verified

---

#### 🐛 **BUG DESCRIPTION**

- **Issue Summary:** In January, February, and March, CHRONICLE queries and Integrate-mode responses routed to `ChronicleLayer.yearly` returned empty or stale context because the yearly synthesizer requires ≥3 monthly aggregation files to produce a valid yearly summary. Before the fix, the router unconditionally selected the yearly layer for pattern/trajectory intents and integrate mode, regardless of calendar month.
- **Affected Components:** `lib/chronicle/query/query_router.dart` (`_inferReflectLayer`, integrate-mode routing); `ChronicleLayer.yearly`; Integrate and Reflect engagement modes
- **Reproduction Steps:**
  1. Open the app in January, February, or March.
  2. Ask LUMARA a pattern or trajectory question (e.g., "What patterns do you see this year?") or use Integrate mode.
  3. Observe that CHRONICLE context is empty or shows stale prior-year data — LUMARA has no current-year history to reference.
- **Expected Behavior:** When the current-year yearly aggregation is not yet populated (month < 4), route to `ChronicleLayer.monthly` (which always has recent data) and use monthly themes for integration/patterns.
- **Actual Behavior:** Router selected `ChronicleLayer.yearly` unconditionally for year-based queries and integrate mode, returning empty context for users in the first quarter of the year.
- **Severity Level:** High (LUMARA gives uninformed responses lacking context for 3 months of each year)
- **First Reported:** 2026-02-20 | **Reporter:** Documentation & Configuration Manager (DOCS/claude.md)

---

#### 🔧 **FIX IMPLEMENTATION**

- **Fix Summary:** Added `month >= 4` guard before routing to `ChronicleLayer.yearly`; early-year (months 1–3) falls back to `ChronicleLayer.monthly`. Applied to both `_inferReflectLayer` and integrate-mode routing. Also added recency signals (→ monthly) and long-term signals (→ multi-year) for finer routing control.
- **Technical Details:**
  - `_inferReflectLayer`: New decision order — recency signals → monthly; long-term signals → multi-year; year keyword or yearly intent → yearly **only if `month >= 4`**, else monthly; month keyword → monthly; default → monthly. Added `currentDate` parameter for testability.
  - Integrate mode: `integrateLayer = now.month >= 4 ? ChronicleLayer.yearly : ChronicleLayer.monthly`.
  - Recency signal regex: `recently|lately|this week|past few days|yesterday|today|right now`.
  - Long-term signal regex: `long-term|over the years|since I started|years ago|multi-year|all time`.
- **Files Modified:**
  - `lib/chronicle/query/query_router.dart` (v3.3.56)
- **Testing Performed:** Code review; routing logic validated against calendar scenarios. `currentDate` injection point enables unit testing.
- **Fix Applied:** 2026-02-20 | **Implementer:** Development session (v3.3.56)

---

#### 🎯 **RESOLUTION ANALYSIS**

- **Root Cause:** The yearly synthesizer (`YearlySynthesizer`) aggregates monthly files and requires ≥3 months to produce meaningful output. The router did not account for this dependency and assumed the yearly layer was always populated.
- **Fix Mechanism:** Calendar-aware routing: check `currentDate.month` before selecting yearly aggregation. Route to monthly as a safe fallback when yearly data is statistically absent.
- **Impact Mitigation:** Users in January–March now receive valid monthly-layer context in CHRONICLE responses instead of empty/stale yearly context. Integrate mode and reflect pattern queries both benefit.
- **Prevention Measures:** The `currentDate` parameter makes the routing logic easily unit-testable. Future layer-selection logic should apply the same "is this layer populated?" heuristic before selection.
- **Related Issues:** CHRONICLE speed-tiered context system; `ChronicleContextBuilder._compressForSpeed` budget-check fix (v3.3.56, same release)

---

#### 📋 **TRACKING INFORMATION**

- **Bug ID:** BUG-CHRONICLE-001
- **Component Tags:** #chronicle #lumara #phase-system #high
- **Version Fixed:** v3.3.56
- **Verification Status:** ✅ Confirmed fixed — routing logic reviewed; early-year path now selects monthly layer
- **Documentation Updated:** 2026-02-20 (this record); CHANGELOG v3.3.56; ARCHITECTURE.md
