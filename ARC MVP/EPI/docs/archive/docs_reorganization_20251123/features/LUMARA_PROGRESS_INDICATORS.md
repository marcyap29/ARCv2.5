# LUMARA Progress Indicators

**Status**: ✅ Implemented  
**Date**: February 2025  
**Version**: v2.3+

## Overview

Progress indicators provide real-time visual feedback during LUMARA cloud API calls, showing users exactly what stage of processing is occurring. This feature enhances user experience by eliminating uncertainty during reflection generation and chat interactions.

## Features

### In-Journal LUMARA Progress Indicators

Real-time progress messages and visual meters displayed within reflection blocks during API calls:

1. **Context Preparation** → "Preparing context..."
2. **History Analysis** → "Analyzing your journal history..."
3. **API Call** → "Calling cloud API..."
4. **Response Processing** → "Processing response..."
5. **Retry (if needed)** → "Retrying API... (X/2)"
6. **Finalization** → "Finalizing insights..."

**Visual Progress Meter:**
- Circular progress spinner (20x20px) with primary theme color
- Linear progress bar (4px height) below spinner and message
- Status message displayed alongside spinner
- Progress meter provides continuous visual feedback during API calls

**First-Time Activation Fix (January 2025):**
- Loading indicator now properly displays when using in-chat LUMARA for the first time
- Placeholder block created immediately to show loading state
- Circle status bar appears correctly during first reflection generation
- Proper error handling removes placeholder block if generation fails

### LUMARA Chat Progress Indicators

Visual progress indicator with meter shown at the bottom of chat interface when processing messages:

- Circular progress spinner with primary theme color
- Linear progress bar below spinner and message
- Status message: "LUMARA is thinking..."
- Automatically displays when `isProcessing` state is active
- Dismisses when response is received

## Technical Implementation

### Architecture

#### Direct Gemini API Integration (No Fallbacks)

**Critical Change**: In-journal LUMARA now uses Gemini API directly via `geminiSend()`, identical to main LUMARA chat. **ALL hardcoded fallback messages have been removed**.

- **No Hardcoded Responses**: In-journal LUMARA no longer falls back to template-based or intelligent fallback responses
- **Direct API Calls**: Uses `geminiSend()` function directly (same protocol as main chat)
- **Error Propagation**: If Gemini API fails, errors are thrown immediately - no automated fallback messages
- **Consistent Behavior**: In-journal and chat LUMARA now have identical API call behavior

#### Progress Callback System

The progress system uses a callback-based approach to report progress at different stages:

```dart
Future<String> generatePromptedReflection({
  // ... other parameters ...
  void Function(String message)? onProgress,
}) async {
  onProgress?.call('Preparing context...');
  // ... processing ...
  onProgress?.call('Calling cloud API...');
  // Direct Gemini API call via geminiSend() - no fallbacks
  final response = await geminiSend(
    system: LumaraPrompts.inJournalPrompt,
    user: userPrompt,
  );
  onProgress?.call('Processing response...');
  // ... finalization ...
}
```

#### In-Journal Progress Tracking

**Location**: `lib/ui/journal/journal_screen.dart`

- **Loading States Map**: `Map<int, bool> _lumaraLoadingStates` tracks loading state per block index
- **Loading Messages Map**: `Map<int, String?> _lumaraLoadingMessages` stores current progress message per block
- **Progress Callbacks**: Each reflection generation method passes `onProgress` callback that updates UI state

**Key Methods**:
- `_generateLumaraReflection()` - First activation with progress tracking
- `_onRegenerateReflection()` - Regeneration with progress updates
- `_onSoftenReflection()` - Tone softening with progress updates
- `_onMoreDepthReflection()` - Depth expansion with progress updates
- `_handleLumaraContinuation()` - Conversation mode with progress updates

#### Chat Progress Tracking

**Location**: `lib/lumara/ui/lumara_assistant_screen.dart`

- **State Management**: Uses `LumaraAssistantCubit` with `isProcessing` boolean flag
- **Visual Indicator**: Conditional rendering of progress indicator with meter based on `isProcessing` state
- **Auto-Dismiss**: Progress indicator and meter automatically hide when response is received

**Implementation**:
```dart
if (state is LumaraAssistantLoaded && state.isProcessing) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircularProgressIndicator(...), // Spinner
            Expanded(
              child: Text('LUMARA is thinking...'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Progress meter
        LinearProgressIndicator(
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary,
          ),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    ),
  );
}
```

### API Service Integration

**Location**: `lib/lumara/services/enhanced_lumara_api.dart`

