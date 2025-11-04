# VEIL-EDGE Architecture Documentation

**Last Updated:** January 15, 2025  
**Status:** Production Ready ✅  
**Version:** 0.1

## Overview

VEIL-EDGE is a fast, cloud-orchestrated variant of VEIL that maintains restorative rhythm without on-device fine-tuning. It functions as a prompt-switching policy layer, routing user context through **ATLAS → RIVET → SENTINEL** to select one of four phase-pair playbooks.

> *"When power is limited, rhythm itself becomes the intelligence."*

## Core Philosophy

While VEIL governs deep nightly restoration cycles, VEIL-EDGE acts as the reflexive complement: a light, real-time equilibrium layer that adjusts prompts, tone, and behavioral scaffolding moment by moment. Because only inference requests are transmitted—and even those are filtered through the ARC *Echo* layer—no raw journal or phase data ever leaves the device.

Within ARC, VEIL-EDGE serves as the adaptive *prompt conscience* that mirrors VEIL's restorative intent for computationally constrained environments.

## System Architecture

### Input Pipeline

```
User Signals → ATLAS → RIVET → SENTINEL → AURORA → Phase Group Selection → Prompt Generation → LUMARA Response
```

### AURORA Integration (January 30, 2025)

VEIL-EDGE now integrates with AURORA for circadian-aware policy adjustments:

