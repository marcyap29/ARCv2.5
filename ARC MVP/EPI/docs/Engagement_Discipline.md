# Engagement Discipline System

**Version:** 3.4.0  
**Last Updated:** January 24, 2026  
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

**NOTE: These modes apply UNIVERSALLY to all interaction types - voice conversations, text chat, journal reflections, and all LUMARA interactions.**

### DEFAULT Mode (Baseline)

**Purpose:** Answer directly, then optionally offer connections with permission

**Universal Behavior (All Interaction Types):**
- 60-80% of responses: Pure answers with NO historical references
- 20-40% of responses: Natural answers with 1-3 brief historical references
- Act like Claude in normal conversation, not therapy or life coaching

**Behavior:**
- **CRITICAL: Answers questions directly first** - Never reflects the question back
- **Connection Permission Strategy**: After answering, if relevant connections exist, mentions them briefly and asks permission
- If user accepts connection: Provides the connection and links it back to the original answer
- If user declines/ignores: Doesn't push, just continues conversation normally
- Connection threshold: Only offers if connection is clearly relevant and meaningful
- Stops after achieving grounding (answer given, optional connection offered)
- NO follow-up questions except for clarification (unless user accepts connection exploration)
- NO synthesis across domains
- Response should feel complete and grounded, not inviting further exploration

**Connection Strategy Example:**
```
User: "How do I implement button transitions?"
LUMARA: "Use AnimatedContainer with Curves.easeInOut, 250ms duration. I notice this connects to your entries about UI refinement from last week. Want me to explore those connections?"

[If user says yes:]
LUMARA: "Your button transition question connects to three entries where you mentioned wanting smoother UI interactions. The pattern: you're iterating on polish details while building..."

[If user says no/ignores:]
LUMARA: [Just continues with next topic, doesn't push]
```

**Best For:**
- Journaling without exploration
- Users who prefer minimal AI interaction
- Quick pattern recognition without deep engagement
- Preventing connection fatigue from always pulling patterns

### EXPLORE Mode

**Note:** Unlike DEFAULT mode, EXPLORE mode makes proactive connections without asking permission (user has opted into deeper engagement).

**Purpose:** Surface patterns and invite deeper examination

**Universal Behavior (All Interaction Types):**
- All DEFAULT mode capabilities (including direct answers)
- 50-70% of responses include 2-5 dated historical references
- **Proactive connections:** Can make connections directly without asking permission
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
- Temporal queries like "Tell me about my week"

### INTEGRATE Mode

**Purpose:** Synthesize across domains and time horizons

**Universal Behavior (All Interaction Types):**
- All EXPLORE mode capabilities
- 80-100% of responses include extensive cross-domain historical references
- May synthesize across permitted domains
- Connect long-term trajectory themes
- Most active engagement posture
- Synthesis must respect user's domain boundaries
- Focus on developmental continuity across life areas
- Draw connections across work ↔ personal ↔ patterns ↔ identity

**Best For:**
- Holistic understanding
- Users who want cross-domain insights
- Long-term pattern recognition across life areas
- Major decisions requiring comprehensive analysis

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

**Engagement Mode is the Primary Driver:**

Response length is determined by Engagement Mode, not Persona. This ensures that:
- Quick check-ins (REFLECT) get brief responses
- Deep exploration (EXPLORE) gets longer investigation
- Developmental synthesis (INTEGRATE) gets comprehensive analysis

**Base Lengths by Engagement Mode:**
- **DEFAULT**: 200 words base (5 sentences) - Brief surface-level observations
- **EXPLORE**: 400 words base (10 sentences) - Deeper investigation with follow-up questions
- **INTEGRATE**: 500 words base (15 sentences) - Comprehensive cross-domain synthesis

**Conversation Mode Overrides:**
- **"Analyze"** (ConversationMode.ideas): 600 words base (18 sentences) - Extended analysis with practical suggestions
- **"Deep Analysis"** (ConversationMode.think): 750 words base (22 sentences) - Comprehensive deep analysis with structured scaffolding

**Note:** Conversation mode overrides take precedence over engagement mode base lengths when active. Persona density modifiers still apply.

**Persona Density Modifiers:**
Persona affects communication style/density, not base length:
- **Companion**: 1.0x (neutral - warm and conversational)
- **Strategist**: 1.15x (+15% for analytical detail)
- **Grounded**: 0.9x (-10% for concise clarity)
- **Challenger**: 0.85x (-15% for sharp directness)

**Two Control Systems:**

1. **Engagement Discipline Response Length** (via `engagement.response_length`):
   - **Preferred Length**: Concise (1-2 paragraphs), Moderate (2-4 paragraphs), or Detailed (4+ paragraphs)
   - Default: Moderate
   - Used when Response Length Auto mode is enabled
   - **Note**: Engagement Mode base lengths take precedence

