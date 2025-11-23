# Phase Hashtag System

## Overview

The Phase Hashtag System automatically adds phase-specific hashtags (e.g., `#transition`, `#discovery`) to journal entries based on the phase regime that contains the entry's creation date. This ensures entries are correctly tagged with their corresponding phase, enabling accurate phase analysis and visualization.

## How It Works

### Phase Regimes

Phase regimes are time-bounded periods where a user is in a specific phase (Discovery, Expansion, Transition, Consolidation, Recovery, or Breakthrough). Each regime has:
- **Start Date**: When the phase begins
- **End Date**: When the phase ends (or `null` if ongoing)
- **Label**: The phase type (`PhaseLabel` enum)
- **Source**: How the regime was created (user, RIVET, etc.)

### Hashtag Assignment Logic

When a journal entry is created or updated, the system:

1. **Determines Entry Date**: Uses the entry's `createdAt` timestamp (which may be adjusted based on photo dates)
2. **Finds Matching Regime**: Uses `PhaseIndex.regimeFor(entryDate)` to find the regime containing that date
3. **Adds Phase Hashtag**: If a regime is found, adds the corresponding phase hashtag (e.g., `#transition`)
4. **Removes Old Hashtags**: When updating entries, removes all existing phase hashtags before adding the correct one

### Implementation Details

#### Entry Creation

The following methods handle phase hashtag assignment during entry creation:

- **`saveEntryWithKeywords`**: Main entry creation method
  - Finds regime for entry date using `phaseIndex.regimeFor(entryDate)`
  - Adds hashtag only if entry date falls within a regime
  - Handles photo date adjustments correctly

- **`saveEntryWithPhase`**: Entry creation with explicit phase
  - Validates that provided phase matches the regime for entry date
  - Only adds hashtag if regime matches provided phase

- **`saveEntryWithPhaseAndGeometry`**: Entry creation with phase and geometry
  - Same validation as `saveEntryWithPhase`

- **`saveEntryWithProposedPhase`**: Entry creation with proposed phase
  - Validates proposed phase against regime for entry date

#### Entry Updates

The **`updateEntryWithKeywords`** method handles hashtag updates when editing entries:

1. Determines the entry's date (which may have been changed)
2. Finds the regime for that date
3. Removes all existing phase hashtags
4. Adds the correct phase hashtag based on the regime
5. If entry date doesn't fall within any regime, removes all phase hashtags

### Key Fixes (January 2025)

#### Problem: Incorrect Hashtag Assignment

Previously, the system checked if there was a "current ongoing regime" but didn't verify that the entry's creation date actually fell within that regime. This caused:
- Entries created in Transition phase getting `#discovery` hashtags
- Entries with adjusted dates (from photos) getting wrong phase hashtags
- Entries created outside any regime getting hashtags from ongoing regimes

#### Solution: Date-Based Regime Detection

Changed from:
```dart
final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
if (currentRegime != null && currentRegime.isOngoing) {
  // Add hashtag
}
```

To:
```dart
final regimeForDate = phaseRegimeService.phaseIndex.regimeFor(entryDate);
if (regimeForDate != null) {
  // Add hashtag based on regime for entry date
}
```

This ensures:
- ✅ Entries get hashtags based on their actual creation date
- ✅ Photo-dated entries get correct phase hashtags
- ✅ Entries outside any regime don't get hashtags
- ✅ Editing entry dates updates hashtags correctly

### Code Locations

- **Entry Creation**: `lib/arc/core/journal_capture_cubit.dart`
  - `saveEntryWithKeywords()` - Lines 578-597
  - `saveEntryWithPhase()` - Lines 302-328
  - `saveEntryWithPhaseAndGeometry()` - Lines 696-721
  - `saveEntryWithProposedPhase()` - Lines 773-800

- **Entry Updates**: `lib/arc/core/journal_capture_cubit.dart`
  - `updateEntryWithKeywords()` - Lines 932-996

- **Regime Management**: `lib/services/phase_regime_service.dart`
  - `updateHashtagsForRegime()` - Updates hashtags when regimes change
  - `PhaseIndex.regimeFor()` - Finds regime for a specific date

### Phase Hashtag Format

Phase hashtags follow the pattern: `#<phasename>` where `<phasename>` is lowercase:
- `#discovery`
- `#expansion`
- `#transition`
- `#consolidation`
- `#recovery`
- `#breakthrough`

### Edge Cases Handled

1. **Entry Date Outside Any Regime**: No hashtag is added
2. **Entry Date Changed**: When editing, hashtag is updated based on new date
3. **Regime Split/Merge**: Hashtags are updated via `updateHashtagsForRegime()`
4. **Multiple Hashtags**: Old hashtags are removed before adding new one
5. **Case Sensitivity**: Hashtag matching is case-insensitive

### Debugging

The system includes extensive debug logging:
- `DEBUG: saveEntryWithKeywords - Entry date ($entryDate) falls within regime: $phase`
- `DEBUG: updateEntryWithKeywords - Updated phase hashtag to $hashtag for entry date ($entryDate)`
- `DEBUG: updateEntryWithKeywords - Entry date ($entryDate) does not fall within any regime, skipping phase hashtag`

### Related Systems

- **Phase Timeline**: Visual representation of phase regimes (`lib/ui/phase/phase_timeline_view.dart`)
- **Phase Analysis**: Automatic phase detection (`lib/ui/phase/phase_analysis_view.dart`)
- **VEIL Policy**: Uses phase information for AI response strategies
- **AURORA**: Uses phase information for circadian intelligence

## Testing

To verify phase hashtag assignment:

1. Create a journal entry in a known phase regime
2. Check that entry content includes correct phase hashtag
3. Edit entry date to fall in different regime
4. Verify hashtag updates correctly
5. Create entry outside any regime
6. Verify no hashtag is added

## Future Enhancements

- [ ] Batch hashtag updates when regimes are backdated
- [ ] Hashtag validation in entry content
- [ ] Phase hashtag suggestions in UI
- [ ] Analytics on hashtag accuracy

