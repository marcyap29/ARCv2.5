# LUMARA Semantic Search Implementation

**Date:** February 2025  
**Version:** 2.4  
**Status:** Production Ready ✅

## Overview

LUMARA v2.4 introduces **Semantic Search** — a powerful enhancement that enables LUMARA to find and utilize relevant journal entries, chat sessions, and media based on meaning rather than just recency. This solves the critical issue where LUMARA couldn't find entries about specific topics (like "old company" or "feelings") if they weren't in the most recent entries.

## Problem Statement

**Before v2.4**: LUMARA context retrieval was limited to:
- ❌ **Recency-based only**: Only the most recent entries were included in context
- ❌ **No semantic understanding**: Couldn't find entries about specific topics if they were older
- ❌ **Keyword matching issues**: Manual keywords like "Shield AI" weren't effectively matched
- ❌ **No cross-modal search**: Media captions, OCR text, and transcripts weren't searched
- ❌ **Fixed settings**: No user control over search parameters

**User Pain Points:**
- "I keep asking about my old company and my feelings, but LUMARA doesn't recognize it despite clear labeling in entries"
- "LUMARA can't find entries with specific keywords even though they're clearly tagged"
- "Why can't LUMARA search through my photos and audio transcripts?"

**After v2.4**: LUMARA now uses intelligent semantic search that:
- ✅ **Finds entries by meaning**: Searches across all entries within configurable lookback period
- ✅ **Respects user settings**: Similarity threshold, lookback period, max matches all configurable
- ✅ **Enhanced keyword matching**: Prioritizes exact case matches, handles multi-word keywords
- ✅ **Cross-modal awareness**: Searches media captions, OCR text, and transcripts
- ✅ **Therapeutic depth integration**: Adjusts search depth based on Therapeutic Presence settings
- ✅ **Works everywhere**: Both in-chat and in-journal LUMARA use semantic search

## Key Features

### 1. Semantic Memory Retrieval

The system now uses `EnhancedMiraMemoryService` to perform semantic search across:
- **Journal Entries**: Full content, keywords (automatic and manual), phase context
- **Chat Sessions**: Conversation history and summaries
- **Media Items**: Captions, OCR text, transcripts (when cross-modal enabled)
- **Drafts**: Unpublished entry content

### 2. Reflection Settings Integration

Users can configure semantic search behavior through **LUMARA Settings → Reflection Settings**:

#### Similarity Threshold (0.1 - 1.0, default: 0.55)
- Controls how closely entries must match the query to be included
- Lower = more results (broader search)
- Higher = fewer results (more precise)

#### Lookback Period (1 - 10 years, default: 5)
- How far back to search for relevant entries
- Respects date filtering to avoid searching too far back

#### Max Matches (1 - 20, default: 5)
- Maximum number of relevant entries to include in context
- Balances relevance with context window size

#### Cross-Modal Awareness (default: enabled)
- When enabled, searches:
  - Photo captions and alt text
  - OCR text from images
  - Audio/video transcripts
- When disabled, only searches text content

#### Therapeutic Presence Depth Level
- **Light (Level 1)**: Reduces search depth by 40% (fewer, more recent results)
- **Standard (Level 2)**: Normal search depth (default)
- **Deep (Level 3)**: Increases search depth by 40-60% (more comprehensive results)

### 3. Enhanced Keyword Matching

The semantic search includes sophisticated keyword matching:

#### Exact Case Match (Highest Priority - 0.7 score boost)
- If query "Shield AI" exactly matches keyword "Shield AI" (same case)
- Ensures precise manual keywords are found

#### Case-Insensitive Exact Match (0.5 score boost)
- If query "Shield AI" matches keyword "shield ai" (case-insensitive)
- Handles variations in capitalization

#### Contains Match (0.4 score boost)
- If query contains keyword or vice versa
- Handles partial matches

#### Word-by-Word Match (0.5 weight)
- Checks individual words in query against keywords
- Handles multi-word keywords effectively

### 4. Scoring Algorithm

Entries are scored based on multiple factors:

```
Score = Content Match (0.5) + Keyword Match (0.3-0.7) + Phase Match (0.2) + Media Match (0.15)
```

- **Content Match**: How well query words appear in entry narrative
- **Keyword Match**: Exact/contains/word-by-word keyword matching
- **Phase Match**: ATLAS phase context relevance
- **Media Match**: Caption, OCR, transcript matches (if cross-modal enabled)

Only entries scoring above the similarity threshold are included.

### 5. Integration Points

