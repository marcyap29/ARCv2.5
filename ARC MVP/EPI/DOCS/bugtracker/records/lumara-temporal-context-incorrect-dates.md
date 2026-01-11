# LUMARA Temporal Context - Incorrect Date References

**Bug ID:** lumara-temporal-context-incorrect-dates  
**Status:** ✅ **RESOLVED**  
**Severity:** High  
**Component:** LUMARA Master Prompt / Temporal Context  
**Date Reported:** January 10, 2026  
**Date Resolved:** January 10, 2026

---

## Problem

LUMARA was referencing past journal entries with incorrect dates in reflections. For example:
- Entry from January 7, 2026 was referenced as "yesterday" when today was January 10, 2026 (should be "3 days ago")
- Entry from January 8, 2026 was referenced as "back on 2026-01-10" (should be "2 days ago")
- Entry from January 2, 2026 was referenced as "on 2026-01-10" (should be "8 days ago")

### Root Cause

1. **Current entry included in recent entries**: The current entry being reflected upon was included in the recent entries list, causing confusion
2. **No relative date information**: Recent entries only showed absolute dates without relative context (e.g., "3 days ago")
3. **Unclear temporal instructions**: The master prompt didn't have explicit instructions on how to use the temporal context correctly
4. **Date calculation inconsistency**: Different parts of the system might calculate dates from different reference points

### Impact

- **User Experience**: Confusing and inaccurate date references in reflections
- **Trust**: Users lose confidence in LUMARA's temporal awareness
- **Context**: Incorrect temporal context leads to less accurate pattern recognition

---

## Solution

### Code Changes

**File:** `lib/arc/chat/services/enhanced_lumara_api.dart`

**Before:**
```dart
final recentEntries = recentJournalEntries.take(5).map((entry) => {
  'date': entry.createdAt,
  'title': entry.content.split('\n').first.trim().isEmpty 
      ? 'Untitled entry' 
      : entry.content.split('\n').first.trim(),
  'id': entry.id,
}).toList();
```

**After:**
```dart
// Exclude current entry from recent entries list to avoid confusion
final now = DateTime.now();
final recentEntries = recentJournalEntries
    .where((entry) => entryId == null || entry.id != entryId) // Exclude current entry
    .take(5)
    .map((entry) {
      final daysAgo = now.difference(entry.createdAt).inDays;
      final relativeDate = daysAgo == 0 
          ? 'today' 
          : daysAgo == 1 
              ? 'yesterday' 
              : '$daysAgo days ago';
      
      return {
        'date': entry.createdAt,
        'relativeDate': relativeDate,
        'daysAgo': daysAgo,
        'title': entry.content.split('\n').first.trim().isEmpty 
            ? 'Untitled entry' 
            : entry.content.split('\n').first.trim(),
        'id': entry.id,
      };
    })
    .toList();
```

**File:** `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`

**Added temporal context instructions:**
```dart
**CRITICAL: TEMPORAL CONTEXT USAGE**
- Use the current date above to calculate relative dates correctly
- When referencing past entries, use the exact dates from the recent_entries list
- Do NOT assume dates - use the dates provided in recent_entries
- Calculate "yesterday", "last week", etc. based on the current date shown above
- If an entry says "3 days ago", that means it was written 3 days before the current date
```

**Updated `injectDateContext` method:**
- Now includes relative date information in the format: `Friday, January 7, 2026 (3 days ago) - Entry Title`
- Uses consistent `DateTime.now()` reference point for all calculations
- Accepts optional `currentDate` parameter for testing

### Key Improvements

1. **Current Entry Exclusion**: Current entry is now excluded from recent entries list
2. **Relative Date Information**: Each entry shows both absolute and relative dates
3. **Clear Instructions**: Explicit instructions on how to use temporal context
4. **Consistent Date Reference**: Single `DateTime.now()` instance used for all calculations

### Files Modified

- `lib/arc/chat/services/enhanced_lumara_api.dart`: Updated recent entries processing to exclude current entry and add relative dates
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`: Added temporal context instructions and updated `injectDateContext` method

---

## Testing

### Test Cases

1. ✅ **Current Entry Exclusion**: Current entry not in recent entries list
2. ✅ **Relative Date Calculation**: Correct "X days ago" for each entry
3. ✅ **Date Formatting**: Both absolute and relative dates shown
4. ✅ **Temporal Instructions**: LUMARA follows instructions correctly

### Verification

- Recent entries list format: `Friday, January 7, 2026 (3 days ago) - Entry Title`
- Current entry excluded from list
- Dates calculated correctly based on current date
- LUMARA uses exact dates from list instead of assuming

---

## Related Issues

- Related to: [gemini-api-empty-user-string.md](gemini-api-empty-user-string.md) - Both part of v3.2.2 improvements
- Part of: Temporal Context Injection feature (v3.2.2)

---

## Commit Information

**Commit:** `[pending]`  
**Branch:** `dev` → `main`  
**Date:** January 10, 2026  
**Message:** `fix: Improve temporal context accuracy in LUMARA reflections`

**Files Changed:**
- `lib/arc/chat/services/enhanced_lumara_api.dart`: Exclude current entry, add relative dates
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`: Add temporal instructions, improve date formatting

---

## Resolution Verified

**Date:** January 10, 2026  
**Status:** ✅ **RESOLVED** - Temporal context now accurate with relative dates and clear instructions

---

## Additional Notes

- This fix is part of the broader Temporal Context Injection feature
- Relative dates make it much easier for LUMARA to understand temporal relationships
- Excluding current entry prevents confusion about which entry is being reflected upon