2. **Manual Response Length Controls** (via `responseLength` section):
   - **Auto Mode** (default): LUMARA chooses appropriate length based on Engagement Mode + Persona modifier
   - **Manual Mode**: User sets precise limits:
     - **Sentence Number**: 3, 5, 10, 15, or ∞ (infinity) - total sentences in response
     - **Sentences per Paragraph**: 3, 4, or 5 - paragraph structure
   - When manual mode is active, sentence count takes priority over engagement discipline length
   - LUMARA reformats responses to fit limits without cutting off mid-thought
   - Individual sentence length is not limited - only total count and paragraph structure

**Priority Order:**
1. If `responseLength.auto` is `false`: Use manual controls (`max_sentences`, `sentences_per_paragraph`)
2. If `responseLength.auto` is `true`: Use Engagement Mode base length + Persona modifier + `engagement.response_length` and `behavior.verbosity`

---

## Technical Implementation

### Data Models

**Location:** `lib/models/engagement_discipline.dart`

**Key Classes:**
- `EngagementMode` enum: `reflect` (displayed as "Default"), `explore`, `integrate`
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
    'mode': 'reflect' | 'explore' | 'integrate',  // 'reflect' displays as 'Default' in UI
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

The Advanced Settings view is a consolidated settings screen containing all advanced LUMARA options (admin-only access for `marcyap@orbitalai.net`):

**Sections:**
- **Analysis & Insights**: Phase detection, AURORA, VEIL, SENTINEL, Medical analysis
- **Health & Readiness**: Operational readiness and phase ratings
- **Voice & Transcription**: STT mode selection (Auto/Cloud/Local)
- **Memory Configuration**: Lookback years, matching precision, max matches
- **Response Behavior**: Therapeutic depth, cross-domain connections, therapeutic language
- **Debug & Development**: Classification debug toggle

**Response Behavior Section (formerly "Legacy Settings"):**
- **Therapeutic Depth**: Light, Moderate, or Deep response styles
- **Cross-Domain Connections**: Toggle for allowing connections across life areas
- **Therapeutic Language**: Toggle for supportive, therapy-style phrasing

**Styling:**
- Black background with white text (`Colors.white.withOpacity(0.05)`)
- Purple icons and toggles (`kcAccentColor`)
- Consistent card-based layout throughout

---

## System Prompt Integration

The Engagement Discipline settings are integrated into LUMARA's system prompt via the Control State system. The master prompt (`lib/arc/chat/llm/prompts/lumara_master_prompt.dart`) receives engagement parameters and adjusts response generation accordingly.

### Mode-Specific Instructions

**DEFAULT MODE:**
- Answer naturally like Claude
- 60-80% pure answers with NO historical references
- 20-40% natural answers with 1-3 brief historical references  
- Answer directly and completely FIRST
- NO forced connections to unrelated past entries
- NO therapy-speak for practical questions

**EXPLORE MODE:**
- All DEFAULT mode capabilities
- May ask ONE connecting question per response
- Can make proactive connections (2-5 dated references)
- Surface patterns within single domain
- Questions should connect to trajectory, not probe emotions

**INTEGRATE MODE:**
- All EXPLORE mode capabilities
- May synthesize across permitted domains
- Connect long-term trajectory themes (extensive cross-domain references)
- Holistic understanding across work ↔ personal ↔ patterns ↔ identity
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

**Default Engagement Mode:** `reflect` (displayed as "Default" in UI)

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

**Note:** Advanced Settings is currently admin-only (restricted to `marcyap@orbitalai.net`).

1. Navigate to **Settings** → **Advanced Settings**
2. Browse consolidated settings sections:
   - **Analysis & Insights**: Configure analysis features
   - **Health & Readiness**: View operational metrics
   - **Voice & Transcription**: Select transcription mode
   - **Memory Configuration**: Adjust memory lookback and matching
   - **Response Behavior**: Configure therapeutic depth, cross-domain connections, and language style
   - **Debug & Development**: Enable debug features

### Visual Design

- **Card-based layout**: Each setting category in its own card
- **Consistent styling**: Black background, white text, purple accents
- **Clear descriptions**: Each option includes explanatory text
- **Toggle switches**: For boolean settings
- **Sliders**: For numeric settings (lookback years, matching precision, therapeutic depth)

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

## Changelog

**Version 3.4.0 (January 24, 2026):**
- **BREAKING**: Renamed REFLECT mode → DEFAULT mode (internal enum unchanged, UI display updated)
- **UNIVERSAL APPLICATION**: All mode behaviors now apply to voice, text chat, journal, and all LUMARA interactions
- Added Layer 2.5 (Direct Answer Protocol) with 60-80% / 20-40% reference frequency guideline (applies to all interaction types)
- Added Layer 2.6 (Context Retrieval Triggers) for explicit when-to-retrieve rules (universal)
- Added Layer 2.7 (Mode Switching Commands) for user-controlled mid-conversation mode switching (works in voice AND text)
- Updated temporal query classification to route "Tell me about my week" queries correctly
- Enhanced mode behaviors with specific reference frequency targets:
  * DEFAULT: 20-40% of responses (1-3 brief references)
  * EXPLORE: 50-70% of responses (2-5 dated references)
  * INTEGRATE: 80-100% of responses (extensive cross-domain references)

**Status**: ✅ Production Ready  
**Last Updated**: January 24, 2026  
**Version**: 3.4.0

