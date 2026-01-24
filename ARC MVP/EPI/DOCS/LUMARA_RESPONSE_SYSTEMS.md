# LUMARA Response Control Systems

> A guide to understanding how LUMARA's responses are shaped by multiple interacting systems.

## Overview

LUMARA's responses are controlled by **three independent systems** that layer together:

| System | When It's Set | What It Controls |
|--------|---------------|------------------|
| **EngagementMode** | Before you write | Depth of engagement & cross-domain connections |
| **EntryClassifier** | Automatic (content-based) | Response length based on message type |
| **ConversationMode** | After LUMARA responds | Follow-up continuation style |

Understanding these systems helps explain why LUMARA responds differently in different contexts.

---

## 1. EngagementMode

**Purpose:** Controls how deeply LUMARA engages with your content.

**When set:** User selects before writing (Reflect / Explore / Integrate selector).

**Location:** `lib/models/engagement_discipline.dart`

### Modes

| Mode | Behavior | Best For |
|------|----------|----------|
| **Reflect** | Surface patterns and stop. Minimal follow-up questions. Just mirrors what you said. | Quick capture without wanting deep engagement |
| **Explore** | Surface patterns + invite deeper examination. Asks follow-up questions. | Active sense-making, when you want to dig deeper |
| **Integrate** | Synthesize across domains and time horizons. Connects to past entries, other life areas. | Holistic understanding, seeing the bigger picture |

### How It Affects Responses

- **Reflect:** LUMARA acknowledges your thoughts but doesn't push further
- **Explore:** LUMARA asks 1-2 questions to help you examine what you wrote
- **Integrate:** LUMARA references past entries, connects themes across life domains (work ↔ relationships ↔ health)

### Code Reference

```dart
enum EngagementMode {
  reflect,   // Surface patterns and stop - minimal follow-up
  explore,   // Surface patterns and invite deeper examination
  integrate  // Synthesize across domains and time horizons
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

Voice mode uses the **same three-tier engagement system as written mode** (Reflect/Explore/Integrate), with automatic depth classification per-turn:

| Mode | Word Limit | Latency | Memory Retrieval |
|------|------------|---------|------------------|
| **Reflect** (default) | 100 words | 5 sec | No |
| **Explore** (when asked) | 200 words | 10 sec | **Yes** |
| **Integrate** (when asked) | 300 words | 15 sec | **Yes** |

### How Voice Mode Routes Requests

Voice mode uses `skipHeavyProcessing` to control memory retrieval:
- **Reflect mode**: `skipHeavyProcessing: true` → Fast, no journal history
- **Explore/Integrate modes**: `skipHeavyProcessing: false` → Full journal history retrieval

### Temporal Query Triggers (v3.3.10)

These phrases automatically trigger **Explore mode with memory retrieval**:
- "How has my week/month/year been?"
- "Summarize my progress"
- "Review my entries"
- "Based on what you know..."
- "What patterns have you noticed?"

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
| No connections to past entries | EngagementMode set to `Reflect` instead of `Integrate` |
| No follow-up questions | EngagementMode set to `Reflect` instead of `Explore` |
| Voice mode slow (30+ seconds) | Explore/Integrate mode with high latency - check API response times |
| Voice mode responses generic | Check depth classification - may be stuck in Reflect mode |

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

| Mode | Triggers | Response | Memory |
|------|----------|----------|--------|
| **Reflect** (default) | No special triggers | 100 words, casual | No retrieval |
| **Explore** | "Analyze", temporal queries, pattern requests | 200 words, analytical | **Journal history** |
| **Integrate** | "Go deeper", "Connect the dots", synthesis requests | 300 words, synthesis | **Journal history** |

### Explore Mode Triggers
- "How has my week been?" (temporal query)
- "Analyze this", "Give me insight"
- "What patterns do you see?"
- "Based on what you know..."

### Integrate Mode Triggers
- "Go deeper", "Deep analysis"
- "Connect the dots", "Synthesize"
- "What's the bigger picture?"

### Reflect Mode (No Triggers)
- Casual conversation, factual questions
- Brief updates, short utterances
- No emotional or analytical content

See [VOICE_MODE_IMPLEMENTATION_GUIDE.md](./VOICE_MODE_IMPLEMENTATION_GUIDE.md) for full details.

---

## Summary

LUMARA's response behavior emerges from multiple control systems:

**For Text/Journal:**
1. **EngagementMode** (user-selected) → Depth of engagement
2. **EntryClassifier** (automatic) → Response length  
3. **ConversationMode** (user-selected after response) → Follow-up style

**For Voice:**
4. **VoiceDepthClassifier** (automatic per-turn) → Reflect / Explore / Integrate mode
5. **SeekingClassifier** (automatic) → Validation / Exploration / Direction / Reflection

These systems are designed to be orthogonal — you can have a short (`conversational`) response with deep connections (`Integrate`), or a long (`reflective`) response without any connections (`Reflect`).

Voice mode classifies each turn independently and routes to the appropriate response style. **Explore and Integrate modes retrieve journal history** for context-aware responses, while Reflect mode stays fast with no memory retrieval.
