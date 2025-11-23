# Calendar Scroll Sync Fix Report

**Date:** November 21, 2025
**Version:** 2.1.27
**Status:** ✅ Fixed

## Issue Description
Users reported a visual desynchronization when using the "Jump to Date" feature in the journal timeline. After selecting a specific date, the main timeline would scroll correctly, but the weekly calendar header (`CalendarWeekTimeline`) would often jump approximately one week *ahead* of the selected date. This required users to manually scroll the calendar back to see the selected date.

## Root Cause Analysis
Investigation revealed two primary contributing factors:

1.  **Inaccurate Height Estimation**: The `InteractiveTimelineView` used a hardcoded `_timelineCardHeight` of `280.0` to estimate the index of visible items. However, the actual rendered height of many cards was significantly smaller (closer to `180.0`). This caused the `AutoScrollController` to calculate an index that was "further down" the list than reality, leading the calendar logic to believe a later date was visible.
2.  **Race Condition during Animation**: When `scrollToIndex` was called, it triggered multiple scroll notifications. The `CalendarWeekTimeline` listened to these notifications and attempted to update its state *during* the scroll animation. Because of the height estimation error, intermediate scroll values could trigger a "next week" update before the scroll settled.

## Implemented Solution

### 1. Refined Height Constant
We reduced the `_timelineCardHeight` constant in `InteractiveTimelineView` from `280.0` to `180.0`. This provides a more conservative and accurate estimate for the `scroll_to_index` logic, ensuring that the calculated index aligns better with the actual visible elements.

### 2. Programmatic Scroll Guard
We introduced a `_isProgrammaticScroll` flag in `TimelineView`.
- **Logic**: When `_jumpToDate` is initiated, this flag is set to `true`.
- **Effect**: The `onVisibleEntryDateChanged` callback, which updates the calendar, is **blocked** while this flag is true.
- **Reset**: The flag is reset to `false` only after the scroll animation completes (plus a small buffer).

This ensures that the calendar does not attempt to update itself based on transient scroll positions during the jump animation. It only updates once the timeline has settled on the correct target date.

## Verification
- **Manual Test**: Verified that jumping to various dates (past, present, future) results in the calendar header showing the correct week containing the selected date.
- **Edge Cases**: Tested jumping to dates at the very beginning and end of the timeline.

## Conclusion
The fix provides a smooth and accurate navigation experience, eliminating the visual disconnect between the timeline and the calendar header.
