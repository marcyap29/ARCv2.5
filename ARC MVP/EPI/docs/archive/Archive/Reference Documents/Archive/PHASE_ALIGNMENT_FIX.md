# Phase Alignment Fix - Implementation Summary

## Date: September 29, 2025

## Problem Identified

The timeline view was showing **rapid, confusing phase changes** for individual journal entries that didn't match the stable overall phase shown in the Phase tab. This was caused by two different phase detection systems:

1. **Timeline View (Individual Entries)**: Used simple keyword matching that changed phases rapidly with every entry
2. **Phase Tab (Overall Phase)**: Used sophisticated EMA smoothing, cooldown, and hysteresis mechanisms for stability

This created a jarring UX where:
- Timeline showed: Discovery → Transition → Recovery → Breakthrough (rapid changes)
- Phase Tab showed: Discovery (stable)

## Solution Implemented

**Priority-Based Phase System:**

We aligned the timeline phase detection with the overall phase tracking system by implementing a clear priority hierarchy:

### Phase Priority (Highest to Lowest):

1. **User Override** (Priority 1)
   - If the user manually changes an entry's phase after creation
   - Stored in `entry.metadata['updated_by_user'] = true`
   - Allows users to correct or override the system's phase assignment

2. **Overall Phase from Arcform Snapshots** (Priority 2)
   - Uses the sophisticated phase tracking system (EMA smoothing, cooldown, hysteresis)
   - Retrieved from `_getPhaseForEntry()` which checks arcform snapshots
   - This is the **authoritative source** for automatic phase assignment

3. **Default Fallback** (Priority 3)
   - If no phase is found, defaults to "Discovery"
   - Clean, predictable fallback behavior

### What Was Removed:

❌ **Removed unreliable keyword-based phase detection:**
- `_determinePhaseFromText()` - Simple keyword matching
- `_determinePhaseFromContent()` - Content-based phase detection
- `_determinePhaseFromAnnotation()` - SAGE annotation phase detection

These methods were causing the rapid phase changes and have been completely removed.

## Code Changes

### File Modified: `lib/features/timeline/timeline_cubit.dart`

**Changes:**
1. Updated `_mapToTimelineEntries()` to use priority-based phase assignment
2. Removed three unreliable phase detection methods
3. Removed unused import (`sage_annotation_model.dart`)

**New Logic:**
```dart
// Priority 1: User override
if (entry.metadata != null && entry.metadata!['updated_by_user'] == true) {
  phase = entry.metadata!['phase'];
}

// Priority 2: Overall phase (authoritative)
if (phase == null) {
  phase = _getPhaseForEntry(entry);
}

// Priority 3: Fallback
if (phase == null) {
  phase = 'Discovery';
}
```

## Benefits

✅ **Consistent**: Timeline entries now match the overall phase system
✅ **Stable**: No more rapid phase switching in timeline
✅ **Reliable**: Uses the sophisticated phase tracking system for all entries
✅ **User Control**: Users can still manually override phases after entry creation
✅ **Predictable**: Clear priority hierarchy for phase assignment

## User Experience

### Before:
- Individual entries showed different phases based on keywords
- Confusing rapid phase changes in timeline
- Timeline and Phase tab showed different information

### After:
- Individual entries use the same stable overall phase
- Consistent phase information across all views
- Users can manually adjust phases when needed

## Technical Details

### Phase Tracking System (Unchanged):
- **EMA Smoothing**: Averages over 7 entries
- **7-Day Cooldown**: Prevents rapid phase changes
- **Hysteresis Gap**: 0.08 score difference required
- **Promotion Threshold**: 0.62 confidence required

### Timeline Integration (New):
- Timeline now respects the sophisticated phase tracking
- User overrides are honored (highest priority)
- Clean fallback to Discovery when no phase exists

## Testing

The changes have been:
- ✅ Analyzed with `flutter analyze` - No errors
- ✅ Code compiles successfully
- ✅ Follows Flutter best practices
- ✅ Maintains backward compatibility with user-updated phases

## Future Enhancements

Potential improvements for later:
1. Add UI indicator when a phase is user-overridden vs. automatic
2. Add "Reset to automatic phase" option for user-overridden entries
3. Show phase confidence scores in timeline view
4. Add phase change history/timeline view

## Notes

- The Gemini API 500 error seen in logs is unrelated to this fix (temporary API issue)
- All existing user-overridden phases will continue to work as expected
- The default phase for entries without any phase information is now consistently "Discovery"