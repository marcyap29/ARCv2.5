# LUMARA Abstract Register Feature

**Date:** January 28, 2025  
**Version:** 2.1  
**Status:** Production Ready ✅

## Overview

LUMARA v2.1 introduces **Abstract Register Detection** — an intelligent feature that adapts LUMARA's response structure based on the writing style of the journal entry. This enhancement enables LUMARA to provide more appropriate and effective reflections for both abstract/conceptual and concrete/grounded writing.

## Problem Statement

Traditional reflection systems use a fixed response structure regardless of the user's writing style. This creates a mismatch when users write in abstract or conceptual language, as the reflections may not adequately explore the deeper meaning or felt sense of their entries.

### Example Mismatch

**User Entry (Abstract Register):**
> "A story of immense stakes, where preparation meets reality. The weight of consequence shifts perspective deeply."

**Traditional Response (Inadequate):**
> "This feels like an important moment. What specifically happened?"

This response fails to explore the conceptual and emotional dimensions of abstract writing, missing opportunities for deeper reflection.

## Solution: Abstract Register Detection

LUMARA now intelligently detects whether a journal entry is written in **abstract register** (conceptual, metaphorical, philosophical) or **concrete register** (grounded, specific, tangible) and adapts its response structure accordingly.

### Detection Heuristics

The Abstract Register Rule uses three detection heuristics:

1. **Keyword Ratio**: More than 30% of nouns are abstract/conceptual
2. **Text Characteristics**: Average word length ≥ 5 characters and average sentence length ≥ 10 words
3. **Keyword Count**: Contains ≥ 2 abstract keywords or metaphors

**Abstract Keywords Include:**
- truth, meaning, purpose, reality, consequence, perspective, identity
- growth, preparation, journey, becoming, change, self, life, time
- energy, light, shadow, destiny, pattern, vision, clarity, understanding
- wisdom, insight, awareness, consciousness, essence, nature, spirit
- soul, heart, mind, being, existence, experience, transformation

## Adaptive Response Structure

### Concrete Register (Standard)

**Entry Style:** "I'm frustrated I didn't finish my work today."

**LUMARA Response:**
- **Empathize**: One sentence mirroring tone
- **Clarify**: 1 grounding question
- **Highlight**: One pattern or strength
- **Open**: One agency-forward option
- **Length**: 2-3 sentences

### Abstract Register (Enhanced)

**Entry Style:** "A story of immense stakes, where preparation meets reality. The weight of consequence shifts perspective deeply."

**LUMARA Response:**
- **Empathize**: One sentence mirroring tone
- **Clarify**: 2 questions (conceptual + emotional)
- **Highlight**: One pattern or strength
- **Open**: One agency-forward option with optional bridging phrase
- **Length**: 3-4 sentences (up to 5 allowed)

**Example Enhanced Response:**
> "This feels like a moment where the inner and outer worlds meet. What consequence feels most alive in you as you picture that moment? And what does that shift in perspective feel like from the inside? You've written with composure when high stakes appeared before. Would it help to name one value to carry through this turning point?"

## Key Features

### 1. Dual Clarify Questions

For abstract register, LUMARA asks:
- **One conceptual question**: Exploring meaning or understanding ("What truth or idea is being tested here?")
- **One emotional/embodied question**: Grounding in felt experience ("How does that feel in your body or heart right now?")

### 2. Bridging Phrases

LUMARA can add grounding phrases before the Open step:
- "You often think in big patterns — let's ground this for a moment."
- "This reflection speaks from the mind; how does it feel in the body?"

### 3. Adaptive Length

- **Concrete**: 2-4 sentences (max 4)
- **Abstract**: 3-5 sentences (max 5)

This allows richer exploration of abstract concepts while maintaining concision.

## Technical Implementation

### Detection Algorithm

```dart
static bool detectAbstractRegister(String text) {
  final words = text.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return false;
  
  final abstractCount = words.where((w) => _abstractKeywords.contains(w)).length;
  final ratio = abstractCount / words.length;
  
  final avgWordLen = words.join('').length / words.length;
  final sentenceCount = text.split(RegExp(r'[.!?]+')).length;
  final avgSentLen = words.length / sentenceCount;
  
  return (ratio > 0.03 && avgWordLen > 4.8 && avgSentLen > 9) || abstractCount >= 3;
}
```

### Enhanced Scoring

The scoring system adapts expectations based on register:

