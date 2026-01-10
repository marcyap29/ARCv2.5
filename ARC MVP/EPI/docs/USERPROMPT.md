# LUMARA Unified Prompt System

**Status:** ✅ **ACTIVE** (Deprecated - Now Unified)  
**Version:** 3.2  
**Date:** January 2026

---

## Overview

**⚠️ NOTE: As of v3.2, the user prompt has been unified into the master prompt. This document is kept for historical reference.**

The LUMARA prompt system has been consolidated into a single unified prompt that contains all instructions, constraints, entry text, and context in one place.

## Architecture

### Unified Prompt System (v3.2+)

LUMARA now uses a single unified prompt:

1. **Unified Master Prompt**: Contains all behavior rules, constraints, entry text, and context
2. **No separate user prompt**: Everything is in one place

**Benefits:**
- Single source of truth
- No duplication of constraints
- No override risk
- Simpler codebase
- Easier maintenance

### Previous Two-Prompt System (v3.0-v3.1)

Previously, LUMARA used a two-prompt architecture:

1. **Master Prompt (System Prompt)**: Defines overall behavior, persona, and constraints
2. **User Prompt**: Provides specific entry content and reinforces constraints

**Critical Rule:** The user prompt came **after** the master prompt, so it had to **reinforce** constraints, not contradict them.

### Control State Flow

```
Entry Classification
    ↓
Persona Selection (Companion-First)
    ↓
Response Mode Configuration
    ↓
Control State Builder
    ↓
Master Prompt (System)
    ↓
User Prompt (Reinforces Constraints)
    ↓
LLM Response
```

## User Prompt Builder

### Location

`lib/arc/chat/services/enhanced_lumara_api.dart`

### Method: `_buildUserPrompt()`

Builds the user prompt that respects control state constraints.

**Parameters:**
- `baseContext`: Historical entries, mood, phase context
- `entryText`: Current journal entry text
- `effectivePersona`: Selected persona (companion, strategist, therapist, challenger)
- `maxWords`: Word limit from control state
- `minPatternExamples`: Minimum dated examples required
- `maxPatternExamples`: Maximum dated examples required
- `isPersonalContent`: Whether entry is personal reflection vs. project/work
- `useStructuredFormat`: Whether to use 5-section structured format
- `entryClassification`: Entry type (reflective, analytical, factual, etc.)
- `conversationMode`: Optional conversation mode (ideas, think, perspective, etc.)
- `regenerate`: Whether this is a regeneration request
- `toneMode`: Optional tone mode override
- `preferQuestionExpansion`: Whether to expand with questions
- `userIntent`: User intent from conversation mode

### Prompt Structure

```
═══════════════════════════════════════════════════════════
CURRENT ENTRY TO RESPOND TO
═══════════════════════════════════════════════════════════

[Entry Text]

═══════════════════════════════════════════════════════════
RESPONSE REQUIREMENTS (from control state)
═══════════════════════════════════════════════════════════

WORD LIMIT: [maxWords] words MAXIMUM
- Count as you write
- STOP at [maxWords] words
- This is NOT negotiable

PATTERN EXAMPLES: [min]-[max] dated examples required
- Include specific dates or timeframes
- Examples:
  * "When you got stuck on Firebase in August..."
  * "Your Learning Space insight from September 15..."
  * "Like when you hit this threshold on October 3..."

CONTENT TYPE: PERSONAL REFLECTION / PROJECT/WORK CONTENT
[Content-specific instructions]

PERSONA: [persona]
[Persona-specific instructions]

[MODE-SPECIFIC INSTRUCTION: if applicable]

═══════════════════════════════════════════════════════════

Respond now following ALL constraints above.
```

## Persona-Specific Instructions

### Companion Mode

```
COMPANION MODE:
✓ Warm, conversational, supportive tone
✓ Start with ✨ Reflection header
✓ 2-4 dated pattern examples
✓ Focus on the person, not their strategic vision

✗ FORBIDDEN PHRASES (never use):
  - "beautifully encapsulates"
  - "profound strength"
  - "evolving identity"
  - "embodying the principles"
  - "on the precipice of"
  - "journey of bringing"
  - "shaping the contours of your identity"
  - "significant moment in your journey"

✗ DO NOT provide action items unless explicitly requested
```

### Strategist Mode

**Structured Format (metaAnalysis only):**
```
STRATEGIST MODE (Structured Format):
✓ Analytical, decisive tone
✓ Start with ✨ Analysis header
✓ Use 5-section structured format:
  1. Signal Separation
  2. Phase Determination
  3. Interpretation
  4. Phase-Appropriate Actions
  5. Reflective Links
✓ Include 3-8 dated examples
✓ Provide 2-4 concrete action items
```

**Conversational Format (reflective entries):**
```
STRATEGIST MODE (Conversational):
✓ Analytical, decisive tone
✓ Start with ✨ Analysis header
✓ Include 3-8 dated examples
✓ Provide 2-4 concrete action items
```

### Therapist Mode

```
THERAPIST MODE:
✓ Gentle, grounding, containing tone
✓ Start with ✨ Reflection header
✓ Use ECHO framework (Empathize, Clarify, Hold space, Offer)
✓ Reference past struggles with dates for continuity
✓ Maximum [maxWords] words
```

### Challenger Mode

