# LUMARA Settings Explained

## Response Length Settings

### Engagement-Mode-Based Response Lengths (Primary Driver)

**Response length is determined by Engagement Mode, not Persona:**

- **REFLECT Mode**: 200 words base (5 sentences)
  - Brief, surface-level observations
  - Focused on grounding and pattern recognition
  - No exploratory questions

- **EXPLORE Mode**: 400 words base (10 sentences)
  - Deeper investigation with follow-up questions
  - Allows connecting questions and alternative framings
  - Medium-length responses for investigation

- **INTEGRATE Mode**: 500 words base (15 sentences)
  - Comprehensive cross-domain synthesis
  - Longest responses for developmental analysis
  - Cross-domain connections and trajectory themes

**Persona Density Modifiers:**
- Persona affects communication style/density, not base length:
  - **Companion**: 1.0x (neutral - warm and conversational)
  - **Strategist**: 1.15x (+15% for analytical detail)
  - **Grounded**: 0.9x (-10% for concise clarity)
  - **Challenger**: 0.85x (-15% for sharp directness)

**Example Word Limits:**

| Engagement Mode | Companion | Strategist | Grounded | Challenger |
|-----------------|-----------|------------|----------|------------|
| **REFLECT**     | 200       | 230        | 180      | 170        |
| **EXPLORE**     | 400       | 460        | 360      | 340        |
| **INTEGRATE**   | 500       | 575        | 450      | 425        |

### Auto Mode vs Manual Mode

**Auto Mode (responseLength.auto = true):**
- LUMARA automatically determines response length based on context
- **ENFORCED LIMIT**: Responses are capped at 10-15 sentences maximum
- LUMARA chooses the appropriate length within this range based on:
  - Engagement Mode (primary driver)
  - Persona density modifier
  - `behavior.verbosity` (0.0-1.0)
  - `engagement.response_length` (concise/moderate/detailed)
  - Context complexity
- **Strict enforcement**: LUMARA must count sentences and stop at 15 maximum

**Manual Mode (responseLength.auto = false):**
- User sets exact limits via sliders:
  - **Max Sentences**: 3, 5, 10, 15, or ∞ (infinity)
  - **Sentences Per Paragraph**: 3, 4, or 5
- **ABSOLUTE STRICT LIMIT**: LUMARA must follow these settings exactly
- No exceptions - if max_sentences = 10, response must have exactly 10 sentences or fewer
- Paragraph structure must match sentences_per_paragraph setting

**Truncation:**
- Responses are truncated at sentence boundaries to prevent mid-sentence cuts
- 25% buffer allows natural flow before truncation triggers

---

## Memory Retrieval Settings

### Max Similar Entries (also called "Max Matches")

**What it does:**
- Controls how many past journal entries LUMARA retrieves when building context
- Determines the **breadth of historical context** available to LUMARA
- Range: 1-20 entries (default: 5)

**How it works:**
- When you write a journal entry or chat message, LUMARA searches your journal history
- It finds entries with similar themes, emotions, or topics (using semantic similarity)
- `maxMatches` determines how many of these similar entries to include in the context
- More entries = broader context, but potentially more noise
- Fewer entries = more focused context, but might miss relevant connections

**Example:**
- If `maxMatches = 5`: LUMARA retrieves the 5 most similar past entries
- If `maxMatches = 10`: LUMARA retrieves the 10 most similar past entries
- These entries are used to understand patterns, provide context, and make connections

**When to adjust:**
- **Increase** (10-20): If you want LUMARA to consider more of your history, see broader patterns
- **Decrease** (1-3): If you want more focused responses, less historical context

---

## Engagement Discipline Settings

### Max Temporal Connections

**What it does:**
- Controls how many references to past entries LUMARA can make **in a single response**
- Determines how many historical connections LUMARA mentions when responding
- Range: 1-5 connections (default: 2)

**How it works:**
- When LUMARA responds, it can reference past journal entries to show patterns or connections
- `maxTemporalConnections` limits how many of these references appear in one response
- This prevents responses from becoming cluttered with too many historical callbacks
- Each "connection" is typically a mention like: "This connects to your entry from [date] where you wrote about..."

**Example:**
- If `maxTemporalConnections = 2`: LUMARA can mention up to 2 past entries in its response
- If `maxTemporalConnections = 5`: LUMARA can mention up to 5 past entries in its response
- LUMARA still has access to all similar entries (via `maxMatches`), but only mentions a limited number

**When to adjust:**
- **Increase** (3-5): If you want more historical references and pattern connections in responses
- **Decrease** (1): If you want minimal historical references, more focused on current entry

---

## Key Difference: Max Similar Entries vs Max Temporal Connections

| Setting | What It Controls | When It's Used |
|---------|-----------------|----------------|
| **Max Similar Entries** | How many past entries LUMARA **retrieves** for context | During context building (before response generation) |
| **Max Temporal Connections** | How many past entries LUMARA **mentions** in response | During response generation (in the actual response text) |

**Analogy:**
- **Max Similar Entries** = How many books LUMARA reads to prepare for the conversation
- **Max Temporal Connections** = How many books LUMARA actually quotes or references in its response

**Example Scenario:**
- You write: "I'm feeling anxious about my presentation tomorrow"
- LUMARA retrieves 10 similar entries (if `maxMatches = 10`) about anxiety, presentations, work stress
- LUMARA uses all 10 entries to understand patterns and context
- But in the response, LUMARA only mentions 2 of them (if `maxTemporalConnections = 2`)
- The response might say: "This connects to your entry from last month about presentation anxiety, and your entry from three months ago about work stress..."

**Why both settings matter:**
- **Max Similar Entries** ensures LUMARA has enough context to understand patterns
- **Max Temporal Connections** ensures responses don't become cluttered with too many references
- You can have high `maxMatches` (comprehensive context) but low `maxTemporalConnections` (concise references)

---

## Recommended Settings

**For focused, concise responses:**
- Max Similar Entries: 3-5
- Max Temporal Connections: 1-2
- Response Length: Manual, 5-10 sentences

**For comprehensive, pattern-rich responses:**
- Max Similar Entries: 10-15
- Max Temporal Connections: 3-4
- Response Length: Auto (10-15 sentences) or Manual, 15 sentences

**For minimal historical context:**
- Max Similar Entries: 1-3
- Max Temporal Connections: 1
- Response Length: Manual, 3-5 sentences

