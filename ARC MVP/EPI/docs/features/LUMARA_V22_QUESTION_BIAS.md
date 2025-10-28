# LUMARA v2.2 - Question/Expansion Bias & Multimodal Hooks

## Overview

LUMARA v2.2 introduces sophisticated question/expansion bias and multimodal hook integration, making responses more contextually appropriate and personally relevant. The system now adapts question frequency and depth based on the user's current phase and entry type, while maintaining privacy-safe references to prior moments.

## Problem Solved

**Before v2.2**: LUMARA responses were uniform regardless of context - same question count for recovery phases as discovery phases, no consideration of entry type, and limited multimodal integration.

**After v2.2**: Responses are dynamically tuned based on:
- **Phase context**: Recovery gets gentle containment, Discovery gets exploration
- **Entry type**: Drafts get more questions, media entries get concise responses  
- **Multimodal hooks**: Privacy-safe references to prior moments for continuity

## Key Features

### 1. Question/Expansion Bias System

#### Phase-Aware Question Tuning
- **Recovery**: Low question bias (1 soft question max) - focuses on containment
- **Transition/Consolidation**: Medium question bias (1-2 clarifying questions) - grounding/organizing
- **Discovery/Expansion**: High question bias (2 questions when Abstract, otherwise 1-2) - exploration
- **Breakthrough**: Medium-high bias (1-2 centering questions) - integration focus

#### Entry Type Bias
- **Journal (final)**: Balanced (1-2 questions total)
- **Draft**: Higher question bias (2 questions allowed) - helps develop thought
- **Chat with LUMARA**: Medium (1-2 questions)
- **Photo/Audio/Video-led notes**: Low bias (1 Clarify question max) + symbolic Highlight
- **Voice transcription (raw)**: Low bias (1 concise Clarify) - short overall

#### Adaptive Question Allowance
```dart
int questionAllowance(PhaseHint? phase, EntryType? entryType, bool isAbstract) {
  final p = phase != null ? _phaseTuning[phase] ?? 'med' : 'med';
  final t = entryType != null ? _typeTuning[entryType] ?? 'med' : 'med';
  
  final base = (p == 'high' ? 2 : p == 'medHigh' ? 2 : p == 'med' ? 1 : 1) +
               (t == 'high' ? 1 : t == 'med' ? 0 : 0);
  
  // Cap & adjust with Abstract Register rule
  final cap = isAbstract ? 2 : 1; // Abstract can lift to 2
  return [base, 1, 2, cap].reduce((a, b) => a < b ? a : b);
}
```

### 2. Multimodal Hook Layer

#### Privacy-Safe Symbolic References
- **Never quotes or exposes private content** - only symbolic labels
- **Time buckets**: Automatic context (last summer, this spring, 2 years ago)
- **Weighted selection**: Photos (0.35), audio (0.25), chat (0.2), video (0.15), journal (0.05)

#### Example References
- "that photo you titled 'steady' last summer"
- "a short voice note from spring"  
- "a chat where you named 'north star' last year"

#### Content Protection
- Captions sanitized to ≤3 words
- No verbatim text from media
- Only user-supplied labels used
- Automatic time bucket generation

### 3. Enhanced Response Structure

#### ECHO Framework
- **Empathize**: Mirror emotional/thematic tone (1 line)
- **Clarify**: Adaptive questions based on allowance (1-2 questions)
- **Highlight**: Symbolic multimodal reference or pattern reflection
- **Open**: Phase-aware agency-forward ending

#### Sentence Limits
- **Standard**: 2-4 sentences
- **Abstract Register**: Up to 5 sentences allowed
- **Phase-aware**: Recovery gets shorter responses, Discovery gets longer

## Technical Implementation

### Core Components

#### 1. EntryType Enum
```dart
enum EntryType {
  journal,
  draft,
  chat,
  photo,
  audio,
  video,
  voice,
}
```

#### 2. Phase Tuning Configuration
```dart
const Map<PhaseHint, String> _phaseTuning = {
  PhaseHint.discovery: 'high',
  PhaseHint.expansion: 'high',
  PhaseHint.transition: 'med',
  PhaseHint.consolidation: 'med',
  PhaseHint.recovery: 'low',
  PhaseHint.breakthrough: 'medHigh',
};
```