#### Enhanced Method Signatures

All reflection generation methods now accept optional `onProgress` callback:

```dart
Future<String> generatePromptedReflection({
  // ... parameters ...
  void Function(String message)? onProgress,
}) async {
  // ... implementation ...
}

Future<String> generatePromptedReflectionV23({
  // ... parameters ...
  void Function(String message)? onProgress,
}) async {
  // Progress reporting at key stages:
  onProgress?.call('Preparing context...');
  onProgress?.call('Analyzing your journal history...');
  onProgress?.call('Calling cloud API...');
  onProgress?.call('Processing response...');
  onProgress?.call('Finalizing insights...');
}
```

#### Progress Stages

1. **Context Preparation** (`onProgress?.call('Preparing context...')`)
   - Triggered before retrieving candidate nodes from storage
   - Indicates initial setup phase

2. **History Analysis** (`onProgress?.call('Analyzing your journal history...')`)
   - Triggered during similarity scoring and node ranking
   - Indicates semantic search phase

3. **API Call** (`onProgress?.call('Calling cloud API...')`)
   - Triggered before making HTTP request to cloud API
   - Generic message that works for all providers (Gemini, OpenAI, Anthropic, etc.)

4. **Response Processing** (`onProgress?.call('Processing response...')`)
   - Triggered after receiving API response
   - Indicates response parsing and formatting phase

5. **Retry** (`onProgress?.call('Retrying API... (X/2)')`)
   - Triggered when API call fails and retry is attempted
   - Shows retry attempt number (up to 2 retries)

6. **Finalization** (`onProgress?.call('Finalizing insights...')`)
   - Triggered during response scoring and formatting
   - Indicates final processing before returning reflection

### UI Components

#### Inline Reflection Block

**Location**: `lib/ui/journal/widgets/inline_reflection_block.dart`

The `InlineReflectionBlock` widget displays progress indicators with a progress meter when `isLoading` is true:

```dart
if (isLoading)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircularProgressIndicator(...), // Spinner
            Expanded(
              child: Text(
                loadingMessage ?? 'LUMARA is thinking...',
                style: ...,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Progress meter
        LinearProgressIndicator(
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary,
          ),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    ),
  )
```

**Properties**:
- `isLoading: bool` - Controls visibility of progress indicator and meter
- `loadingMessage: String?` - Custom progress message to display
- **Progress Meter**: LinearProgressIndicator provides continuous visual feedback

## User Experience

### Benefits

1. **Transparency**: Users see exactly what LUMARA is doing at each stage
2. **Reduced Anxiety**: Eliminates uncertainty during API calls
3. **Error Awareness**: Retry attempts are clearly communicated
4. **Provider Visibility**: Users know which AI provider is being used
5. **Professional Feel**: Smooth, responsive UI feedback

### Visual Design

- **Circular Progress Indicator**: 20x20px spinner with primary theme color
- **Linear Progress Meter**: 4px height progress bar with rounded corners
- **Progress Messages**: Secondary text color with italic font style
- **Non-Blocking**: Progress indicators don't prevent user interaction with other parts of the UI
- **Consistent**: Same visual style across in-journal and chat interfaces
- **Dual Visual Feedback**: Spinner + progress meter provides comprehensive loading indication

## Provider Prioritization

### Gemini API Priority

**Location**: `lib/lumara/config/api_config.dart`

The system explicitly prioritizes Gemini API for in-journal insights:

```dart
// Preference order: Gemini first (explicit), then other Cloud APIs, then internal models
final geminiConfig = _configs[LLMProvider.gemini];
if (geminiConfig != null && geminiConfig.isAvailable) {
  return geminiConfig;
}
```

This ensures that:
- Gemini is always used when available and configured
- Other cloud APIs (OpenAI, Anthropic) are fallbacks
- Internal models are last resort

### Logging

Enhanced logging shows which provider is being used:

```
LUMARA Enhanced API v2.3: Using Google Gemini for reflection generation
LUMARA Enhanced API v2.3: Calling generateResponse()...
LUMARA: Google Gemini API response received (length: X)
```

## Integration Points

### Reflection Generation Actions

All reflection generation actions support progress indicators:

1. **First Activation** (FAB button)
   - Full progress tracking with placeholder block (-1 index)
   - Shows all stages from context preparation to finalization

2. **Regenerate Reflection**
   - Progress updates during regeneration
   - Shows provider name and retry status if needed

3. **Soften Tone**
   - Progress updates during tone adjustment
   - Maintains user awareness during processing

