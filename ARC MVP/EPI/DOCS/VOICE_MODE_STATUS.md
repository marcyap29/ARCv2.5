# Voice Mode Status & Architecture

> Last Updated: January 22, 2026 (v3.3.10)
> 
> **STATUS: IMPLEMENTED** - Phase-specific prompts with seeking classification for improved response quality.
> See [VOICE_MODE_IMPLEMENTATION_GUIDE.md](./VOICE_MODE_IMPLEMENTATION_GUIDE.md) for full details.

## Overview

Voice mode allows users to have spoken conversations with LUMARA. The system captures speech via **Wispr Flow** (optional, user-provided API key) or **Apple On-Device** (default), processes it through PRISM (PII scrubbing), sends to LUMARA for response generation, and plays back via TTS.

**Voice mode uses two classification systems:**

### 1. Engagement Mode (Three-Tier System)
- **Reflect Mode** (default) - Casual conversation, 1-3 sentences, 100 words max
- **Explore Mode** (when asked) - Pattern analysis, 4-8 sentences, 200 words max
- **Integrate Mode** (when asked) - Cross-domain synthesis, 6-12 sentences, 300 words max

### 2. Seeking Classification (NEW in v3.3.9)
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

---

## Voice Usage Limits

| Subscription | Monthly Limit |
|--------------|---------------|
| **Free** | 60 minutes |
| **Premium** | Unlimited |

- Usage resets on the 1st of each month
- Remaining time shown in voice mode UI
- Upgrade dialog shown when limit reached

---

## Current Implementation Status

