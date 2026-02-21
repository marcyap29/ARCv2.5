# Voice Mode Implementation Guide
## Three-Tier Engagement System (Reflect/Explore/Integrate)

> Last Updated: January 23, 2026 (v3.3.10)

## Overview

Voice mode uses the **same three-tier engagement system as written mode**, with automatic depth classification per-turn:

| Mode | Response Style | Word Limit | Latency Target |
|------|----------------|------------|----------------|
| **Reflect** (default) | Casual conversation, surface patterns | 100 words | 5 seconds |
| **Explore** (when asked) | Pattern analysis, deeper discussion | 200 words | 10 seconds |
| **Integrate** (when asked) | Cross-domain synthesis, deep reflection | 300 words | 15 seconds |

**Note:** Word limits were reverted to original values in v3.3.10 after implementing phase-specific prompts with good/bad examples, which provide quality without needing longer responses.

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
│  Only scrubbed text sent - PII never leaves device      │
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

## File Locations

| Component | Path |
|-----------|------|
| **Voice Depth Classifier** | `lib/services/lumara/entry_classifier.dart` |
| **Voice Prompt Builders** | `lib/arc/chat/voice/prompts/voice_response_builders.dart` |
| **Voice Session Service** | `lib/arc/chat/voice/services/voice_session_service.dart` |
| **Enhanced LUMARA API** | `lib/arc/chat/services/enhanced_lumara_api.dart` |

---

## Depth Classification

### EngagementMode Enum (Three-Tier System)

```dart
enum EngagementMode {
  reflect,   // Default: Surface patterns and stop, no memory retrieval
  explore,   // Pattern analysis with journal history retrieval
  integrate  // Cross-domain synthesis with full memory access
}
```

### VoiceDepthResult

```dart
class VoiceDepthResult {
  final EngagementMode depth;   // Uses EngagementMode, not VoiceDepthMode
  final double confidence;      // 0.0 to 1.0
  final List<String> triggers;  // What triggered the classification
}
```

### Reflective Triggers

The classifier detects these categories of triggers:

| Category | Examples |
|----------|----------|
| **Processing Language** | "I need to process...", "Help me think through...", "Can we talk about..." |
| **Struggle Language** | "I'm struggling with...", "I can't...", "I'm stuck..." |
| **Emotional States** | "I'm feeling anxious...", "I feel overwhelmed..." |
| **Decision Support** | "Should I...", "What do you think about...", "Help me decide..." |
| **Self-Reflective Questions** | "Why do I...", "Am I being...", "What does it mean that I..." |
| **Relationship/Identity** | "My relationship with...", "Who I am...", "What I want..." |
| **High Emotional Density** | 15%+ emotional words in utterance |
| **Long Personal Utterance** | 50+ words with high first-person pronoun density |

---

## Prompt Builders

### PhaseVoicePrompts (Current Implementation)

The current implementation uses `PhaseVoicePrompts.getPhasePrompt()` which builds phase-specific prompts with:

```dart
PhaseVoicePrompts.getPhasePrompt(
  phase: 'transition',
  engagementMode: EngagementMode.explore,
  seeking: SeekingType.exploration,
  daysInPhase: 14,
  emotionalDensity: 0.3,
);
```

**Output prompt characteristics:**
- Phase-specific tone and guidance (Recovery, Breakthrough, Transition, etc.)
- Engagement mode word limits (Reflect: 100, Explore: 200, Integrate: 300)
- Seeking classification calibrates response style
- Explicit good/bad examples for each phase
- Voice-optimized (~500 words vs 260KB master prompt)

---

## Phase-Aware Styling

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

## Design Decisions

### 1. Memory Retrieval by Engagement Mode

**Decision:** Voice mode retrieves journal history based on engagement mode.

| Mode | Memory Retrieval | Rationale |
|------|------------------|-----------|
| **Reflect** (default) | No | Fast responses for casual conversation |
| **Explore** | **Yes** | Temporal queries need history context |
| **Integrate** | **Yes** | Synthesis requires cross-entry patterns |

**How it works:**
- Reflect mode sets `skipHeavyProcessing: true` → No memory retrieval
- Explore/Integrate modes set `skipHeavyProcessing: false` → Full journal history retrieval

**Temporal Query Triggers (v3.3.10):**
Users can trigger memory retrieval by asking:
- "How has my week/month/year been?"
- "What have I been working on?"
- "Summarize my progress"
- "Review my entries"
- "Based on what you know..."
- "What patterns have you noticed?"

These phrases automatically trigger **Explore mode** with full journal context.

**Example:**
```
User: "What's up?" → REFLECT (no memory, fast)
User: "How has my month been?" → EXPLORE (retrieves journal history)
User: "Go deeper on that" → INTEGRATE (full synthesis with history)
```

### 2. Per-Turn Classification

**Decision:** Each utterance is classified independently. No "sticky" mode.

**Example:**
```
User: "I'm struggling with this decision..." → REFLECT (processing)
User: "How has my week been?" → EXPLORE (with memory retrieval)
User: "What time is it?" → REFLECT (quick)
User: "Go deeper on that" → INTEGRATE (synthesis)
```

