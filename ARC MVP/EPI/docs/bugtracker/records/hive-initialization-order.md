# Hive Initialization Order Errors

Date: 2025-10-29
Status: Resolved ✅
Area: App bootstrap, Rivet/Hive

Summary
- App startup failed due to services using Hive before initialization and duplicate adapter registration errors.

Impact
- Startup crashes, adapter conflicts, inconsistent initialization state.

Root Cause
- Parallel service init allowed `MediaPackTrackingService` and Rivet to touch Hive before `Hive.initFlutter()`.
- Adapter registration attempted twice, causing duplicate registration exceptions.

Fix
- Sequentialize initialization: initialize Hive first, then dependent services.
- Wrap each adapter registration in try/catch; handle "already registered" gracefully; remove rethrows.

Files
- `lib/main/bootstrap.dart`
- `lib/atlas/rivet/rivet_storage.dart`

Verification
- App boots cleanly without Hive initialization or duplicate adapter errors.

References
- `docs/status/HIVE_INITIALIZATION_FIX_OCT_29_2025.md`

