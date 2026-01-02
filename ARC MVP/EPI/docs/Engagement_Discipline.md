# Engagement Discipline System

**Version:** 2.1.75  
**Last Updated:** December 29, 2025  
**Status:** ✅ Production Ready

---

## Overview

The Engagement Discipline system provides user-controlled boundaries for LUMARA's conversational engagement while preserving all temporal intelligence capabilities. This system allows users to calibrate *how* LUMARA engages, not whether it engages, maintaining ARC's category-defining capability of tracking psychological continuity across time.

## Core Principle

**LUMARA functions as a "thinking partner who knows your trajectory"** - not as a therapist or passive mirror. The goal is **engagement discipline**, not silence. ARC's differentiation is continuous developmental understanding—we calibrate engagement depth, not capability.

## Key Distinction

**We are NOT building:**
- A therapy-style "reflect then stay silent" system
- A passive mirror that only echoes
- A system that apologizes for its capabilities

**We ARE building:**
- A developmental intelligence system with explicit engagement modes
- A thinking partner with clear stopping conditions
- A system with user-controlled synthesis depth

---

## Engagement Modes

### Reflect Mode (Default)

**Purpose:** Surface patterns and stop - minimal follow-up

**Behavior:**
- Surfaces patterns and temporal connections
- Names tensions without resolving them
- Stops after achieving grounding (pattern named, request fulfilled, temporal connection made)
- NO follow-up questions except for clarification
- NO synthesis across domains
- Response should feel complete and grounded, not inviting further exploration

**Best For:**
- Journaling without exploration
- Users who prefer minimal AI interaction
- Quick pattern recognition without deep engagement

### Explore Mode

**Purpose:** Surface patterns and invite deeper examination

**Behavior:**
- All REFLECT mode capabilities
- May ask ONE connecting question per response
- Can propose alternative framings
- Invite deeper examination when it adds developmental value
- Questions should connect to trajectory, not probe emotions
- Example good question: "This pattern connects to [past entry] - does that resonate?"
- Example bad question: "What feelings does this bring up for you?"

**Best For:**
- Active sense-making
- Users who want guided exploration
- Connecting current insights to past patterns

### Integrate Mode

**Purpose:** Synthesize across domains and time horizons

**Behavior:**
- All EXPLORE mode capabilities
- May synthesize across permitted domains
- Connect long-term trajectory themes
- Most active engagement posture
- Synthesis must respect user's domain boundaries
- Focus on developmental continuity across life areas

**Best For:**
- Holistic understanding
- Users who want cross-domain insights
- Long-term pattern recognition across life areas

---

## Synthesis Preferences

Users can control which life domains LUMARA can connect together (only applies in INTEGRATE mode):

### Available Synthesis Options

- **Faith & Work**: Connect spiritual themes with professional decisions
- **Relationships & Work**: Connect personal relationships to work context
- **Health & Emotions**: Connect physical health to emotional patterns
- **Creative & Intellectual**: Connect creative pursuits to intellectual work

### Protected Domains

Users can designate specific domains as "protected" - LUMARA will never synthesize across these boundaries, even in INTEGRATE mode.

---

## Response Discipline

Fine-tune how LUMARA responds and what language it uses:

### Temporal Connections

- **Max Temporal Connections**: Maximum connections to past entries per response (1-5, default: 2)
- Controls how many historical references LUMARA can make in a single response

### Question Limits

- **Max Questions**: Maximum exploratory questions per response (0-2, default: 1)
- Only applies in EXPLORE and INTEGRATE modes
- REFLECT mode never asks exploratory questions

### Language Boundaries

- **Allow Therapeutic Language**: Permit therapy-style phrasing ("How does this make you feel?")
  - Default: `false` - Therapeutic questions are prohibited by default
- **Allow Prescriptive Guidance**: Permit direct advice ("You should...", "It's important to...")
  - Default: `false` - Prescriptive language is prohibited by default

### Response Length

**Two Control Systems:**

1. **Engagement Discipline Response Length** (via `engagement.response_length`):
   - **Preferred Length**: Concise (1-2 paragraphs), Moderate (2-4 paragraphs), or Detailed (4+ paragraphs)
   - Default: Moderate
   - Used when Response Length Auto mode is enabled

2. **Manual Response Length Controls** (via `responseLength` section):
   - **Auto Mode** (default): LUMARA chooses appropriate length based on question complexity
   - **Manual Mode**: User sets precise limits:
     - **Sentence Number**: 3, 5, 10, 15, or ∞ (infinity) - total sentences in response
     - **Sentences per Paragraph**: 3, 4, or 5 - paragraph structure
   - When manual mode is active, sentence count takes priority over engagement discipline length
   - LUMARA reformats responses to fit limits without cutting off mid-thought
   - Individual sentence length is not limited - only total count and paragraph structure

**Priority Order:**
1. If `responseLength.auto` is `false`: Use manual controls (`max_sentences`, `sentences_per_paragraph`)
2. If `responseLength.auto` is `true`: Use `engagement.response_length` and `behavior.verbosity`

---

## Technical Implementation

### Data Models

**Location:** `lib/models/engagement_discipline.dart`

