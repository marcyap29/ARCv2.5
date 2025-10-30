# Timeline Infinite Rebuild Loop Fix - October 29, 2025

## Problem
Timeline screen was stuck in an infinite rebuild loop, continuously rebuilding with the same state, causing:
- App performance degradation
- Excessive CPU usage
- Potential UI freezing
- Debug logs flooded with repeated rebuild messages

## Root Cause
1. `BlocBuilder` in `InteractiveTimelineView` was calling `_notifySelectionChanged()` on every rebuild via `addPostFrameCallback`
2. This callback triggered `setState()` in the parent `TimelineView` widget
3. Parent rebuild caused child rebuild, which triggered the callback again, creating an infinite loop

## Solution
1. **Added State Tracking**: Introduced `_previousSelectionMode`, `_previousSelectedCount`, and `_previousTotalEntries` to track previous notification state
2. **Conditional Notifications**: Only call `_notifySelectionChanged()` when selection state actually changes (not on every rebuild)
3. **Immediate State Updates**: Update previous values immediately before scheduling callback to prevent race conditions
4. **Parent Widget Guard**: Added conditional check in parent widget to only call `setState()` when values actually change

## Files Modified
- `lib/arc/ui/timeline/widgets/interactive_timeline_view.dart`
- `lib/arc/ui/timeline/timeline_view.dart`

## Status
✅ **PRODUCTION READY**

## Testing
Timeline rebuilds only when actual data changes or user interacts with selection. No more infinite rebuild loops.

