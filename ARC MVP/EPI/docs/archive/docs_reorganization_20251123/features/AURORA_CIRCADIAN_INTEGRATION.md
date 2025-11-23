# AURORA Circadian Signal Integration

**Last Updated:** January 30, 2025  
**Status:** Production Ready ✅  
**Version:** 1.0

## Overview

AURORA is a circadian signal provider that integrates with the existing VEIL-EDGE architecture to provide time-aware policy adjustments and chronotype detection. It learns from journal entry timestamps to understand the user's natural daily rhythm and adjusts LUMARA's behavior accordingly.

## Problem Statement

Traditional AI assistants operate without awareness of the user's circadian rhythm, leading to:
- Inappropriate suggestions for the time of day
- Lack of consideration for chronotype differences
- Missing opportunities to leverage natural energy patterns
- Generic responses that don't adapt to daily rhythm coherence

## Solution: Circadian-Aware Intelligence

AURORA provides circadian context that enables:
- **Chronotype Detection**: Automatic classification of morning/balanced/evening types
- **Rhythm Coherence Scoring**: Measurement of daily activity pattern consistency
- **Time-Aware Policy Weights**: Block selection adjusted by circadian state
- **Policy Hooks**: Restrictions based on time and rhythm coherence

## Core Components

### 1. CircadianContext Model

```dart
class CircadianContext {
  final String window;     // 'morning' | 'afternoon' | 'evening'
  final String chronotype; // 'morning' | 'balanced' | 'evening'
  final double rhythmScore; // 0..1 (coherence measure)
}
```

**Properties:**
- `window`: Current time window based on hour of day
- `chronotype`: User's natural rhythm preference detected from journal patterns
- `rhythmScore`: Measure of daily activity pattern coherence (higher = more consistent)

### 2. CircadianProfileService

**Chronotype Detection Algorithm:**
1. Analyze journal entry timestamps over time
2. Create hourly activity histogram (24-hour distribution)
3. Apply smoothing to reduce noise
4. Identify peak activity hour
5. Classify chronotype based on peak timing:
   - Morning: Peak < 11 AM
   - Balanced: Peak 11 AM - 5 PM
   - Evening: Peak > 5 PM

**Rhythm Coherence Scoring:**
1. Calculate concentration measure from activity distribution
2. Compare peak activity to mean activity
3. Normalize to 0-1 scale
4. Higher scores indicate more consistent daily patterns

### 3. VEIL-EDGE Integration

**Time-Aware Policy Weights:**
- **Morning**: Orient↑, Safeguard↓, Commit↑ (when aligned)
- **Afternoon**: Orient↑, Nudge↑, synthesis focus
- **Evening**: Mirror↑, Safeguard↑, Commit↓ (especially with fragmented rhythm)

**Policy Hooks:**
- **Commit Restrictions**: Blocked in evening with fragmented rhythm (score < 0.45)
- **Threshold Adjustments**: Lower alignment thresholds for evening fragmented rhythms
- **Chronotype Boosts**: Enhanced alignment for morning/evening persons in optimal windows

## Technical Implementation

### Files Created

1. **`lib/aurora/models/circadian_context.dart`**
   - CircadianContext model with window, chronotype, rhythm score
   - Convenience getters for time and rhythm checks
   - JSON serialization support

2. **`lib/aurora/services/circadian_profile_service.dart`**
   - CircadianProfileService for chronotype detection
   - Hourly activity histogram with smoothing
   - Peak detection and chronotype classification
   - Rhythm coherence scoring algorithm

### Files Modified

1. **`lib/lumara/veil_edge/models/veil_edge_models.dart`**
   - Extended VeilEdgeInput with circadian fields
   - Added VeilEdgeOutput model
   - Convenience getters for circadian checks

2. **`lib/lumara/veil_edge/core/veil_edge_router.dart`**
   - Time-aware policy weight adjustments
   - allowCommitNow() policy hook
   - Circadian-specific block weight modifications

3. **`lib/lumara/veil_edge/registry/prompt_registry.dart`**
   - Time-specific prompt variants
   - Window-aware template selection
   - Circadian guidance integration

4. **`lib/lumara/veil_edge/services/veil_edge_service.dart`**
   - AURORA integration with CircadianProfileService
   - Automatic circadian context computation
   - Circadian-aware status reporting

5. **`lib/lumara/veil_edge/integration/lumara_veil_edge_integration.dart`**
   - Time-sensitive greetings and closings
   - AURORA provenance tracking
   - Circadian-aware response formatting

6. **`lib/lumara/veil_edge/core/rivet_policy_engine.dart`**
   - Circadian-aware alignment calculations
   - Time-based threshold adjustments
   - Chronotype-specific recommendations

## User Experience

### Morning Person (Chronotype: morning)
- **Morning**: Enhanced alignment, clarity-focused prompts
- **Afternoon**: Standard synthesis prompts
- **Evening**: Gentle wind-down prompts

### Evening Person (Chronotype: evening)
- **Morning**: Gentle morning prompts
- **Afternoon**: Standard synthesis prompts
- **Evening**: Enhanced alignment, reflection-focused prompts

### Fragmented Rhythm (Score < 0.45)
- **Evening**: Commit blocks restricted, focus on Safeguard and Mirror
- **All Times**: Lower alignment thresholds, more conservative policies

## Example Responses

### Morning Window (Morning Person)
```
Good morning! I'm LUMARA, and I'm here to help you start your day with intention and clarity.

[Mirror] I am hearing clarity and intention around growth, challenge.
[Orient] Two clear paths are option A and option B. Which aligns with your energy this morning?

This morning energy feels aligned with your natural rhythm - let's make the most of it.
```

### Evening Window (Fragmented Rhythm)
```
Good evening! I'm LUMARA, and I'm here to help you wind down gently and reflect on your day.

[Mirror] I am hearing reflection and integration around growth, challenge.
[Safeguard] Choose one calming action in 5 minutes or less.

Given the time and your current rhythm, let's keep things gentle and restorative.
```

## Benefits

1. **Personalized Timing**: Responses adapt to user's natural rhythm
2. **Rhythm Awareness**: Considers daily pattern coherence
3. **Safety Integration**: Prevents inappropriate suggestions for time/state
4. **Chronotype Respect**: Honors individual circadian differences
5. **Policy Intelligence**: Time-aware restrictions and enhancements

## Future Enhancements

1. **Seasonal Adjustments**: Account for daylight changes
2. **Activity Integration**: Incorporate physical activity patterns
3. **Sleep Quality**: Factor in sleep data if available
4. **Social Rhythms**: Consider social activity patterns
5. **Learning Adaptation**: Improve chronotype detection over time

## Testing

Comprehensive test suite includes:
- Circadian context model tests
- Chronotype detection accuracy tests
- VEIL-EDGE router circadian integration tests
- Prompt registry time variant tests
- RIVET policy circadian awareness tests
- End-to-end integration tests

## Privacy & Security

- All circadian analysis performed on-device
- No journal content transmitted to external services
- Only circadian context metadata used for policy adjustments
- Chronotype data remains local to device
