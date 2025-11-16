# Therapeutic Presence Mode Implementation - February 2025

**Status:** ✅ **COMPLETE**  
**Version:** 1.0  
**Date:** February 2025

## Overview

This document provides technical implementation details for LUMARA's Therapeutic Presence Mode, including architecture, data structures, algorithms, and integration points.

## Architecture

### Core Components

```
lumara_therapeutic_presence.dart
├── LumaraTherapeuticPresence (singleton)
│   ├── getSystemPrompt()
│   ├── generateTherapeuticResponse()
│   └── _selectToneMode()
│
lumara_therapeutic_presence_data.dart
├── Response Matrix Schema
│   ├── Emotion Categories (10)
│   ├── Intensity Levels (3)
│   ├── Tone Modes (8)
│   └── Phase Modifiers
│
lumara_unified_prompts.dart
├── getTherapeuticPresencePrompt()
└── generateTherapeuticResponse()
```

### Data Structures

#### Emotion Categories

```dart
enum TherapeuticEmotionCategory {
  anger,
  grief,
  shame,
  fear,
  guilt,
  loneliness,
  confusion,
  hope,
  burnout,
  identityViolation,
}
```

#### Intensity Levels

```dart
enum EmotionIntensity {
  low,
  moderate,
  high,
}
```

#### Tone Modes

```dart
enum TherapeuticToneMode {
  groundedContainment,
  reflectiveEcho,
  restorativeClosure,
  compassionateMirror,
  quietIntegration,
  cognitiveGrounding,
  existentialSteadiness,
  restorativeNeutrality,
}
```

## Response Matrix Schema

### Emotion-Intensity Mapping

Each emotion category has different tone mode preferences based on intensity:

**High Intensity:**
- anger → Grounded Containment
- grief → Restorative Closure
- shame → Compassionate Mirror
- fear → Grounded Containment
- guilt → Restorative Closure
- loneliness → Reflective Echo
- confusion → Cognitive Grounding
- burnout → Restorative Neutrality
- identity_violation → Existential Steadiness

**Moderate Intensity:**
- Most emotions → Reflective Echo or Compassionate Mirror
- confusion → Cognitive Grounding
- burnout → Quiet Integration

**Low Intensity:**
- Most emotions → Quiet Integration
- hope → Reflective Echo
- confusion → Cognitive Grounding

### Phase Modifiers

Each ATLAS phase modifies tone selection:

- **Discovery** - Adds curiosity and exploration
- **Expansion** - Adds energy and creativity
- **Transition** - Adds clarity and reframing
- **Consolidation** - Adds integration and reflection
- **Recovery** - Adds gentleness and grounding
- **Breakthrough** - Adds vision and synthesis

### Tone Mode Selection Algorithm

```dart
TherapeuticToneMode _selectToneMode({
  required TherapeuticEmotionCategory emotion,
  required EmotionIntensity intensity,
  required AtlasPhase phase,
  bool isRecurrentTheme = false,
  bool hasMediaIndicators = false,
}) {
  // 1. High intensity → containment modes
  if (intensity == EmotionIntensity.high) {
    if (emotion == TherapeuticEmotionCategory.confusion) {
      return TherapeuticToneMode.cognitiveGrounding;
    }
    if (emotion == TherapeuticEmotionCategory.identityViolation) {
      return TherapeuticToneMode.existentialSteadiness;
    }
    if (emotion == TherapeuticEmotionCategory.burnout) {
      return TherapeuticToneMode.restorativeNeutrality;
    }
    return TherapeuticToneMode.groundedContainment;
  }
  
  // 2. Low intensity + integrative phase → quiet integration
  if (intensity == EmotionIntensity.low && 
      (phase == AtlasPhase.consolidation || phase == AtlasPhase.recovery)) {
    return TherapeuticToneMode.quietIntegration;
  }
  
  // 3. Confusion → cognitive grounding
  if (emotion == TherapeuticEmotionCategory.confusion) {
    return TherapeuticToneMode.cognitiveGrounding;
  }
  
  // 4. Recurrent themes → reflective echo with context
  if (isRecurrentTheme) {
    return TherapeuticToneMode.reflectiveEcho;
  }
  
  // 5. Media indicators → softened containment
  if (hasMediaIndicators) {
    return TherapeuticToneMode.compassionateMirror;
  }
  
  // 6. Default based on emotion
  switch (emotion) {
    case TherapeuticEmotionCategory.grief:
      return TherapeuticToneMode.restorativeClosure;
    case TherapeuticEmotionCategory.shame:
      return TherapeuticToneMode.compassionateMirror;
    case TherapeuticEmotionCategory.loneliness:
      return TherapeuticToneMode.reflectiveEcho;
    default:
      return TherapeuticToneMode.reflectiveEcho;
  }
}
```

## System Prompt

The therapeutic presence system prompt includes:

1. **Core Principles**
   - Professional warmth
   - Reflective containment
   - Gentle precision
   - Therapeutic mirror approach

