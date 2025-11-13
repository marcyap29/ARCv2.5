# LUMARA Rich Context Expansion Questions

**Date:** February 2025  
**Version:** 2.3  
**Status:** Production Ready ✅

## Overview

LUMARA v2.3 introduces **Rich Context Expansion Questions** — an enhancement that enables the first in-journal LUMARA activation to gather and utilize comprehensive contextual information including mood, phase, circadian profile, recent chats, and media when generating personalized expansion questions.

## Problem Statement

**Before v2.3**: The first LUMARA activation in a journal entry used a generic context without considering:
- User's current mood or emotional state
- Circadian rhythm patterns (time window, chronotype, rhythm coherence)
- Recent LUMARA chat conversations
- Media attachments (photos, videos) with OCR/transcript content
- Earlier journal entries with similar themes

This limited the relevance and personalization of expansion questions, making them feel disconnected from the user's actual context and state.

**After v2.3**: The first activation gathers a rich contextual tapestry that informs expansion questions, making them:
- **Mood-aware**: Considers emotional state when crafting questions
- **Circadian-aware**: Adapts to user's natural rhythm patterns
- **Continuity-aware**: References recent conversations and media
- **Pattern-aware**: Draws connections from earlier entries
- **Phase-aware**: Integrates with ATLAS phase detection

## Key Features

### 1. Rich Context Gathering

The system now gathers comprehensive context from multiple sources:

#### Mood & Emotion
- Extracts mood from current entry (`JournalEntry.mood`)
- Captures emotion from entry or widget selection (`JournalEntry.emotion`)
- Provides emotional context for appropriate question tone

#### Circadian Profile (AURORA)
- **Time Window**: Current time of day (morning/afternoon/evening)
- **Chronotype**: User's natural rhythm preference (morning/balanced/evening)
- **Rhythm Score**: Daily activity pattern coherence (0.0-1.0)
- **Fragmentation Status**: Whether rhythm is fragmented or coherent

#### Recent Chats
- Gathers up to 5 most recent active chat sessions
- Includes first 3 messages from each session
- Provides conversation continuity context
- Example: "Session: 'Career exploration' (2025-02-15): user: ... assistant: ..."

#### Media Attachments
- Extracts media items from existing entries and current state
- Includes alt text descriptions
- Incorporates OCR text from images
- Includes transcripts from audio/video
- Provides multimodal context for questions

#### Earlier Entries
- Uses ProgressiveMemoryLoader to gather historical context
- Up to 25 recent entries from current year
- **Semantic Search Integration (v2.4)**: Now uses EnhancedMiraMemoryService for intelligent semantic search
  - Finds relevant entries across configurable lookback period (default: 5 years)
  - Respects similarity threshold, max matches, and therapeutic depth settings
  - Searches keywords (automatic and manual), phase context, and media content
  - Prioritizes semantically relevant entries over just recent ones
- Pattern recognition across entries

### 2. First Activation vs. Subsequent Activations

#### First Activation (Rich Context)
- Uses `EnhancedLumaraApi.generatePromptedReflection()` with `includeExpansionQuestions: true`
- Full ECHO structure (Empathize → Clarify → Highlight → Open)
- 1-2 clarifying expansion questions that consider all contextual factors
- Personalized based on mood, phase, chrono profile, chats, and media

#### Subsequent Activations (Brief)
- Uses `ArcLLM.chat()` for concise reflections
- 1-2 sentences maximum (150 characters total)
- Quick follow-up without full context gathering

### 3. Context Integration in Prompts

The enhanced user prompt includes:

```
Current entry: "{entryText}"

Mood: {mood}
Phase: {phase}

Circadian context: Time window: {window}, Chronotype: {chronotype}, 
Rhythm coherence: {score}% {fragmented?}

Historical context from earlier entries: {matched excerpts}

Recent chat sessions: {chat summaries}

Media in this entry: {media descriptions with OCR/transcripts}

Follow the ECHO structure (Empathize → Clarify → Highlight → Open) and include 
1-2 clarifying expansion questions that help deepen the reflection. Consider 
the mood, phase, circadian context, recent chats, and any media when crafting 
questions that feel personally relevant and timely.
```