#### In-Chat LUMARA
- **Location**: `lib/arc/chat/bloc/lumara_assistant_cubit.dart`
- **Method**: `_buildEntryContext()` now accepts `userQuery` parameter
- **Behavior**: Uses semantic search to find relevant entries, merges with recent entries
- **Fallback**: If semantic search fails, falls back to recent entries only

#### In-Journal LUMARA
- **Location**: `lib/ui/journal/journal_screen.dart`
- **Method**: `_buildJournalContext()` now accepts optional `query` parameter
- **Behavior**: Uses current entry text as query for semantic search
- **Integration**: Works with existing rich context expansion system

#### Enhanced Lumara API
- **Location**: `lib/arc/chat/services/enhanced_lumara_api.dart`
- **Method**: `generatePromptedReflectionV23()` now uses reflection settings
- **Behavior**: Respects similarity threshold, lookback years, max matches

## Technical Implementation

### Core Components

#### 1. LumaraReflectionSettingsService
**Location**: `lib/arc/chat/services/lumara_reflection_settings_service.dart`

Singleton service for persisting and retrieving reflection settings:

```dart
class LumaraReflectionSettingsService {
  // Settings with defaults
  Future<double> getSimilarityThreshold() async; // Default: 0.55
  Future<int> getEffectiveLookbackYears() async; // Default: 5, adjusted by depth
  Future<int> getEffectiveMaxMatches() async; // Default: 5, adjusted by depth
  Future<bool> isCrossModalEnabled() async; // Default: true
  Future<bool> isTherapeuticPresenceEnabled() async; // Default: true
  Future<int> getTherapeuticDepthLevel() async; // Default: 2
}
```

#### 2. Enhanced Memory Service
**Location**: `lib/polymeta/memory/enhanced_mira_memory_service.dart`

Enhanced `retrieveMemories()` method with new parameters:

```dart
Future<MemoryRetrievalResult> retrieveMemories({
  String? query,
  List<MemoryDomain>? domains,
  double? similarityThreshold,
  int? lookbackYears,
  int? maxMatches,
  int? therapeuticDepthLevel,
  bool? crossModalEnabled,
  // ... other parameters
}) async
```

#### 3. Context Building Methods

**In-Chat Context Building**:
```dart
Future<String> _buildEntryContext(
  ContextWindow context, {
  String? userQuery,
}) async {
  // 1. Load reflection settings
  // 2. Call memory service with query and settings
  // 3. Extract entry IDs from memory nodes
  // 4. Fetch full entry content
  // 5. Merge with recent entries (avoid duplicates)
  // 6. Return context string
}
```

**In-Journal Context Building**:
```dart
Future<String> _buildJournalContext(
  List<JournalEntry> loadedEntries, {
  String? query,
}) async {
  // 1. Use query or current entry text
  // 2. Load reflection settings
  // 3. Call memory service with query and settings
  // 4. Extract entry IDs and fetch content
  // 5. Merge with recent entries
  // 6. Return context string
}
```

### Settings UI Integration

#### LUMARA Settings Screen
**Location**: `lib/arc/chat/ui/lumara_settings_screen.dart`

- Loads settings from `LumaraReflectionSettingsService`
- Provides sliders for similarity threshold, lookback years, max matches
- Toggle for cross-modal awareness
- Integration with Therapeutic Presence depth level

#### Settings View
**Location**: `lib/shared/ui/settings/lumara_settings_view.dart`

- Same settings controls in shared settings view
- Persists settings using the service

## User Experience Examples

### Example 1: Finding Old Company Entry

**User Query**: "Tell me about my old company"

**Before v2.4**:
- Only searched most recent entries
- If "old company" entry was from 2 years ago, not found
- Response: Generic or no context

**After v2.4**:
- Semantic search finds entry with keyword "old company" from 2 years ago
- Entry included in context even if not recent
- Response: "Based on your entry from [date] about [old company], you mentioned..."

### Example 2: Multi-Word Keyword Match

**User Query**: "Shield AI"

**Entry Keyword**: "Shield AI" (exact case)

**Result**:
- Exact case match detected (0.7 score boost)
- Entry found even if "Shield AI" not in entry content
- High confidence match passes similarity threshold

### Example 3: Cross-Modal Search

**User Query**: "park bench"

**Entry**: Has photo with OCR text "park bench, sunset, trees"

**Result** (with cross-modal enabled):
- OCR text matches query
- Entry included in context
- LUMARA can reference the photo contextually

### Example 4: Therapeutic Depth Adjustment

**User Query**: "feelings about work"

**Therapeutic Depth**: Deep (Level 3)

**Result**:
- Lookback period increased by 40-60%
- Max matches increased
- More comprehensive search finds entries across longer time period
- Better context for deep therapeutic reflection

