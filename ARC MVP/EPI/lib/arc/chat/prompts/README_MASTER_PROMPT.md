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
- **FAVORITES**: Top 25 Reinforced Signature (favoritesProfile)
- **PRISM**: Multimodal Cognitive Context (prism_activity)
- **THERAPY MODE**: ECHO + SAGE (therapyMode)

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

The journal reflection system uses the master prompt:

```dart
final controlStateJson = await LumaraControlStateBuilder.buildControlState(
  userId: userId,
  prismActivity: prismActivity,
  chronoContext: chronoContext,
);

final systemPrompt = LumaraMasterPrompt.getMasterPrompt(controlStateJson);
```

## Behavior Rules

The master prompt enforces these integration rules:

1. **Begin with phase + readinessScore** - Sets readiness and safety constraints
2. **Apply VEIL sophistication + timeOfDay + usagePattern** - Determines rhythm and capacity
3. **Apply VEIL health signals** - Adjusts warmth, rigor, challenge, abstraction
4. **Apply FAVORITES** - Stylistic reinforcement
5. **Apply PRISM** - Emotional + narrative context
6. **Apply THERAPY MODE** - Relational stance + pacing
7. **If sentinelAlert = true** - Override everything with maximum safety

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

## Future Enhancements

- Enhanced PRISM activity analysis (sentiment, cognitive load detection)
- Health tracking integration (sleep, energy, medication)
- Chronotype detection and usage pattern learning
- Favorites profile analysis (extract actual style patterns from favorites)

---

**Status**: ✅ Active  
**Last Updated**: January 2025  
**Version**: 2.0

