# LUMARA Master Unified Prompt System

**Status:** ✅ **ACTIVE**  
**Version:** 2.0  
**Date:** January 2025

## Overview

The LUMARA Master Unified Prompt System replaces all previous prompt systems with a single, authoritative prompt that governs all LUMARA behavior through a unified control state JSON.

## Architecture

### Master Prompt (`lumara_master_prompt.dart`)

The master prompt is the single source of truth for LUMARA's personality and behavior. It receives a unified control state JSON that combines signals from:

- **ATLAS**: Readiness + Safety Sentinel (phase, readinessScore, sentinelAlert)
- **VEIL**: Tone Regulator + Rhythm Intelligence (sophisticationLevel, timeOfDay, usagePattern, health)
- **FAVORITES**: Top 40 Reinforced Signature (favoritesProfile)
- **PRISM**: Multimodal Cognitive Context (prism_activity)
- **THERAPY MODE**: ECHO + SAGE (therapyMode)
- **ENGAGEMENT DISCIPLINE**: Response Boundaries (mode, synthesis_allowed, response_length, etc.)
- **RESPONSE LENGTH CONTROLS**: Manual sentence and paragraph limits (auto, max_sentences, sentences_per_paragraph)
- **MEMORY RETRIEVAL PARAMETERS**: Context access controls (similarityThreshold, lookbackYears, maxMatches, etc.)

### Control State Builder (`lumara_control_state_builder.dart`)

The `LumaraControlStateBuilder` service collects data from all sources and builds the unified control state JSON:

```dart
final controlStateJson = await LumaraControlStateBuilder.buildControlState(
  userId: userId,
  prismActivity: prismActivity,
  chronoContext: chronoContext,
);

final masterPrompt = LumaraMasterPrompt.getMasterPrompt(controlStateJson);
```

## Control State Structure

The control state JSON contains:

```json
{
  "atlas": {
    "phase": "Discovery",
    "readinessScore": 65,
    "sentinelAlert": false
  },
  "veil": {
    "sophisticationLevel": "moderate",
    "recentActivity": "moderate",
    "timeOfDay": "afternoon",
    "usagePattern": "sporadic",
    "health": {
      "sleepQuality": 0.7,
      "energyLevel": 0.7,
      "medicationStatus": null
    }
  },
  "favorites": {
    "favoritesProfile": {
      "directness": 0.5,
      "warmth": 0.6,
      "rigor": 0.5,
      "stepwise": 0.4,
      "systemsThinking": 0.5
    },
    "count": 5
  },
  "prism": {
    "prism_activity": {
      "journal_entries": [],
      "drafts": [],
      "chats": [],
      "media": [],
      "patterns": [],
      "emotional_tone": "neutral",
      "cognitive_load": "moderate"
    }
  },
  "therapy": {
    "therapyMode": "supportive"
  },
  "behavior": {
    "toneMode": "balanced",
    "warmth": 0.6,
    "rigor": 0.5,
    "abstraction": 0.5,
    "verbosity": 0.6,
    "challengeLevel": 0.5
  },
  "engagement": {
    "mode": "reflect",
    "response_length": "moderate",
    "synthesis_allowed": {...},
    "max_temporal_connections": 2,
    "max_explorative_questions": 1
  },
  "responseLength": {
    "auto": true,
    "max_sentences": -1,
    "sentences_per_paragraph": 4
  },
  "memory": {
    "similarityThreshold": 0.55,
    "lookbackYears": 5,
    "maxMatches": 5,
    "crossModalEnabled": true,
    "therapeuticDepth": 2
  }
}
```

## Integration Points

### Chat (`lumara_assistant_cubit.dart`)

The chat system uses the master prompt in `_buildSystemPrompt()`:

```dart
final controlStateJson = await LumaraControlStateBuilder.buildControlState(
  userId: _userId,
  prismActivity: prismActivity,
  chronoContext: chronoContext,
);

final masterPrompt = LumaraMasterPrompt.getMasterPrompt(controlStateJson);
```

### Journal Reflections (`enhanced_lumara_api.dart`)

The journal reflection system uses the master prompt with a user prompt that reinforces constraints:

```dart
// Build control state
final controlStateJson = await LumaraControlStateBuilder.buildControlState(
  userId: userId,
  prismActivity: prismActivity,
  chronoContext: chronoContext,
  userMessage: request.userText,
  maxWords: responseMode.maxWords,
  userIntent: detectedUserIntent,
);

// Get master prompt (system prompt)
final systemPrompt = LumaraMasterPrompt.getMasterPrompt(controlStateJson);

// Build user prompt that REINFORCES constraints (not overrides)
final userPrompt = _buildUserPrompt(
  baseContext: baseContext,
  entryText: request.userText,
  effectivePersona: effectivePersona,
  maxWords: maxWords,
  minPatternExamples: minPatternExamples,
  maxPatternExamples: maxPatternExamples,
  isPersonalContent: isPersonalContent,
  useStructuredFormat: useStructuredFormat,
  entryClassification: entryClassification,
  // ... other parameters
);
```

**Critical:** The user prompt must **reinforce** the master prompt constraints, not override them. See [User Prompt System](../../../../docs/USERPROMPT.md) for details.

## Behavior Rules

The master prompt enforces these integration rules:

1. **Begin with phase + readinessScore** - Sets readiness and safety constraints
2. **Apply VEIL sophistication + timeOfDay + usagePattern** - Determines rhythm and capacity
3. **Apply VEIL health signals** - Adjusts warmth, rigor, challenge, abstraction
4. **Apply FAVORITES** - Stylistic reinforcement
5. **Apply PRISM** - Emotional + narrative context
6. **Apply THERAPY MODE** - Relational stance + pacing
7. **Apply ENGAGEMENT DISCIPLINE** - Response boundaries and synthesis permissions
8. **Check RESPONSE LENGTH CONTROLS** - Determine sentence and paragraph limits (if manual mode is active)
9. **Check MEMORY RETRIEVAL PARAMETERS** - Understand what context is available
10. **If sentinelAlert = true** - Override everything with maximum safety
11. **Natural Openings** - Avoid formulaic restatements; start with insight, not paraphrasing
12. **Natural Endings** - Avoid generic ending questions; let responses end naturally when complete

## Archived Prompt Systems

The following prompt systems have been archived:

- `lumara_therapeutic_presence_data.dart` - Replaced by control state therapy mode
- `lumara_unified_prompts.dart` - Replaced by master prompt
- `lumara_prompts.dart` - Replaced by master prompt
- `lumara_system_prompt.dart` - Replaced by master prompt (on-device still uses for compatibility)

See `docs/archive/prompts_legacy/` for archived prompt files.

## Migration Notes

- All therapeutic presence settings are now integrated into the control state
- Health tracking factors are part of PRISM pull
- Chronotype and time-of-day are part of VEIL
- Favorites are automatically included in control state
- Phase and readiness are from ATLAS

## Response Guidelines

### Natural Openings

LUMARA avoids formulaic restatements of the user's question. Instead:
- Start with insight, observation, or direct answer
- Jump into the substance rather than paraphrasing
- Use acknowledgment phrases only when they add context or show deeper understanding

**Prohibited patterns:**
- "It sounds like you're actively seeking my perspective on..."
- "You're asking about how recognizing these dynamics will help you..."
- Restating the question in slightly different words

### Natural Endings

LUMARA avoids generic, formulaic ending questions. Responses should:
- End naturally when the thought is complete
- Use ending questions only when they genuinely deepen reflection
- Allow silence as a valid and often preferred ending

**Prohibited ending questions:**
- "Does this resonate with you?"
- "Does this resonate?"
- "What would be helpful to focus on next?" (when used as default closing)
- "Is there anything else you want to explore here?"
- "How does this sit with you?" (when used formulaically)

**When ending questions are appropriate:**
- They connect directly to a specific insight or pattern identified
- They genuinely invite deeper reflection on a particular aspect
- They feel like a natural extension of the conversation, not a default mechanism
- They are specific and contextual, not generic or formulaic

## Related Documentation

- [User Prompt System](../../../../docs/USERPROMPT.md) - How user prompts reinforce master prompt constraints
- [LUMARA v3.0 Implementation Summary](../../../../LUMARA_V3_IMPLEMENTATION_SUMMARY.md) - Complete v3.0 changes

## Future Enhancements

- Enhanced PRISM activity analysis (sentiment, cognitive load detection)
- Health tracking integration (sleep, energy, medication)
- Chronotype detection and usage pattern learning
- Favorites profile analysis (extract actual style patterns from favorites)

---

**Status**: ✅ Active  
**Last Updated**: January 2026  
**Version**: 3.0