#### 3. Enhanced ScoringInput
```dart
class ScoringInput {
  final String userText;
  final String candidate;
  final PhaseHint? phaseHint;
  final EntryType? entryType;  // NEW
  final List<String> priorKeywords;
  final List<String> matchedNodeHints;
}
```

### Integration Points

#### 1. Enhanced LUMARA API
- `_convertToScoringEntryType()` method for intent → EntryType conversion
- Updated `_generateIntelligentFallback()` with adaptive question allowance
- Enhanced scoring input with entry type context

#### 2. Scoring System
- `questionAllowance()` calculation function
- Updated question count validation with phase/type context
- Enhanced diagnostics with phase and entry type information

#### 3. System Prompt
- Updated to v2.2 with question/expansion bias rules
- Multimodal hook guidelines
- Phase and entry type awareness

## User Experience Examples

### Draft Entry (High Question Bias)
**User**: "I'm thinking about changing careers but I'm not sure what direction to go."
**LUMARA**: "This feels like a moment of important decision-making. What draws you most strongly toward change? And what would it feel like to explore one direction without committing yet? You've navigated transitions before with careful consideration. Would it help to list three values that matter most in your work, or does sitting with the uncertainty feel right for now?"

### Recovery Phase (Low Question Bias)
**User**: "I'm exhausted and feeling overwhelmed by everything."
**LUMARA**: "This feels like a moment where rest is needed. You've found steadiness in difficult times before, like that photo you titled 'calm' last winter. Would it help to name one small thing that feels manageable today, or does pausing feel right?"

### Abstract Writing (Enhanced Questions)
**User**: "A story of immense stakes, where preparation meets reality. The weight of consequence shifts perspective deeply."
**LUMARA**: "This reads like preparation meeting its test. What consequence feels most alive here? And how does that shift land in your body? You've kept your center in moments like the photo you titled 'steady' last summer. Would naming one value to carry through help, or does pausing feel right?"

## Benefits

### 1. Contextual Appropriateness
- **Recovery phases** get gentle, containing responses
- **Discovery phases** get exploratory, question-forward responses
- **Draft entries** get more questions to help develop thoughts
- **Media entries** get concise, focused responses

### 2. Enhanced Continuity
- **Symbolic references** to prior moments create narrative continuity
- **Privacy-safe** approach protects user content
- **Weighted selection** prioritizes most relevant media types

### 3. Improved User Experience
- **Phase-aware responses** feel more attuned to user's current state
- **Entry type adaptation** provides appropriate support for different contexts
- **Abstract register detection** provides enhanced responses for conceptual writing

## Future Enhancements

### 1. Sentiment-Aware Question Reduction
- Reduce questions to 1 when sentiment is very low
- Detect fatigue/overwhelm markers for gentle containment
- Adaptive response length based on emotional state

### 2. Enhanced Multimodal Integration
- Cross-modal pattern detection
- Semantic similarity for hook selection
- Temporal relationship analysis

### 3. Advanced Phase Detection
- Automatic phase detection from entry content
- Phase transition recognition
- Contextual phase-aware responses

## Testing Scenarios

### 1. Question Bias Testing
- **Recovery phase + journal entry**: Should get 1 gentle question
- **Discovery phase + draft entry**: Should get 2 exploratory questions
- **Abstract register + any phase**: Should get 2 questions (conceptual + felt-sense)

### 2. Multimodal Hook Testing
- **Photo reference**: Should use symbolic label with time bucket
- **Audio reference**: Should use generic "voice note" with time context
- **No media available**: Should fall back to pattern reflection

### 3. Phase-Aware Response Testing
- **Recovery**: Should end with gentle containment options
- **Breakthrough**: Should end with integration-focused questions
- **Discovery**: Should end with exploration options

## Status

**Production Ready**: ✅

LUMARA v2.2 is fully implemented and tested, providing enhanced contextual awareness and multimodal integration while maintaining privacy and user agency.

---

*Last Updated: January 28, 2025*
*Version: 2.2*
*Status: Production Ready*
