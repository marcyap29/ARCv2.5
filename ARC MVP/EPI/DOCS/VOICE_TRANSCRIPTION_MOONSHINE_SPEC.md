# Voice Transcription Specification for LUMARA

## System Overview

Voice mode uses **Apple On-Device Speech** (Speech Framework) as the primary and only on-device ASR. **Wispr Flow** is available as an optional backend for users who configure an API key in **LUMARA Settings → External Services** (admin/test accounts). A mandatory **cleanup pass** removes filler words and corrects common misrecognitions before PRISM processing.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER VOICE INPUT                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              TRANSCRIPTION LAYER                             │
│  Optional: Wispr Flow (if API key set in Settings)           │
│  Primary:  Apple On-Device Speech Framework                  │
└──────────────────────┬──────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              CLEANUP LAYER (on-device)                       │
│  • Remove filler words (um, uh, like, you know)             │
│  • Fix common misrecognitions                               │
│  • Correct repetitions and false starts                     │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              PRISM PII SCRUBBING (on-device)                 │
└────────────────────┬────────────────────────────────────────┘
                     ▼
              LUMARA ASSISTANT (phase-aware)
```

---

## Backends

1. **Apple On-Device (primary)**  
   Always used unless Wispr is selected. Uses iOS Speech Framework; no network, no extra setup.

2. **Wispr Flow (optional)**  
   Configurable in **LUMARA Settings → External Services**. When an API key is set and the user is an allowed admin/test account, voice mode can use Wispr Flow instead of Apple for that session.

---

## File Structure

```
lib/arc/chat/voice/
├── transcription/
│   ├── unified_transcription_service.dart   # Wispr optional → Apple On-Device, cleanup
│   ├── ondevice_provider.dart               # Apple Speech (primary)
│   ├── transcription_provider.dart
│   └── cleanup/
│       └── transcript_cleanup_service.dart  # Mandatory cleanup pass
```

Wispr configuration and API key storage: see `WisprConfigService` and LUMARA Settings UI.

---

## Core Requirements

1. **Primary ASR: Apple On-Device**  
   Use Apple Speech Framework. Partial and final results; same flow as before.

2. **Optional: Wispr Flow**  
   If user has Wispr API key in Settings and is allowed (e.g. admin), voice mode can use Wispr as the backend.

3. **Cleanup Layer (mandatory)**  
   Remove fillers, fix common ASR errors; preserve meaning. Applied to final transcripts before PRISM.

4. **Privacy**  
   Cleaned transcript → PRISM PII scrubbing; raw audio and transcripts handled per app policy.
