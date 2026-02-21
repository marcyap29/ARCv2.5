// lib/core/prompts_phase_classification.dart
// Combined RIVET + SENTINEL Phase Classification Prompt
// This prompt is used by cloud APIs for phase detection with integrated wellbeing monitoring

class PhaseClassificationPrompts {
  /// Combined RIVET + SENTINEL Phase Classification Prompt
  /// Returns probability distributions across six phases plus SENTINEL signals
  static const String systemPrompt = r'''
You are a phase classifier for a developmental tracking system. Analyze journal entries and return probability distributions across six psychological phases, plus signals for wellbeing monitoring.

## The Six Phases

**Recovery**: Emotional exhaustion, protective withdrawal, need for rest and healing. Low energy, negative valence. Past-focused reflection on what drained them. Language of depletion, overwhelm, needing space.

**Transition**: Identity questioning, environmental shifts, liminal uncertainty. Variable energy, mixed valence. Present-focused but unsettled. Language of change, leaving, moving between, not knowing, becoming.

**Breakthrough**: Genuine perspective shift or reframe with integration. NOT just insight words like "realized" or "aha" - requires evidence of before/after thinking AND connecting dots/pattern recognition. Meta-cognitive clarity that explains why things are the way they are.

**Discovery**: Active exploration, openness to new experiences, energized curiosity. High energy, positive valence. Future-oriented toward possibilities. Language of wonder, learning, trying, exploring, beginnings.

**Expansion**: Confidence building, capacity growth, forward momentum. High energy, positive valence. Future-focused on growth. Language of scaling, reaching, building, growing, amplifying capability.

**Consolidation**: Integration work, pattern recognition, grounding new identity into habits. Moderate energy, stable valence. Present-focused on stability. Language of weaving together, organizing, establishing routine, making permanent.

## CRITICAL: Breakthrough Dominance Rule

Do NOT assign Breakthrough as the top phase just because the entry contains words like "realized", "insight", "clarity", or "aha".

Breakthrough should only dominate when there is BOTH:
1. A genuine perspective shift or reframe (before/after thinking)
2. Integration of meaning (connecting dots, "this explains why...", "now I see...")

If insight language appears without reframe+integration, allocate Breakthrough as a secondary probability (0.1-0.3), not the primary phase.

**Examples that are NOT Breakthrough-dominant:**
- "I realized I need to exercise more" → Discovery or Expansion
- "Had a great insight about my project today" → Discovery
- "Finally figured out the bug" → Discovery or Consolidation

**Examples that ARE Breakthrough-dominant:**
- "I just realized my perfectionism isn't about quality, it's about fear of judgment" → Breakthrough
- "Suddenly understood why all my relationships follow this pattern" → Breakthrough
- "The pieces clicked - this connects everything I've been struggling with" → Breakthrough

## SENTINEL Integration: Wellbeing Signals

In addition to phase classification, detect signals for wellbeing monitoring:

### Critical Language Detection
Check for self-harm or crisis language:
- **Direct self-harm:** `kill myself`, `end my life`, `want to die`, `suicide`, `not worth living`, `better off dead`, `can't go on`, `end it all`, `no way out`, `no reason to live`
- **Hopelessness cascade:** BOTH hopelessness (`hopeless`, `no point`, `pointless`, `meaningless`, `giving up`) AND duration language (`always`, `never going to`, `can't ever`, `will never`)

### Isolation Markers
Check for social withdrawal language:
- `alone`, `lonely`, `isolated`, `abandoned`, `rejected`, `unwanted`, `hiding`, `avoiding`, `withdrawn`, `disconnected`, `can't talk to anyone`, `no one understands`, `cut off`, `invisible`

### Relief Markers
Check for improvement/positive movement language:
- `better`, `improving`, `helped`, `relief`, `calmer`, `hope`, `hopeful`, `progress`, `lighter`, `clearer`, `breakthrough` (when genuine), `understanding`, `connecting`, `supported`

### Emotional Amplitude
Assess the emotional intensity of the entry on a 0.0-1.0 scale:
- **0.9-1.0:** Extreme intensity (ecstatic, devastated, furious, terrified, panicked, shattered, despair)
- **0.7-0.8:** High intensity (overwhelmed, miserable, anxious, depressed, angry, joyful, excited)
- **0.5-0.6:** Moderate intensity (happy, sad, worried, grateful, frustrated, tired)
- **0.3-0.4:** Low intensity (calm, content, fine, okay, neutral)
- **0.0-0.2:** Minimal emotional signal

## Output Format

Return ONLY a valid JSON object:

```json
{
  "recovery": 0.0,
  "transition": 0.0,
  "breakthrough": 0.0,
  "discovery": 0.0,
  "expansion": 0.0,
  "consolidation": 0.0,
  "confidence": 0.85,
  "reasoning": "Brief explanation of primary signals",
  "status": "ok",
  "user_message": "",
  "sentinel": {
    "critical_language": false,
    "isolation_markers": [],
    "relief_markers": [],
    "amplitude": 0.65
  }
}
```

## Validation Rules

**Probabilities:**
- All phase values must be numbers between 0.0 and 1.0
- Must sum to EXACTLY 1.0 (tolerance ±0.001)
- All six phases must be present

**Calibration constraints:**
- If confidence ≥ 0.75: top phase should be ≥ 0.55 and exceed runner-up by ≥ 0.20
- If confidence ≤ 0.40: distribution should be spread (top phase usually ≤ 0.40)
- If confidence is high but probabilities are flat, reduce confidence
- If probabilities are decisive but confidence is low, increase confidence

**Status:**
- `"ok"` if confidence > 0.40 and clear signals detected
- `"uncertain"` if confidence ≤ 0.40 or signals are weak

**User message:**
- Empty string `""` if status is "ok"
- `"Saved. I'm not sure which phase this fits yet. I'll re-check as you write more."` if status is "uncertain"

**SENTINEL signals:**
- `critical_language`: boolean - true if self-harm or hopelessness cascade detected
- `isolation_markers`: array of strings - specific isolation keywords found
- `relief_markers`: array of strings - specific relief keywords found
- `amplitude`: number between 0.0 and 1.0 - emotional intensity

**Other:**
- Confidence must be between 0.0 and 1.0
- Reasoning must be a non-empty string under 240 characters
- Response must be valid JSON only - no markdown, no explanatory text
''';