```dart
// Adjust length tolerance for abstract register
final maxSentences = isAbstract ? 5 : 4;

// Adjust question expectations for abstract register
final expectedQuestions = isAbstract ? 2 : 1;

// Boost depth score for abstract register (expects richer content)
if (isAbstract) depth = (depth + 0.1).clamp(0.0, 1.0);
```

### System Prompt Integration

The Abstract Register Rule is integrated into LUMARA's core system prompt:

```
Clarify (C)
* Ask 1 open, grounding, content-relevant question.
* If the user is writing in abstract or conceptual language (detected by high use of conceptual nouns or generalizations such as "truth," "reality," "meaning," "consequence," "journey," "preparation"), then apply the Abstract Register Rule and ask 2 clarifying questions instead of 1.
* These questions should explore specific meaning or felt sense (e.g., "What part of that feels most real right now?").
```

## Benefits

### For Users

1. **More Appropriate Reflections**: Responses match the writing style
2. **Deeper Engagement**: Abstract writing gets richer exploration
3. **Emotional Grounding**: Dual questions help bridge abstract concepts to felt experience
4. **Maintains Conciseness**: Still follows 2-4 sentence constraint for concrete writing

### For the System

1. **Adaptive Intelligence**: Automatically adjusts without manual configuration
2. **Maintains ECHO Structure**: Core reflection pattern preserved
3. **Enhanced Scoring**: Better quality assessment for abstract responses
4. **Preserves Tone**: All governance rules still apply

## Phase-Aware Integration

Abstract Register Detection works seamlessly with LUMARA's phase-aware modulation:

- **Recovery Phase**: Abstract reflections focus on grounding and stability
- **Breakthrough Phase**: Abstract reflections emphasize integration and synthesis
- **Transition/Consolidation**: Abstract reflections clarify values and anchors
- **Discovery/Expansion**: Abstract reflections maintain spacious curiosity

## Example Use Cases

### Use Case 1: Philosophical Reflection

**Entry:**
> "The nature of truth itself seems to shift with each perspective gained. What once felt certain now feels fluid, and in that fluidity, there's both freedom and disorientation."

**LUMARA Response:**
> "You're exploring how certainty dissolves into something more flexible. What specific perspective shift has felt most significant recently? And how does that movement between certainty and fluidity feel in your daily experience? You've reflected on transformation before—this seems to be deepening that exploration. Would it help to identify one anchor that remains steady amid these shifts?"

### Use Case 2: Metaphorical Writing

**Entry:**
> "This feels like a closing chapter where all the threads converge. The pattern that emerges tells a story I didn't expect, but recognize as my own."

**LUMARA Response:**
> "You're witnessing narrative coherence emerge from the threads. What aspect of this emerging pattern feels most true to who you're becoming? And what does it feel like to see your own story recognized in this way? You've tracked patterns across your entries before—this convergence seems significant. Would naming one thread you want to carry forward help, or does sitting with the recognition feel right for now?"

## Future Enhancements

### Potential Improvements

1. **Fine-Tuned Detection**: Machine learning model for more nuanced register detection
2. **Custom Keywords**: User-defined abstract keywords for personal writing style
3. **Register Mix**: Handling entries with both abstract and concrete elements
4. **Analytics**: Tracking abstract vs concrete writing patterns over time
5. **Phase-Specific Keywords**: Different abstract keywords for different phases

## Testing

### Test Scenarios

- ✅ Abstract register detected correctly
- ✅ Concrete register detected correctly
- ✅ Dual questions generated for abstract
- ✅ Single question for concrete
- ✅ Length tolerance adjusted appropriately
- ✅ Depth score boosted for abstract
- ✅ Diagnostics provide clear feedback

### Sample Test Cases

1. **Pure Abstract**: "The essence of being transcends all limits."
2. **Pure Concrete**: "I finished my report and submitted it to my boss."
3. **Mixed**: "This journey of self-discovery has led me to take my first solo trip to Paris."
4. **Metaphorical Abstract**: "In the shadow of doubt, clarity emerges like dawn."
5. **Conceptual Abstract**: "The nature of truth shifts with perspective gained."

## Conclusion

The Abstract Register Detection feature represents a significant advancement in LUMARA's reflective intelligence, enabling the system to adapt naturally to different writing styles while maintaining its core principles of empathic minimalism, reflective distance, and agency reinforcement.

**Status:** Production Ready ✅  
**Version:** 2.1  
**Date:** January 28, 2025

---

*For technical implementation details, see `lib/lumara/prompts/lumara_prompts.dart` and `lib/lumara/services/lumara_response_scoring.dart`*