### What's Working
- Long-press on "+" button activates voice mode
- **Wispr Flow** (optional) or **Apple On-Device** (default) for speech-to-text
- Tap-to-toggle interaction (tap to start recording, tap to stop)
- PRISM PII scrubbing before sending to LUMARA (PII never leaves device)
- TTS playback of LUMARA responses (with PII restored)
- Phase-aware UI colors (matches user's current phase)
- Visual feedback (sigil animations for listening/thinking/speaking states)
- Multi-turn conversations within a session
- **Voice usage tracking** with monthly limits for free users
- **Sessions saved to timeline** when user taps "Finish"
- **Export/import compatible** - voice entries preserve all metadata

### Current Response Path
Voice mode now uses the **full Master Unified Prompt** (260KB) matching written mode, ensuring consistent personality, tone, and capabilities:

| Engagement Mode | Response Length | Latency Target | Processing |
|-----------------|-----------------|----------------|------------|
| Reflect (default) | 1-3 sentences, 100 words max | 5 sec | Lightweight (skips node matching) |
| Explore (when asked) | 4-8 sentences, 200 words max | 10 sec | Full processing (pattern analysis) |
| Integrate (when asked) | 6-12 sentences, 300 words max | 15 sec | Full processing (synthesis) |

**Benefits:**
- Full access to user's journal history
- Pattern recognition across entries
- Deep therapeutic engagement
- Phase-specific guidance from the master prompt
- Consistent personality and tone with written mode
- Multi-turn conversation tracking

---

## File Locations

| Component | Path |
|-----------|------|
| Voice Session Service | `lib/arc/chat/voice/services/voice_session_service.dart` |
| Voice Usage Service | `lib/arc/chat/voice/services/voice_usage_service.dart` |
| Voice Mode Screen | `lib/arc/chat/voice/ui/voice_mode_screen.dart` |
| Voice Sigil Widget | `lib/arc/chat/voice/ui/voice_sigil.dart` |
| Unified Transcription | `lib/arc/chat/voice/transcription/unified_transcription_service.dart` |
| Apple On-Device Provider | `lib/arc/chat/voice/transcription/ondevice_provider.dart` |
| Wispr Flow Service | `lib/arc/chat/voice/wispr/wispr_flow_service.dart` |
| Wispr Config Service | `lib/arc/chat/voice/config/wispr_config_service.dart` |
| TTS Client | `lib/arc/chat/voice/voice_journal/tts_client.dart` |
| Voice System Initializer | `lib/arc/chat/voice/config/voice_system_initializer.dart` |
| Enhanced LUMARA API | `lib/arc/chat/services/enhanced_lumara_api.dart` |
| Entry Classifier | `lib/services/lumara/entry_classifier.dart` |

---

## Proposed Enhancement: Dual-Mode Voice Conversations

### Vision
Support two conversation styles within voice mode:

| Mode | Inspiration | Character |
|------|-------------|-----------|
| **Jarvis Mode** | Tony Stark's AI | Quick, efficient, transactional |
| **Samantha Mode** | "Her" (2013 film) | Deep, reflective, emotionally engaged |

### Proposed Flow

```
User speaks
    │
    ▼
Transcribed → "I need to process something that happened today..."
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  VOICE DEPTH DETECTOR                                   │
│  Analyzes transcript for "Samantha triggers"            │
│                                                         │
│  Trigger phrases:                                       │
│  - "I need to process..."                               │
│  - "I'm struggling with..."                             │
│  - "Help me think through..."                           │
│  - "I'm feeling [emotional word]..."                    │
│  - "I don't know what to do about..."                   │
│  - "Can we talk about..."                               │
│  - "Something's been bothering me..."                   │
│  - "I need to work through..."                          │
│  - High emotional word density                          │
│  - Long utterances (>50 words)                          │
└─────────────────────────────────────────────────────────┘
    │
    ├─── No triggers ────────► JARVIS MODE
    │                           - Fast path prompt (~200 words)
    │                           - Response: 50-100 words
    │                           - Latency: 2-5 seconds
    │                           - Style: Direct, helpful, efficient
    │
    └─── Triggers detected ──► SAMANTHA MODE
                                - Voice-optimized prompt (~10-20KB)
                                - Response: 150-200 words
                                - Latency: 8-15 seconds
                                - Style: Warm, reflective, engaged
                                - Includes: Phase awareness, recent context
```

### Key Design Decisions

1. **Default is Jarvis (fast)**
   - Most voice interactions are quick queries or updates
   - Fast response feels more natural for voice
   - Reduces API costs and latency

2. **Auto-switch to Samantha based on content**
   - No UI toggle required
   - User's words signal their needs
   - Evaluated fresh each turn

3. **Per-turn evaluation**
   - Each utterance is evaluated independently
   - User can have quick exchanges, then go deep, then back to quick
   - Mirrors natural conversation flow

4. **Voice-optimized Samantha prompt**
   - NOT the full 260KB master prompt
   - Trimmed version (~10-20KB) that includes:
     - LUMARA's core personality
     - Current phase context
     - Recent conversation history (this session)
     - Emotional attunement guidelines
   - Excludes:
     - Full journal history retrieval
     - Pattern analysis across months
     - Heavy memory matching algorithms

---

## Implementation Plan

### Phase 1: Voice Depth Detector
Create a new utility class that analyzes transcripts for depth triggers.

```dart
class VoiceDepthDetector {
  /// Determines if the user's speech indicates need for deep engagement
  static VoiceDepthMode detectDepth(String transcript) {
    // Check for explicit triggers
    // Check emotional word density
    // Check utterance length
    // Return jarvis or samantha
  }
}

enum VoiceDepthMode {
  jarvis,   // Quick, efficient responses
  samantha, // Deep, reflective engagement
}
```

### Phase 2: Voice-Optimized Samantha Prompt
Create a trimmed prompt that balances depth with speed.

```dart
class VoiceSamanthaPrompt {
  static String build({
    required String userText,
    required String phase,
    required List<String> conversationHistory,
  }) {
    // ~10-20KB prompt with:
    // - LUMARA personality core
    // - Phase-specific guidance
    // - Conversation context
    // - 150-200 word target
  }
}
```

### Phase 3: Routing Logic
Update `voice_session_service.dart` to route between modes.

```dart
// In _processTranscript():
final depthMode = VoiceDepthDetector.detectDepth(transcript);

if (depthMode == VoiceDepthMode.samantha) {
  // Use Samantha path with voice-optimized prompt
  final response = await _lumaraApi.generatePromptedReflection(
    entryText: transcript,
    forceQuickResponse: false,  // Allow deeper processing
    chatContext: VoiceSamanthaPrompt.build(...),
  );
} else {
  // Use Jarvis path (current fast implementation)
  final response = await _lumaraApi.generatePromptedReflection(
    entryText: transcript,
    forceQuickResponse: true,
  );
}
```

---

## Trigger Phrase Examples

### Jarvis Mode (default - no triggers)
- "What time is it?"
- "Remind me about my meeting"
- "Had a good lunch today"
- "The weather is nice"
- "Add milk to my shopping list"

### Samantha Mode (triggers detected)
- "I need to process what happened at work today"
- "I'm struggling with my relationship with my dad"
- "Help me think through this decision"
- "I'm feeling really anxious about tomorrow"
- "Something's been weighing on me"
- "I don't know what to do about my career"
- "Can we talk about what I mentioned yesterday?"
- "I need to work through some feelings"

---

## Response Style Comparison

### Jarvis Response Example
**User:** "How did my meeting go yesterday?"

**LUMARA:** "Your meeting with the product team went well - you mentioned feeling heard when you proposed the timeline change. The team agreed to the two-week extension."

*(~30 words, 3 seconds)*

### Samantha Response Example
**User:** "I'm struggling with whether to take this new job offer..."

**LUMARA:** "That sounds like a significant crossroads. From what you've shared recently, your current role has felt limiting, but there's also comfort in the familiar relationships you've built there. 

What feels most alive when you imagine yourself in the new role? And what feels most scary? Sometimes the tension between those two feelings can reveal what matters most to you right now.

I'm here to think through this with you, at whatever pace feels right."

*(~85 words, 10 seconds)*

---

## Open Questions

1. **Should Samantha mode access journal history?**
   - Pro: More personalized, can reference past patterns
   - Con: Adds latency (memory retrieval), increases prompt size

2. **Should there be a "sticky" mode?**
   - Once Samantha is triggered, stay in Samantha for the session?
   - Or re-evaluate each turn independently?

3. **Should the UI indicate which mode is active?**
   - Subtle indicator showing "deep conversation" mode?
   - Or keep it invisible/seamless?

4. **What's the maximum acceptable latency for Samantha mode?**
   - 8-10 seconds feels conversational
   - 15+ seconds might feel like the app is broken

5. **Should certain phases default to Samantha?**
   - Recovery phase users might need deeper engagement by default
   - Discovery phase users might prefer quick exchanges

---

## Technical Considerations

### API Costs
- Jarvis: ~200 input tokens, ~100 output tokens
- Samantha: ~2000-5000 input tokens, ~200 output tokens
- Full Master Prompt: ~50000+ input tokens, ~500 output tokens

### Latency Breakdown (Estimated)
| Step | Jarvis | Samantha |
|------|--------|----------|
| Transcription | 0.5s | 0.5s |
| PRISM scrubbing | 0.1s | 0.1s |
| Depth detection | - | 0.1s |
| Prompt building | 0.1s | 0.5s |
| LLM API call | 2-3s | 5-10s |
| TTS start | 0.5s | 0.5s |
| **Total to first audio** | **3-4s** | **7-12s** |

---

## Next Steps

1. Review this document and confirm approach
2. Implement VoiceDepthDetector with trigger phrase list
3. Create VoiceSamanthaPrompt (trimmed voice-optimized prompt)
4. Update voice_session_service.dart routing logic
5. Test with various conversation styles
6. Tune trigger phrases based on real usage

---

## Related Documentation

- [LUMARA Response Systems](./LUMARA_RESPONSE_SYSTEMS.md) - How EntryClassifier and response modes work
- [Sentinel Architecture](./SENTINEL_ARCHITECTURE.md) - Safety and emotional detection
- [Prompt References](./PROMPT_REFERENCES.md) - Master prompt structure
