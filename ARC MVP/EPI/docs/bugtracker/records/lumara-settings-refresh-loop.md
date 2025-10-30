# LUMARA Settings Refresh Loop During Model Downloads

Date: 2025-01-12
Status: Resolved ✅
Area: Settings UI, Model downloads

Summary
- Excessive API refreshes and terminal spam during model download progress updates.

Impact
- UI jank/blocking, noisy logs, degraded UX.

Root Cause
- Progress updates triggered frequent refreshes without debouncing or completion tracking.

Fix
- Add completion tracking set to avoid duplicate processing.
- Add 5s cooldown between refreshes; reduce timeouts; increase UI debounce to 500ms.
- Throttle logging.

Files
- `lib/lumara/ui/lumara_settings_screen.dart`

Verification
- Smooth downloads; clean logs; no refresh loops.

References
- `docs/bugtracker/Bug_Tracker.md` (LUMARA Settings Refresh Loop Fix)