```
CHALLENGER MODE:
✓ Direct, challenging, growth-oriented tone
✓ No header needed
✓ Use 1-2 sharp dated examples
✓ Ask hard questions
✓ Maximum [maxWords] words
```

## Critical Constraints

### Word Limit Enforcement

**MUST:**
- State exact word limit: "WORD LIMIT: 250 words MAXIMUM"
- Instruct to count: "Count as you write"
- Emphasize strictness: "STOP at 250 words - This is NOT negotiable"

**MUST NOT:**
- Say "no limit on response length"
- Say "be thorough and detailed" without word limit
- Contradict master prompt constraints

### Pattern Examples Requirement

**MUST:**
- Require specific number: "2-4 dated examples required"
- Provide examples: "When you got stuck on Firebase in August..."
- Emphasize dates: "Include specific dates or timeframes"

**MUST NOT:**
- Say "ACTIVELY reference past journal entries" without date requirement
- Use vague language like "show patterns" without specificity
- Allow project name-dropping without dates

### Action Items

**MUST:**
- Only provide action items when `userIntent == suggestSteps` or `userIntent == thinkThrough`
- For Companion mode: "DO NOT provide action items unless explicitly requested"

**MUST NOT:**
- Say "You are encouraged to offer gentle guidance"
- Say "feel free to offer suggestions" for personal reflections
- Provide unrequested action items

### Banned Phrases

**MUST:**
- List all banned phrases in Companion mode instructions
- Reference the master prompt's banned phrases list
- Emphasize these are forbidden

**MUST NOT:**
- Use any banned phrases in examples
- Allow melodramatic language

## Mode-Specific Instructions

### Conversation Modes

**Ideas Mode:**
```
Expand with 2-3 practical suggestions drawn from past successful patterns.
```

**Think Mode:**
```
Generate logical scaffolding (What → Why → What now).
```

**Perspective Mode:**
```
Reframe using contrastive reasoning ("Another way to see this...").
```

**Next Steps Mode:**
```
Provide small, phase-appropriate actions.
```

**Reflect Deeply Mode:**
```
Deep introspection with expanded Clarify and Highlight sections.
```

**Continue Thought Mode:**
```
Extend previous reflection with additional insights, building naturally.
```

### Regenerate Mode

```
Rebuild reflection with different rhetorical focus.
```

### Soft Tone Mode

```
Use gentler, slower rhythm. Add permission language.
```

### Question Expansion Mode

```
Expand Clarify and Highlight for richer introspection.
```

## Integration with Control State

The user prompt builder reads from the control state JSON:

```dart
final controlState = jsonDecode(controlStateJson) as Map<String, dynamic>;
final responseModeState = controlState['responseMode'] as Map<String, dynamic>? ?? {};
final personaState = controlState['persona'] as Map<String, dynamic>? ?? {};

final effectivePersona = personaState['effective'] as String? ?? 'companion';
final maxWords = responseModeState['maxWords'] as int? ?? 250;
final minPatternExamples = responseModeState['minPatternExamples'] as int? ?? 2;
final maxPatternExamples = responseModeState['maxPatternExamples'] as int? ?? 4;
final isPersonalContent = responseModeState['isPersonalContent'] as bool? ?? true;
final useStructuredFormat = responseModeState['useStructuredFormat'] as bool? ?? false;
```

## Common Mistakes to Avoid

### ❌ Overriding Constraints

**Wrong:**
```dart
"Be thorough and detailed - there is no limit on response length"
```

**Right:**
```dart
"WORD LIMIT: 250 words MAXIMUM - STOP at 250 words"
```

### ❌ Vague Pattern Instructions

**Wrong:**
```dart
"ACTIVELY reference past journal entries to show patterns"
```

**Right:**
```dart
"2-4 dated examples required - Include specific dates or timeframes"
```

### ❌ Unrequested Action Items

**Wrong:**
```dart
"You are encouraged to offer gentle guidance"
```

**Right:**
```dart
"DO NOT provide action items unless explicitly requested"
```

## Testing

### Test Case: Personal Reflection

**Entry:**
```
I think if I had to describe my superpower it's never giving up.
I'm not as fast as other people. Nor am I knowledgeable in Breath of Depth.
What I can offer though is flexibility, the ability to learn quickly, and the
ability to iterate and break things down quickly.

Maybe I'm just being too lazy or stubborn but it's such a pain in the butt
trying to get Stripe integrated with the app right now.

I did make progress however on trying to integrate Wispr Flow into my app.
A requirement of Wispr Flow in order to use their API is that you need to
request permission. Apparently however I got the permission, I was never told
about it. Because once I looked at my professional account for Wispr Flow, I
saw that I've been given approval to create API keys.
```

**Expected Response:**
- ✅ 200-250 words
- ✅ 2-4 dated examples (e.g., "Firebase in August", "phase detection in October")
- ✅ No banned phrases
- ✅ No unrequested action items
- ✅ Warm, conversational Companion tone
- ✅ Focus on personal persistence pattern, not strategic vision

## Related Documentation

- [LUMARA Master Prompt System](prompts/README_MASTER_PROMPT.md)
- [LUMARA v3.0 Implementation Summary](../../LUMARA_V3_IMPLEMENTATION_SUMMARY.md)
- [Bug Tracker: User Prompt Override](../bugtracker/records/lumara-user-prompt-override.md)

---

**Status**: ✅ Active  
**Last Updated**: January 2026  
**Version**: 3.0

