# LUMARA Response Control Systems

> A guide to understanding how LUMARA's responses are shaped by multiple interacting systems.

## Overview

LUMARA's responses are controlled by **three independent systems** that layer together:

| System | When It's Set | What It Controls |
|--------|---------------|------------------|
| **EngagementMode** | Before you write (or via voice command) | Depth of engagement & cross-domain connections |
| **EntryClassifier** | Automatic (content-based) | Response length based on message type |
| **ConversationMode** | After LUMARA responds | Follow-up continuation style |

Understanding these systems helps explain why LUMARA responds differently in different contexts.

---

## 1. EngagementMode

**Purpose:** Controls how deeply LUMARA engages with your content.

**When set:** User selects before writing (DEFAULT / EXPLORE / INTEGRATE selector) OR uses voice commands to switch mid-conversation.

**Location:** `lib/models/engagement_discipline.dart`, `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` (Layers 2.5, 2.6, 2.7)

### Modes

| Mode | Behavior | Historical References | Best For |
|------|----------|----------------------|----------|
| **DEFAULT** | Answer naturally like Claude. 60-80% pure answers with NO references, 20-40% with 1-3 brief references. | 20-40% of responses (1-3 refs) | Casual conversation, quick questions, factual queries |
| **EXPLORE** | Surface patterns + invite deeper examination. Ask follow-up questions. Proactive connections. | 50-70% of responses (2-5 dated refs) | Active sense-making, pattern analysis, temporal queries |
| **INTEGRATE** | Synthesize across domains and time horizons. Connect past entries, other life areas. Full synthesis. | 80-100% of responses (extensive refs) | Holistic understanding, big picture, comprehensive analysis |

### Voice Commands for Mode Switching (Layer 2.7)

Users can switch modes mid-conversation:

**To DEFAULT:** "Keep it simple", "Just answer briefly", "Quick response"
**To EXPLORE:** "Explore this more", "Show me patterns", "Go deeper on this"
**To INTEGRATE:** "Full synthesis", "Connect across everything", "Big picture"

### How It Affects Responses

- **DEFAULT:** LUMARA answers directly and naturally, with occasional brief historical references (1-3 when relevant)
- **EXPLORE:** LUMARA asks 1 connecting question, surfaces patterns, includes 2-5 dated references to help you examine what you wrote
- **INTEGRATE:** LUMARA provides comprehensive synthesis, references extensive past entries, connects themes across life domains (work ↔ relationships ↔ health)

### Code Reference

```dart
enum EngagementMode {
  reflect,   // Displayed as "Default" in UI - answer naturally with occasional references
  explore,   // Surface patterns and invite deeper examination
  integrate  // Synthesize across domains and time horizons
}

// Display names
extension EngagementModeExtension on EngagementMode {
  String get displayName {
    switch (this) {
      case EngagementMode.reflect:
        return 'Default';  // Changed from 'Reflect' in v3.4.0
      case EngagementMode.explore:
        return 'Explore';
      case EngagementMode.integrate:
        return 'Integrate';
    }
  }
}
```

---

## 2. EntryClassifier

**Purpose:** Automatically determines response length based on what you wrote.

**When set:** Automatic — analyzes your text content.

**Location:** `lib/services/lumara/entry_classifier.dart`

### Entry Types

| Type | Detected When... | Word Target | Speed |
|------|------------------|-------------|-------|
| **conversational** | Short updates, low emotion, observational ("Had coffee. Walked the dog.") | ~50 words | Fast |
| **factual** | Questions, clarifications, learning notes ("Is Newton's 3rd law about...?") | ~100 words | Fast |
| **reflective** | Emotions, goals, struggles, personal metrics ("I feel frustrated because...") | ~250 words | Medium |
| **analytical** | Long essays, third-person, theoretical content | ~300 words | Medium |
| **metaAnalysis** | Explicit pattern requests ("What patterns do you see in my entries?") | ~500 words | Slower |

### Detection Logic

The classifier analyzes:
- **Word count** — Short vs. long entries
- **Emotional density** — How many emotional words (frustrated, happy, anxious, grateful)
- **First-person density** — "I", "my", "me" frequency
- **Question marks** — Indicates factual/clarification seeking
- **Goal language** — "I want to", "my goal is", "working on"
- **Struggle language** — "struggling", "can't", "stuck", "overwhelmed"
- **Meta-analysis triggers** — "what patterns", "looking back", "how have I changed"

### Why This Matters

A quick life update shouldn't get a 500-word philosophical response. A deep emotional struggle shouldn't get a 50-word brush-off. The classifier ensures response length matches content depth.

### Code Reference

