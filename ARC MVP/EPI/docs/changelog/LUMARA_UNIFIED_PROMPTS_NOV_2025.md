# LUMARA Unified Prompt System Update - November 2025

**Version:** 2.1  
**Date:** November 2025  
**Status:** Complete with Expert Mentor Mode and Decision Clarity Mode

## Overview

Unified all LUMARA assistant prompts under a single, architecture-aligned system (EPI v2.1) with context-aware behavior for ARC Chat, ARC In-Journal, and VEIL/Recovery modes. Added Expert Mentor Mode for on-demand domain expertise and Decision Clarity Mode for structured decision-making.

## Changes

### New Unified Prompt System

1. **Created Unified Prompt Infrastructure**
   - `lib/arc/chat/prompts/lumara_profile.json` - Full JSON configuration for development/auditing
   - `lib/arc/chat/prompts/lumara_system_compact.txt` - Condensed runtime prompt (< 1000 tokens)
   - `lib/arc/chat/prompts/lumara_system_micro.txt` - Micro prompt for emergency/fallback (< 300 tokens)
   - `lib/arc/chat/prompts/lumara_unified_prompts.dart` - Unified prompt manager class
   - `lib/arc/chat/prompts/decision_brief_template.md` - Decision Brief template with scoring framework

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

6. **Expert Mentor Mode** (Added November 2025)
   - On-demand domain expertise activation
   - Personas: Faith/Biblical Scholar, Systems Engineer, Marketing Lead, Generic Expert
   - Protocol: Scope → Explain → Do Work → Coach Forward
   - Quality standards: accuracy, clarity, adaptivity
   - Maintains interpretive-diagnostic core while adding expert-grade guidance

7. **Decision Clarity Mode** (Added November 2025)
   - Structured decision-making framework
   - Narrative Preamble: conversational transition to structured analysis
   - Scoring Framework: Becoming Alignment vs Practical Viability (1-10 per dimension)
   - Decision Brief output: context, options, criteria, scorecard, synthesis, next steps
   - Mini template for quick mobile decisions

## Architecture Alignment

Aligned with EPI v2.1 Consolidated Architecture:
- **ARC** - Journaling, Chat UI, Arcform
- **PRISM.ATLAS** - Phase/Readiness, RIVET, SENTINEL, multimodal analysis
- **MIRA** - Memory graph + MCP/ARCX secure store
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
- `MIRA.query` - Retrieve relevant memories
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
- `lib/arc/chat/prompts/lumara_profile.json` - Full system configuration with Expert Mentor and Decision Clarity modes
- `lib/arc/chat/prompts/lumara_system_compact.txt` - Condensed runtime prompt (< 1000 tokens)
- `lib/arc/chat/prompts/lumara_system_micro.txt` - Micro prompt for emergency/fallback (< 300 tokens)
- `lib/arc/chat/prompts/lumara_unified_prompts.dart` - Unified prompt manager class
- `lib/arc/chat/prompts/decision_brief_template.md` - Decision Brief template with scoring framework
- `lib/arc/chat/prompts/README_UNIFIED_PROMPTS.md` - Usage documentation
- `docs/changelog/LUMARA_UNIFIED_PROMPTS_NOV_2025.md` - This document

### Modified Files
- `lib/arc/chat/prompts/lumara_prompts.dart` - Updated to use unified system (backward compatible)
- `lib/arc/chat/prompts/lumara_system_prompt.dart` - Updated to use unified system (backward compatible)
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Uses unified prompts with context tags
- `lib/arc/chat/veil_edge/integration/lumara_veil_edge_integration.dart` - Integrated with unified prompts
- `pubspec.yaml` - Added `assets/prompts/` directory for prompt file loading

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

## Expert Mentor Mode

LUMARA can activate Expert Mentor Mode when users request domain expertise or task help. This mode adds expert-level guidance while maintaining LUMARA's core ethics and interpretive stance.

### Activation Cues
- Explicit: "act as...", "teach me...", "help me do..."
- Implicit: Technical or craft questions requiring domain authority

### Available Personas
- **Faith / Biblical Scholar** - Christian theology, exegesis, spiritual practices
- **Systems Engineer** - Requirements, CONOPS, SysML/MBSE, verification/validation
- **Marketing Lead** - Positioning, ICPs, funnels, messaging, analytics
- **Generic Expert** - Any requested domain (with safety boundaries)

### Protocol
1. Scope/Criteria - Confirm what to deliver; note constraints
2. Explain & Decide - Present concise, accurate guidance with options
3. Do the Work - Provide usable artifacts (plans, templates, checklists, code)
4. Coach Forward - Suggest 1-3 next steps; invite calibration

## Decision Clarity Mode

LUMARA can activate Decision Clarity Mode when users need help choosing between options or making complex decisions. This mode uses a structured framework to surface values, score options, and recommend paths.

### Activation Cues
- Explicit: "help me decide", "should I", "choose between"
- Implicit: User describes options or trade-offs without clear decision criteria

### Protocol
1. Narrative Preamble - Conversational transition to structured analysis
2. Frame the Decision - Name what's at stake; identify core values in tension
3. List Options - Capture all viable paths (including status quo and hybrid options)
4. Define Criteria - Extract 3-5 decision factors from user's values and constraints
5. Score Options - Evaluate across Becoming Alignment vs Practical Viability (1-10 per dimension)
6. Synthesize - Highlight path that best honors Becoming; name trade-offs explicitly
7. Invite Calibration - Check alignment with user's intuition; adjust criteria if needed

### Scoring Framework
- **Becoming Alignment** (1-10): Values/long-term coherence/identity congruence
- **Practical Viability** (1-10): Utility/constraints/risk mitigation/short-term feasibility
- When dimensions diverge: Surface tension and help user choose which matters more

## Version

**EPI v2.1** - November 2025  
**Update Status:** Complete with Expert Mentor Mode and Decision Clarity Mode

