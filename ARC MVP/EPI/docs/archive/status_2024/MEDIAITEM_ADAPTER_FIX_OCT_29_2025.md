# MediaItem Adapter Registration Fix

**Date**: October 29, 2025  
**Status**: ✅ Complete  
**Branch**: arcx export

## Overview

Fixed critical bug preventing entries with photos from being saved to the Hive database during import operations. The issue was caused by adapter ID conflicts between MediaItem adapters and Rivet adapters.

## Problem

Entries with media items were failing to save with the error:
```
HiveError: Cannot write, unknown type: MediaItem. Did you forget to register an adapter?
```

**Impact**:
- Entries with photos were not being imported from unencrypted `.zip` archives
- Import logs showed "5 entries were NOT imported" (entries 23, 24, 25 had photos)
- Entries were processed but failed to save to Hive database
- Some entries with media appeared in timeline (loaded from cache) but couldn't be saved

## Root Cause

### Adapter ID Conflict

1. **MediaItem Adapters**:
   - `MediaTypeAdapter`: ID 10
   - `MediaItemAdapter`: ID 11

2. **Rivet Adapters** (conflicting):
   - `EvidenceSourceAdapter`: ID 10 (conflict!)
   - `RivetEventAdapter`: ID 11 (conflict!)
   - `RivetStateAdapter`: ID 12

3. **Initialization Race Condition**:
   - `_initializeHive()` and `_initializeRivet()` run in parallel
   - `_initializeHive()` registers MediaItem adapters (IDs 10, 11)
   - `_initializeRivet()` checks `if (!Hive.isAdapterRegistered(10))` and sees ID 10 is registered
   - Rivet initialization skips registering its adapters, but still expects IDs 10, 11
   - Result: MediaItem adapter may not be properly registered when saving entries

## Solution

### 1. Fixed Adapter ID Conflicts

Changed Rivet adapter IDs to avoid conflicts:
- `EvidenceSource`: ID 10 → **20**
- `RivetEvent`: ID 11 → **21**
- `RivetState`: ID 12 → **22**

**Files Modified**:
- `lib/atlas/rivet/rivet_models.dart` - Updated `@HiveType(typeId:)` annotations
- `lib/atlas/rivet/rivet_storage.dart` - Updated adapter registration checks

### 2. Regenerated Hive Adapters

Ran `build_runner` to regenerate adapter code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Fixed Set Conversion Bug

Fixed generated adapter to properly convert List to Set:
```dart
// Before (error):
keywords: (fields[3] as List).cast<String>(),

// After (fixed):
keywords: (fields[3] as List).cast<String>().toSet(),
```

**File Modified**: `lib/atlas/rivet/rivet_models.g.dart`

### 4. Added Safety Check

Added `_ensureMediaItemAdapter()` method in `JournalRepository` to verify adapter registration before saving entries with media:

```dart
void _ensureMediaItemAdapter() {
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(MediaTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(11)) {
    Hive.registerAdapter(MediaItemAdapter());
  }
}
```

Called before saving entries with media:
```dart
if (entry.media.isNotEmpty) {
  _ensureMediaItemAdapter();
  // Verify adapter is registered
  if (!Hive.isAdapterRegistered(11)) {
    print('❌ CRITICAL - MediaItemAdapter (ID: 11) is NOT registered!');
  }
}
```

**File Modified**: `lib/arc/core/journal_repository.dart`

### 5. Enhanced Debug Logging

Added comprehensive logging in `bootstrap.dart` to track adapter registration:
- Logs when adapters are registered
- Verifies MediaItemAdapter is registered after initialization
- Provides diagnostic information for troubleshooting

**File Modified**: `lib/main/bootstrap.dart`

## Files Modified

1. `lib/atlas/rivet/rivet_models.dart` - Changed adapter typeIds
2. `lib/atlas/rivet/rivet_storage.dart` - Updated adapter registration
3. `lib/atlas/rivet/rivet_models.g.dart` - Fixed Set conversion
4. `lib/main/bootstrap.dart` - Added adapter registration logging
5. `lib/arc/core/journal_repository.dart` - Added safety check

## Testing

### Before Fix
- Import logs showed: "5 entries were NOT imported"
- Entries with photos failed to save
- Error: `HiveError: Cannot write, unknown type: MediaItem`

### After Fix
- All entries with photos successfully import
- Media items correctly saved to database
- Entries appear in timeline with photos
- No adapter registration errors

## Verification

Check logs for:
- `✅ Registered MediaItemAdapter (ID: 11)`
- `✅ Verified MediaItemAdapter (ID: 11) is registered`
- `✅ JournalRepository: Verified MediaItemAdapter (ID: 11) is registered`

## Related Issues

- See `docs/ARCHITECTURE_COMPARISON.md` for import architecture comparison
- See `docs/bugtracker/Bug_Tracker.md` for bug tracking entry

## Notes

- Adapter IDs must be unique across the entire application
- When changing adapter IDs, always regenerate adapters with `build_runner`
- Safety checks in `JournalRepository` provide fallback if bootstrap registration fails
- Hot reload may not pick up adapter registration changes - full restart required

