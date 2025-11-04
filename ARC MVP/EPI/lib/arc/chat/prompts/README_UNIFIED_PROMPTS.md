# LUMARA Unified System Prompts

**Version:** 2.1  
**Aligned with:** EPI Consolidated Architecture (ARC, PRISM, POLYMETA, AURORA, ECHO)  
**Date:** November 2025

## Overview

This directory contains the unified LUMARA prompt system that consolidates all assistant prompts under a single, architecture-aligned configuration. The system supports both:

1. **Full JSON Profile** (`lumara_profile.json`) - For development, auditing, and configuration
2. **Condensed Runtime Prompt** (`lumara_system_compact.txt`) - For production inference (< 1000 tokens)

## Files

- `lumara_profile.json` - Full system configuration with all behavior settings, archetypes, and module handoffs
- `lumara_system_compact.txt` - Condensed prompt string for runtime use
- `lumara_unified_prompts.dart` - Dart class that loads and manages the unified prompts
- `lumara_prompts.dart` - Updated to use unified system (backward compatible)
- `lumara_system_prompt.dart` - Updated to use unified system (backward compatible)

## Usage

### Context Tags

The unified system supports three context modes:

- **`arc_chat`** - For ARC Chat UI (reflection + strategic guidance)
- **`arc_journal`** - For ARC In-Journal reflections (self-understanding + coherence)
- **`recovery`** - For recovery/VEIL mode (calm containment, slower pace)

### Basic Usage

```dart
import 'package:my_app/arc/chat/prompts/lumara_unified_prompts.dart';

// Get system prompt for ARC Chat
final prompt = await LumaraUnifiedPrompts.instance.getSystemPrompt(
  context: LumaraContext.arcChat,
  phaseData: {'phase': 'Expansion', 'readiness': 0.8},
  energyData: {'level': 'medium', 'timeOfDay': 'morning'},
);
```

### Using Legacy Classes (Backward Compatible)

```dart
import 'package:my_app/arc/chat/prompts/lumara_prompts.dart';

// Legacy static prompts still work
final legacyPrompt = LumaraPrompts.inJournalPrompt;

// But new context-aware method is preferred
final unifiedPrompt = await LumaraPrompts.getSystemPromptForContext(
  context: LumaraContext.arcJournal,
);
```

## Architecture Alignment

The prompts are aligned with EPI v2.1 modules:

- **ARC** - Journaling, Chat UI, Arcform
- **PRISM.ATLAS** - Phase/Readiness, RIVET, SENTINEL, multimodal analysis
- **POLYMETA** - Memory graph + MCP/ARCX secure store
- **AURORA.VEIL** - Circadian scheduling + restorative regimens
- **ECHO** - LLM interface, guardrails, privacy

## Guidance Mode

**Interpretive-Diagnostic** approach:
1. **Describe** - Lead with interpretation, not data requests
2. **Check** - Name values/tensions inferred from input + memory
3. **Deepen** - Invite confirmation, then explore what matters
4. **Integrate** - Offer synthesis or next right step

## Module Handoffs

The prompt system includes hooks for:

- `ECHO.guard` - Apply safety/privacy to inputs/outputs
- `POLYMETA.query` - Retrieve relevant memories
- `PRISM.atlas.phase/readiness` - Adjust pacing and firmness
- `RIVET` - Detect interest/value shifts
- `AURORA.veil` - Switch to recovery cadence on overload

## Best Practices

1. **Always specify context tag** - Use `arc_chat`, `arc_journal`, or `recovery`
2. **Pass phase/energy data when available** - Improves response quality
3. **Use condensed prompt for runtime** - Full JSON is for development only
4. **Maintain backward compatibility** - Legacy prompts still work

## Migration Guide

To migrate existing code:

1. Replace `LumaraPrompts.inJournalPrompt` with:
   ```dart
   await LumaraPrompts.getSystemPromptForContext(
     context: LumaraContext.arcJournal,
   )
   ```

2. Replace `LumaraPrompts.chatPrompt` with:
   ```dart
   await LumaraPrompts.getSystemPromptForContext(
     context: LumaraContext.arcChat,
   )
   ```

3. For recovery mode:
   ```dart
   await LumaraPrompts.getSystemPromptForContext(
     context: LumaraContext.recovery,
   )
   ```

## Token Limits

- **Condensed prompt**: < 1000 tokens (optimized for production)
- **Full JSON profile**: For development/auditing only
- **Runtime usage**: Always use condensed prompt

## Testing

The unified system includes embedded fallbacks if files cannot be loaded. This ensures the system always works even if asset loading fails.

## Version History

- **v2.1** (Nov 2025) - Unified prompt system with context tags
- **v2.0** - Initial EPI v2.1 consolidation
- **v1.x** - Legacy prompt system

