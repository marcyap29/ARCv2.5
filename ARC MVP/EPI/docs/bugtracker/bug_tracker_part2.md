# EPI MVP - Bug Tracker (Part 2: November 2025)

**Version:** 2.1.32  
**Last Updated:** January 1, 2026  
**Coverage:** November 2025 releases (v2.1.27 - v2.1.42)

---

## Resolved Issues (v2.1.32)

### Timeline Date Jumping Inaccuracy
- **Issue**: When selecting a date (e.g., 10/13/2025), the timeline would jump to an incorrect date (e.g., 09/24/2025).
- **Root Cause**: The date jumping logic was using unfiltered entries, while the displayed timeline uses filtered and deduplicated entries, causing index mismatches.
- **Resolution**: 
  1. Updated `_jumpToDate` to use the same filtering and deduplication logic as `InteractiveTimelineView._getFilteredEntries`
  2. Ensures the calculated scroll index matches what's actually displayed in the timeline
  3. Added debug logging for troubleshooting date matching
- **Status**: ✅ Fixed
- **Related Record**: [timeline-ordering-timestamps.md](records/timeline-ordering-timestamps.md)

### Calendar & Arcform Preview Clipping
- **Issue**: The calendar week header and arcform preview containers were clipping into each other when scrolling.
- **Root Cause**: Calendar header height (76px) didn't account for month text display, and arcform preview had insufficient top margin.
- **Resolution**: 
  1. Increased calendar header height from 76px to 108px to properly account for month text
  2. Added proper container wrapper with background color for calendar header
  3. Increased arcform preview top margin from 8px to 16px to prevent clipping with pinned calendar header
- **Status**: ✅ Fixed

---

## Resolved Issues (v2.1.27)

### Calendar Scroll Sync Desynchronization
- **Issue**: Selecting a date in the "Jump to Date" picker caused the weekly calendar to jump approximately one week ahead of the target date.
- **Root Cause**: 
  1. `_timelineCardHeight` constant (280.0) in `InteractiveTimelineView` was overestimating actual item height, leading to incorrect index calculations.
  2. `CalendarWeekTimeline` was reacting to scroll notifications generated during the programmatic "jump" animation, causing it to drift.
- **Resolution**:
  1. Reduced `_timelineCardHeight` to 180.0 for better accuracy.
  2. Implemented `_isProgrammaticScroll` flag in `TimelineView` to suppress calendar updates during jump animations.
- **Status**: ✅ Fixed

### Saved Chats Navigation Issue
- **Issue**: Clicking on "Saved Chats" in Chat History did not navigate to a list of saved chats, making them inaccessible.
- **Root Cause**: Missing dedicated screen and navigation logic for the saved chats section.
- **Resolution**: Created `SavedChatsScreen` and updated `EnhancedChatsScreen` to navigate to it.
- **Status**: ✅ Fixed

---

**Status**: ✅ Complete  
**Last Updated**: January 1, 2026

