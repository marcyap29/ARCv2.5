# LUMARA Contextual Push-to-Talk Voice Chat

## Overview

This document describes the implementation of the push-to-talk voice chat feature for LUMARA. The system provides hands-free voice interaction with context-aware routing to Journal, Main Chat, and Files.

## Architecture

```
UI (MicButton, VoiceChatPanel)
        │
PushToTalkController  ← state machine (Idle, Listening, Thinking, Speaking)
        │
VoiceChatPipeline (Mode A / Mode B)
        │
Intent & Context Layer
 ┌───────────────┬───────────────┬───────────────┐
 │ JournalManager│ MainChatMgr   │ FileManager   │
 │ (create/edit) │ (reply+persist)│ (retrieve/sum)│
 └───────────────┴───────────────┴───────────────┘
        │
TTS → Auto-resume Listening → Loop
```

## Pipeline Modes

### Mode A (Preferred): On-device STT → PRISM PII Scrub → LLM → TTS

1. **Speech-to-Text**: Uses `speech_to_text` plugin for on-device transcription
2. **PII Scrubbing**: Uses PRISM scrubber to remove personally identifiable information
3. **LLM Processing**: Sends scrubbed text to EnhancedLumaraApi
4. **Text-to-Speech**: Uses `flutter_tts` to speak the response

### Mode B (Fallback): Audio → LLM (no scrub)

- Direct audio-to-LLM processing (not yet fully implemented)
- Bypasses local transcription and PII scrubbing

## Components

### Core Files

- `voice_permissions.dart` - Handles microphone and speech recognition permissions
- `push_to_talk_controller.dart` - State machine for voice chat flow
- `audio_io.dart` - Wraps speech_to_text and flutter_tts
- `voice_chat_pipeline.dart` - Implements Mode A and Mode B pipelines
- `prism_scrubber.dart` - Integrates with existing PII scrubbing service
- `intent_router.dart` - Detects user intent (journal, chat, files)
- `context_memory.dart` - Tracks conversation context
- `voice_orchestrator.dart` - Orchestrates the full pipeline
- `voice_chat_service.dart` - Main service that wires everything together
- `voice_diagnostics.dart` - Performance and debugging metrics

### Manager Classes

- `journal_manager.dart` - Creates and manages journal entries
- `main_chat_manager.dart` - Handles main chat interactions
- `file_manager.dart` - File search and summarization (stub)

### UI Components

- `mic_button.dart` - Push-to-talk button widget
- `voice_chat_panel.dart` - Complete voice chat UI panel

## Usage

### Basic Integration

```dart
// Initialize the service
final voiceService = VoiceChatService(
  lumaraApi: enhancedLumaraApi,
  journalCubit: journalCaptureCubit,
  chatCubit: lumaraAssistantCubit,
  contextProvider: contextProvider,
);

final initialized = await voiceService.initialize();
if (!initialized) {
  // Handle permission denial
}

// Get the controller
final controller = voiceService.controller;

// Use in UI
VoiceChatPanel(
  controller: controller!,
  diagnostics: voiceService.diagnostics,
  partialTranscript: voiceService.partialTranscript,
)
```

### State Flow

1. **Idle** → User taps Mic → **Listening**
2. **Listening** → User taps Mic again → **Thinking** → Process → **Speaking**
3. **Speaking** → TTS completes → **Listening** (auto-resume)
4. Any state → User taps End → **Idle**

## Permissions

### iOS

Required permissions in `Info.plist`:
- `NSMicrophoneUsageDescription` - "Needed for voice chat."
- `NSSpeechRecognitionUsageDescription` - "Needed for transcription."

The `speech_to_text` plugin handles speech recognition permissions automatically.

### Android

- `RECORD_AUDIO` permission is handled by the `speech_to_text` plugin

## Intent Detection

The system uses heuristic-based intent detection:

- **Journal New**: "new journal", "start a journal"
- **Journal Append**: "add to", "append", "update journal"
- **Journal Query**: "summarize journal"
- **File Search**: "search file"
- **File Summarize**: "summarize paper/doc/file"
- **Chat**: Default fallback

Future enhancement: Replace with LLM-based intent detection.

## Privacy Rules

1. **Temp Audio**: Raw audio files are stored temporarily and deleted after transcription
2. **PII Scrubbing**: Only scrubbed transcripts are sent to LLM in Mode A
3. **Persistence**: Only scrubbed text is persisted to journal entries or chat history
4. **Confirmation**: Destructive journal edits require spoken confirmation (TODO)

## Diagnostics

The system tracks:
- `t_mic_start` - When microphone starts
- `t_first_partial` - First partial transcript received
- `t_final_text` - Final transcript received
- `t_scrub_done` - PII scrubbing completed
- `t_llm_reply` - LLM response received
- `t_tts_end` - Text-to-speech completed

## Error Handling

- Permission denial: Shows dialog with link to settings
- Network errors: Falls back gracefully
- STT errors: Ends session and shows error
- LLM errors: Returns fallback message

## Future Enhancements

- [ ] Replace heuristic intent detection with LLM-based intent
- [ ] Add "confirm destructive edits" voice dialog
- [ ] Add "context peek" subtitle showing what context is being used
- [ ] Add session transcript export to Journal
- [ ] Implement Mode B (audio-to-LLM) fully
- [ ] Add silence detection (auto-stop after 2s silence)

## Dependencies

- `speech_to_text: ^7.0.0` - Speech recognition
- `flutter_tts: ^4.0.2` - Text-to-speech
- `permission_handler: ^12.0.1` - Permission management
- `path_provider: ^2.1.4` - Temporary file paths

## Testing

### Acceptance Criteria

- [x] First run permission flow works
- [x] Deep link to Settings on permanent deny
- [ ] One-tap conversation loop (3+ back-and-forth turns)
- [ ] Journal: create, append, summarize by voice
- [ ] Main Chat: replies grounded in prior turns
- [ ] Files: search and summarize
- [x] TTS never runs while mic is active
- [ ] Mode toggle A/B works without restart
- [x] Temp audio is removed
- [x] Transcripts are scrubbed in Mode A

