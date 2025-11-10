# Phase Hashtag Detection Fixes - January 2025

## Summary

Fixed critical issue where phase hashtags were being incorrectly assigned to journal entries. The system now correctly detects the phase regime based on the entry's creation date rather than just checking for an ongoing regime.

## Problem

The app was adding `#discovery` hashtags to entries even when users were clearly in Transition phase. This occurred because:

1. **Incorrect Detection Logic**: The code checked if there was a "current ongoing regime" but didn't verify that the entry's creation date actually fell within that regime's date range.

2. **Photo Date Issues**: Entries created with photos (which have their own dates) were getting hashtags based on the current time, not the photo date.

3. **No Date Validation**: Entries created outside any regime were still getting hashtags from ongoing regimes.

## Solution

### Changed Detection Method

**Before:**
```dart
final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
if (currentRegime != null && currentRegime.isOngoing) {
  // Add hashtag - WRONG!
}
```

**After:**
```dart
final regimeForDate = phaseRegimeService.phaseIndex.regimeFor(entryDate);
if (regimeForDate != null) {
  // Add hashtag based on regime for entry date - CORRECT!
}
```

### Files Modified

1. **`lib/arc/core/journal_capture_cubit.dart`**
   - `saveEntryWithKeywords()`: Now uses `regimeFor(entryDate)` instead of `currentRegime`
   - `saveEntryWithPhase()`: Validates phase against regime for entry date
   - `saveEntryWithPhaseAndGeometry()`: Same validation
   - `saveEntryWithProposedPhase()`: Same validation
   - `updateEntryWithKeywords()`: Restored phase hashtag update logic

2. **`lib/prism/pipelines/prism_joiner.dart`**
   - Fixed missing `standMin` variable that was causing build errors

3. **`lib/ui/phase/phase_timeline_view.dart`**
   - Fixed split phase dialog to properly capture selected phase

## Technical Details

### Entry Date Handling

The system now properly handles:
- **Current Time Entries**: Uses `DateTime.now()` for new entries
- **Photo-Dated Entries**: Uses photo metadata date, adjusted to local time
- **Edited Entry Dates**: When users change entry date/time, hashtag updates accordingly

### Regime Detection

The `PhaseIndex.regimeFor(DateTime)` method uses binary search to efficiently find the regime containing a specific timestamp:
- Checks if timestamp falls within regime's start/end range
- Handles ongoing regimes (end = null)
- Returns null if no regime contains the timestamp

### Hashtag Management

When updating entries:
1. All existing phase hashtags are removed
2. Correct hashtag is added based on regime for entry date
3. If entry date doesn't fall within any regime, all hashtags are removed

## Impact

### Before Fix
- ❌ Entries in Transition phase getting `#discovery` hashtags
- ❌ Photo-dated entries getting wrong phase hashtags
- ❌ Entries outside regimes getting hashtags from ongoing regimes
- ❌ Editing entry dates didn't update hashtags

### After Fix
- ✅ Entries get correct phase hashtags based on their creation date
- ✅ Photo-dated entries get correct phase hashtags
- ✅ Entries outside regimes don't get hashtags
- ✅ Editing entry dates updates hashtags correctly

## Testing

To verify the fix:

1. **Create entry in Transition phase**
   - Should get `#transition` hashtag
   - Should NOT get `#discovery` hashtag

2. **Create entry with photo from past**
   - Should get hashtag for phase regime at photo date
   - Not current phase

3. **Edit entry date**
   - Hashtag should update to match new date's regime

4. **Create entry outside any regime**
   - Should not get any phase hashtag

## Related Issues

- Fixed issue where split phase dialog wasn't applying selected phase
- Fixed build error with missing `standMin` variable
- Fixed `RegExp.escape` usage (replaced with simpler regex patterns)

## Commit

Commit: `3c210b15` on branch `UI/UX-Improvements`
Date: January 2025

## Documentation

See `docs/features/PHASE_HASHTAG_SYSTEM.md` for complete system documentation.

