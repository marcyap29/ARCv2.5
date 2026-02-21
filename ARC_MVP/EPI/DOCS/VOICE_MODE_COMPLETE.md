# Voice Mode - Complete Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Status:** ✅ Implemented (v3.3.10)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Three-Tier Engagement System](#three-tier-engagement-system)
4. [Transcription Backend](#transcription-backend)
5. [Privacy & PII Scrubbing](#privacy--pii-scrubbing)
6. [Timeline Saving](#timeline-saving)
7. [Usage Limits](#usage-limits)
8. [Implementation Details](#implementation-details)
9. [Version History](#version-history)

---

## Overview

Voice mode allows users to have spoken conversations with LUMARA. The system captures speech via **Wispr Flow** (optional, user-provided API key) or **Apple On-Device** (default), processes it through PRISM (PII scrubbing), sends to LUMARA for response generation, and plays back via TTS.

**Voice mode uses two classification systems:**

### 1. Engagement Mode (Three-Tier System)
- **Reflect Mode** (default) - Casual conversation, 1-3 sentences, 100 words max, no memory retrieval
- **Explore Mode** (when asked) - Pattern analysis, 4-8 sentences, 200 words max, **with journal history**
- **Integrate Mode** (when asked) - Cross-domain synthesis, 6-12 sentences, 300 words max, **with journal history**

### 2. Seeking Classification (v3.3.9)
Detects what the user wants from the interaction:

| Seeking | User Intent | Response Style |
|---------|-------------|----------------|
| **Validation** | "Am I right to feel this way?" | Affirm, normalize, validate |
| **Exploration** | "Help me think through this" | Ask deepening questions |
| **Direction** | "Tell me what to do" | Clear recommendations |
| **Reflection** | "I need to process this" | Space, brief acknowledgments |

**Explicit Voice Commands:**
- Explore: "Analyze", "Give me insight", "What patterns do you see?"
- Integrate: "Deep analysis", "Go deeper", "Connect the dots"

**Temporal Query Triggers (v3.3.10):**
These phrases automatically trigger **Explore mode with full journal history retrieval**:
- "How has my week/month/year been?"
- "What have I been working on?"
- "Summarize my progress"
- "Review my entries"
- "Based on what you know..."
- "Recommendations based on my journal"

---

## Architecture

```
User speaks
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  TRANSCRIPTION                                          │
│  Wispr Flow (optional) or Apple On-Device (default)     │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  PRISM PII SCRUBBING (On-Device)                        │
│  Removes names, locations, etc. before cloud call       │
│  Creates reversible map for TTS restoration             │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  EntryClassifier.classifyVoiceDepth()                   │
│  Analyzes scrubbed transcript for engagement triggers   │
└─────────────────────────────────────────────────────────┘
    │
    ├─── No triggers ────────► REFLECT MODE (default)
    │                           100 words max, 5 seconds
    │                           skipHeavyProcessing: true
    │
    ├─── "Analyze"/"insight" ─► EXPLORE MODE
    │    "How has my week been"   200 words max, 10 seconds
    │    Temporal queries          Full pattern analysis
    │
    └─── "Go deeper"/etc. ───► INTEGRATE MODE
                               300 words max, 15 seconds
                               Cross-domain synthesis
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  LUMARA API (Cloud) with Master Unified Prompt          │
│  Only scrubbed text sent - PII never leaves device     │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  PII RESTORATION → TTS → User hears response            │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  SESSION SAVED TO TIMELINE                              │
│  When user taps "Finish" - saved as voice_conversation  │
└─────────────────────────────────────────────────────────┘
```

---

## Three-Tier Engagement System

Voice mode uses the **same three-tier engagement system as written mode**, with automatic depth classification per-turn:

| Mode | Response Style | Word Limit | Latency Target |
|------|----------------|------------|----------------|
| **Reflect** (default) | Casual conversation, surface patterns | 100 words | 5 seconds |
| **Explore** (when asked) | Pattern analysis, deeper discussion | 200 words | 10 seconds |
| **Integrate** (when asked) | Cross-domain synthesis, deep reflection | 300 words | 15 seconds |

**Note:** Word limits were reverted to original values in v3.3.10 after implementing phase-specific prompts with good/bad examples, which provide quality without needing longer responses.

### Memory Retrieval by Engagement Mode

**Decision:** Voice mode retrieves journal history based on engagement mode.

| Mode | Memory Retrieval | Rationale |
|------|------------------|-----------|
| **Reflect** (default) | No | Fast responses for casual conversation |
| **Explore** | **Yes** | Temporal queries need history context |
| **Integrate** | **Yes** | Synthesis requires cross-entry patterns |

**How it works:**
- Reflect mode sets `skipHeavyProcessing: true` → No memory retrieval
- Explore/Integrate modes set `skipHeavyProcessing: false` → Full journal history retrieval

**Example:**
```
User: "What's up?" → REFLECT (no memory, fast)
User: "How has my month been?" → EXPLORE (retrieves journal history)
User: "Go deeper on that" → INTEGRATE (full synthesis with history)
```

### Per-Turn Classification

**Decision:** Each utterance is classified independently. No "sticky" mode.

**Example:**
```
User: "I'm struggling with this decision..." → REFLECT (processing)
User: "How has my week been?" → EXPLORE (with memory retrieval)
User: "What time is it?" → REFLECT (quick)
User: "Go deeper on that" → INTEGRATE (synthesis)
```

### Phase-Aware Styling

All engagement modes adapt tone and depth based on current phase:

| Phase | Tone & Approach |
|-------|-----------------|
| **Recovery** | Extra validation. Slow pacing. No pressure. Honor processing needs. |
| **Breakthrough** | Match energy. Challenge strategically. Capitalize on clarity. |
| **Transition** | Normalize uncertainty. Ground. Navigate ambiguity without rushing. |
| **Discovery** | Encourage exploration. Reflect patterns. Support experimentation. |
| **Expansion** | Prioritize opportunities. Strategic guidance. Sustain momentum. |
| **Consolidation** | Integrate. Recognize progress. Support sustainability. |

Each phase has explicit good/bad response examples in `PhaseVoicePrompts`.

---

## Transcription Backend

Voice mode uses a two-tier transcription system:

```
Voice Mode Start
       │
       ▼
┌─────────────────────────────────────────┐
│  CHECK USAGE LIMITS                     │
│  Free users: 60 min/month               │
│  Premium: Unlimited                     │
│  ✗ Limit exceeded → Show upgrade dialog │
└─────────────────────────────────────────┘
       │ Allowed
       ▼
┌─────────────────────────────────────────┐
│  1. WISPR FLOW (Optional)               │
│     ✓ High accuracy streaming           │
│     ✓ Real-time transcription           │
│     ✗ Requires user's own API key       │
│     User configures in LUMARA Settings  │
│     → External Services                 │
└─────────────────────────────────────────┘
       │ If not configured
       ▼
┌─────────────────────────────────────────┐
│  2. APPLE ON-DEVICE (Default)           │
│     ✓ Always available                  │
│     ✓ No network required               │
│     ✓ No API costs                      │
│     ✓ Good accuracy                     │
└─────────────────────────────────────────┘
```

### User-Provided Wispr Flow

Wispr Flow is available as an **optional** transcription backend for users who configure their own API key:

1. User obtains API key from [wisprflow.ai](https://wisprflow.ai)
2. User enters key in **LUMARA Settings → External Services → Wispr Flow**
3. Voice mode automatically uses Wispr when configured

**Note:** Wispr Flow API is for personal use only. Users manage their own usage/billing.

---

## Privacy & PII Scrubbing

Voice mode scrubs PII **before** sending text to the cloud LLM:

```
Transcript: "I told Sarah about my job at Google in San Francisco"
                │
                ▼ PRISM Scrubbing (on-device)
                │
Scrubbed:   "I told [NAME1] about my job at [ORG1] in [LOCATION1]"
                │
                ▼ Sent to LUMARA API (cloud)
                │
Response:   "It sounds like sharing with [NAME1] was meaningful..."
                │
                ▼ PII Restoration (on-device)
                │
TTS Output: "It sounds like sharing with Sarah was meaningful..."
```

**Privacy Guarantee:** PII never leaves the device to reach the LLM.

---

## Timeline Saving

Voice sessions are automatically saved to the timeline when the user taps "Finish".

### How It Works

```dart
// In voice_mode_screen.dart
Future<void> _onSessionComplete(VoiceSession session) async {
  final journalRepository = JournalRepository();
  final voiceStorage = VoiceTimelineStorage(journalRepository: journalRepository);
  await voiceStorage.saveVoiceSession(session);
}
```

### What Gets Saved

| Field | Value |
|-------|-------|
| `entryType` | `'voice_conversation'` |
| `isVoiceEntry` | `true` |
| `content` | Formatted transcript (You: ... / LUMARA: ...) |
| `tags` | `['voice', 'conversation', 'lumara']` |
| `phase` | User's current phase at time of conversation |
| `voiceSession.sessionId` | Unique session identifier |
| `voiceSession.turnCount` | Number of conversation turns |
| `voiceSession.totalDurationMs` | Session duration in milliseconds |

### Export/Import Compatibility

Voice entries are fully compatible with export/import:
- **Export**: `metadata` field included with all voice data
- **Import**: Original metadata preserved via spread operator (`...?entryJson['metadata']`)

---

## Usage Limits

| Subscription | Monthly Limit |
|--------------|---------------|
| **Free** | 60 minutes |
| **Premium** | Unlimited |

- Usage resets on the 1st of each month
- Remaining time shown in voice mode UI
- Dialog prompts upgrade when limit reached
- Premium users see no limit indicator

---

## Implementation Details

### File Locations

| Component | Path |
|-----------|------|
| **Voice Depth Classifier** | `lib/services/lumara/entry_classifier.dart` |
| **Voice Prompt Builders** | `lib/arc/chat/voice/prompts/voice_response_builders.dart` |
| **Voice Session Service** | `lib/arc/chat/voice/services/voice_session_service.dart` |
| **Enhanced LUMARA API** | `lib/arc/chat/services/enhanced_lumara_api.dart` |
| **Unified Transcription** | `lib/arc/chat/voice/transcription/unified_transcription_service.dart` |
| **Usage Service** | `lib/arc/chat/voice/services/voice_usage_service.dart` |
| **Wispr Flow** | `lib/arc/chat/voice/wispr/wispr_flow_service.dart` |
| **Apple On-Device** | `lib/arc/chat/voice/transcription/ondevice_provider.dart` |
| **Timeline Storage** | `lib/arc/chat/voice/storage/voice_timeline_storage.dart` |

### Usage in VoiceSessionService

```dart
// In _processTranscript():

// 1. Classify engagement mode (Reflect/Explore/Integrate)
final depthResult = EntryClassifier.classifyVoiceDepth(transcript);
final engagementMode = depthResult.depth; // Uses EngagementMode enum

// 2. Classify what user is seeking (Validation/Exploration/Direction/Reflection)
final seekingResult = EntryClassifier.classifySeeking(transcript);

// 3. Build phase-specific voice prompt
final voiceModeInstructions = _buildVoiceModeInstructions(
  engagementMode: engagementMode,
  currentPhase: _currentPhase,
  conversationHistory: conversationHistory,
  seeking: seekingResult.seeking,
);

// 4. Call LUMARA API - skipHeavyProcessing controls memory retrieval
final result = await _lumaraApi.generatePromptedReflection(
  entryText: transcript,
  chatContext: voiceModeInstructions,
  skipHeavyProcessing: engagementMode == EngagementMode.reflect,
  ...
);
```

### Phase Detection

Voice mode uses `PhaseRegimeService` (same as Phase tab) for accurate phase detection:

```dart
// In home_view.dart
final analyticsService = AnalyticsService();
final rivetSweepService = RivetSweepService(analyticsService);
final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
await phaseRegimeService.initialize();

final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
```

This ensures voice mode displays the correct phase based on user activity patterns, not the static onboarding selection.

### Debug Output

The voice session service logs classification results:

```
VoiceSession: Engagement mode classification: explore (confidence: 0.85, triggers: exploration_request)
VoiceSession: Seeking classification: exploration (confidence: 0.85, triggers: exploration_request)
VoiceSession: Using EXPLORE mode with Master Unified Prompt (matches written mode)
VoiceSession: LUMARA API took 8234ms (explore mode, target: 10000ms)
```

### Classification Examples

| Input | Engagement Mode | Triggers |
|-------|-----------------|----------|
| "What time is it?" | reflect | [] |
| "Had a good lunch" | reflect | [] |
| "How has my week been?" | **explore** | [exploration_request] |
| "What patterns do you see?" | **explore** | [exploration_request] |
| "Go deeper" | **integrate** | [integration_request] |
| "Connect the dots" | **integrate** | [integration_request] |
| "I'm struggling with this" | reflect | [struggle_language] |

---

## Version History

- **v3.3.10** (2026-01-22): Added temporal query triggers for Explore mode with memory retrieval, reverted word limits to 100/200/300
- **v3.3.9** (2026-01-22): Added phase-specific prompts with good/bad examples, seeking classification system
- **v3.2** (2026-01-19): Fixed multi-turn voice conversations (speech_to_text state reset)
- **v3.1** (2026-01-19): Added voice usage limits (60 min/month free, unlimited premium), removed AssemblyAI
- **v3.0** (2026-01-19): Restored Wispr Flow as user-configurable option (personal API key)
- **v2.1** (2026-01-17): Added timeline saving, documented PRISM PII flow, updated architecture diagram
- **v2.0** (2026-01-17): Removed Wispr Flow (commercial restrictions), AssemblyAI now primary
- **v1.2** (2026-01-17): Added Apple On-Device as final transcription fallback
- **v1.1** (2026-01-17): Added AssemblyAI fallback, fixed phase detection, fixed Finish button
- **v1.0** (2026-01-17): Initial implementation with Jarvis/Samantha dual-mode system

---

## Related Documentation

- [LUMARA Response Systems](./LUMARA_RESPONSE_SYSTEMS.md) - Full response system architecture
- [Engagement Discipline](./Engagement_Discipline.md) - Three-tier engagement system details
- [Unified Intent Classifier Prompt](./UNIFIED_INTENT_CLASSIFIER_PROMPT.md) - Detailed classification spec
- [Prompt References](./PROMPT_REFERENCES.md) - All LUMARA prompts including voice mode