## Technical Implementation

### Core Components

#### 1. `_buildRichContext()` Method
**Location**: `lib/ui/journal/journal_screen.dart`

Gathers all contextual factors:

```dart
Future<Map<String, dynamic>> _buildRichContext(
  List<JournalEntry> loadedEntries,
  UserProfile? userProfile,
) async {
  final context = <String, dynamic>{};
  
  // Entry text from progressive memory
  context['entryText'] = _buildJournalContext(loadedEntries);
  
  // Mood/emotion from entry or widget
  context['mood'] = mood;
  context['emotion'] = emotion;
  
  // Circadian context from all entries
  final chronoContext = await circadianService.compute(allEntries);
  context['chronoContext'] = {...};
  
  // Recent chats from ChatRepo
  final chatContext = await gatherChatContext();
  context['chatContext'] = chatContext;
  
  // Media from entry and attachments
  final mediaContext = await gatherMediaContext();
  context['mediaContext'] = mediaContext;
  
  return context;
}
```

#### 2. Enhanced API Parameters
**Location**: `lib/lumara/services/enhanced_lumara_api.dart`

Extended `generatePromptedReflection()` signature:

```dart
Future<String> generatePromptedReflection({
  required String entryText,
  required String intent,
  String? phase,
  String? userId,
  bool includeExpansionQuestions = false,
  String? mood,                    // NEW
  Map<String, dynamic>? chronoContext,  // NEW
  String? chatContext,              // NEW
  String? mediaContext,             // NEW
}) async
```

#### 3. Context-Aware Prompt Building

The API now constructs prompts with all contextual factors:

```dart
// Build rich context string
final contextParts = <String>[];
contextParts.add('Current entry: "$entryText"');

if (mood != null && mood.isNotEmpty) {
  contextParts.add('Mood: $mood');
}

if (chronoContext != null) {
  contextParts.add('Circadian context: Time window: $window, '
                   'Chronotype: $chronotype, '
                   'Rhythm coherence: ${score}% ${isFragmented ? "(fragmented)" : ""}');
}

// Add historical context, chats, media...
```

### Integration Points

#### 1. CircadianProfileService
- Computes circadian context from all journal entries
- Provides time window, chronotype, and rhythm coherence
- Used in first activation for time-aware questions

#### 2. ChatRepo
- Retrieves recent active chat sessions
- Extracts message summaries for context
- Provides conversation continuity

#### 3. MediaConversionUtils
- Converts attachments to MediaItem format
- Extracts alt text, OCR, transcripts
- Provides multimodal context

#### 4. ProgressiveMemoryLoader
- Loads recent journal entries
- Provides historical context
- Enables pattern recognition

## User Experience Examples

### Example 1: Morning Entry with Chat Context

**Entry**: "Woke up feeling anxious about the presentation today."

**Rich Context**:
- Mood: anxious
- Phase: Discovery
- Chrono: Morning person, morning window, 0.72 rhythm score (coherent)
- Recent Chat: "Session: 'Presentation prep' (2025-02-15): user: I'm worried about... assistant: Consider starting with your strongest point..."
- No media

**LUMARA Response** (First Activation):
> "This morning anxiety has weight. Given your preparation in yesterday's chat, what part of the presentation feels most uncertain right now? And how does that uncertainty sit in your body—restless or focused? You've prepared well, and your morning rhythm shows you're most coherent during these early hours. Would it help to review your opening lines one more time, or does grounding with a brief pause feel right?"

### Example 2: Evening Entry with Media

**Entry**: "Spent the day at the park. Feeling peaceful."

