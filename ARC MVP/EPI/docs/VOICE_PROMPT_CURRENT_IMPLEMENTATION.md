# Voice Prompt Current Implementation

## Overview

This document describes how the current voice prompt system works in ARC's voice mode. This is intended to help create a more detailed and improved prompt system.

## Architecture

The voice system supports two modes:
- **Journal Mode**: Saves to journal only, never to chat
- **Chat Mode**: Saves to chat history only, never to journal

Both modes use the same pipeline:
1. **AssemblyAI STT** (streaming transcription)
2. **PRISM** (local PII scrubbing)
3. **Gemini** (LLM response with system prompt)
4. **TTS** (text-to-speech)

## Current System Prompts

### Journal Mode Prompt

**Location**: `lib/arc/chat/voice/voice_journal/voice_mode.dart` (lines 42-47)

```dart
'''You are LUMARA, a compassionate and insightful journaling assistant. 
You help users reflect on their thoughts and feelings through their voice journal entries.
Keep responses conversational, warm, and concise (2-3 sentences).
Ask thoughtful follow-up questions to encourage deeper reflection.
Focus on emotions, patterns, and growth opportunities.
Never repeat back what the user said verbatim.'''
```

### Chat Mode Prompt

**Location**: `lib/arc/chat/voice/voice_journal/voice_mode.dart` (lines 49-53)

```dart
'''You are LUMARA, a helpful and friendly AI assistant.
You engage in natural conversation, answer questions, and provide assistance.
Keep responses concise but helpful (2-4 sentences).
Be conversational and engaging.
Ask clarifying questions when needed.'''
```

## How the Prompt is Used

### 1. Initialization

**File**: `lib/arc/chat/voice/voice_journal/unified_voice_service.dart` (lines 182-186)

When the voice service initializes, it creates a `GeminiJournalClient` with a mode-specific prompt:

```dart
_gemini = GeminiJournalClient(
  api: _lumaraApi,
  config: GeminiConfig(systemPrompt: _mode.systemPrompt),
  metrics: _metrics,
);
```

The `_mode.systemPrompt` comes from the `VoiceModeExtension` which returns the appropriate prompt based on the current mode (journal or chat).

### 2. Prompt Configuration

**File**: `lib/arc/chat/voice/voice_journal/gemini_client.dart` (lines 16-36)

The `GeminiConfig` class holds the system prompt configuration:

```dart
class GeminiConfig {
  final String systemPrompt;
  final int maxTokens;
  final double temperature;

  const GeminiConfig({
    this.systemPrompt = '''[default journal prompt]''',
    this.maxTokens = 256,
    this.temperature = 0.7,
  });
}
```

**Key Configuration Values**:
- `maxTokens`: 256 (relatively short responses)
- `temperature`: 0.7 (moderate creativity)

### 3. Prompt Usage in API Call

**File**: `lib/arc/chat/voice/voice_journal/gemini_client.dart` (lines 109-127)

When generating a response, the system prompt is used as the `chatContext`:

```dart
String chatContext = _config.systemPrompt;
if (conversationHistory != null && conversationHistory.isNotEmpty) {
  chatContext += '\n\nPrevious conversation:\n${conversationHistory.join("\n")}';
}

final result = await _api.generatePromptedReflection(
  entryText: payloadJson,
  intent: cloudPayload.intent,
  phase: null,
  userId: null,
  chatContext: chatContext + '\n\nNote: Input is a structured privacy-preserving payload. '
      'Respond naturally to the semantic summary and themes provided.',
  onProgress: (msg) {
    debugPrint('Gemini progress: $msg');
  },
);
```

**Important Notes**:
- The system prompt is passed as `chatContext` to `generatePromptedReflection`
- Conversation history is appended to the prompt
- A note about the privacy-preserving payload structure is added
- The `phase` parameter is `null` (not integrated with ATLAS phases)
- The `userId` parameter is `null` (no user-specific context)

## Security & Privacy

### PRISM Integration

**File**: `lib/arc/chat/voice/voice_journal/gemini_client.dart` (lines 324-340)

Before the prompt is used, the user's input goes through PRISM scrubbing:

1. **PII Scrubbing**: Raw transcript is scrubbed to remove PII
2. **Correlation-Resistant Transformation**: Text is transformed to a structured payload
3. **Semantic Summary**: The payload includes a semantic summary, not verbatim text

The system prompt is applied to the scrubbed/transformed content, not the raw transcript.

### Security Invariants

- Raw transcript NEVER leaves device
- Only scrubbed text goes to Gemini
- PRISM reversible map stays local
- No raw text in logs

## Conversation History

**File**: `lib/arc/chat/voice/voice_journal/gemini_client.dart` (lines 109-112, 293-364)

The system maintains conversation history:

```dart
final List<String> _scrubbedHistory = [];
```

History is stored as scrubbed versions:
- `User: [semantic summary]`
- `LUMARA: [response]`

This history is appended to the system prompt for context, but it's abstracted (not verbatim).

