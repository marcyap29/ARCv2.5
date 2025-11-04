# LUMARA Unified Prompt System Update - November 2025

## Overview

Unified all LUMARA assistant prompts under a single, architecture-aligned system (EPI v2.1) with context-aware behavior for ARC Chat, ARC In-Journal, and VEIL/Recovery modes.

## Changes

### New Unified Prompt System

1. **Created Unified Prompt Infrastructure**
   - `lib/arc/chat/prompts/lumara_profile.json` - Full JSON configuration for development/auditing
   - `lib/arc/chat/prompts/lumara_system_compact.txt` - Condensed runtime prompt (< 1000 tokens)
   - `lib/arc/chat/prompts/lumara_unified_prompts.dart` - Unified prompt manager class

2. **Context-Aware Prompts**
   - `arc_chat` - Reflection + strategic guidance (Observation → Framing → Confirmation → Strategy)
   - `arc_journal` - Self-understanding + coherence (Observation → Framing → Confirmation → Deepening)
   - `recovery` - VEIL mode (calm containment, slower pace, gentle invitations)

3. **Updated Existing Classes**
   - `lumara_prompts.dart` - Now uses unified system with backward compatibility
   - `lumara_system_prompt.dart` - Now uses unified system with backward compatibility
   - Both classes include new `getSystemPromptForContext()` methods

4. **VEIL-EDGE Integration**
   - Updated `lumara_veil_edge_integration.dart` to use unified prompts
   - Extracts phase data from ATLAS routing
   - Extracts energy data from AURORA circadian context
   - Uses `LumaraContext.recovery` for VEIL cadence

5. **Enhanced LUMARA API**
   - Updated `enhanced_lumara_api.dart` to use unified prompts with context tags
   - Passes phase and energy data to unified system

## Architecture Alignment

Aligned with EPI v2.1 Consolidated Architecture:
- **ARC** - Journaling, Chat UI, Arcform
- **PRISM.ATLAS** - Phase/Readiness, RIVET, SENTINEL, multimodal analysis
- **POLYMETA** - Memory graph + MCP/ARCX secure store
- **AURORA.VEIL** - Circadian scheduling + restorative regimens
- **ECHO** - LLM interface, guardrails, privacy

## Guidance Mode

**Interpretive-Diagnostic** approach:
- Describe → Check → Deepen → Integrate
- Lead with interpretation, not data requests
- Name values/tensions inferred from input + memory
- Offer synthesis or next right step

## Module Handoffs

- `ECHO.guard` - Apply safety/privacy to inputs/outputs
- `POLYMETA.query` - Retrieve relevant memories
- `PRISM.atlas.phase/readiness` - Adjust pacing and firmness
- `RIVET` - Detect interest/value shifts
- `AURORA.veil` - Switch to recovery cadence on overload

## Migration Guide

### For Developers

**Old:**
```dart
final prompt = LumaraPrompts.inJournalPrompt;
```

**New:**
```dart
final prompt = await LumaraPrompts.getSystemPromptForContext(
  context: LumaraContext.arcJournal,
  phaseData: {'phase': 'Transition', 'readiness': 0.7},
  energyData: {'level': 'medium', 'timeOfDay': 'afternoon'},
);
```

### Backward Compatibility

All legacy prompts remain available but are marked `@deprecated`. The system will continue to work with existing code while encouraging migration to the unified system.

## Files Modified

### New Files
- `lib/arc/chat/prompts/lumara_profile.json`
- `lib/arc/chat/prompts/lumara_system_compact.txt`
- `lib/arc/chat/prompts/lumara_unified_prompts.dart`
- `lib/arc/chat/prompts/README_UNIFIED_PROMPTS.md`
- `docs/changelog/LUMARA_UNIFIED_PROMPTS_NOV_2025.md`

### Modified Files
- `lib/arc/chat/prompts/lumara_prompts.dart`
- `lib/arc/chat/prompts/lumara_system_prompt.dart`
- `lib/arc/chat/services/enhanced_lumara_api.dart`
- `lib/arc/chat/veil_edge/integration/lumara_veil_edge_integration.dart`

## Testing

- ✅ Unified prompts load correctly from assets
- ✅ Context tags work for all three modes (arc_chat, arc_journal, recovery)
- ✅ Phase and energy data properly integrated
- ✅ VEIL-EDGE integration uses unified prompts
- ✅ Backward compatibility maintained
- ✅ Build succeeds with no errors

## Benefits

1. **Single Source of Truth** - All prompts unified under one system
2. **Context Awareness** - Different behavior for different contexts
3. **Phase Sensitivity** - Prompts adapt to user's current life phase
4. **Energy Awareness** - Prompts adjust based on circadian rhythm
5. **Maintainability** - Easy to update prompts in one place
6. **Consistency** - Same behavior across all LUMARA integrations

## Version

**EPI v2.1** - November 2025