**Key Classes:**
- `EngagementMode` enum: `reflect`, `explore`, `integrate`
- `SynthesisPreferences`: Domain synthesis permissions
- `ResponseDiscipline`: Response boundaries and limits
- `EngagementSettings`: Main settings container
- `EngagementContext`: Integration with LUMARA Control State

### Integration with LUMARA

**Location:** `lib/arc/chat/services/lumara_control_state_builder.dart`

The Engagement Discipline system integrates with LUMARA's Control State JSON system:

```dart
{
  'engagement': {
    'mode': 'reflect' | 'explore' | 'integrate',
    'synthesis_allowed': {
      'faith_work': bool,
      'relationship_work': bool,
      'health_emotional': bool,
      'creative_intellectual': bool
    },
    'max_temporal_connections': int,
    'max_explorative_questions': int,
    'allow_therapeutic_language': bool,
    'allow_prescriptive_guidance': bool,
    'response_length': 'concise' | 'moderate' | 'detailed',
    'synthesis_depth': 'surface' | 'moderate' | 'deep',
    'protected_domains': [string],
    'behavioral_params': {...}
  }
}
```

### Settings Persistence

**Location:** `lib/arc/chat/services/lumara_reflection_settings_service.dart`

Engagement settings are persisted using SharedPreferences and integrated with the existing LUMARA reflection settings system.

### UI Implementation

**Location:** `lib/shared/ui/settings/advanced_settings_view.dart`

The Engagement Discipline UI is located in the Advanced Settings menu:

- **Engagement Mode Selector**: Radio button selection for Reflect, Explore, or Integrate
- **Cross-Domain Synthesis Card**: Toggle switches for each synthesis option
- **Response Boundaries Card**: Sliders and toggles for response discipline settings

**Styling:**
- Black background with white text (`Colors.white.withOpacity(0.05)`)
- Purple icons and toggles (`kcAccentColor`)
- Consistent with other Advanced Settings cards

---

## System Prompt Integration

The Engagement Discipline settings are integrated into LUMARA's system prompt via the Control State system. The master prompt (`lib/arc/chat/llm/prompts/lumara_master_prompt.dart`) receives engagement parameters and adjusts response generation accordingly.

### Mode-Specific Instructions

**REFLECT MODE:**
- Surface patterns and temporal connections
- Name tensions without resolving them
- Stop after achieving grounding
- NO follow-up questions except for clarification
- NO synthesis across domains

**EXPLORE MODE:**
- All REFLECT mode capabilities
- May ask ONE connecting question per response
- Can propose alternative framings
- Questions should connect to trajectory, not probe emotions

**INTEGRATE MODE:**
- All EXPLORE mode capabilities
- May synthesize across permitted domains
- Connect long-term trajectory themes
- Synthesis must respect user's domain boundaries

---

## Prohibited Patterns

The system automatically filters out prohibited patterns regardless of mode:

- Therapeutic questions: "How does this make you feel?"
- Dependency-forming language: "I'm here for you"
- Prescriptive language: "You should...", "It's important for you to..."
- Emotional probing: "What feelings come up for you?"

These patterns are filtered at the response validation layer before presentation to the user.

---

## Default Settings

**Default Engagement Mode:** `reflect`

**Default Synthesis Preferences:**
- Faith & Work: `false`
- Relationships & Work: `true`
- Health & Emotions: `true`
- Creative & Intellectual: `false`

**Default Response Discipline:**
- Max Temporal Connections: `2`
- Max Questions: `1`
- Allow Therapeutic Language: `false`
- Allow Prescriptive Guidance: `false`
- Preferred Length: `moderate`

---

## User Experience

### Settings Access

1. Navigate to **Settings** → **Advanced Settings**
2. Scroll to **Engagement Discipline** section
3. Configure:
   - **Engagement Mode**: Select Reflect, Explore, or Integrate
   - **Cross-Domain Synthesis**: Toggle synthesis options (only applies in Integrate mode)
   - **Response Boundaries**: Adjust temporal connections, questions, and language permissions

### Visual Design

- **Card-based layout**: Each setting category in its own card
- **Consistent styling**: Black background, white text, purple accents
- **Clear descriptions**: Each option includes explanatory text
- **Radio buttons**: For engagement mode selection
- **Toggle switches**: For synthesis and language permissions
- **Sliders**: For numeric settings (temporal connections, questions)

---

## Future Enhancements

### Planned Features

1. **Conversation-Level Overrides**: Temporarily change engagement mode for a specific conversation
2. **Adaptive Mode Switching**: Let ATLAS phase or VEIL state influence engagement mode
3. **Advanced Synthesis Controls**: More granular domain protection
4. **Response Templates**: Pre-configured response styles per mode
5. **Usage Analytics**: Track which modes users prefer

---

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
- [FEATURES.md](FEATURES.md) - Complete feature documentation
- [UI_UX.md](UI_UX.md) - UI/UX design documentation
- [CHANGELOG.md](CHANGELOG.md) - Version history and changes

---

**Status**: ✅ Production Ready  
**Last Updated**: December 29, 2025  
**Version**: 2.1.75