  /// User prompt template for phase classification
  static String getUserPrompt(String entryText) => '''
Now classify this entry:
$entryText
''';

  /// SENTINEL Response Integration - How SENTINEL uses classification output
  static const String sentinelIntegrationPrompt = r'''
## How SENTINEL Uses the Classification Output

When SENTINEL receives a classified entry, it performs the following analysis:

### 1. CRITICAL LANGUAGE - Immediate alert, bypass all other analysis
If `sentinel.critical_language` is true, return CRITICAL alert immediately.

### 2. AMPLITUDE SPIKE - Compare to user's baseline
Check if current amplitude exceeds user's P80 + 2*stdDev threshold.
If sustained (2+ entries in 72 hours), return HIGH alert.
If single extreme spike (3+ stdDev), return ELEVATED alert.

### 3. ISOLATION CASCADE - Check for accelerating pattern
Group entries by week and count isolation markers.
If isolation markers are accelerating week over week and current week >= 3 markers, return ELEVATED alert.

### 4. PATTERN COLLAPSE - Check for sudden silence after distress
If days since last entry > median cadence * 5 AND last entry was high amplitude, return HIGH alert.
If days since last entry > median cadence * 3 AND last entry was high amplitude, return ELEVATED alert.

### 5. PERSISTENT DISTRESS - Check for sustained high amplitude
Count consecutive days with high amplitude and no relief markers.
If >= 14 consecutive days, return HIGH alert.
If >= 7 consecutive days, return ELEVATED alert.
''';

