# Timeline Infinite Rebuild Loop

Date: 2025-10-29
Status: Resolved ✅
Area: Timeline UI (Flutter)

Summary
- Timeline was stuck in an infinite rebuild loop due to a post-frame callback triggering parent setState repeatedly.
- Introduced previous state tracking and conditional notifications to break the loop; guarded parent setState.

Impact
- High CPU usage, potential UI freeze, noisy logs, degraded UX.

Root Cause
1) `BlocBuilder` in `InteractiveTimelineView` scheduled `_notifySelectionChanged()` via `addPostFrameCallback` on every rebuild.
2) Callback triggered `setState()` in parent `TimelineView`, causing child rebuild and re-triggering again (feedback loop).

Fix
- Add `_previousSelectionMode`, `_previousSelectedCount`, `_previousTotalEntries` to track last notification state.
- Only notify when selection state changes; update previous values immediately.
- Guard parent to only call `setState()` when values actually change.

Files
- `lib/arc/ui/timeline/widgets/interactive_timeline_view.dart`
- `lib/arc/ui/timeline/timeline_view.dart`

Verification
- Timeline rebuilds only on actual state change or interaction. No loops observed.

References
- `docs/status/TIMELINE_REBUILD_LOOP_FIX_OCT_29_2025.md`