4. **More Depth**
   - Progress updates during depth expansion
   - Shows analysis and processing stages

5. **Conversation Continuation**
   - Progress updates for different conversation modes
   - Dynamic loading messages based on mode

### Chat Interactions

All chat messages trigger progress indicators:

- User message sent → Progress indicator appears
- API call in progress → "LUMARA is thinking..." message
- Response received → Progress indicator dismisses
- Error occurs → Progress indicator hides, error shown

## Error Handling

### API Failures

When API calls fail:
- Progress messages show retry attempts: "Retrying API... (1/2)"
- After max retries, progress indicator is cleared
- Error message is displayed to user
- Loading state is reset

### Provider Unavailability

When no provider is available:
- Error is thrown immediately: "No LLM provider available"
- User is directed to Settings to configure API key
- Progress indicators don't show for failed configurations

## Testing Scenarios

### Test 1: First Activation Progress
1. Tap LUMARA FAB button
2. ✅ Progress shows: "Preparing context..."
3. ✅ Progress updates: "Analyzing your journal history..."
4. ✅ Progress updates: "Calling cloud API..."
5. ✅ Progress updates: "Processing response..."
6. ✅ Progress updates: "Finalizing insights..."
7. ✅ Reflection appears with loading cleared

### Test 2: Regenerate with Progress
1. Click "Regenerate" on existing reflection
2. ✅ Progress shows: "Regenerating reflection..."
3. ✅ Progress updates through API call stages
4. ✅ New reflection replaces old one

### Test 3: Chat Progress Indicator
1. Send message in LUMARA chat
2. ✅ Progress indicator appears: "LUMARA is thinking..."
3. ✅ Progress indicator shows during API call
4. ✅ Progress indicator dismisses when response received

### Test 4: Retry Handling
1. Trigger API call with network issues
2. ✅ Progress shows: "Retrying API... (1/2)"
3. ✅ Progress shows: "Retrying API... (2/2)" if needed
4. ✅ Error shown if all retries fail

### Test 5: Provider Selection
1. Configure multiple providers (Gemini, OpenAI)
2. ✅ Progress shows: "Calling cloud API..." (generic for all providers)
3. ✅ Falls back to other provider if primary unavailable

## Files Modified

### Core Implementation
- `lib/lumara/services/enhanced_lumara_api.dart`
  - Added `onProgress` parameter to all reflection generation methods
  - Implemented progress reporting at key stages
  - Enhanced logging with provider names

- `lib/ui/journal/journal_screen.dart`
  - Added `_lumaraLoadingStates` and `_lumaraLoadingMessages` maps
  - Integrated progress callbacks in all reflection methods
  - Added first activation progress tracking

- `lib/ui/journal/widgets/inline_reflection_block.dart`
  - Added `isLoading` and `loadingMessage` properties
  - Implemented progress indicator UI
  - Disabled action buttons during loading

### Chat Implementation
- `lib/lumara/ui/lumara_assistant_screen.dart`
  - Added progress indicator rendering based on `isProcessing` state
  - Integrated with BlocConsumer for state management

- `lib/lumara/bloc/lumara_assistant_cubit.dart`
  - Uses existing `isProcessing` flag in `LumaraAssistantLoaded` state
  - No changes needed (existing state management)

### Configuration
- `lib/lumara/config/api_config.dart`
  - Enhanced `getBestProvider()` to explicitly prioritize Gemini
  - Improved logging for provider selection

## Future Enhancements

### Potential Improvements

1. **Progress Percentages**
   - Add percentage completion estimates
   - Show "30% complete" type messages

2. **Estimated Time Remaining**
   - Calculate ETA based on API response times
   - Show "~5 seconds remaining" messages

3. **Multi-Stage Progress Bars**
   - Visual progress bar showing stages completed
   - More granular progress indication

4. **Cancellation Support**
   - Allow users to cancel long-running API calls
   - Clear progress indicators on cancellation

5. **Offline Mode Indicators**
   - Show different progress for on-device vs cloud processing
   - Indicate when using local models

## Status

**Production Ready**: ✅

LUMARA Progress Indicators are fully implemented and integrated with:
- In-journal reflection generation
- LUMARA chat assistant
- All reflection action types (regenerate, soften, more depth, continuation)
- Error handling and retry logic
- Provider prioritization (Gemini-first)

---

**Last Updated**: February 2025  
**Related Features**: [LUMARA Rich Context Expansion](./LUMARA_RICH_CONTEXT_EXPANSION.md), [LUMARA v2.3 Question Bias](./LUMARA_V22_QUESTION_BIAS.md)