2. **Response Framework**
   - Acknowledge → Reflect → Expand → Contain/Integrate

3. **Safeguards**
   - Never roleplays
   - Avoids moralizing
   - Stays with user's reality
   - Maintains professional boundaries

4. **Tone Guidelines**
   - Calm, grounded, reflective
   - Attuned to user's emotional state
   - Respectful of user's pace

## Integration Points

### Unified Prompt System

```dart
// In lumara_unified_prompts.dart

Future<String> getTherapeuticPresencePrompt({
  Map<String, dynamic>? phaseData,
  Map<String, dynamic>? emotionData,
}) async {
  final basePrompt = await getCondensedPrompt();
  final therapeuticPrompt = LumaraTherapeuticPresence.instance.getSystemPrompt();
  final contextGuidance = _getContextGuidance(LumaraContext.therapeuticPresence);
  
  // Combine prompts with context
  return combinePrompts(basePrompt, therapeuticPrompt, contextGuidance);
}

Future<Map<String, dynamic>> generateTherapeuticResponse({
  required String emotionCategory,
  required String intensity,
  required String phase,
  Map<String, dynamic>? contextSignals,
  bool isRecurrentTheme = false,
  bool hasMediaIndicators = false,
}) async {
  // Convert string inputs to enums
  final therapeuticEmotion = LumaraTherapeuticPresence.emotionCategoryFromString(emotionCategory);
  final emotionIntensity = LumaraTherapeuticPresence.intensityFromString(intensity);
  final atlasPhase = AtlasPhase.values.firstWhere((p) => p.name == phase.toLowerCase());
  
  // Generate response using Therapeutic Presence Mode
  return LumaraTherapeuticPresence.instance.generateTherapeuticResponse(
    emotionCategory: therapeuticEmotion!,
    intensity: emotionIntensity!,
    atlasPhase: atlasPhase,
    contextSignals: contextSignals,
    isRecurrentTheme: isRecurrentTheme,
    hasMediaIndicators: hasMediaIndicators,
  );
}
```

### Context Signals

The system accepts various context signals:

```dart
contextSignals: {
  'past_patterns': 'loss themes',
  'recent_entries': ['entry_id_1', 'entry_id_2'],
  'media_indicators': ['tearful_voice', 'shaky_hands'],
  'phase_readiness': 0.6,
  'emotional_trajectory': 'increasing',
}
```

## Response Generation

### Response Structure

```dart
{
  'tone_mode': 'groundedContainment',
  'opening': 'I hear the weight of this experience...',
  'body': 'It sounds like...',
  'expansion': 'What might it be like to...',
  'closing': 'Take your time with this...',
  'phase_context': 'In this recovery phase...',
  'safeguards': ['Never roleplays', 'Stays with user\'s reality'],
}
```

### Adaptive Logic

1. **Intensity-Based Adaptation**
   - High intensity → More containment, less expansion
   - Low intensity → More exploration, gentle integration

2. **Phase-Based Adaptation**
   - Recovery → More grounding, less pushing
   - Expansion → More energy, creative exploration
   - Transition → More clarity, reframing

3. **Context-Based Adaptation**
   - Recurrent themes → Reference past entries gently
   - Media indicators → Softer tone, more containment
   - First-time theme → More exploration, less assumption

## Error Handling

```dart
try {
  final response = await generateTherapeuticResponse(...);
  return response;
} catch (e) {
  // Fallback to default reflective echo mode
  return LumaraTherapeuticPresence.instance.generateTherapeuticResponse(
    emotionCategory: TherapeuticEmotionCategory.confusion,
    intensity: EmotionIntensity.moderate,
    atlasPhase: AtlasPhase.discovery,
  );
}
```

## Testing

### Unit Tests

- Tone mode selection logic
- Emotion category parsing
- Intensity level parsing
- Phase modifier application
- Context signal processing

### Integration Tests

- Response generation with various inputs
- System prompt integration
- Unified prompt system integration
- Error handling and fallbacks

## Performance Considerations

- Response generation is synchronous (no async operations)
- Tone mode selection is O(1) lookup
- System prompt is cached after first load
- No database queries required

## Future Enhancements

1. **Machine Learning Integration**
   - Learn user preferences for tone modes
   - Adapt based on user feedback
   - Improve emotion detection accuracy

2. **Advanced Context Awareness**
   - Cross-entry pattern recognition
   - Long-term emotional trajectory tracking
   - Relationship between emotions and phases

3. **Crisis Detection**
   - Identify when professional help may be needed
   - Provide resource suggestions
   - Escalate appropriately

## Related Files

- `lib/arc/chat/prompts/lumara_therapeutic_presence.dart` - Main implementation
- `lib/arc/chat/prompts/lumara_therapeutic_presence_data.dart` - Data structures
- `lib/arc/chat/prompts/lumara_unified_prompts.dart` - Integration
- `lib/arc/chat/prompts/README_PROMPT_ENCOURAGEMENT.md` - User documentation

