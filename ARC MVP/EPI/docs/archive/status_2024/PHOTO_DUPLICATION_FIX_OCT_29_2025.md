# Photo Duplication Fix in View Entry Screen

**Date**: October 29, 2025  
**Status**: ✅ Complete  
**Branch**: arcx export

## Overview

Fixed bug where photos appeared twice when viewing journal entries - once in the main content area grid and again in the "Photos (N)" section below the text.

## Problem

When viewing an entry in view-only mode, photos were displayed twice:
1. **Main Grid**: Photos appeared in a 3x3 grid at the top of the entry content
2. **Photos Section**: Photos appeared again in the "Photos (N)" section below the text

This created visual duplication and confusion for users.

## Root Cause

Two separate methods were both displaying photos:

1. **`_buildContentView()`** (line 2267):
   - Called when `widget.isViewOnly && !_isEditMode` is true
   - Converted photo attachments to MediaItems and displayed them in a Wrap widget
   - Intended to show content with inline thumbnails for view-only mode

2. **`_buildInterleavedContent()`** (line 1417):
   - Called for all entries (both view and edit modes)
   - Displayed photos via `_buildPhotoThumbnailGrid()` method
   - Shows photos in a proper "Photos (N)" section with header

**Flow**:
```
_buildAITextField() 
  ↓ (if view-only)
_buildContentView() → Shows photos in Wrap widget ❌
  ↓
_buildInterleavedContent() → Shows photos via _buildPhotoThumbnailGrid() ❌
```

Both methods were rendering photos, causing duplication.

## Solution

Removed photo display from `_buildContentView()` method:

**Before**:
- `_buildContentView()` converted attachments to MediaItems and displayed them in a Wrap widget
- Photos appeared twice - once here and once in `_buildPhotoThumbnailGrid()`

**After**:
- `_buildContentView()` now only displays text content
- Photos are displayed only once via `_buildInterleavedContent()` -> `_buildPhotoThumbnailGrid()`
- Added comment explaining that photos are handled separately

## Files Modified

- `lib/ui/journal/journal_screen.dart`:
  - Removed photo display logic from `_buildContentView()` method
  - Simplified method to only show text content
  - Added comment explaining photo display is handled separately

## Testing

### Before Fix
- Photos appeared twice when viewing entries
- Main grid showed 9 photos (with duplicates)
- "Photos (N)" section showed same photos again
- Visual clutter and confusion

### After Fix
- Photos appear only once in the "Photos (N)" section
- Clean layout with no duplication
- Better user experience

## Code Changes

```dart
// Before: _buildContentView() displayed photos
Widget _buildContentView(ThemeData theme) {
  final mediaItems = _entryState.attachments
      .whereType<PhotoAttachment>()
      .map((attachment) => MediaItem(...))
      .toList();
  
  return Container(
    child: Column(
      children: [
        Text(_entryState.text),
        if (mediaItems.isNotEmpty) ...[
          Wrap(children: mediaItems.map(...).toList()), // ❌ Duplicate display
        ],
      ],
    ),
  );
}

// After: _buildContentView() only shows text
Widget _buildContentView(ThemeData theme) {
  // In view-only mode, just show the text content
  // Photos are displayed separately via _buildInterleavedContent -> _buildPhotoThumbnailGrid
  return Container(
    child: Column(
      children: [
        Text(_entryState.text), // ✅ Only text
      ],
    ),
  );
}
```

## Related Issues

- See `docs/bugtracker/Bug_Tracker.md` for bug tracking entry
- See `docs/changelog/CHANGELOG.md` for changelog entry

## Notes

- Photos are now consistently displayed via `_buildInterleavedContent()` -> `_buildPhotoThumbnailGrid()` for both view and edit modes
- The "Photos (N)" section provides a clean, organized display of all photos
- This fix ensures consistent photo display across all entry viewing modes

