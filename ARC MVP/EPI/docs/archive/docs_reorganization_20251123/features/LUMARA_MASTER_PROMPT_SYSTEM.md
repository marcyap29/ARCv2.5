# LUMARA Master Unified Prompt System

**Status:** ✅ **ACTIVE**  
**Version:** 2.0  
**Date:** January 2025

## Overview

The LUMARA Master Unified Prompt System consolidates all previous prompt systems into a single, authoritative prompt that governs all LUMARA behavior through a unified control state JSON.

## Key Features

- **Single Source of Truth**: One master prompt replaces all previous prompt systems
- **Unified Control State**: All behavioral signals combined into a single JSON structure
- **Backend-Side Computation**: Control state is computed backend-side, LUMARA only follows it
- **Complete Integration**: ATLAS, VEIL, FAVORITES, PRISM, and THERAPY MODE all integrated

## Architecture

### Master Prompt (`lumara_master_prompt.dart`)

The master prompt receives a unified control state JSON that combines signals from:

- **ATLAS**: Readiness + Safety Sentinel (phase, readinessScore, sentinelAlert)
- **VEIL**: Tone Regulator + Rhythm Intelligence (sophisticationLevel, timeOfDay, usagePattern, health)
- **FAVORITES**: Top 25 Reinforced Signature (favoritesProfile)
- **PRISM**: Multimodal Cognitive Context (prism_activity)
- **THERAPY MODE**: ECHO + SAGE (therapyMode)

### Control State Builder (`lumara_control_state_builder.dart`)

The `LumaraControlStateBuilder` service collects data from all sources and builds the unified control state JSON.

## Integration Points

### Chat System (`lumara_assistant_cubit.dart`)

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

### VEIL-EDGE Integration (`lumara_veil_edge_integration.dart`)

VEIL-EDGE routing also uses the master prompt system.

## Behavior Rules

The master prompt enforces these integration rules:

1. **Begin with phase + readinessScore** - Sets readiness and safety constraints
2. **Apply VEIL sophistication + timeOfDay + usagePattern** - Determines rhythm and capacity
3. **Apply VEIL health signals** - Adjusts warmth, rigor, challenge, abstraction
4. **Apply FAVORITES** - Stylistic reinforcement
5. **Apply PRISM** - Emotional + narrative context
6. **Apply THERAPY MODE** - Relational stance + pacing
7. **If sentinelAlert = true** - Override everything with maximum safety
8. **Knowledge Attribution** - Strictly distinguish between EPI Knowledge (user context) and General Knowledge (world facts). NEVER use "General EPI Knowledge".
9. **Response Variety** - Avoid repetitive stock phrases (e.g., "Would it help to name one small step..."). Vary closing questions.

## Migration from Previous Systems

### Replaced Systems

- `lumara_therapeutic_presence_data.dart` → Control state therapy mode
- `lumara_unified_prompts.dart` → Master prompt
- `lumara_prompts.dart` → Master prompt
- `lumara_system_prompt.dart` → Master prompt (on-device still uses for compatibility)

### Archived Files

Old prompt files have been moved to `lib/arc/chat/prompts/archive/`:
- `lumara_therapeutic_presence_data.dart`
- `lumara_unified_prompts.dart`
- `lumara_prompts.dart`

### Deprecated Files

- `lumara_system_prompt.dart` - Kept for on-device LLM compatibility only

## Control State Structure

See `lib/arc/chat/prompts/README_MASTER_PROMPT.md` for detailed control state structure.

## Future Enhancements

- Enhanced PRISM activity analysis (sentiment, cognitive load detection)
- Health tracking integration (sleep, energy, medication)
- Chronotype detection and usage pattern learning
- Favorites profile analysis (extract actual style patterns from favorites)

## Related Documentation

- [Master Prompt README](../lib/arc/chat/prompts/README_MASTER_PROMPT.md)
- [LUMARA Favorites System](./LUMARA_FAVORITES_SYSTEM.md)
- [Therapeutic Presence Mode](./THERAPEUTIC_PRESENCE_MODE_FEB_2025.md)

---

**Status**: ✅ Active  
**Last Updated**: November 2025  
**Version**: 2.0

