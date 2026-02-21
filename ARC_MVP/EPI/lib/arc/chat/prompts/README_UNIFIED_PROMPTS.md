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

LUMARA can activate **Decision Clarity Mode** when users need help choosing between options or making complex decisions. This mode uses an intelligent selector to route between analytical, attuned, or blended approaches, applying a shared Viability–Meaning–Trajectory framework.

### Activation Cues

- **Explicit**: "help me decide", "should I", "choose between"
- **Implicit**: User describes options or trade-offs without clear decision criteria
- **Context**: Uncertainty about a choice with multiple viable paths
- **Signals**: Ambivalence, conflicting values, major life transition context

### Intelligent Mode Selector

The Decision Mode Selector automatically routes to the optimal mode based on context analysis:

**Input Signals:**
- Phase (ATLAS phase: Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough)
- Emotion intensity (0.0-1.0, aggregated from entries/drafts/chats/voice, POLYMETA emotional valence)
- Stakes score (0.0-1.0, impact on identity/career/relationships)
- Ambiguity score (0.0-1.0, uncertainty/option spread)
- Time pressure (0.0-1.0, deadline proximity)
- Memory relevance (0.0-1.0, POLYMETA similarity to past decisions)
- Therapeutic depth (1-3, from Therapeutic Presence depth slider if active)
- Keywords (salient tokens from recent context, POLYMETA memory nodes)
- POLYMETA context (similar decisions, value evolution, phase history)

**Routing Logic:**
1. Calculate base context score using phase weights, keyword boosts, memory relevance
2. Apply modifiers (time pressure, therapeutic depth, similar decision patterns)
3. Calculate confidence and attuned_ratio (0.0-1.0)
4. Select mode:
   - **Attuned Mode** (attuned_ratio ≥ 0.65): High emotional weight, Transition/Recovery phases
   - **Blended Mode** (0.35 ≤ attuned_ratio < 0.65): Moderate emotional weight, balanced approach
   - **Base Mode** (attuned_ratio < 0.35): Low emotion + high time pressure, analytical focus

**Enhanced Features:**
- POLYMETA memory integration (similar past decisions boost attuned score)
- Therapeutic Presence depth slider integration
- Confidence scoring for routing decisions
- Adaptive learning from user feedback
- Mode blending for nuanced responses

### Shared Framework: Viability–Meaning–Trajectory

All modes use the same analytical framework:

**1. Viability**
- Definition: What works in practice — feasibility, risk, leverage, and external advantage
- Focus Areas: Realistic outcomes, compound advantage, risk mitigation, resource constraints, execution readiness
- Questions: What are realistic outcomes? Which compounds advantage? What risks/constraints exist?

**2. Meaning**
- Definition: What aligns with the user's identity, values, and developmental phase
- Focus Areas: Identity congruence, values alignment, long-term motivation, emotional truth, developmental coherence
- Questions: Which reflects who you're becoming? Which sustains motivation? What emotional signals appear?

**3. Trajectory**
- Definition: Where each path leads over time — forward momentum and reversibility
- Focus Areas: 1/3/5-year implications, optionality preservation, door-opening/closing, narrative arc, developmental vector
- Questions: What are 1/3/5-year implications? Which preserves optionality? Which opens/closes doors?

### Mode Descriptions

**Base Mode (Analytical)**
- Tone: Calm, logical, reality-anchored
- Approach: Skip attunement, apply shared framework directly
- Best for: Low emotion + high time pressure scenarios
- Output: Viability Analysis → Meaning Analysis → Trajectory Analysis → Comparative Table → Synthesis

**Attuned Mode (Hybrid)**
- Tone: Grounded, empathic, reality-anchored
- Workflow: (1) Phase/Context Awareness, (2) POLYMETA Integration, (3) Context Parsing, (4) Attunement Reflection (2-4 sentences), (5) Transition Phrase, (6) Shared Framework (tailored to phase), (7) Synthesis
- Best for: High emotion, Transition/Recovery phases, when Therapeutic Presence is active
- Output: Attunement Reflection → Viability Analysis → Meaning Analysis → Trajectory Analysis → Comparative Table → Synthesis

**Blended Mode (Hybrid Ratio)**
- Approach: Combines attunement and analysis based on calculated ratio
- If attuned_ratio > 0.5: Brief attunement (2-3 sentences) then full analysis
- If attuned_ratio ≤ 0.5: Brief acknowledgment (1 sentence) then analysis with occasional check-ins
- Output: Calibrated attunement → Full framework analysis → Synthesis

### Output Format

**Decision Brief** includes:
- Attunement Reflection (if Attuned or Blended mode)
- Viability Analysis (pros/cons with clear reasoning)
- Meaning Analysis (alignment with values and growth)
- Trajectory Analysis (1/3/5-year implications)
- Comparative Summary Table (Option A vs Option B across dimensions)
- Synthesis Statement (clear recommendation with developmental insight)
- Offer: 1-year projection simulation or POLYMETA memory exploration

**Comparative Table Template:**
| Dimension | Option A | Option B |
|-----------|----------|----------|
| Viability | [analysis] | [analysis] |
| Meaning | [analysis] | [analysis] |
| Trajectory | [analysis] | [analysis] |
| Signal | [summary] | [summary] |

**Mini Template** (one-screen mobile):
```
Decision: [name]
Options: [A, B, C]
Top Criterion: [value]
Viability: [Option] ([score]/10)
Meaning: [Option] ([score]/10)
Trajectory: [Option] ([score]/10)
Recommendation: [path]
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

