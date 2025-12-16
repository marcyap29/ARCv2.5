# Unified Voice Module

A complete voice solution for LUMARA supporting both **Journal** and **Chat** modes with clean separation of concerns.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        UnifiedVoiceService                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │ AssemblyAI   │───▶│    PRISM     │───▶│   Gemini     │          │
│  │    STT       │    │  (Scrubber)  │    │   Client     │          │
│  └──────────────┘    └──────────────┘    └──────────────┘          │
│         │                   │                   │                   │
│         │                   │                   ▼                   │
│         │                   │            ┌──────────────┐          │
│         │                   │            │     TTS      │          │
│         │                   │            │   Client     │          │
│         ▼                   ▼            └──────────────┘          │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │                      Storage                              │     │
│  │  ┌─────────────────┐           ┌─────────────────┐       │     │
│  │  │  JournalStore   │           │   ChatStore     │       │     │
│  │  │ (Journal Mode)  │           │  (Chat Mode)    │       │     │
│  │  └─────────────────┘           └─────────────────┘       │     │
│  └──────────────────────────────────────────────────────────┘     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Features

### Mode Separation
- **Journal Mode**: Saves to journal repository ONLY, never to chat
- **Chat Mode**: Saves to chat history ONLY, never to journal

### Security
- Raw transcript NEVER leaves device
- Only scrubbed (PII-free) text sent to Gemini
- PRISM reversible map stays local
- No raw text in logs
- Security guardrails validate before sending

### State Machine

```
IDLE ──────────▶ LISTENING ──────────▶ TRANSCRIBING
  ▲                                          │
  │                                          ▼
  │                                     SCRUBBING
  │                                          │
  │                                          ▼
SAVED ◀──────── SPEAKING ◀──────────── THINKING
```

## Usage

### Basic Usage

```dart
import 'package:my_app/arc/chat/voice/voice_service.dart';

// Create service
final service = UnifiedVoiceService(
  assemblyAIService: assemblyAIService,
  lumaraApi: lumaraApi,
  journalCubit: journalCubit,  // For journal mode
  chatCubit: chatCubit,        // For chat mode
  initialMode: VoiceMode.journal,
);

// Initialize
await service.initialize();

// Start session
await service.startSession();
await service.startListening();

// User speaks... transcripts arrive via callbacks

// When user taps stop:
await service.endTurnAndProcess();

// LUMARA responds, then listening auto-resumes

// To save and end:
await service.saveAndEndSession();
```

### With UI Panel

```dart
UnifiedVoicePanel(
  service: voiceService,
  showModeSwitch: true,  // Allow switching between journal/chat
  onSessionSaved: () {
    Navigator.pop(context);
  },
)
```

### Switching Modes

```dart
// Switch from journal to chat (only when idle)
service.switchMode(VoiceMode.chat);
```

## Files

| File | Description |
|------|-------------|
| `voice_mode.dart` | Mode enum and mode-specific configs |
| `voice_journal_state.dart` | State machine and metrics |
| `prism_adapter.dart` | PII scrubbing wrapper |
| `assemblyai_stt.dart` | Streaming STT with fallback |
| `gemini_client.dart` | LLM client with security |
| `tts_client.dart` | Text-to-speech |
| `journal_store.dart` | Journal-only persistence |
| `chat_store.dart` | Chat-only persistence |
| `unified_voice_service.dart` | Main orchestrator |
| `unified_voice_panel.dart` | Reusable UI widget |

## Latency Tracking

The service tracks latency metrics:

- Time to first partial transcript
- Turn end to scrub start
- Scrub duration
- Scrub end to Gemini request
- Time to first Gemini token
- Gemini to TTS start
- Time to first audio
- Total session time

Access via `service.metrics.toLatencyReport()`.

## Migration from VoiceChatService

The old `VoiceChatService` is deprecated. Migrate as follows:

```dart
// OLD (deprecated)
final service = VoiceChatService(
  lumaraApi: api,
  journalCubit: cubit,
  context: VoiceContext.journal,
);

// NEW (recommended)
final service = UnifiedVoiceService(
  assemblyAIService: assemblyAIService,
  lumaraApi: api,
  journalCubit: cubit,
  initialMode: VoiceMode.journal,
);
```

Key differences:
1. Requires `AssemblyAIService` for cloud STT
2. Uses `VoiceMode` enum instead of `VoiceContext`
3. Journal mode never touches chat history
4. Chat mode never touches journal
5. Better state machine with explicit states

