# LUMARA Prompt Encouragement System

**Version:** 1.0  
**Date:** January 2025  
**Purpose:** Help LUMARA expand capabilities with phase-aware, emotion-sensitive journaling prompts

## Overview

The LUMARA Prompt Encouragement System provides structured guidance for helping users express themselves through journaling, especially when they're new to writing or experiencing writer's block. The system integrates ATLAS phase context, emotional states, recent patterns, and draft data to generate personalized, contextually appropriate prompts.

## Architecture

### Core Components

1. **`lumara_prompt_encouragement.dart`** - Main system class
   - Provides API for generating journaling prompts
   - Handles phase-emotion matching
   - Manages prompt library and emotion matrix data

2. **`lumara_prompt_encouragement_data.dart`** - Embedded data
   - Prompt Library v1.0 (30 prompts across 6 ATLAS phases)
   - Phase + Emotion Matrix v1.0 (24 phase-emotion combinations)

3. **Integration with `lumara_unified_prompts.dart`**
   - Enhanced journaling context guidance
   - New methods: `getJournalingSystemPrompt()` and `generateJournalingPrompt()`

## Features

### Context Awareness

The system considers:
- **ATLAS Phase**: Adjusts tone and style to current life phase
  - Discovery → curious, exploratory
  - Expansion → creative, energizing
  - Transition → clarifying, reframing
  - Consolidation → integrative, reflective
  - Recovery → gentle, grounding
  - Breakthrough → visionary, synthesizing

- **Emotional State**: Fine-tunes prompts based on detected emotion
- **Recent Patterns**: Links to previous entries or themes
- **Current Drafts**: Helps continue or complete unfinished writing

### Prompt Types

1. **Warm Start** - Short, welcoming encouragement for hesitant users
2. **Memory Bridge** - Links today's moment to previous entries
3. **Sensory Anchor** - Invites presence through detail
4. **Perspective Shift** - Reframes or elevates the view
5. **Phase-Aligned Deep Prompt** - Reflective exploration tied to ATLAS phase
6. **Creative Diverter** - Gentle pattern break for writer's block

### Phase + Emotion Matrix

Cross-references 6 ATLAS phases with 4 emotional states each:
- **Discovery**: curious, anxious, hopeful, lost
- **Expansion**: inspired, overwhelmed, confident, restless
- **Transition**: uncertain, reflective, drained, determined
- **Consolidation**: calm, grateful, reflective, stuck
- **Recovery**: tired, sad, healing, numb
- **Breakthrough**: excited, empowered, relieved, awed

## Usage

### Basic Usage

```dart
import 'package:my_app/arc/chat/prompts/lumara_prompt_encouragement.dart';
import 'package:my_app/arc/chat/prompts/lumara_unified_prompts.dart';

// Generate a prompt based on phase and emotion
final promptData = await LumaraUnifiedPrompts.instance.generateJournalingPrompt(
  phase: 'discovery',
  emotion: 'curious',
  recentTheme: 'change',
);

print(promptData['prompt']); // The prompt text
print(promptData['contextEcho']); // Optional context connection
```

### Using the Encouragement System Directly

```dart
import 'package:my_app/arc/chat/prompts/lumara_prompt_encouragement.dart';

final encouragement = LumaraPromptEncouragement.instance;

// Generate prompt with phase and emotion
final prompt = await encouragement.generatePrompt(
  phase: AtlasPhase.discovery,
  emotion: EmotionalState.curious,
  recentPatterns: {'theme': 'exploration'},
);

// Get all prompts for a phase
final discoveryPrompts = await encouragement.getPhasePrompts(AtlasPhase.discovery);

// Get prompts by intent type
final warmStarts = await encouragement.getPromptsByIntent(PromptIntent.warmStart);
```

### Enhanced System Prompt for Journaling

```dart
final journalingPrompt = await LumaraUnifiedPrompts.instance.getJournalingSystemPrompt(
  phaseData: {'phase': 'Expansion', 'readiness': 0.8},
  energyData: {'level': 'medium', 'timeOfDay': 'morning'},
);
```

## Output Format

Prompts are returned with the following structure:

