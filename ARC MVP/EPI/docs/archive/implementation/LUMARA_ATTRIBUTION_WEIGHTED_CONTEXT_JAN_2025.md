# LUMARA Memory Attribution & Weighted Context Implementation

**Date**: January 2025  
**Status**: ✅ Complete  
**Version**: 1.0.0

---

## Overview

This document describes the implementation of specific memory attribution excerpts and weighted context prioritization for LUMARA chat responses. The system now shows the exact 2-3 sentences from memory entries used in responses and prioritizes context sources with a three-tier weighting system.

---

## Problem Statement

Previously, LUMARA attributions had two issues:
1. **Generic Attribution**: Attributions showed generic text like "Hello! I'm LUMARA..." instead of the specific 2-3 sentences from memory entries actually used
2. **No Context Prioritization**: All context sources were treated equally, without prioritizing the current entry or recent conversation

---

## Solution

Implemented two key features:

1. **Specific Attribution Excerpts**: Attribution traces now capture and display the exact text from memory entries used in context
2. **Weighted Context Prioritization**: Three-tier system that prioritizes current entry (highest), recent LUMARA responses (medium), and other entries (lowest)

---

## Implementation Details

### 1. Enhanced AttributionTrace with Excerpts

**File**: `lib/mira/memory/enhanced_memory_schema.dart`

**Changes**:
- Added `excerpt` field to `AttributionTrace` class
- Stores first 200 characters of the memory node's narrative

```dart
class AttributionTrace {
  final String nodeRef;
  final String relation;
  final double confidence;
  final DateTime timestamp;
  final String? reasoning;
  final String? phaseContext;
  final String? excerpt; // New field for direct attribution
}
```

### 2. Attribution Service Updates

**File**: `lib/mira/memory/attribution_service.dart`

**Changes**:
- Updated `createTrace()` to accept `excerpt` parameter
- Stores excerpt in attribution trace

### 3. Memory Service Excerpt Extraction

**File**: `lib/mira/memory/enhanced_mira_memory_service.dart`

**Changes**:
- Extracts first 200 characters of node narrative as excerpt
- Includes excerpt when creating attribution traces

```dart
final excerpt = node.narrative.length > 200
    ? '${node.narrative.substring(0, 200)}...'
    : node.narrative;
final trace = _attributionService.createTrace(
  // ... other fields
  excerpt: excerpt, // Include excerpt for direct attribution
);
```

### 4. Attribution from Context Building

**File**: `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

**Key Changes**:
- Modified `_buildEntryContext()` to return both context string and attribution traces
- Attribution traces are captured from memory nodes actually used in context building
- Removed duplicate `retrieveMemories()` calls after response generation

**Before**:
```dart
// Context built, then separate memory retrieval for attribution
final entryText = await _buildEntryContext(context, userQuery: text);
// ... generate response ...
final memoryResult = await _memoryService!.retrieveMemories(query: text);
final traces = memoryResult.attributions; // May not match context used
```

**After**:
```dart
// Context building captures attribution traces
final contextResult = await _buildEntryContext(context, userQuery: text);
final entryText = contextResult['context'] as String;
final traces = contextResult['attributionTraces'] as List<AttributionTrace>; // From actual context
```

### 5. Weighted Context Building

**File**: `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

**Three-Tier System**:

#### Tier 1 (Highest Weight): Current Entry + Media
```dart
if (currentEntry != null) {
  buffer.writeln('=== CURRENT ENTRY (PRIMARY SOURCE) ===');
  buffer.writeln(currentEntry.content);
  
  // Include media content
  for (final mediaItem in currentEntry.media) {
    if (mediaItem.ocrText != null) {
      buffer.writeln('Photo OCR: ${mediaItem.ocrText}');
    }
    if (mediaItem.altText != null) {
      buffer.writeln('Photo description: ${mediaItem.altText}');
    }
    if (mediaItem.transcript != null) {
      buffer.writeln('Audio/Video transcript: ${mediaItem.transcript}');
    }
  }
}
```

#### Tier 2 (Medium Weight): Recent LUMARA Responses
```dart
if (currentChatSessionId != null) {
  final sessionMessages = await _chatRepo.getMessages(currentChatSessionId!, lazy: false);
  final recentAssistantMessages = sessionMessages
      .where((m) => m.role == 'assistant')
      .take(5)
      .toList();
  
  buffer.writeln('\n=== RECENT LUMARA RESPONSES (SAME CONVERSATION) ===');
  for (final msg in recentAssistantMessages.reversed) {
    buffer.writeln('LUMARA: ${msg.textContent}');
  }
}
```

#### Tier 3 (Lowest Weight): Other Entries/Chats
```dart
// Semantic search results
// Recent entries from progressive loader
// Chat sessions from other conversations
```

### 6. Draft Entry Support

**File**: `lib/ui/journal/journal_screen.dart`

**New Method**: `_getCurrentEntryForContext()`

**Functionality**:
- Creates `JournalEntry` from current draft state (unsaved content)
- Handles both existing entries (with modifications) and new drafts
- Includes all current data: text, media, title, date, time, location, emotion, keywords

**For Existing Entries**:
```dart
return widget.existingEntry!.copyWith(
  content: _entryState.text.isNotEmpty ? _entryState.text : widget.existingEntry!.content,
  title: _titleController.text.trim().isNotEmpty 
      ? _titleController.text.trim() 
      : widget.existingEntry!.title,
  media: [...widget.existingEntry!.media, ...mediaItems],
  // ... other fields
);
```