```dart
enum EntryType {
  factual,        // Questions, clarifications, learning notes
  reflective,     // Feelings, struggles, personal assessment, goals
  analytical,     // Essays, theories, frameworks, external analysis
  conversational, // Quick updates, mundane logging
  metaAnalysis    // Explicit requests for pattern recognition
}
```

---

## 3. ConversationMode

**Purpose:** Controls what LUMARA does when you ask for a follow-up.

**When set:** User taps a button after LUMARA's initial response.

**Location:** `lib/arc/chat/models/lumara_reflection_options.dart`

### Continuation Options

| Button | ConversationMode | What It Does | Word Target |
|--------|------------------|--------------|-------------|
| **Regenerate** | `regenerate` | Rewrite the response with different phrasing | Same as original |
| **Analyze** | `ideas` | Expand with practical ideas from past patterns | ~600 words |
| **Deep Analysis** | `think` | Go even deeper with logical scaffolding | ~750 words |
| **Different Perspective** | `perspective` | Offer a reframing or alternative viewpoint | ~400 words |
| **Next Steps** | `nextSteps` | Suggest phase-appropriate actions | ~300 words |
| **Reflect Deeply** | `reflectDeeply` | Invoke the "More Depth" pipeline | ~500 words |

### Code Reference

```dart
enum ConversationMode {
  ideas,           // Suggest practical ideas from past patterns
  think,           // Help think through with logical scaffolding
  perspective,     // Offer different perspective/reframing
  nextSteps,       // Suggest next steps (phase-appropriate)
  reflectDeeply,   // Reflect more deeply (invoke More Depth pipeline)
  continueThought, // Finish the previous reply without restarting context
}
```

---

## How The Systems Layer Together

