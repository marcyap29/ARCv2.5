# Voice Mode Implementation Guide
## Jarvis/Samantha Dual-Mode System

> Last Updated: January 17, 2026

## Overview

Voice mode supports two conversation styles that are automatically detected per-turn:

| Mode | Inspiration | Response Style | Latency Target |
|------|-------------|----------------|----------------|
| **Jarvis** | Tony Stark's AI | Quick, efficient, 50-100 words | 3-5 seconds |
| **Samantha** | "Her" (2013) | Deep, reflective, 150-200 words | 8-10 seconds |

---

## Architecture

```
User speaks
    │
    ▼
Wispr transcribes
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  EntryClassifier.classifyVoiceDepth()                   │
│  Analyzes transcript for reflective triggers            │
└─────────────────────────────────────────────────────────┘
    │
    ├─── No triggers ────────► JARVIS MODE
    │                           JarvisPromptBuilder.build()
    │                           forceQuickResponse: true
    │                           50-100 words, 3-5 seconds
    │
    └─── Triggers found ─────► SAMANTHA MODE
                                SamanthaPromptBuilder.build()
                                forceQuickResponse: false
                                150-200 words, 8-10 seconds
    │
    ▼
LUMARA API → TTS → User hears response
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

### VoiceDepthMode Enum

```dart
enum VoiceDepthMode {
  transactional,  // Jarvis: Quick, efficient
  reflective,     // Samantha: Deep, engaged
}
```

### VoiceDepthResult

```dart
class VoiceDepthResult {
  final VoiceDepthMode depth;
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

### JarvisPromptBuilder (Transactional)

```dart
JarvisPromptBuilder.build(
  userText: "What time is my meeting tomorrow?",
  currentPhase: PhaseLabel.consolidation,
  conversationHistory: ["User: Hi / LUMARA: Hello!"],
);
```

**Output prompt characteristics:**
- Phase affects tone only, not depth
- 50-100 word response target
- No pattern recognition or memory retrieval
- Direct, efficient style

### SamanthaPromptBuilder (Reflective)

```dart
SamanthaPromptBuilder.build(
  userText: "I'm struggling with whether to take this new job...",
  currentPhase: PhaseLabel.transition,
  conversationHistory: [...],
  detectedTriggers: ["struggle_language", "decision_support"],
);
```

**Output prompt characteristics:**
- Phase affects both tone AND depth guidance
- 150-200 word response target
- May include one connecting question
- Warm, engaged, therapeutically-informed style

---

## Phase-Aware Styling

Both modes adapt tone based on current phase:

### Jarvis Mode (Tone Only)

| Phase | Tone |
|-------|------|
| Recovery | Gentle and supportive |
| Breakthrough | Direct and confident |
| Transition | Grounding and clear |
| Discovery | Encouraging and curious |
| Expansion | Energetic and focused |
| Consolidation | Steady and affirming |

### Samantha Mode (Tone + Depth)

| Phase | Guidance |
|-------|----------|
| Recovery | Extra validation. Slow pacing. No pressure. Honor processing needs. |
| Breakthrough | Match energy. Challenge strategically. Capitalize on clarity. |
| Transition | Normalize uncertainty. Ground. Navigate ambiguity without rushing. |
| Discovery | Encourage exploration. Reflect patterns. Support experimentation. |
| Expansion | Prioritize opportunities. Strategic guidance. Sustain momentum. |
| Consolidation | Integrate. Recognize progress. Support sustainability. |

---

## Design Decisions

### 1. No Journal History in Voice Mode

**Decision:** Voice mode does NOT retrieve semantic memory or journal history.

**Rationale:**
- Voice demands real-time responsiveness (<10s ceiling)
- Most reflective voice moments are about current processing
- Memory retrieval adds 3-7 seconds latency

**Future:** Add explicit trigger "What did I say about this before?" for on-demand history.

### 2. Per-Turn Classification

**Decision:** Each utterance is classified independently. No "sticky" mode.

**Example:**
```
User: "I'm struggling with this decision..." → SAMANTHA (deep)
User: "What time is it?" → JARVIS (quick)
User: "Actually, let's go back to that decision..." → SAMANTHA (deep)
```

### 3. No UI Mode Indicator

**Decision:** No visible indicator showing Jarvis/Samantha mode.

**Rationale:**
- Adds cognitive load for zero user benefit
- Response style IS the indicator
- Keep interface clean

### 4. Latency Ceiling: 10 Seconds

**Targets:**
- Jarvis: 3-5 seconds
- Samantha: 8-10 seconds
- Hard limit: 10 seconds (anything longer feels broken)

---

## Usage in VoiceSessionService

```dart
// In _processTranscript():

// 1. Classify depth
final depthResult = EntryClassifier.classifyVoiceDepth(transcript);
final isReflective = depthResult.depth == VoiceDepthMode.reflective;

// 2. Build appropriate prompt
String voicePrompt;
if (isReflective) {
  voicePrompt = SamanthaPromptBuilder.build(...);
} else {
  voicePrompt = JarvisPromptBuilder.build(...);
}

// 3. Call LUMARA API with mode-appropriate settings
final result = await _lumaraApi.generatePromptedReflection(
  entryText: transcript,
  intent: isReflective ? 'reflective' : 'conversational',
  chatContext: voicePrompt,
  forceQuickResponse: !isReflective,  // Only force quick for Jarvis
  ...
);
```

---

## Testing & Debugging

### Debug Output

The voice session service logs classification results:

```
VoiceSession: Depth classification: reflective (confidence: 0.75, triggers: struggle_language, decision_support)
VoiceSession: Using SAMANTHA mode (reflective)
VoiceSession: LUMARA API took 8234ms (Samantha mode, limit: 10000ms)
```

### Classification Examples

| Input | Classification | Triggers |
|-------|---------------|----------|
| "What time is it?" | transactional | [] |
| "Had a good lunch" | transactional | [] |
| "I'm struggling with this decision" | reflective | [struggle_language] |
| "Help me think through my career" | reflective | [processing_language] |
| "Why do I always do this?" | reflective | [self_reflective_question] |
| "I feel anxious about tomorrow" | reflective | [emotional_state] |

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
- `entry_classifier.dart` - Voice depth classification
- `voice_response_builders.dart` - Jarvis/Samantha prompts

---

## Transcription Backend Fallback Chain

Voice mode uses a two-tier transcription fallback system:

```
Voice Mode Start
       │
       ▼
┌─────────────────────────────────────────┐
│  1. ASSEMBLYAI (Primary)                │
│     ✓ High accuracy cloud               │
│     ✓ Real-time streaming               │
│     ✗ Requires PRO/BETA tier            │
└─────────────────────────────────────────┘
       │ If not PRO/unavailable
       ▼
┌─────────────────────────────────────────┐
│  2. APPLE ON-DEVICE (Fallback)          │
│     ✓ Always available                  │
│     ✓ No network required               │
│     ✓ No API costs                      │
│     ✗ Slightly lower accuracy           │
└─────────────────────────────────────────┘
```

### Implementation Files

| Component | File |
|-----------|------|
| Unified Service | `lib/arc/chat/voice/transcription/unified_transcription_service.dart` |
| AssemblyAI | `lib/arc/chat/voice/transcription/assemblyai_provider.dart` |
| Apple On-Device | `lib/arc/chat/voice/transcription/ondevice_provider.dart` |

### User Feedback Messages

| Backend | Message Shown |
|---------|---------------|
| AssemblyAI | (none - primary backend) |
| Apple On-Device | "Using on-device transcription" |

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

- v2.0 (2026-01-17): Removed Wispr Flow (commercial restrictions), AssemblyAI now primary
- v1.2 (2026-01-17): Added Apple On-Device as final transcription fallback
- v1.1 (2026-01-17): Added AssemblyAI fallback, fixed phase detection, fixed Finish button
- v1.0 (2026-01-17): Initial implementation with Jarvis/Samantha dual-mode system