#### **Circadian Context** (`CircadianContext`)
- **Window**: morning | afternoon | evening (current time window)
- **Chronotype**: morning | balanced | evening (user's natural rhythm)
- **Rhythm Score**: 0.0 to 1.0 (daily activity pattern coherence)

#### **Time-Aware Policy Weights**
- **Morning**: Orient↑, Safeguard↓, Commit↑ (when aligned)
- **Afternoon**: Orient↑, Nudge↑, synthesis focus
- **Evening**: Mirror↑, Safeguard↑, Commit↓ (especially with fragmented rhythm)

#### **Policy Hooks**
- **Commit Restrictions**: Blocked in evening with fragmented rhythm (score < 0.45)
- **Threshold Adjustments**: Lower alignment thresholds for evening fragmented rhythms
- **Chronotype Boosts**: Enhanced alignment for morning/evening persons in their optimal windows

### Core Components

#### 1. **ATLAS State** (`AtlasState`)
- **Phase**: Discovery | Transition | Recovery | Consolidation | Breakthrough
- **Confidence**: 0.0 to 1.0 (phase detection confidence)
- **Neighbor**: Adjacent phase for blending when confidence < 0.60

#### 2. **SENTINEL State** (`SentinelState`)
- **State**: ok | watch | alert
- **Notes**: Safety monitoring annotations
- **Modifiers**:
  - `watch` → safe variants, 10-minute session cap
  - `alert` → Safeguard + Mirror blocks only, no phase changes

#### 3. **RIVET State** (`RivetState`)
- **Align**: 0.0 to 1.0 (alignment score)
- **Stability**: 0.0 to 1.0 (stability trend)
- **Window Days**: 7 (rolling window size)
- **Last Switch**: Timestamp for cooldown tracking

#### 4. **User Signals** (`UserSignals`)
- **Actions**: Extracted verbs from user input
- **Feelings**: Emotion words detected
- **Words**: All words for context
- **Outcomes**: Recent outcomes from context

## Phase Groups

### 1. **D-B (Discovery ↔ Breakthrough)**
- **System**: "You are LUMARA in Exploration mode. Expand options, then converge on one tractable experiment."
- **Style**: Upbeat, concrete, time-boxed
- **Blocks**: Mirror, Orient, Nudge, Commit, Log
- **Use Case**: Creative exploration, breakthrough moments

### 2. **T-D (Transition ↔ Discovery)**
- **System**: "You are LUMARA in Bridge mode. Normalize uncertainty; preserve optionality."
- **Style**: Gentle, exploratory, non-committal
- **Blocks**: Mirror, Orient, Safeguard, Nudge, Log
- **Use Case**: Navigating uncertainty, maintaining options

### 3. **R-T (Recovery ↔ Transition)**
- **System**: "You are LUMARA in Restore mode. Prioritize body-first restoration."
- **Style**: Compassionate, grounding, restorative
- **Blocks**: Mirror, Safeguard, Nudge, Commit, Log
- **Use Case**: Recovery periods, self-care focus

### 4. **C-R (Consolidation ↔ Recovery)**
- **System**: "You are LUMARA in Consolidate mode. Lock gains and document playbooks."
- **Style**: Methodical, reflective, systematic
- **Blocks**: Mirror, Orient, Nudge, Commit, Log
- **Use Case**: Systematizing practices, creating routines

## Routing Logic

### Phase Group Selection

1. **Base Mapping**: Phase → Phase Group
   - Discovery/Breakthrough → D-B
   - Transition → T-D
   - Recovery → R-T
   - Consolidation → C-R

2. **Confidence Blending**: If confidence < 0.60, blend with neighbor's group

3. **Hysteresis Check**: Requires stability ≥ 0.55 AND 48-hour cooldown before switching

4. **SENTINEL Modifiers**:
   - `watch` → use safe variants, cap session ≤ 10 min
   - `alert` → Safeguard + Mirror blocks only, no Commit, phase changes locked

### RIVET Policy

Every turn ends with a `Log` payload. Phase change requires both:
1. Mean `align` ≥ 0.62 over 3 logs
2. Non-negative `stability` trend over 7 days

If `align` < 0.45 for two consecutive logs, the next turn forces a safe variant.

## API Contract

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/veil-edge/route` | POST | Input {signals, atlas, sentinel, rivet} → Output {phase_group, variant, blocks[]} |
| `/veil-edge/log` | POST | Accepts LogSchema → {ack, rivet_updates} |
| `/veil-edge/registry?version=0.1` | GET | Retrieve prompt registry |
| `/veil-edge/status` | GET | Service diagnostics |

### Configuration Thresholds

- `atlas.confidence_low = 0.60`
- `rivet.stability_min = 0.55`
- `rivet.align_ok = 0.62`
- `rivet.align_low = 0.45`
- `cooldown = 48 hours`
- `sentinel.watch`: safe mode + 10 min cap
- `sentinel.alert`: Safeguard + Mirror only, no phase change

## Implementation Details

### File Structure

```
lib/lumara/veil_edge/
├── models/
│   └── veil_edge_models.dart          # Core data models
├── core/
│   ├── veil_edge_router.dart          # Phase group routing logic
│   └── rivet_policy_engine.dart       # RIVET policy implementation
├── registry/
│   └── prompt_registry.dart           # Prompt families and templates
├── services/
│   └── veil_edge_service.dart         # Main orchestration service
├── integration/
│   └── lumara_veil_edge_integration.dart  # LUMARA chat integration
└── veil_edge.dart                     # Barrel export file
```

### Key Classes

#### `VeilEdgeRouter`
- Implements phase group selection algorithm
- Handles confidence-based blending
- Applies hysteresis and cooldown logic
- Manages SENTINEL safety modifiers

#### `RivetPolicyEngine`
- Tracks alignment and stability over time
- Validates phase change conditions
- Generates policy recommendations
- Manages log history and cleanup

#### `VeilEdgePromptRegistry`
- Contains all phase family definitions
- Provides prompt rendering with variable substitution
- Supports JSON serialization/deserialization
- Version management (currently v0.1)

#### `LumaraVeilEdgeIntegration`
- Integrates with existing LUMARA chat system
- Extracts signals from user messages
- Generates LUMARA responses using VEIL-EDGE prompts
- Handles fallback scenarios

## Operational Walkthrough

1. **Collect Signals** → derive ATLAS, SENTINEL, RIVET summaries
2. **Call `/veil-edge/route`** → receive {group, variant, blocks}
3. **Render Blocks** → into LLM prompt using registry
4. **After Response** → POST `LogSchema` to RIVET
5. **RIVET Updates** → alignment and stability; ATLAS shifts phase only when thresholds met

## Safety Considerations

- **Avoid Phase Thrash**: Respect cooldowns and stability requirements
- **Always Emit Log**: Every session must end with a Log block
- **SENTINEL Alert**: Suppresses commit blocks for safety
- **Keep Registry Light**: Never send raw journals to LLM
- **Privacy First**: Only inference requests transmitted, no raw data

## Performance Characteristics

- **Stateless Between Turns**: Only rolling windows maintained in RIVET
- **Fast Routing**: Sub-second phase group selection
- **Memory Efficient**: Automatic cleanup of old log history
- **Edge Compatible**: Designed for iPhone-class devices
- **Cloud Orchestrated**: No on-device fine-tuning required

## Integration Points

### LUMARA Chat System
- Seamless integration with existing chat models
- Signal extraction from user messages
- Context-aware phase detection
- Fallback message handling

### ARC Echo Layer
- All inference requests filtered through Echo
- Privacy-preserving prompt generation
- Dignified text output
- No raw journal data exposure

### MIRA System
- Phase detection integration
- Confidence scoring
- Neighbor phase identification
- Context object building

## Future Compatibility

VEIL-EDGE is designed to be forward-compatible with VEIL v0.1+, allowing seamless migration to adapter-based tuning when hardware permits. The prompt registry system supports versioning, and the API contract is designed for extensibility.

## Summary

VEIL-EDGE extends the restorative rhythm of VEIL into low-power and privacy-bound environments. It reacts within seconds, using prompts instead of parameter updates. The design is forward-compatible with VEIL v0.1+, allowing seamless migration to adapter-based tuning when hardware permits.

Within ARC, VEIL-EDGE serves as the *reflexive bridge*—a real-time, Echo-filtered rhythm that lets the system breathe, balance, and renew even under computational constraint.

---

**Related Documentation:**
- [EPI Architecture](./EPI_Architecture.md) - Complete 8-module system
- [MIRA Basics](./MIRA_Basics.md) - Phase detection and quick answers
- [LUMARA Integration Guide](../guides/LUMARA_Integration_Guide.md) - Chat system integration
