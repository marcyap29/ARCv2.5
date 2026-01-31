# VEIL-CHRONICLE Integration Summary

**Date:** January 2025  
Status:** ✅ Complete

---

## Overview

CHRONICLE synthesis has been unified with the VEIL narrative integration cycle. CHRONICLE is no longer a separate system - it IS the automated implementation of the VEIL cycle stages.

---

## Conceptual Alignment

### VEIL Stages → CHRONICLE Layers

| VEIL Stage | Cognitive Function | CHRONICLE Layer | Implementation |
|------------|-------------------|-----------------|----------------|
| **Verbalize** | Immediate capture of experience | Layer 0 (Raw Entries) | ✅ Journal entry creation |
| **Examine** | Pattern recognition across recent events | Layer 1 (Monthly) | ✅ MonthlySynthesizer |
| **Integrate** | Synthesis into coherent narrative | Layer 2 (Yearly) | ✅ YearlySynthesizer |
| **Link** | Cross-temporal biographical connections | Layer 3 (Multi-Year) | ✅ MultiYearSynthesizer |

---

## New Components

### 1. VeilChronicleScheduler (`lib/echo/rhythms/veil_chronicle_scheduler.dart`)

**Purpose**: Unified scheduler that runs both:
- VEIL maintenance tasks (archives, cache, PRISM, RIVET)
- CHRONICLE narrative integration (VEIL cycle stages)

**Key Methods**:
- `start(userId, tier)` - Start unified nightly cycle
- `runNightlyCycle(userId, tier)` - Execute complete cycle
- `getNextCycleTime()` - Get next scheduled time

**Usage**:
```dart
final scheduler = await VeilChronicleFactory.createAndStart(
  userId: userId,
  tier: SynthesisTier.premium,
);
```

### 2. ChronicleNarrativeIntegration (`lib/chronicle/integration/chronicle_narrative_integration.dart`)

**Purpose**: Wraps SynthesisEngine and frames synthesis as VEIL stages.

**Key Methods**:
- `runVeilCycle(userId, tier)` - Execute VEIL stages based on tier
- `_examineRecentPatterns()` - EXAMINE stage (monthly)
- `_integrateIntoNarrative()` - INTEGRATE stage (yearly)
- `_linkAcrossYears()` - LINK stage (multi-year)

### 3. VeilStage Models (`lib/chronicle/integration/veil_stage_models.dart`)

**Enums & Classes**:
- `VeilStage` - Enum for VEIL stages
- `VeilCycleResult` - Result from running VEIL cycle
- `StageResult` - Result from single stage
- `VeilCycleStatus` - Status for UI display

### 4. VeilChronicleFactory (`lib/chronicle/integration/veil_chronicle_factory.dart`)

**Purpose**: Factory for easy initialization of unified scheduler.

**Usage**:
```dart
final scheduler = await VeilChronicleFactory.createAndStart(
  userId: userId,
  tier: SynthesisTier.premium,
);
```

---

## Updated Components

### 1. Synthesis Prompts

All synthesizers now include VEIL stage framing in their prompts:

**MonthlySynthesizer** (EXAMINE):
- Prompt explicitly references "EXAMINE stage of VEIL cycle"
- Explains role: pattern recognition, not summarization
- References next stages (INTEGRATE, LINK)

**YearlySynthesizer** (INTEGRATE):
- Prompt references "INTEGRATE stage"
- Explains role: creating coherent narrative from examinations
- References LINK stage

**MultiYearSynthesizer** (LINK):
- Prompt references "LINK stage"
- Explains role: biographical throughlines across years

### 2. Aggregation Markdown

All aggregations now include VEIL stage in frontmatter:

```yaml
---
type: monthly_aggregation
veil_stage: examine
...
---
```

Markdown content includes VEIL stage header:
```markdown
**VEIL Stage: EXAMINE**  
*Pattern recognition across 28 entries*
```

### 3. Changelog

Changelog entries now track VEIL stages:
```json
{
  "action": "veil_examine",
  "metadata": {
    "veil_stage": "examine",
    "summary": "Found 3 dominant themes in 2025-01"
  }
}
```

---

## Deprecation

### ChronicleBackgroundTasks

**Status**: `@Deprecated`

**Reason**: CHRONICLE synthesis is now part of VEIL nightly cycle, not a separate background task.

**Migration**:
```dart
// Old (deprecated)
final tasks = await ChronicleBackgroundTasksFactory.create(...);
tasks?.start();

// New (unified)
final scheduler = await VeilChronicleFactory.createAndStart(...);
```

---

## Integration Flow

### Nightly Cycle

```
Midnight Trigger
  ↓
VeilChronicleScheduler.runNightlyCycle()
  ↓
┌─────────────────────────────────────┐
│ Part 1: System Maintenance           │
│ - Archive rotation                   │
│ - Cache cleanup                      │
│ - PRISM integration                  │
│ - RIVET snapshots                    │
│ - Keyword cleanup                    │
│ - Phase analysis                     │
└─────────────────────────────────────┘
  ↓
┌─────────────────────────────────────┐
│ Part 2: Narrative Integration        │
│ (CHRONICLE as VEIL cycle)            │
│                                      │
│ ChronicleNarrativeIntegration        │
│   .runVeilCycle()                    │
│     ├─ EXAMINE (monthly)             │
│     ├─ INTEGRATE (yearly)            │
│     └─ LINK (multi-year)             │
└─────────────────────────────────────┘
  ↓
VeilNightlyReport
```

---

## User-Facing Changes

### Before
- "CHRONICLE synthesis runs in background"
- "Synthesis status: Monthly complete"
- Separate concepts: VEIL (maintenance) + CHRONICLE (synthesis)

### After
- "LUMARA performs VEIL cycle nightly"
- "Last EXAMINE: Yesterday (3 themes found)"
- "Last INTEGRATE: 3 days ago (Q1 narrative updated)"
- Unified concept: VEIL cycle (maintenance + narrative integration)

---

## Benefits

1. **Theoretical Coherence**: CHRONICLE = automated VEIL cycle (not separate system)
2. **User Understanding**: Single conceptual model ("VEIL cycle")
3. **Code Simplification**: One scheduler instead of two
4. **Marketing Alignment**: "LUMARA runs VEIL nightly" connects paper → product
5. **Differentiation**: "Narrative integration" sounds richer than "memory synthesis"

---

## Migration Checklist

- [x] Create VeilChronicleScheduler
- [x] Create ChronicleNarrativeIntegration
- [x] Create VeilStage models
- [x] Update synthesis prompts with VEIL framing
- [x] Add VEIL stage to aggregation frontmatter
- [x] Update changelog to track VEIL stages
- [x] Deprecate ChronicleBackgroundTasks
- [x] Create VeilChronicleFactory
- [ ] Update app initialization
- [ ] Create VEIL status dashboard UI
- [ ] Update user-facing documentation

---

## Next Steps

1. **App Initialization**: Update app startup to use VeilChronicleScheduler
2. **UI Components**: Create VEIL status dashboard
3. **Documentation**: Update user docs to explain VEIL cycle
4. **Testing**: Integration tests for unified scheduler

---

**Implementation Complete** ✅  
**Ready for Integration Testing**