**Rich Context**:
- Mood: peaceful
- Phase: Consolidation
- Chrono: Balanced chronotype, evening window, 0.58 rhythm score
- Media: Photo with OCR "park bench, sunset, trees"
- No recent chats

**LUMARA Response** (First Activation):
> "Peace has settled after the park. What made that space feel particularly grounding today? And how does this peaceful feeling differ from other moments this week? The photo captures that quiet moment—there's something about being among trees that supports you. Would it help to name one quality from today you want to carry into tomorrow, or does staying with the peace feel right for now?"

### Example 3: Fragmented Rhythm Warning

**Entry**: "Feeling scattered. Can't focus on anything."

**Rich Context**:
- Mood: scattered
- Phase: Recovery
- Chrono: Evening person, afternoon window, 0.35 rhythm score (FRAGMENTED)
- Earlier Entries: Multiple entries about difficulty focusing

**LUMARA Response** (First Activation):
> "Scattered energy makes everything feel harder. What specifically feels most pressing right now? Your rhythm has been fragmented recently, which can amplify this sense. You've navigated these periods before—what helped then? Would it help to name one small thing that feels manageable, or does resting feel necessary first?"

## Benefits

### 1. Personalized Relevance
- Questions feel directly connected to user's current state
- Mood-aware tone adjustment
- Circadian-aware timing considerations

### 2. Continuity Awareness
- References recent conversations naturally
- Draws connections from earlier entries
- Maintains narrative coherence

### 3. Multimodal Integration
- Incorporates visual/audio content meaningfully
- Uses OCR/transcript data for context
- Respects privacy (symbolic references only)

### 4. Enhanced Engagement
- More relevant questions increase user response
- Context-aware prompts feel more intelligent
- Reduces generic or disconnected responses

## Implementation Details

### Files Modified
- `lib/ui/journal/journal_screen.dart`
  - Added `_buildRichContext()` method
  - Updated `_generateLumaraReflection()` to use rich context
  - Integrated CircadianProfileService, ChatRepo, MediaConversionUtils

- `lib/lumara/services/enhanced_lumara_api.dart`
  - Extended method signature with context parameters
  - Enhanced prompt building with contextual factors
  - Integrated mood, chrono, chat, media into user prompt

### Dependencies
- `CircadianProfileService` (AURORA module)
- `ChatRepoImpl` (LUMARA chat system)
- `MediaConversionUtils` (multimodal conversion)
- `ProgressiveMemoryLoader` (historical context)

## Future Enhancements

### 1. Sentiment Analysis Integration
- More nuanced mood detection
- Automatic sentiment scoring
- Adaptive question tone based on sentiment

### 2. Enhanced Chrono Integration
- Time-of-day specific question types
- Energy level awareness
- Chronotype-specific question styles

### 3. Cross-Modal Pattern Detection
- Semantic similarity between chats and entries
- Visual pattern recognition
- Temporal relationship analysis

### 4. Context Caching
- Cache computed circadian context
- Optimize chat retrieval
- Reduce API call overhead

## Testing Scenarios

### Test 1: First Activation with Full Context
- ✅ Gathers mood from entry
- ✅ Computes circadian context
- ✅ Retrieves recent chats
- ✅ Extracts media information
- ✅ Builds comprehensive prompt
- ✅ Generates personalized questions

### Test 2: Subsequent Activation (Brief)
- ✅ Uses ArcLLM for brief response
- ✅ No context gathering
- ✅ 150 character limit enforced

### Test 3: Edge Cases
- ✅ No mood/emotion → graceful fallback
- ✅ No chats → skips chat context
- ✅ No media → skips media context
- ✅ Fragmented rhythm → appropriate handling

## Status

**Production Ready**: ✅

LUMARA v2.3 Rich Context Expansion Questions is fully implemented and integrated with:
- AURORA circadian intelligence
- LUMARA chat system
- Multimodal media handling
- Progressive memory loading

---

*Last Updated: February 2025*  
*Version: 2.3*  
*Status: Production Ready*