```
┌─────────────────────────────────────────────────────────────────┐
│                        YOU WRITE SOMETHING                       │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: EntryClassifier analyzes your text                     │
│  ─────────────────────────────────────────                      │
│  "I've been feeling overwhelmed at work lately..."              │
│                                                                  │
│  Detected: reflective (emotional words, first-person, struggle) │
│  Word target: ~250 words                                         │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 2: EngagementMode shapes the response style               │
│  ─────────────────────────────────────────────                  │
│  You had "Integrate" selected                                    │
│                                                                  │
│  → LUMARA will connect to past entries about work stress        │
│  → May reference patterns from other life domains               │
│  → Will synthesize across time ("Last month you mentioned...")  │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                     LUMARA RESPONDS                              │
│  ─────────────────────────────────────────                      │
│  ~250 word empathetic reflection with cross-domain connections  │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 3: You tap "Deep Analysis"                                │
│  ─────────────────────────────────────────                      │
│  ConversationMode: think                                         │
│                                                                  │
│  → LUMARA generates ~750 word follow-up                         │
│  → Provides logical scaffolding to think through the issue      │
│  → May suggest frameworks or structured approaches              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Voice Mode: Three-Tier Engagement System

Voice mode uses the **same three-tier engagement system as written mode** (DEFAULT/EXPLORE/INTEGRATE), with automatic depth classification per-turn and user-controlled mode switching:

| Mode | Word Limit | Latency | Historical References | Memory Retrieval |
|------|------------|---------|----------------------|------------------|
| **DEFAULT** (baseline) | 100 words | 5 sec | 20-40% of responses (1-3 refs) | Conditional |
| **EXPLORE** (when asked) | 200 words | 10 sec | 50-70% of responses (2-5 refs) | **Yes** |
| **INTEGRATE** (when asked) | 300 words | 15 sec | 80-100% of responses (extensive refs) | **Yes** |

### How Voice Mode Routes Requests

Voice mode uses `skipHeavyProcessing` to control memory retrieval:
- **DEFAULT mode**: `skipHeavyProcessing: true` for general questions → Fast, no journal history unless temporal query detected
- **EXPLORE/INTEGRATE modes**: `skipHeavyProcessing: false` → Full journal history retrieval

**Layer 2.5 (Voice Mode Direct Answer Protocol):**
- 60-80% of responses: Pure answers with NO historical references
- 20-40% of responses: Natural answers with 1-3 brief historical references
- User can override with explicit requests like "Give me your full thoughts"

### Temporal Query Triggers (v3.3.11)

These phrases automatically trigger **EXPLORE mode with memory retrieval** (Layer 2.6):
- "Tell me about my [week/month/day]"
- "What have I been [doing/working on]"
- "How am I doing [with X]"
- "Summarize my progress"
- "What's been going on [with me/lately]"
- "Catch me up on [my work/my progress]"

### Code Location

`lib/arc/chat/voice/services/voice_session_service.dart` — Routes based on engagement mode

```dart
// Explore/Integrate get full journal history
skipHeavyProcessing: engagementMode == EngagementMode.reflect,
```

---

## Additional Systems (Related but Separate)

### ToneMode

Controls the emotional tone of LUMARA's response.

| Mode | Behavior |
|------|----------|
| **normal** | Balanced, phase-aware |
| **soft** | Gentle, containing, fewer directives |

### PhaseHint

LUMARA adjusts responses based on your current life phase:
- **Discovery** — Curious, exploratory
- **Expansion** — Encouraging growth
- **Transition** — Supportive during change
- **Consolidation** — Reinforcing stability
- **Recovery** — Gentle, containing
- **Breakthrough** — Celebrating progress

---

## Quick Reference: "Why did LUMARA respond that way?"

| Symptom | Likely Cause |
|---------|--------------|
| Response too short | EntryClassifier detected `conversational` or `factual` |
| Response too long | EntryClassifier detected `reflective`, `analytical`, or `metaAnalysis` |
| No connections to past entries | EngagementMode set to `DEFAULT` instead of `INTEGRATE` |
| Very few historical references | DEFAULT mode (20-40% reference frequency) - say "Explore this more" for deeper analysis |
| No follow-up questions | EngagementMode set to `DEFAULT` instead of `EXPLORE` |
| Voice mode slow (30+ seconds) | EXPLORE/INTEGRATE mode with high latency - check API response times |
| Voice mode responses generic | Check depth classification - may be in DEFAULT mode, try "Show me patterns" |
| "Tell me about my week" not retrieving context | Check temporal query classification in `entry_classifier.dart` |

---

## File Locations

| System | File |
|--------|------|
| EngagementMode | `lib/models/engagement_discipline.dart` |
| EntryClassifier | `lib/services/lumara/entry_classifier.dart` |
| ConversationMode | `lib/arc/chat/models/lumara_reflection_options.dart` |
| Response length targets | `lib/services/lumara/response_mode.dart` |
| Voice depth classifier | `lib/services/lumara/entry_classifier.dart` (`classifyVoiceDepth()`) |
| Voice prompt builders | `lib/arc/chat/voice/prompts/voice_response_builders.dart` |
| Voice session service | `lib/arc/chat/voice/services/voice_session_service.dart` |
| LUMARA API | `lib/arc/chat/services/enhanced_lumara_api.dart` |

---

## Voice Mode: Three-Tier Engagement Classification

Voice mode classifies each utterance into one of three engagement modes:

| Mode | Triggers | Response | Historical References | Memory |
|------|----------|----------|----------------------|--------|
| **DEFAULT** (baseline) | No special triggers OR user command | 100 words, conversational | 20-40% (1-3 refs) | Conditional |
| **EXPLORE** | "Explore this", temporal queries, pattern requests OR user command | 200 words, analytical | 50-70% (2-5 refs) | **Journal history** |
| **INTEGRATE** | "Full synthesis", "Big picture", cross-domain requests OR user command | 300 words, comprehensive | 80-100% (extensive refs) | **Journal history** |

### Mode Switching Commands (Layer 2.7)

**To DEFAULT Mode:**
- "Keep it simple", "Just answer briefly", "Quick response"
- "Don't go too deep", "Surface level is fine"

**To EXPLORE Mode:**
- "Explore this more", "Show me patterns", "Go deeper on this"
- "Tell me about my [week/month]" (temporal queries)
- "What patterns do you see?"

**To INTEGRATE Mode:**
- "Full synthesis", "Connect across everything", "Big picture"
- "Comprehensive analysis", "Long-term view"
- "Connect this across time"

### DEFAULT Mode (No Special Triggers)
- Casual conversation, factual questions
- Brief updates, short utterances
- Technical how-to questions

See [VOICE_MODE_IMPLEMENTATION_GUIDE.md](./VOICE_MODE_IMPLEMENTATION_GUIDE.md) for full details.

---

## Summary

LUMARA's response behavior emerges from multiple control systems:

**For Text/Journal:**
1. **EngagementMode** (user-selected OR voice command) → Depth of engagement & reference frequency
2. **EntryClassifier** (automatic) → Response length  
3. **ConversationMode** (user-selected after response) → Follow-up style

**For Voice:**
4. **VoiceDepthClassifier** (automatic per-turn OR voice command) → DEFAULT / EXPLORE / INTEGRATE mode
5. **SeekingClassifier** (automatic) → Validation / Exploration / Direction / Reflection
6. **Mode Switching Commands** (Layer 2.7) → User can override mode mid-conversation

These systems are designed to be orthogonal — you can have a short (`conversational`) response with deep connections (`INTEGRATE`), or a long (`reflective`) response without any connections (`DEFAULT`).

Voice mode classifies each turn independently and routes to the appropriate response style. **EXPLORE and INTEGRATE modes retrieve journal history** for context-aware responses, while DEFAULT mode conditionally retrieves only for temporal queries ("Tell me about my week").
