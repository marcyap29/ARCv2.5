# LUMARA Closing Statement Engine

## Overview

The Closing Statement Engine prevents LUMARA from using repetitive, predictable closing lines. It implements a rotation system with contextual logic that adapts to conversation context and user preferences.

## Problem Solved

**Before:** LUMARA was overusing a single exit pattern:
- "Would it help to name one small next step, or does pausing feel right?"

This created:
- Predictable, robotic responses
- Emotional flatness
- Habituation fatigue

**After:** Structured, phase-aware, tone-aware rotation with 75+ closing variations across 5 categories.

## Architecture

### Three-Layer System

#### Layer A: Context Category

Each response classifies the conversation into one of five buckets:

1. **Reflection / Emotion Processing** - Exploring feelings, processing emotions, internal states
2. **Planning / Execution** - Actions, next steps, practical decisions
3. **Identity / Phase Insight** - Self-concept, life phases, personal growth patterns
4. **Regulation / Overwhelm** - Signs of overwhelm, need for grounding, emotional regulation
5. **Neutral / Light Interaction** - Casual check-ins, light journaling, low-intensity exchanges

#### Layer B: Ending Style

Within each category, rotate among these styles:

- **Soft question** - Gentle inquiry that gives user choice
- **Reflective echo** - Mirroring back what was shared
- **Gentle prompt** - Light suggestion without pressure
- **Non-prompt closure** - Simple acknowledgment without asking for more
- **Pause-affirmation** - Validating the need to stop or rest
- **Next-step suggestion** - Offering concrete action (only when appropriate)
- **User-led turn** - Open-ended invitation for user to direct

#### Layer C: Variation Pool

75 closing lines organized by category (15 per category), each with:
- Unique ID
- Category classification
- Style classification
- ATLAS phase bias (which phases it fits best)
- Energy level (low/medium/high)
- Optional tags

## ATLAS Phase Integration

Closing statements adjust based on current ATLAS phase:

- **Recovery** → Softer, containment-oriented endings (pause-affirmations, gentle questions)
- **Expansion** → Slightly more forward momentum (next-step suggestions, gentle prompts)
- **Consolidation** → Reflective, integrative closures (reflective echoes, soft questions)
- **Discovery** → Curiosity-driven options (gentle prompts, soft questions)
- **Transition** → Choice-oriented framing (user-led turns, soft questions)
- **Breakthrough** → Grounding before action (pause-affirmations, gentle prompts)

## Behavioral Rules

1. **Never repeat the same closing line within the last 15 messages** unless the user explicitly requests similar guidance
2. **Avoid patterned predictability** - Rotate styles, categories, and phrasings
3. **Match energy level** - Use low-energy closings for regulation/overwhelm, medium for most interactions, high only for breakthrough moments
4. **Contextual appropriateness** - The closing should feel natural given the conversation content

## Implementation

### System Prompt Integration

The closing statement engine is integrated into the LUMARA Master prompt in `sendChatMessage.ts`. The prompt includes:

1. Context category identification rules
2. Ending style rotation guidelines
3. ATLAS phase adjustment instructions
4. Variation rules and examples
5. Anti-repetition enforcement

### Code Structure

- **`closingPatterns.ts`** - Contains the 75 closing patterns with metadata
- **System prompt** - Contains the engine rules and instructions for the LLM
- **Future: Preference learning** - MIRA variant for learning user preferences over time (planned)

## Example Closings by Category

### Reflection / Emotion Processing
- "Do you want to stay with this feeling a bit longer or let it rest here for now?"
- "Is this something you want to unpack more, or is naming it enough for today?"
- "Would it help to follow this thread a little further, or pause and come back later?"

### Planning / Action
- "Do you want to identify one concrete next step, or is reflection enough for now?"
- "Should we distill this into a single action, or keep it as a note to yourself?"
- "Would a tiny next move help you feel less stuck, or does holding the insight feel better?"

### Identity / Phase Insight
- "Do you want to connect this to how you see yourself changing, or leave it as a snapshot?"
- "Should we link this to your current phase, or simply let it stand as a moment in time?"
- "Would it help to name what this says about who you are becoming, or is that too heavy right now?"

### Regulation / Overwhelm
- "Do you need one small grounding step right now, or does simply naming this feel enough?"
- "Would it help to slow down with a brief pause, or keep moving while the energy is here?"
- "Do you want to write one stabilizing sentence to yourself, or close gently here?"

### Neutral / Light Interaction
- "Is there anything else tugging at your attention before we pause?"
- "Do you want to explore one more thread, or is this a good stopping point?"
- "Would it feel good to add one small detail, or are you satisfied with what you captured?"

## Future: Preference Learning (MIRA Variant)

Planned enhancement: A preference-learning system that adjusts closing lines over time based on user responses.

### Signals to Track
- `closing_id` - Which closing was used
- `timestamp` - When it was used
- `atlas_phase` - Phase at time of use
- `category` - Context category
- `style` - Ending style
- Outcome scores:
  - `continued` - User sent another message within X seconds/minutes
  - `accepted` - User explicitly agreed ("yes", "let's do that", etc.)
  - `rejected` - User pushed back ("stop asking that", "no", "this is annoying")
  - `silence` - No further message for a longer window
  - `sentiment` - Rough polarity (optional)

### Scoring Rule
```
score = 0.0 initially

on event:
  if accepted:      score += +2
  if continued:     score += +1
  if neutral:       score += +0
  if rejected:       score += -3
  if silence:       score += -1
  also apply small decay over time
```

### Selection Rule
1. Filter by category, not used in last N messages, not in muted list
2. Weight candidates with softmax over (base_weight + phase_weight + category_weight + individual_score)
3. Sample according to that distribution (not pure max) to keep exploration

## JSON Schema (Future Implementation)

See the original specification for:
- `ClosingPattern` schema
- `UserPreferenceProfile` schema

These will be implemented when preference learning is added.

## Benefits

1. **Variety** - 75+ closing variations prevent repetition
2. **Context-awareness** - Closings match conversation content
3. **Phase-awareness** - Closings adapt to ATLAS phase
4. **User agency** - Closings give users choice and control
5. **Perceived intelligence** - Varied, thoughtful closings feel more human
6. **Reduced fatigue** - No more robotic repetition

## Testing

To verify the closing statement engine is working:

1. Send multiple chat messages in a row
2. Check that closing statements vary
3. Verify no repetition within 15 messages
4. Confirm closings match conversation context
5. Test across different ATLAS phases (if available)

## Maintenance

- Add new closing patterns to `closingPatterns.ts`
- Update system prompt if rules change
- Monitor for patterns that users reject
- Adjust phase biases based on feedback