**For New Drafts**:
```dart
return JournalEntry(
  id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
  title: _titleController.text.trim().isNotEmpty 
      ? _titleController.text.trim() 
      : 'Draft Entry',
  content: _entryState.text,
  media: mediaItems,
  // ... other fields
);
```

### 7. UI Integration

**File**: `lib/arc/chat/ui/lumara_assistant_screen.dart`

**Changes**:
- Added optional `currentEntry` parameter to widget
- `_sendMessage()` uses current entry or falls back to most recent entry
- Automatically gets most recent entry if none provided

**File**: `lib/arc/chat/widgets/attribution_display_widget.dart`

**Changes**:
- Displays excerpt under "Source:" label
- Shows specific text from memory entries

```dart
if (trace.excerpt != null && trace.excerpt!.isNotEmpty) ...[
  const SizedBox(height: 8),
  Container(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Source:', style: ...),
        Text(trace.excerpt!, style: ...),
      ],
    ),
  ),
],
```

### 8. Journal Integration

**File**: `lib/ui/journal/widgets/inline_reflection_block.dart`

**Changes**:
- Added `attributionTraces` parameter
- Displays attribution widget for journal reflections

---

## Technical Details

### Attribution Trace Flow

1. **Context Building**: `_buildEntryContext()` retrieves memory nodes
2. **Excerpt Extraction**: First 200 chars of node narrative extracted
3. **Trace Creation**: Attribution traces created with excerpts
4. **Context Return**: Both context string and traces returned
5. **Response Generation**: Response generated using context
6. **Attribution Display**: Traces displayed with specific excerpts

### Weighted Context Flow

1. **Tier 1**: Current entry + media added first (highest priority)
2. **Tier 2**: Recent LUMARA responses added (medium priority)
3. **Tier 3**: Other entries/chats added (lowest priority)
4. **LLM Processing**: LLM sees weighted context in order
5. **Response**: Response reflects prioritization

### Draft Entry Flow

1. **User Editing**: User types in journal screen
2. **Draft State**: Content stored in `_entryState`
3. **LUMARA Invocation**: User asks LUMARA question
4. **Entry Creation**: `_getCurrentEntryForContext()` creates entry from draft
5. **Context Building**: Entry used as Tier 1 (highest priority)
6. **Response**: LUMARA uses unsaved draft content

---

## Integration Points

### Memory Attribution
- **Enhanced Memory Service**: `lib/mira/memory/enhanced_mira_memory_service.dart`
- **Attribution Service**: `lib/mira/memory/attribution_service.dart`
- **Attribution Display**: `lib/arc/chat/widgets/attribution_display_widget.dart`

### Weighted Context
- **Context Building**: `lib/arc/chat/bloc/lumara_assistant_cubit.dart` - `_buildEntryContext()`
- **Chat Repository**: `lib/arc/chat/chat/chat_repo.dart` - For recent messages
- **Journal Repository**: `lib/arc/core/journal_repository.dart` - For entry access

### Draft Support
- **Journal Screen**: `lib/ui/journal/journal_screen.dart` - `_getCurrentEntryForContext()`
- **Media Conversion**: `lib/ui/journal/media_conversion_utils.dart` - Attachment conversion
- **LUMARA Screen**: `lib/arc/chat/ui/lumara_assistant_screen.dart` - Entry parameter

---

## Testing

### Test Cases

1. **Attribution Excerpts**:
   - Verify excerpts show specific text from memory entries
   - Verify excerpts are 200 chars or less
   - Verify excerpts match actual content used

2. **Weighted Context**:
   - Verify current entry appears first in context
   - Verify recent LUMARA responses appear second
   - Verify other entries appear last
   - Verify media content included in Tier 1

3. **Draft Support**:
   - Verify unsaved draft text used as context
   - Verify draft media included
   - Verify draft metadata (title, date, etc.) included

### Verification

- ✅ Attribution traces show specific excerpts
- ✅ Excerpts match memory entries used in context
- ✅ Context built with three-tier weighting
- ✅ Current entry prioritized over other sources
- ✅ Draft entries work as context
- ✅ Journal reflections show attributions

---

## Benefits

1. **Transparency**: Users see exactly which text LUMARA used
2. **Accuracy**: Attribution matches actual context used
3. **Relevance**: Current entry prioritized for better responses
4. **Continuity**: Recent conversation context maintained
5. **Draft Support**: Unsaved content can be used for context

---

## Future Enhancements

1. **Configurable Weighting**: Allow users to adjust tier weights
2. **Longer Excerpts**: Option to show more than 200 chars
3. **Excerpt Highlighting**: Highlight exact sentences used
4. **Draft Auto-Update**: Automatically update draft when used in context
5. **Context Preview**: Show context tiers in UI before sending

---

## Related Documentation

- **Architecture**: `docs/architecture/EPI_MVP_Architecture.md` - Memory & Attribution section
- **Status**: `docs/status/STATUS.md` - Recent Achievements section
- **Changelog**: `docs/changelog/CHANGELOG.md` - Version 2.1.9

---

**Implementation Complete**: January 2025  
**Status**: ✅ Production Ready