### 3. No UI Mode Indicator

**Decision:** No visible indicator showing engagement mode.

**Rationale:**
- Adds cognitive load for zero user benefit
- Response style IS the indicator
- Keep interface clean

### 4. Latency Targets

**Targets by mode:**
- Reflect: 5 seconds
- Explore: 10 seconds
- Integrate: 15 seconds

---

## Usage in VoiceSessionService

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

---

## Testing & Debugging

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

## Removed Orphaned Code

The following files were removed as orphaned (not imported by production code):

- `lib/services/lumara/companion_first_service.dart`
- `lib/services/lumara/lumara_classifier_integration.dart`
- `lib/services/lumara/master_prompt_builder.dart`
- `lib/services/lumara/validation_service.dart`
- `lib/services/lumara/response_mode_v2.dart`
- `test/services/lumara/companion_first_test.dart`
- `test/services/lumara/lumara_pattern_recognition_test.dart`

Their useful functionality was merged into:
- `entry_classifier.dart` - Voice depth classification (`classifyVoiceDepth`, `classifySeeking`)
- `phase_voice_prompts.dart` - Phase-specific voice prompts with good/bad examples

---

## Transcription Backend Fallback Chain

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

### Voice Mode Usage Limits

| Subscription | Monthly Limit |
|--------------|---------------|
| **Free** | 60 minutes |
| **Premium** | Unlimited |

- Usage resets on the 1st of each month
- Remaining time shown in voice mode UI
- Dialog prompts upgrade when limit reached
- Premium users see no limit indicator

### User-Provided Wispr Flow

Wispr Flow is available as an **optional** transcription backend for users who configure their own API key:

1. User obtains API key from [wisprflow.ai](https://wisprflow.ai)
2. User enters key in **LUMARA Settings → External Services → Wispr Flow**
3. Voice mode automatically uses Wispr when configured

**Note:** Wispr Flow API is for personal use only. Users manage their own usage/billing.

### Implementation Files

| Component | File |
|-----------|------|
| Unified Service | `lib/arc/chat/voice/transcription/unified_transcription_service.dart` |
| Usage Service | `lib/arc/chat/voice/services/voice_usage_service.dart` |
| Wispr Flow | `lib/arc/chat/voice/wispr/wispr_flow_service.dart` |
| Wispr Config | `lib/arc/chat/voice/config/wispr_config_service.dart` |
| Apple On-Device | `lib/arc/chat/voice/transcription/ondevice_provider.dart` |
| Settings UI | `lib/arc/chat/ui/lumara_settings_screen.dart` (External Services card) |
| Voice Mode UI | `lib/arc/chat/voice/ui/voice_mode_screen.dart` (Usage indicator) |

### User Feedback Messages

| Backend | Message Shown |
|---------|---------------|
| AssemblyAI | (none - primary backend) |
| Apple On-Device | "Using on-device transcription" |

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

### Implementation Files

| Component | File |
|-----------|------|
| Storage Service | `lib/arc/chat/voice/storage/voice_timeline_storage.dart` |
| UI Integration | `lib/arc/chat/voice/ui/voice_mode_screen.dart` |
| Export | `lib/mira/store/arcx/services/arcx_export_service_v2.dart` |
| Import | `lib/mira/store/arcx/services/arcx_import_service_v2.dart` |

---

## Privacy: PRISM PII Scrubbing

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

## Phase Detection

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

---

## Related Documentation

- [LUMARA Response Systems](./LUMARA_RESPONSE_SYSTEMS.md) - Full response system architecture
- [Voice Mode Status](./VOICE_MODE_STATUS.md) - Implementation status overview
- [Unified Intent Classifier Prompt](./UNIFIED_INTENT_CLASSIFIER_PROMPT.md) - Detailed classification spec
- [Prompt References](./PROMPT_REFERENCES.md) - All LUMARA prompts including voice mode

---

## Version History

- v3.3.10 (2026-01-22): Added temporal query triggers for Explore mode with memory retrieval, reverted word limits to 100/200/300
- v3.3.9 (2026-01-22): Added phase-specific prompts with good/bad examples, seeking classification system
- v3.2 (2026-01-19): Fixed multi-turn voice conversations (speech_to_text state reset)
- v3.1 (2026-01-19): Added voice usage limits (60 min/month free, unlimited premium), removed AssemblyAI
- v3.0 (2026-01-19): Restored Wispr Flow as user-configurable option (personal API key)
- v2.1 (2026-01-17): Added timeline saving, documented PRISM PII flow, updated architecture diagram
- v2.0 (2026-01-17): Removed Wispr Flow (commercial restrictions), AssemblyAI now primary
- v1.2 (2026-01-17): Added Apple On-Device as final transcription fallback
- v1.1 (2026-01-17): Added AssemblyAI fallback, fixed phase detection, fixed Finish button
- v1.0 (2026-01-17): Initial implementation with Jarvis/Samantha dual-mode system
