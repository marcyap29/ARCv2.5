# ARCX Export Photo Directory Mismatch Fix

**Date:** October 31, 2025  
**Branch:** `photo-gallery-scroll`  
**Status:** ✅ RESOLVED

## Problem

ARCX export was failing to include photos in the final archive, even though photos were being processed successfully by `McpPackExportService`. The exported archive was only ~368KB, indicating no photos were included.

**Symptoms:**
- Exported `.arcx` files were significantly smaller than expected (< 1MB)
- Terminal logs showed `McpPackExportService` successfully processing photos: "📹 Added image: [filename] ([bytes] bytes)"
- ARCX export logs showed: "Extracted 32 journal nodes, 0 photo nodes"
- Photo files were being extracted correctly to `media/photos/` directory
- Photo node JSONs were present in extracted ZIP structure

## Root Cause

**Directory Name Mismatch**: `McpPackExportService` writes photo node JSON files to `nodes/media/photos/` (plural), but `ARCXExportService` was reading from `nodes/media/photo/` (singular).

### Technical Details

1. **McpPackExportService writes to:**
   - Photo node JSONs: `nodes/media/photos/{id}.json` (uses `mediaSubDir = 'photos'` for images)
   - Photo files: `media/photos/{sha256}.jpg`

2. **ARCXExportService was reading from:**
   - `nodes/media/photo/` (singular) - directory that doesn't exist

3. **Result:**
   - Photo node JSONs were never found, so `photoNodes` list remained empty
   - Even though photo files were extracted correctly, they weren't referenced in the final payload

## Solution

Updated `ARCXExportService.exportSecure()` to check both directory names for compatibility:

1. **Primary Check**: Try `nodes/media/photos/` (plural) first (where files actually are)
2. **Fallback Check**: If not found, try `nodes/media/photo/` (singular) for backward compatibility
3. **Recursive Search**: If neither directory exists, perform recursive search for photo node JSON files
4. **Enhanced Logging**: Added detailed logging to track photo node discovery and copying

### Code Changes

**File**: `lib/arcx/services/arcx_export_service.dart`

**Changes:**
- Modified photo node reading logic to check `photos/` (plural) first
- Added fallback to `photo/` (singular) for compatibility
- Added recursive search if directories don't exist
- Enhanced logging throughout photo detection and copying process

**Key Fix:**
```dart
// Before: Only checked singular
final photoDir = Directory(path.join(nodesDir.path, 'media', 'photo'));

// After: Check plural first, then singular
var photoDir = Directory(path.join(nodesDir.path, 'media', 'photos'));
if (!await photoDir.exists()) {
  photoDir = Directory(path.join(nodesDir.path, 'media', 'photo'));
}
```

## Impact

### Before Fix
- Photo exports failed silently (0 photos exported)
- Archives were tiny (~368KB for 32 entries with 34 photos)
- Photo files were extracted but not referenced
- Users lost photo data in exports

### After Fix
- All photos successfully included in exports
- Archive sizes match expected (75MB+ for entries with photos)
- Photo files correctly copied to `payload/media/photos/`
- Photo node metadata properly included in final archive

## Testing

### Verification Steps
1. Export journal entry with multiple photos
2. Check terminal logs for "Found X photo nodes"
3. Verify archive size is reasonable (> 1MB if photos present)
4. Import archive and verify photos are restored

### Terminal Logs (After Fix)
```
ARCX Export: Reading photo nodes from: .../nodes/media/photos
ARCX Export: Found 34 photo nodes in .../nodes/media/photos
ARCX Export: Extracted 32 journal nodes, 34 photo nodes
ARCX Export: Found 32 journal entries, 34 photos, 0+0 health items
ARCX Export: ✓ Copied photo file: [filename] ([bytes] bytes)
...
ARCX Export: ✓ Payload archived (75912228 bytes)
ARCX Export: ✓ Final archive created (75936082 bytes)
```

## Related Issues

This fix also resolves:
- Photo linking after ARCX import (see `photo-linking-after-arcx-import.md`)
- Photo detection in `McpPackExportService` (photo detection now works correctly)

## Files Modified

- `lib/arcx/services/arcx_export_service.dart` - Fixed photo node directory path

## Status

✅ **RESOLVED** - Photos now correctly included in ARCX exports. Archive sizes match expected values and all photos are restored during import.

