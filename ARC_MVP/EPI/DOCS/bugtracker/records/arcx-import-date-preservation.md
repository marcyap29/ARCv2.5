# ARCX Import Date Preservation Fix

Date: 2025-11-02
Status: Resolved ✅
Area: Import/Export, Data Integrity

## Summary
Fixed critical issue where ARCX imports were changing entry creation dates, corrupting chronological order and losing original entry timestamps.

## Impact
- **Data Integrity**: Entry dates were being changed during import, making it impossible to maintain accurate journal chronology
- **User Experience**: Users noticed entries appearing with wrong dates after importing ARCX archives
- **Chronological Order**: Timeline ordering became incorrect after imports
- **Data Loss**: Original entry timestamps were being lost

## Root Cause
1. **Timestamp Parsing Fallback**: Import service was falling back to `DateTime.now()` when timestamp parsing failed
2. **No Duplicate Detection**: Existing entries were being overwritten with potentially different dates
3. **Weak Error Handling**: Parsing failures silently used current time instead of preserving original dates

## Fix
1. **Enhanced Timestamp Parsing**:
   - Removed `DateTime.now()` fallback for entry dates (preserves data integrity)
   - Added multiple parsing strategies with better error handling
   - Attempts to extract at least date portion (YYYY-MM-DD) before failing
   - Throws exceptions for unparseable timestamps (skips entry rather than importing with wrong date)

2. **Duplicate Entry Detection**:
   - Checks if entry already exists before importing
   - Skips existing entries entirely to preserve original creation dates
   - Logs warnings when duplicates are detected

3. **Enhanced Logging**:
   - Detailed logging for timestamp extraction from exports
   - Logs parsing results and any failures
   - Helps identify timestamp format issues during import

## Technical Details

### Timestamp Parsing Improvements
- Handles malformed timestamps missing 'Z' suffix
- Detects timezone offsets and handles appropriately
- Tries multiple parsing strategies before failing
- Extracts date portion as last resort before throwing error
- Never uses `DateTime.now()` for entry dates

### Duplicate Detection Logic
```dart
// Check if entry already exists - skip to preserve original dates
final existingEntry = _journalRepo!.getJournalEntryById(entry.id);
if (existingEntry != null) {
  // Skip to prevent date changes
  continue;
}
```

## Files Modified
- `lib/arcx/services/arcx_import_service.dart`
  - Enhanced `_parseTimestamp()` method
  - Added duplicate detection in import loop
  - Enhanced logging throughout import process

## Verification
- ARCX archives validated - both exports use full timestamp precision
- Import service now preserves original dates correctly
- Entries with unparseable timestamps are skipped (preserves data integrity)
- Duplicate entries are skipped (prevents date overwrites)
- Comprehensive logging helps identify any timestamp issues

## Related Issues
- Timeline Ordering & Timestamp Inconsistencies (previously resolved)
- This fix addresses the same underlying concern for ARCX imports specifically

## References
- `docs/changelog/CHANGELOG.md` (ARCX Import Date Preservation Fix - November 2, 2025)
- `docs/bugtracker/records/timeline-ordering-timestamps.md` (Related timestamp fixes)

