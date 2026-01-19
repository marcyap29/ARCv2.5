# Unified Intent Depth Classification Prompt

## Purpose
Classify user input (voice transcript or text message) to determine engagement depth needed.

## Classification Types

**TRANSACTIONAL** - Quick, efficient responses needed
- Factual questions with objective answers
- Brief status updates or observations
- Technical how-to questions
- Math calculations or conversions
- Definitions or explanations
- Short statements about daily activities
- Time-sensitive queries ("What time is...", "Remind me...")

**REFLECTIVE** - Deep, emotionally engaged responses needed
- Processing emotions or experiences
- Decision-making support
- Identity or relationship questions
- Existential or meaning-oriented queries
- Working through difficulties
- Seeking perspective on personal matters

---

## Detection Rules

### REFLECTIVE Triggers (if ANY match → classify as REFLECTIVE)

**Explicit processing language:**
- "I need to process..."
- "I need to think through..."
- "I need to work through..."
- "Help me think about..."
- "Help me understand..."
- "Can we talk about..."
- "Let's explore..."

**Emotional struggle markers:**
- "I'm struggling with..."
- "I'm having trouble with..."
- "I'm worried about..."
- "I'm anxious about..."
- "I'm confused about..."
- "I don't know what to do about..."
- "Something's been bothering me..."
- "Something's been weighing on me..."

**Emotional state declarations:**
- "I'm feeling [any emotion word]..."
- "I feel [any emotion word] about..."
- Contains multiple emotion words (anxious, scared, excited, overwhelmed, etc.)

**Decision support requests:**
- "Should I..."
- "What do you think about..." (re: personal matter)
- "Do you think I should..."
- "Help me decide..."

**Self-reflective questions:**
- "Why do I..."
- "Why am I..."
- "What does it mean that I..."
- "Am I being..." (too hard on myself, unreasonable, etc.)

**Relationship or identity exploration:**
- Questions about "my relationship with..."
- Questions about "who I am" or "what I want"
- Questions about purpose, meaning, values

**High emotional density:**
- 3+ emotion words in utterance
- Utterance >50 words with personal pronouns (I, me, my)

**Uncertainty about internal states:**
- "I don't understand why I..."
- "I can't figure out..."
- "I'm not sure what I..."

---

### TRANSACTIONAL Indicators (default if no REFLECTIVE triggers)

**Factual queries:**
- "What is...", "When did...", "Where is...", "Who is..."
- "How do I [technical task]..."
- "Explain [concept]..."
- "Define [term]..."

**Brief observations:**
- "Had a good [activity] today"
- "The [thing] is [adjective]"
- "[Event] went well"
- Short status updates (<20 words, no emotional language)

**Task-oriented requests:**
- "Remind me..."
- "Add [item] to..."
- "Set a timer..."
- "Calculate..."
- "Convert..."

**Short utterances with no emotional content:**
- <20 words
- No emotion words
- No personal struggle language
- Factual or observational tone

---

## Response Format

You must respond with ONLY a JSON object. No markdown formatting, no explanation, no preamble.

```json
{
  "depth": "transactional" | "reflective",
  "confidence": 0.0-1.0,
  "triggers": ["trigger1", "trigger2"]
}
```

**Fields:**
- `depth`: Either "transactional" or "reflective"
- `confidence`: 0.0 to 1.0 (how certain you are)
- `triggers`: Array of specific phrases/patterns that led to classification (empty array if transactional by default)

---

## Decision Logic

1. Scan input for ANY reflective triggers
2. If triggers found → classify as REFLECTIVE with confidence based on number/strength of triggers
3. If no triggers → classify as TRANSACTIONAL (default)
4. When uncertain → default to REFLECTIVE (better to over-engage than under-engage)

---

## Example Classifications

### REFLECTIVE Examples

**Input:** "I need to process what happened at work today"
```json
{
  "depth": "reflective",
  "confidence": 0.95,
  "triggers": ["I need to process"]
}
```

**Input:** "I'm struggling with whether to take this new job offer"
```json
{
  "depth": "reflective",
  "confidence": 0.98,
  "triggers": ["I'm struggling with", "decision support"]
}
```