## Current Limitations

### 1. **No Integration with LUMARA Master Prompt**

The voice prompts are **completely separate** from the main LUMARA Master Unified Prompt system used in text chat. This means:
- Voice mode doesn't use the unified control state (ATLAS, VEIL, FAVORITES, PRISM, THERAPY MODE, ENGAGEMENT DISCIPLINE)
- Voice mode doesn't respect user settings like persona, therapeutic depth, response length controls
- Voice mode doesn't have access to memory retrieval parameters
- Voice mode doesn't use phase-aware behavior

### 2. **No ATLAS Phase Integration**

The `phase` parameter is hardcoded to `null`:
```dart
phase: null,
```

This means voice mode doesn't adapt to the user's current ATLAS phase (Discovery, Exploration, Integration, etc.).

### 3. **No User Context**

The `userId` parameter is `null`:
```dart
userId: null,
```

This means voice mode doesn't have access to user-specific settings or preferences.

### 4. **No Memory Retrieval**

Voice mode doesn't retrieve or use past journal entries or chat history for context, except for the immediate conversation history within the current voice session.

### 5. **No Response Length Controls**

Voice mode has hardcoded response length guidance:
- Journal: "2-3 sentences"
- Chat: "2-4 sentences"

This doesn't respect the user's response length settings (Auto, 3/5/10/15 sentences, sentences per paragraph).

### 6. **No Persona Selection**

Voice mode doesn't respect the user's LUMARA persona selection (Companion, Strategist, Challenger, Therapist).

### 7. **No Therapeutic Depth**

Voice mode doesn't respect therapeutic depth settings or auto-adapt behavior.

### 8. **No Engagement Discipline**

Voice mode doesn't respect engagement discipline settings (mode, synthesis allowed, max temporal connections, etc.).

### 9. **Static Prompts**

The prompts are hardcoded strings with no dynamic behavior based on:
- Time of day (day/night shift)
- User's emotional state
- Context of the conversation
- User's preferences

### 10. **Limited Context**

The prompt only includes:
- Basic system prompt
- Conversation history (scrubbed, abstracted)
- Note about privacy-preserving payload

It doesn't include:
- User's journal history
- User's chat history
- User's preferences
- Current phase
- Emotional context
- Memory patterns

## Code Locations

### Key Files

1. **Prompt Definitions**: `lib/arc/chat/voice/voice_journal/voice_mode.dart`
   - Lines 39-55: System prompt definitions

2. **Prompt Usage**: `lib/arc/chat/voice/voice_journal/gemini_client.dart`
   - Lines 16-36: `GeminiConfig` class
   - Lines 109-127: Prompt construction and API call
   - Lines 190-193: Legacy prompt usage (deprecated)

3. **Service Integration**: `lib/arc/chat/voice/voice_journal/unified_voice_service.dart`
   - Lines 182-186: Initialization with mode-specific prompt

4. **Conversation Management**: `lib/arc/chat/voice/voice_journal/gemini_client.dart`
   - Lines 285-391: `VoiceJournalConversation` class
   - Lines 293-308: History management

## Integration Points

### EnhancedLumaraApi

**File**: `lib/arc/chat/services/enhanced_lumara_api.dart`

The voice system uses `EnhancedLumaraApi.generatePromptedReflection()` which:
- Takes the system prompt as `chatContext`
- Sends the request to Firebase Functions
- Returns the LUMARA response

This is the same API used by text chat, but text chat uses the full LUMARA Master Prompt system, while voice mode uses the simple hardcoded prompts.

### PRISM Adapter

**File**: `lib/arc/chat/voice/voice_journal/prism_adapter.dart`

PRISM scrubbing happens before the prompt is used, ensuring privacy-preserving payloads are sent to Gemini.

## Recommendations for Improvement

1. **Integrate with LUMARA Master Prompt**: Use the unified control state system
2. **Add ATLAS Phase Support**: Make responses phase-aware
3. **Add User Context**: Include user settings and preferences
4. **Add Memory Retrieval**: Access past journal entries and chat history
5. **Respect Response Length Controls**: Use user's sentence/paragraph settings
6. **Support Persona Selection**: Allow users to choose persona for voice mode
7. **Add Therapeutic Depth**: Respect therapeutic settings
8. **Add Engagement Discipline**: Respect engagement boundaries
9. **Dynamic Prompts**: Make prompts context-aware
10. **Better Context Integration**: Include more relevant context in prompts

## Example: What a Better Prompt Might Look Like

Instead of the current simple prompt, a better prompt would:

1. Use the LUMARA Master Unified Prompt as the base
2. Include the unified control state JSON
3. Add voice-specific instructions (concise, conversational, natural pauses)
4. Include conversation history
5. Include relevant memory context
6. Respect user's response length preferences
7. Adapt to current phase and persona

This would make voice mode consistent with text chat while maintaining the unique characteristics needed for voice interactions (brevity, natural flow, conversational tone).