```dart
{
  'prompt': 'What\'s been catching your attention lately — even in small ways?',
  'intent': 'warmStart',
  'phase': 'discovery',
  'contextEcho': 'You\'ve been exploring themes of change lately. Would you like to start there today?',
}
```

## Integration Points

### System Prompt Enhancement

The journaling context guidance in `lumara_unified_prompts.dart` now includes:
- Phase-aware prompt generation instructions
- Emotional tone consideration
- Pattern recognition guidance
- SAGE Echo mode activation for free-writing users

### User-Facing Features

The system provides:
- **Onboarding Message**: Welcome text for new users
- **Dynamic Prompt Generation**: Context-aware prompts based on current state
- **Context Echo**: Optional connections to recent patterns

## Data Structure

### Prompt Library

Each phase contains 5 prompts, organized by intent type:
- `type`: One of the 6 prompt intent types
- `prompt`: The actual prompt text

### Emotion Matrix

Each phase-emotion combination includes:
- `tone`: Descriptive tone guidance
- `intent`: Recommended prompt intent type
- `prompt`: Phase-emotion specific prompt

## Therapeutic Presence Mode

**Status:** ✅ **IMPLEMENTED** - Therapeutic Presence Mode v1.0 is now fully integrated.

Therapeutic Presence Mode provides specialized support for users journaling through emotionally complex experiences (racism, grief, anger, burnout, shame, identity confusion, loneliness, existential uncertainty, etc.). The system uses 8 tone modes and adaptive response logic based on emotional intensity and ATLAS phase.

### Features

- **8 Tone Modes**: Grounded Containment, Reflective Echo, Restorative Closure, Compassionate Mirror, Quiet Integration, Cognitive Grounding, Existential Steadiness, Restorative Neutrality
- **10 Emotion Categories**: anger, grief, shame, fear, guilt, loneliness, confusion, hope, burnout, identity_violation
- **3 Intensity Levels**: low, moderate, high
- **Response Framework**: Acknowledge → Reflect → Expand → Contain/Integrate
- **Phase-Aware**: Adapts tone and prompts based on ATLAS phase
- **Context-Aware**: References past entries, patterns, and media signals

### Usage

```dart
import 'package:my_app/arc/chat/prompts/lumara_unified_prompts.dart';

// Generate therapeutic response
final response = await LumaraUnifiedPrompts.instance.generateTherapeuticResponse(
  emotionCategory: 'grief',
  intensity: 'high',
  phase: 'recovery',
  contextSignals: {'past_patterns': 'loss themes'},
  isRecurrentTheme: true,
);

// Get therapeutic presence system prompt
final therapeuticPrompt = await LumaraUnifiedPrompts.instance.getTherapeuticPresencePrompt(
  phaseData: {'phase': 'Recovery', 'readiness': 0.6},
  emotionData: {'category': 'grief', 'intensity': 'high'},
);
```

### Tone Mode Selection Logic

- **High Intensity** → Grounded Containment or Restorative Neutrality
- **Low Intensity + Integrative Phase** → Quiet Integration
- **Recurrent Themes** → Context echo with gentle reference to past entries
- **Media Indicators** (tearful/shaky voice) → Softened tone + containment endings

## Future Enhancements

Potential extensions:
- Emotional subtype variations (e.g., anxious Discovery vs. inspired Discovery)
- Confidence scoring for phase detection
- Few-shot examples for LLM tuning
- User preference learning
- Multi-language support

## Files

- `lumara_prompt_encouragement.dart` - Main system class for prompt encouragement
- `lumara_prompt_encouragement_data.dart` - Embedded data structures (prompt library & emotion matrix)
- `lumara_therapeutic_presence.dart` - Therapeutic Presence Mode system class
- `lumara_therapeutic_presence_data.dart` - Response Matrix Schema and system prompt
- `lumara_unified_prompts.dart` - Integration with unified prompt system
- `README_PROMPT_ENCOURAGEMENT.md` - This documentation

## References

Based on the LUMARA Reflective Guidance Prompt v1 specification, integrating:
- System-level prompt for journaling assistance
- JSON-ready prompt templates
- User-facing onboarding messages
- Extended prompt library with ATLAS phase examples
- Phase + Emotion Matrix for precise prompt generation