  /// LUMARA Crisis Response Templates
  static const Map<String, String> crisisResponses = {
    'critical': '''
I need to pause here. What you just wrote concerns me deeply.

If you're having thoughts of harming yourself, please reach out right now:

• Call 988 (Suicide & Crisis Lifeline) - available 24/7
• Text "HELLO" to 741741 (Crisis Text Line)
• Go to your nearest emergency room

I'm here to listen, but I'm not equipped to help in a crisis. Your safety matters more than anything we're discussing.

Are you safe right now?
''',
    'high_isolation': '''
I need to say something. Over the past two weeks, I've noticed you describing feeling increasingly isolated and overwhelmed. The intensity of what you're experiencing seems to be building.

I don't want to overstep, but I care about you. Have you talked to anyone else about this? A friend, family member, therapist?

I'm here to listen, but I think you might benefit from support beyond what I can offer.
''',
    'high_persistent': '''
You've been carrying something heavy for two weeks now. I see you trying to process it through writing, but the weight doesn't seem to be lifting.

Sometimes when we're stuck in it this long, it helps to bring someone else into the picture - someone who can see what we can't.

What would it take for you to reach out to a therapist or counselor?
''',
    'high_collapse': '''
Hey - I haven't heard from you in a while, and your last entry had me worried.

I know sometimes silence is just needing space, but I wanted to check in. How are you doing?

If you're not okay, please talk to someone. I'm here, but a real person who knows you would be better.
''',
    'elevated_isolation': '''
I'm noticing you've mentioned feeling alone a few times recently. I wonder if that's been harder than usual, or if I'm reading too much into it?

What's your connection to people like right now?
''',
    'elevated_persistent': '''
You've been in a really difficult stretch this week. Sometimes when we're in the middle of it, it's hard to see if we're moving through it or getting stuck in it.

How do you know when you need help vs when you just need time?
''',
    'elevated_spike': '''
That last entry felt really intense. I'm here if you want to talk about it more, or if you just needed to get it out.

How are you feeling now?
''',
    'elevated_collapse': '''
It's been a little while since you wrote - longer than usual. No pressure to respond, but I wanted to say I'm here when you're ready.
''',
  };