## Benefits

### 1. Improved Context Relevance
- Finds entries by meaning, not just recency
- Better responses to questions about past topics
- Maintains narrative continuity across time

### 2. User Control
- Configurable search parameters
- Adjustable similarity threshold
- Customizable lookback period
- Therapeutic depth integration

### 3. Enhanced Keyword Support
- Exact case matching for precise keywords
- Multi-word keyword handling
- Manual and automatic keywords both searched

### 4. Cross-Modal Intelligence
- Searches media content (captions, OCR, transcripts)
- Multimodal context awareness
- Better understanding of visual/audio content

### 5. Seamless Integration
- Works in both in-chat and in-journal LUMARA
- Integrates with existing rich context system
- Graceful fallback to recent entries if search fails

## Implementation Details

### Files Modified

#### Core Implementation
- `lib/arc/chat/services/lumara_reflection_settings_service.dart` - **NEW**: Settings service
- `lib/polymeta/memory/enhanced_mira_memory_service.dart` - Enhanced with semantic search parameters
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` - Updated `_buildEntryContext()` for semantic search
- `lib/ui/journal/journal_screen.dart` - Updated `_buildJournalContext()` for semantic search
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Uses reflection settings

#### UI Integration
- `lib/arc/chat/ui/lumara_settings_screen.dart` - Loads/saves reflection settings
- `lib/shared/ui/settings/lumara_settings_view.dart` - Settings UI integration

#### Supporting Services
- `lib/arc/chat/services/semantic_similarity_service.dart` - Updated recency boost to respect lookback years

### Dependencies
- `EnhancedMiraMemoryService` (POLYMETA module)
- `LumaraReflectionSettingsService` (ARC module)
- `SharedPreferences` (for settings persistence)
- `JournalRepository` (for fetching full entry content)

## Configuration

### Default Settings
```dart
similarityThreshold: 0.55
lookbackYears: 5
maxMatches: 5
crossModalEnabled: true
therapeuticPresenceEnabled: true
therapeuticDepthLevel: 2 (Standard)
```

### Therapeutic Depth Adjustments
```dart
// Light (Level 1)
effectiveLimit = (limit * 0.6).round() // -40%
effectiveLookbackYears = (lookbackYears * 0.6).round()

// Standard (Level 2)
effectiveLimit = limit
effectiveLookbackYears = lookbackYears

// Deep (Level 3)
effectiveLimit = (limit * 1.4).round() // +40%
effectiveLookbackYears = (lookbackYears * 1.6).round() // +60%
```

## Testing Scenarios

### Test 1: Basic Semantic Search
- ✅ Query finds relevant entries across time periods
- ✅ Similarity threshold filters results correctly
- ✅ Max matches limit respected

### Test 2: Keyword Matching
- ✅ Exact case keywords found (e.g., "Shield AI")
- ✅ Case-insensitive keywords found
- ✅ Multi-word keywords handled correctly
- ✅ Manual keywords prioritized

### Test 3: Cross-Modal Search
- ✅ Media captions searched when enabled
- ✅ OCR text searched when enabled
- ✅ Transcripts searched when enabled
- ✅ Cross-modal disabled works correctly

### Test 4: Therapeutic Depth
- ✅ Light depth reduces search scope
- ✅ Standard depth uses normal settings
- ✅ Deep depth increases search scope

### Test 5: Settings Persistence
- ✅ Settings saved to SharedPreferences
- ✅ Settings loaded on app restart
- ✅ Settings apply to both in-chat and in-journal LUMARA

### Test 6: Fallback Behavior
- ✅ Falls back to recent entries if semantic search fails
- ✅ Graceful error handling
- ✅ No crashes on memory service errors

## Future Enhancements

### 1. Advanced Semantic Scoring
- Vector embeddings for better semantic understanding
- Contextual similarity beyond keyword matching
- Temporal relationship weighting

### 2. Query Expansion
- Automatic query expansion for better results
- Synonym detection
- Related topic discovery

### 3. Learning from Feedback
- Track which entries were most useful
- Adjust scoring based on user interactions
- Personalize search parameters

### 4. Performance Optimization
- Cache frequently accessed entries
- Optimize memory node queries
- Batch processing for large result sets

## Status

**Production Ready**: ✅

LUMARA v2.4 Semantic Search is fully implemented and integrated with:
- Enhanced MIRA Memory Service
- Reflection Settings Service
- In-chat and in-journal LUMARA
- Cross-modal awareness
- Therapeutic Presence Mode

---

*Last Updated: February 2025*  
*Version: 2.4*  
*Status: Production Ready*

