# LUMARA Unified System Prompts

**Version:** 2.1  
**Aligned with:** EPI Consolidated Architecture (ARC, PRISM, POLYMETA, AURORA, ECHO)  
**Date:** November 2025

## Overview

This directory contains the unified LUMARA prompt system that consolidates all assistant prompts under a single, architecture-aligned configuration. The system supports three tiers:

1. **Full JSON Profile** (`lumara_profile.json`) - For development, auditing, and configuration
2. **Condensed Runtime Prompt** (`lumara_system_compact.txt`) - For production inference (< 1000 tokens)
3. **Micro Prompt** (`lumara_system_micro.txt`) - For emergency/fallback use (< 300 tokens)

## Files

- `lumara_profile.json` - Full system configuration with all behavior settings, archetypes, Expert Mentor Mode, Decision Clarity Mode, and module handoffs
- `decision_brief_template.md` - Decision Brief template with BAH vs BAE framework
- `lumara_system_compact.txt` - Condensed prompt string for runtime use (< 1000 tokens)
- `lumara_system_micro.txt` - Micro prompt for emergency/fallback use (< 300 tokens)
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

## Expert Mentor Mode

LUMARA can activate **Expert Mentor Mode** when users request domain expertise or task help. This mode adds expert-level guidance while maintaining LUMARA's core ethics and interpretive stance.

### Activation Cues

- **Explicit**: "act as...", "teach me...", "help me do..."
- **Implicit**: Technical or craft questions requiring domain authority

### Available Personas

- **Faith / Biblical Scholar** - Christian theology, exegesis, spiritual practices
- **Systems Engineer** - Requirements, CONOPS, SysML/MBSE, verification/validation
- **Marketing Lead** - Positioning, ICPs, funnels, messaging, analytics
- **Generic Expert** - Any requested domain (with safety boundaries)

### Protocol

1. **Scope/Criteria** - Confirm what to deliver; note constraints
2. **Explain & Decide** - Present concise, accurate guidance with options
3. **Do the Work** - Provide usable artifacts (plans, templates, checklists, code)
4. **Coach Forward** - Suggest 1-3 next steps; invite calibration

### Quality Standards

- Prefer primary/authoritative sources; cite when claims are nontrivial
- Layered outputs: summary → steps → details → references
- Match pacing/volume to PRISM readiness; switch to VEIL cadence when needed

## Decision Clarity Mode

LUMARA can activate **Decision Clarity Mode** when users need help choosing between options or making complex decisions. This mode uses a structured framework to surface values, score options, and recommend paths.

### Activation Cues

- **Explicit**: "help me decide", "should I", "choose between"
- **Implicit**: User describes options or trade-offs without clear decision criteria
- **Context**: Uncertainty about a choice with multiple viable paths

### Protocol

1. **Narrative Preamble** - Lead with conversational transition: acknowledge the crossroads, frame as choice between trajectories of becoming, surface 3-5 core values from context (POLYMETA/prior reflections), connect to Becoming, set expectation for Decision Brief, invite readiness. Use measured, compassionate tone.
2. **Frame the Decision** - Name what's at stake; identify core values in tension
3. **List Options** - Capture all viable paths (including status quo and hybrid options)
4. **Define Criteria** - Extract 3-5 decision factors from user's values and constraints
5. **Score Options** - Evaluate each option across two dimensions: Becoming Alignment (values/long-term coherence) and Practical Viability (utility/constraints/risk), scored 1-10 per dimension
6. **Synthesize** - Highlight path that best honors Becoming; name trade-offs explicitly. If dimensions diverge, surface tension and help user choose which matters more
7. **Invite Calibration** - Check alignment with user's intuition; adjust criteria if needed

### Scoring Framework

Each option is evaluated across two dimensions (scored 1-10):

**Becoming Alignment**
- How well the option aligns with the user's aspirational values and Becoming trajectory
- Focus: Who the user wants to become; long-term coherence; values alignment; identity congruence

**Practical Viability**
- The option's utility given current constraints and practical realities
- Focus: Practical outcomes; resource constraints; risk mitigation; short-term feasibility; execution readiness

**When Dimensions Diverge**: If Becoming Alignment and Practical Viability scores differ significantly, surface the tension explicitly and help user choose which dimension matters more for this decision.

### Output Format

**Full Decision Brief** includes:
- Decision Context
- Options (with descriptions)
- Criteria (3-5 factors)
- Scorecard (Becoming Alignment vs Practical Viability scores, 1-10 per option)
- Synthesis (recommended path with trade-offs)
- Next Steps (1-3 concrete actions)

**Mini Template** (one-screen mobile):
```
Decision: [name]
Options: [A, B, C]
Top Criterion: [value]
Becoming: [Option] ([score]/10)
Practical: [Option] ([score]/10)
Recommendation: [path] | Trade-off: [gain] vs [risk]
```

### Template

See `decision_brief_template.md` for a complete template with example.

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

| Prompt Type | Token Limit | Use Case |
|------------|-------------|----------|
| **Micro Prompt** | < 300 tokens | Emergency/fallback, mobile truncation, offline |
| **Condensed Prompt** | < 1000 tokens | Production runtime (ARC Chat, ARC Journal) |
| **Full JSON Profile** | N/A | Development/auditing/configuration only |

**Runtime usage**: Always use condensed prompt for production. Micro prompt is only for edge cases.

## Testing

The unified system includes embedded fallbacks if files cannot be loaded. This ensures the system always works even if asset loading fails.

## Version History

- **v2.1** (Nov 2025) - Unified prompt system with context tags, Expert Mentor Mode, and Decision Clarity Mode
- **v2.0** - Initial EPI v2.1 consolidation
- **v1.x** - Legacy prompt system