  /// Few-shot examples for phase classification
  static const List<Map<String, dynamic>> fewShotExamples = [
    // Example 1: Recovery (High Confidence)
    {
      'entry': "I'm so fucking tired. Need to just stop for a bit.",
      'output': {
        'recovery': 0.9,
        'transition': 0.1,
        'breakthrough': 0.0,
        'discovery': 0.0,
        'expansion': 0.0,
        'consolidation': 0.0,
        'confidence': 0.95,
        'reasoning': 'Explicit exhaustion, protective withdrawal, need for rest',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': [],
          'amplitude': 0.75,
        },
      },
    },
    // Example 2: Discovery with Breakthrough Signal
    {
      'entry': "Started learning Rust today. The ownership model is wild but I'm starting to see why it matters.",
      'output': {
        'recovery': 0.0,
        'transition': 0.0,
        'breakthrough': 0.2,
        'discovery': 0.7,
        'expansion': 0.1,
        'consolidation': 0.0,
        'confidence': 0.8,
        'reasoning': 'Active learning (discovery primary), beginning pattern recognition (breakthrough signal)',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': [],
          'amplitude': 0.55,
        },
      },
    },
    // Example 3: Breakthrough (Genuine Reframe)
    {
      'entry': "Holy shit. I just realized my anxiety about this promotion isn't about capability - it's about becoming visible. Every time I've advanced, I've sabotaged it to stay small.",
      'output': {
        'recovery': 0.0,
        'transition': 0.1,
        'breakthrough': 0.85,
        'discovery': 0.0,
        'expansion': 0.05,
        'consolidation': 0.0,
        'confidence': 0.95,
        'reasoning': 'Perspective reframe (anxiety recontextualized), pattern integration across history',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': ['understanding'],
          'amplitude': 0.8,
        },
      },
    },
    // Example 4: Insufficient Evidence
    {
      'entry': 'interesting',
      'output': {
        'recovery': 0.17,
        'transition': 0.17,
        'breakthrough': 0.16,
        'discovery': 0.17,
        'expansion': 0.17,
        'consolidation': 0.16,
        'confidence': 0.2,
        'reasoning': 'Insufficient evidence to determine phase',
        'status': 'uncertain',
        'user_message': "Saved. I'm not sure which phase this fits yet. I'll re-check as you write more.",
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': [],
          'amplitude': 0.1,
        },
      },
    },
    // Example 5: Consolidation (Integration Language)
    {
      'entry': "Been thinking about how all these pieces fit together. The morning routine, the boundaries I've set, the way I'm approaching work now - it's all starting to feel like *me* instead of things I'm trying.",
      'output': {
        'recovery': 0.0,
        'transition': 0.0,
        'breakthrough': 0.1,
        'discovery': 0.0,
        'expansion': 0.05,
        'consolidation': 0.85,
        'confidence': 0.9,
        'reasoning': 'Integration language, grounding new patterns into identity, automaticity',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': [],
          'amplitude': 0.5,
        },
      },
    },
    // Example 6: Not Breakthrough - Just Problem Solving
    {
      'entry': 'Finally figured out the algorithm. Took three days but got it working.',
      'output': {
        'recovery': 0.0,
        'transition': 0.0,
        'breakthrough': 0.1,
        'discovery': 0.3,
        'expansion': 0.5,
        'consolidation': 0.1,
        'confidence': 0.7,
        'reasoning': 'Problem solved (expansion), learning process (discovery), insight present but no reframe',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': [],
          'amplitude': 0.6,
        },
      },
    },
    // Example 7: SENTINEL Critical Language Detection
    {
      'entry': "I can't do this anymore. I just want it all to end. There's no point.",
      'output': {
        'recovery': 0.3,
        'transition': 0.2,
        'breakthrough': 0.0,
        'discovery': 0.0,
        'expansion': 0.0,
        'consolidation': 0.5,
        'confidence': 0.85,
        'reasoning': 'Extreme distress, hopelessness with duration language',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': true,
          'isolation_markers': [],
          'relief_markers': [],
          'amplitude': 0.95,
        },
      },
    },
    // Example 8: SENTINEL Isolation Pattern
    {
      'entry': "Spent the whole weekend alone. Can't bring myself to reach out to anyone. Feel completely disconnected from everyone.",
      'output': {
        'recovery': 0.6,
        'transition': 0.2,
        'breakthrough': 0.0,
        'discovery': 0.0,
        'expansion': 0.0,
        'consolidation': 0.2,
        'confidence': 0.75,
        'reasoning': 'Social withdrawal, need for rest but with isolation pattern',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': ['alone', 'disconnected'],
          'relief_markers': [],
          'amplitude': 0.7,
        },
      },
    },
    // Example 9: Mixed Signals with Relief Markers
    {
      'entry': "Still feeling overwhelmed but talked to Sarah today and it helped. Starting to see a path forward.",
      'output': {
        'recovery': 0.3,
        'transition': 0.3,
        'breakthrough': 0.1,
        'discovery': 0.2,
        'expansion': 0.1,
        'consolidation': 0.0,
        'confidence': 0.65,
        'reasoning': 'Mixed state - overwhelm present but movement toward clarity and support',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': ['helped', 'clearer'],
          'amplitude': 0.6,
        },
      },
    },
    // Example 10: Transition Phase
    {
      'entry': "I don't know who I am anymore. Everything feels like it's shifting. Nothing feels solid.",
      'output': {
        'recovery': 0.2,
        'transition': 0.7,
        'breakthrough': 0.0,
        'discovery': 0.1,
        'expansion': 0.0,
        'consolidation': 0.0,
        'confidence': 0.9,
        'reasoning': 'Identity uncertainty, liminal state, everything in flux - classic transition',
        'status': 'ok',
        'user_message': '',
        'sentinel': {
          'critical_language': false,
          'isolation_markers': [],
          'relief_markers': [],
          'amplitude': 0.75,
        },
      },
    },
  ];
}
