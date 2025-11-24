# EPI MVP - Bug Tracker

**Version:** 2.1.36  
**Last Updated:** January 2025

## Resolved Issues (v2.1.36)

### CreatedAt Changing on Entry Updates
- **Issue**: When updating an existing journal entry, the `createdAt` timestamp could be changed if user selected a new date/time, breaking Time Echo reminders and historical accuracy.
- **Root Cause**: `updateEntryWithKeywords` method allowed `createdAt` to be modified when user selected a new date/time.
- **Resolution**: 
  1. Modified `updateEntryWithKeywords` to always preserve original `createdAt`
  2. Added `originalCreatedAt` storage in metadata for safety
  3. Added `originalCreatedAt` getter to `JournalEntry` model
  4. Updated all reflective query services to use `originalCreatedAt` instead of `createdAt`
  5. `updatedAt` always reflects last modification time
- **Impact**: Time Echo reminders now use correct historical dates, ensuring accurate periodic reflections
- **Status**: ✅ Fixed

## Resolved Issues (v2.1.35)

### Phase Detection Discovery Default Issue
- **Issue**: Discovery phase was defaulting too often, overriding other phases incorrectly.
- **Root Cause**: `getHighestScoringPhase` defaulted to Discovery if all scores were 0.0, and normalization didn't ensure at least one phase had a non-zero score.
- **Resolution**: 
  1. Added safety check in normalization to assign equal probability if all scores are zero
  2. Normalization ensures phases with evidence get minimum scores
  3. Discovery only wins if it has the highest score, not as a default
- **Status**: ✅ Fixed

### Older Entries Showing Wrong Phase in Dropdown
- **Issue**: Older entries showed "Consolidation" in dropdown even though Discovery was first in list.
- **Root Cause**: Older entries had `phase` set but no `autoPhase` or `legacyPhaseTag`, so `computedPhase` fell back to old `phase` field.
- **Resolution**: 
  1. Added `ensureLegacyPhaseTag()` method to populate `legacyPhaseTag` from `phase` for older entries
  2. Updated `computedPhase` getter to handle legacy phase tag population dynamically
  3. Auto-populate and save `legacyPhaseTag` when older entries are displayed
- **Status**: ✅ Fixed

### Build Error: List to Set Conversion
- **Issue**: Build error: `The argument type 'List<String>' can't be assigned to the parameter type 'Set<String>'` in `rivet_models.g.dart`.
- **Root Cause**: Generated Hive adapter was trying to assign List to Set field.
- **Resolution**: Added `.toSet()` conversion in generated file.
- **Status**: ✅ Fixed

## Resolved Issues (v2.1.34)

### ZIP Export Empty Entries Error
- **Issue**: When exporting ZIP files with "All Entries" selected, export would fail with "No entries to export" error even though entries existed.
- **Root Cause**: Missing validation checks before calling export service and incorrect photo counting logic.
- **Resolution**: 
  1. Added validation in export screen to check filteredEntries.isEmpty before calling service
  2. Added validation in McpPackExportService to check entries list at start
  3. Fixed photo counting to check for both 'image' and 'photo' kinds (MediaType.name returns 'image')
  4. Added debug logging to track entry count and date range selection
- **Status**: ✅ Fixed

### ZIP Export Navigation Loop
- **Issue**: After completing ZIP export, clicking "OK" on success dialog would show export screen again, causing navigation loop.
- **Root Cause**: Progress dialog wasn't closed before showing success dialog, and navigation wasn't handled properly.
- **Resolution**: 
  1. Close progress dialog before showing success dialog
  2. Navigate back to MCP Management screen when clicking OK or Share
  3. Added barrierDismissible: false to prevent accidental dismissal
- **Status**: ✅ Fixed

### ZIP Export Photo Count Display
- **Issue**: Photos were exported but not counted correctly in export summary (showed 0 photos).
- **Root Cause**: Media nodes use MediaType.name which is 'image' for photos, but code was checking for 'photo'.
- **Resolution**: Updated counting logic to check for both 'image' and 'photo' kinds.
- **Status**: ✅ Fixed

## Resolved Issues (v2.1.32)

### Timeline Date Jumping Inaccuracy
- **Issue**: When selecting a date (e.g., 10/13/2025), the timeline would jump to an incorrect date (e.g., 09/24/2025).
- **Root Cause**: The date jumping logic was using unfiltered entries, while the displayed timeline uses filtered and deduplicated entries, causing index mismatches.
- **Resolution**: 
  1. Updated `_jumpToDate` to use the same filtering and deduplication logic as `InteractiveTimelineView._getFilteredEntries`
  2. Ensures the calculated scroll index matches what's actually displayed in the timeline
  3. Added debug logging for troubleshooting date matching
- **Status**: ✅ Fixed

### Calendar & Arcform Preview Clipping
- **Issue**: The calendar week header and arcform preview containers were clipping into each other when scrolling.
- **Root Cause**: Calendar header height (76px) didn't account for month text display, and arcform preview had insufficient top margin.
- **Resolution**: 
  1. Increased calendar header height from 76px to 108px to properly account for month text
  2. Added proper container wrapper with background color for calendar header
  3. Increased arcform preview top margin from 8px to 16px to prevent clipping with pinned calendar header
- **Status**: ✅ Fixed

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