**Input:** "Help me think through this conversation I need to have with my dad"
```json
{
  "depth": "reflective",
  "confidence": 0.92,
  "triggers": ["Help me think through", "relationship exploration"]
}
```

**Input:** "I'm feeling really anxious about tomorrow's presentation and I don't know why"
```json
{
  "depth": "reflective",
  "confidence": 0.96,
  "triggers": ["I'm feeling [emotion]", "I don't know why I", "emotional state"]
}
```

**Input:** "Why do I always do this to myself?"
```json
{
  "depth": "reflective",
  "confidence": 0.90,
  "triggers": ["Why do I", "self-reflective question"]
}
```

### TRANSACTIONAL Examples

**Input:** "What time is it?"
```json
{
  "depth": "transactional",
  "confidence": 1.0,
  "triggers": []
}
```

**Input:** "Had a good lunch today"
```json
{
  "depth": "transactional",
  "confidence": 0.95,
  "triggers": []
}
```

**Input:** "How do I center a div in CSS?"
```json
{
  "depth": "transactional",
  "confidence": 0.98,
  "triggers": []
}
```

**Input:** "What's 15% of 240?"
```json
{
  "depth": "transactional",
  "confidence": 1.0,
  "triggers": []
}
```

**Input:** "Remind me about my meeting tomorrow"
```json
{
  "depth": "transactional",
  "confidence": 0.97,
  "triggers": []
}
```

### Edge Cases

**Input:** "I'm excited about the new project starting Monday"
```json
{
  "depth": "reflective",
  "confidence": 0.70,
  "triggers": ["I'm feeling [emotion]"]
}
```
*Note: Contains emotion word but low intensity - confidence reflects uncertainty*

**Input:** "How should I approach this React component?"
```json
{
  "depth": "transactional",
  "confidence": 0.85,
  "triggers": []
}
```
*Note: "How should I" but clearly technical context - no personal struggle*

**Input:** "Can we talk about my goals for next quarter?"
```json
{
  "depth": "reflective",
  "confidence": 0.80,
  "triggers": ["Can we talk about"]
}
```
*Note: Trigger phrase detected, but could be simple planning - moderate confidence*

---

## Integration Notes

### For Voice Mode (Wispr Flow)
After transcript is received:
1. Run classification
2. If TRANSACTIONAL → Use Jarvis response path (fast, 50-100 words)
3. If REFLECTIVE → Use Samantha response path (deep, 150-200 words)

### For Text Chat
After message is received:
1. Run classification
2. If TRANSACTIONAL → Skip semantic memory search, minimal context prompt
3. If REFLECTIVE → Full semantic memory retrieval, phase-aware context

### Confidence Thresholds
- **≥0.80 confidence TRANSACTIONAL** → Use fast path
- **<0.80 confidence OR REFLECTIVE** → Use deep path
- When in doubt, err toward reflective engagement

### Performance
- Classification call: ~150-200 tokens total
- Use fastest/cheapest model (GPT-4o-mini, Claude Haiku)
- Cost per classification: ~$0.00002
- Latency: <500ms

---

## Prompt to Send to LLM

```
You are an intent depth classifier. Analyze the user's input and determine if it requires transactional (quick, factual) or reflective (deep, emotionally engaged) response.

REFLECTIVE triggers include:
- Processing language: "I need to process/think through/work through"
- Emotional struggle: "I'm struggling with", "I'm worried about", "Something's been bothering me"
- Emotional states: "I'm feeling [emotion]", high emotion word density
- Decision support: "Should I", "What do you think about [personal matter]"
- Self-reflection: "Why do I", "Am I being", "What does it mean that I"
- Relationship/identity: Questions about relationships, purpose, meaning, values
- Uncertainty about self: "I don't understand why I", "I can't figure out"

TRANSACTIONAL is the default for:
- Factual queries, technical questions, brief observations
- Task requests, calculations, definitions
- Short utterances (<20 words) with no emotional content

When uncertain, default to REFLECTIVE.

User input: "{user_input}"

Respond with ONLY this JSON format (no markdown, no explanation):
{"depth": "transactional" | "reflective", "confidence": 0.0-1.0, "triggers": ["trigger1", "trigger2"]}
```

---

## Version History
- v1.0 (2026-01-19): Initial unified classifier combining voice depth detection and text query classification
