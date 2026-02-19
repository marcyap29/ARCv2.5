# CHRONICLE: Temporal Aggregation Memory Architecture

**CHRONICLE** = **C**hronological **R**ecall **O**ptimization via **N**ative **I**mitation of **C**onsolidated **L**ongitudinal **E**xperience.

This document describes the **user's CHRONICLE** (layers 0–3): the temporal aggregation memory that backs the user's timeline. **The user's CHRONICLE is SACRED.** It shall not be modified by LUMARA under any circumstances. LUMARA has its own CHRONICLE (same acronym) where it stores inferences, gaps, and gap-fill events; LUMARA reads from the user's CHRONICLE only.

**Version:** 2.0  
**Last Updated:** January 2025  
**Status:** ✅ Complete (Phases 1-5 + VEIL Integration)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [VEIL Integration](#veil-integration)
4. [Component Details](#component-details)
5. [Data Flow](#data-flow)
6. [Integration Points](#integration-points)
7. [File Structure](#file-structure)
8. [Usage Examples](#usage-examples)
9. [Configuration](#configuration)
10. [Testing](#testing)
11. [Future Enhancements](#future-enhancements)

---

## Executive Summary

CHRONICLE (the user's, as described here) is a temporal aggregation memory architecture that enables LUMARA to maintain longitudinal biographical intelligence by progressively consolidating journal entries into hierarchical temporal layers. LUMARA reads from it only; it never writes to the user's CHRONICLE. The system reduces context requirements by 50-75% for temporal queries while enabling biographical analysis across unlimited time horizons.

**Key Innovation:** CHRONICLE synthesis IS the automated implementation of the VEIL narrative integration cycle, not a separate system.

### Key Features

- **4-Layer Architecture**: Raw entries → Monthly → Yearly → Multi-Year aggregations
- **VEIL Cycle Integration**: EXAMINE → INTEGRATE → LINK stages
- **Intelligent Query Routing**: Automatically selects appropriate layers based on query intent
- **Tier-Based Synthesis**: Different cadences and retention policies per user tier
- **Unified Scheduling**: Part of VEIL nightly cycle
- **Hybrid Mode Support**: Can combine CHRONICLE aggregations with raw entries for drill-down

### Implementation Status

✅ **Phase 1**: Core Infrastructure (Layer 0, Models, Storage)  
✅ **Phase 2**: Synthesis Engine (Monthly, Yearly, Multi-Year)  
✅ **Phase 3**: Query Router & Context Builder  
✅ **Phase 4**: Master Prompt Integration  
✅ **Phase 5**: Synthesis Scheduler  
✅ **VEIL Integration**: Unified with VEIL nightly cycle

---

## Architecture Overview

### System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Query                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              ChronicleQueryRouter                            │
│  • Intent Classification (LLM-based)                        │
│  • Layer Selection                                           │
│  • Date Filter Extraction                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              ChronicleContextBuilder                         │
│  • Load Aggregations                                         │
│  • Format for Prompt                                         │
│  • Build Mini-Context (Voice Mode)                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              LumaraMasterPrompt                                │
│  • Mode Selection (chronicleBacked/rawBacked/hybrid)        │
│  • Context Injection                                         │
│  • Attribution Rules                                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    LLM (Gemini)                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              VEIL Nightly Cycle (Unified)                  │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              VeilChronicleScheduler                          │
│  ├─ System Maintenance (VEIL tasks)                        │
│  └─ Narrative Integration (CHRONICLE as VEIL)              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              ChronicleNarrativeIntegration                   │
│  • EXAMINE (Monthly synthesis)                             │
│  • INTEGRATE (Yearly synthesis)                             │
│  • LINK (Multi-year synthesis)                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              SynthesisEngine                                 │
│  • Orchestrates Synthesis                                    │
│  • Error Handling                                            │
│  • Changelog Logging                                         │
└──────────────────────┬──────────────────────────────────────┘
```

### Layer Hierarchy

```
Layer 0: Raw Event Stream (Hive) - VERBALIZE
  └─> Layer 1: Monthly Aggregations (Markdown) - EXAMINE
        └─> Layer 2: Yearly Aggregations (Markdown) - INTEGRATE
              └─> Layer 3: Multi-Year Aggregations (Markdown) - LINK
```

---

## VEIL Integration

### Conceptual Alignment

CHRONICLE synthesis is the automated implementation of the VEIL narrative integration cycle:

| VEIL Stage | Cognitive Function | CHRONICLE Layer | Implementation |
|------------|-------------------|-----------------|----------------|
| **Verbalize** | Immediate capture of experience | Layer 0 (Raw Entries) | ✅ Journal entry creation |
| **Examine** | Pattern recognition across recent events | Layer 1 (Monthly) | ✅ MonthlySynthesizer |
| **Integrate** | Synthesis into coherent narrative | Layer 2 (Yearly) | ✅ YearlySynthesizer |
| **Link** | Cross-temporal biographical connections | Layer 3 (Multi-Year) | ✅ MultiYearSynthesizer |

### Unified Architecture

**VeilChronicleScheduler** runs both:
1. **System Maintenance** (existing VEIL tasks):
   - Archive rotation
   - Cache cleanup
   - PRISM integration
   - RIVET snapshots
   - Keyword cleanup
   - Phase analysis

2. **Narrative Integration** (CHRONICLE as VEIL):
   - EXAMINE stage (Monthly synthesis)
   - INTEGRATE stage (Yearly synthesis)
   - LINK stage (Multi-year synthesis)

### Nightly Cycle Flow

```
Midnight Trigger
  ↓
VeilChronicleScheduler.runNightlyCycle()
  ↓
├─ Part 1: VEIL Maintenance
│   ├─ Archive rotation
│   ├─ Cache cleanup
│   ├─ PRISM integration
│   └─ RIVET snapshots
  ↓
└─ Part 2: VEIL Narrative Integration (CHRONICLE)
    ├─ EXAMINE (Monthly synthesis)
    ├─ INTEGRATE (Yearly synthesis)
    └─ LINK (Multi-year synthesis)
```

### Usage

```dart
// Initialize unified scheduler
final scheduler = await VeilChronicleFactory.createAndStart(
  userId: userId,
  tier: SynthesisTier.premium,
);

// Scheduler automatically runs nightly at midnight
// Manual trigger:
final report = await scheduler.runNightlyCycle(
  userId: userId,
  tier: tier,
);
```

---

## Component Details

### 1. Models

#### ChronicleLayer (`lib/chronicle/models/chronicle_layer.dart`)

```dart
enum ChronicleLayer {
  layer0,      // Raw entries (Hive) - VERBALIZE
  monthly,     // Monthly aggregations - EXAMINE
  yearly,      // Yearly aggregations - INTEGRATE
  multiyear,   // Multi-year aggregations - LINK
}
```

#### ChronicleAggregation (`lib/chronicle/models/chronicle_aggregation.dart`)

**Fields**:
- `layer`: ChronicleLayer
- `period`: String (e.g., "2025-01", "2025", "2020-2024")
- `synthesisDate`: DateTime
- `entryCount`: int
- `compressionRatio`: double
- `content`: String (Markdown with VEIL stage metadata)
- `sourceEntryIds`: List<String>
- `userEdited`: bool
- `version`: int
- `userId`: String

#### QueryPlan (`lib/chronicle/models/query_plan.dart`)

**Query Intent Types**:
1. `specificRecall` → Raw entries only
2. `temporalQuery` → Monthly/Yearly based on period
3. `patternIdentification` → Monthly + Yearly
4. `developmentalTrajectory` → Multi-year + Yearly
5. `historicalParallel` → Multi-year + Yearly + Monthly
6. `inflectionPoint` → Yearly + Monthly

### 2. Storage

#### Layer0Repository (`lib/chronicle/storage/layer0_repository.dart`)

**Storage**: Hive box `chronicle_raw_entries`

**Key Methods**:
- `saveEntry(ChronicleRawEntry)` - Save raw entry
- `getEntriesForMonth(userId, month)` - Get entries for month
- `cleanupOldEntries(userId, retentionDays)` - Cleanup based on tier

#### AggregationRepository (`lib/chronicle/storage/aggregation_repository.dart`)

**Storage**: File-based (Markdown + YAML frontmatter)

**Structure**:
```
chronicle/
  ├── monthly/
  │   └── 2025-01.md
  ├── yearly/
  │   └── 2025.md
  └── multiyear/
      └── 2020-2024.md
```

#### ChangelogRepository (`lib/chronicle/storage/changelog_repository.dart`)

**Storage**: JSONL file (`chronicle/changelog/changelog.json`)

**Purpose**: Tracks synthesis history, VEIL stages, errors, and user edits.

### 3. Synthesis

#### SynthesisEngine (`lib/chronicle/synthesis/synthesis_engine.dart`)

**Purpose**: Orchestrates all synthesis operations.

**Internal Components**:
- `MonthlySynthesizer` - Layer 1 synthesis (EXAMINE)
- `YearlySynthesizer` - Layer 2 synthesis (INTEGRATE)
- `MultiYearSynthesizer` - Layer 3 synthesis (LINK)

#### ChronicleNarrativeIntegration (`lib/chronicle/integration/chronicle_narrative_integration.dart`)

**Purpose**: Wraps SynthesisEngine and frames synthesis as VEIL stages.

**Key Methods**:
- `runVeilCycle(userId, tier)` - Execute VEIL stages based on tier
- `_examineRecentPatterns()` - EXAMINE stage (monthly)
- `_integrateIntoNarrative()` - INTEGRATE stage (yearly)
- `_linkAcrossYears()` - LINK stage (multi-year)

### 4. Query System

#### ChronicleQueryRouter (`lib/chronicle/query/query_router.dart`)

**Purpose**: Classifies queries and determines which layers to access.

#### ChronicleContextBuilder (`lib/chronicle/query/context_builder.dart`)

**Purpose**: Formats aggregations for prompt injection.

#### DrillDownHandler (`lib/chronicle/query/drill_down_handler.dart`)

**Purpose**: Handles cross-layer navigation for evidence requests.

### 5. Scheduling

#### VeilChronicleScheduler (`lib/echo/rhythms/veil_chronicle_scheduler.dart`)

**Purpose**: Unified scheduler for VEIL maintenance + CHRONICLE narrative integration.

**Tier Configurations**:

| Tier | Monthly | Yearly | Multi-Year | Retention |
|------|---------|--------|------------|-----------|
| Free | ❌ | ❌ | ❌ | 0 days |
| Basic | ✅ Daily | ❌ | ❌ | 30 days |
| Premium | ✅ Daily | ✅ Weekly | ❌ | 90 days |
| Enterprise | ✅ Daily | ✅ Weekly | ✅ Monthly | 365 days |

---

## Data Flow

### Synthesis Flow

```
Journal Entry Created
  ↓
JournalRepository.createJournalEntry()
  ↓
Layer0Populator.populateFromJournalEntry()
  ↓
Layer0Repository.saveEntry()
  ↓
[VEIL Nightly Cycle: ChronicleNarrativeIntegration.runVeilCycle()]
  ↓
SynthesisEngine.synthesizeLayer(layer: monthly, period: "2025-01")
  ↓
MonthlySynthesizer.synthesize() [EXAMINE stage]
  ↓
1. Load Layer 0 entries
2. Extract themes (LLM with VEIL framing)
3. Calculate patterns
4. Generate Markdown (with VEIL stage metadata)
5. Save to AggregationRepository
6. Log to ChangelogRepository (veil_examine action)
```

### Query Flow

```
User Query: "Tell me about my month"
  ↓
EnhancedLumaraApi.generateReflection()
  ↓
ChronicleQueryRouter.route()
  → Intent: temporalQuery
  → Layers: [monthly]
  → Period: "2025-01"
  ↓
ChronicleContextBuilder.buildContext()
  → Load monthly aggregation for "2025-01"
  → Format for prompt
  ↓
LumaraMasterPrompt.getMasterPrompt()
  → Mode: chronicleBacked
  → Inject CHRONICLE context
  ↓
LLM receives prompt with CHRONICLE aggregation
  ↓
Response cites CHRONICLE layer and period
```

---

## Integration Points

### 1. Journal Entry Creation

**File**: `lib/arc/internal/mira/journal_repository.dart`

**Integration**:
```dart
Future<void> createJournalEntry(JournalEntry entry) async {
  // ... existing save logic ...
  
  // Populate Layer 0 (VERBALIZE stage)
  await _populateLayer0(entry);
}
```

### 2. Reflection Generation

**File**: `lib/arc/chat/services/enhanced_lumara_api.dart`

**Integration**:
```dart
// Route query for CHRONICLE
if (_chronicleInitialized && _queryRouter != null) {
  queryPlan = await _queryRouter!.route(
    query: request.userText,
    userContext: {'userId': userId},
  );
  
  if (queryPlan.usesChronicle) {
    chronicleContext = await _contextBuilder!.buildContext(
      userId: userId,
      queryPlan: queryPlan,
    );
    promptMode = LumaraPromptMode.chronicleBacked;
  }
}
```

### 3. VEIL Nightly Cycle

**Integration with App Lifecycle**:

```dart
// In app initialization
final scheduler = await VeilChronicleFactory.createAndStart(
  userId: currentUserId,
  tier: getUserTier(), // Free, Basic, Premium, Enterprise
);

// Scheduler automatically runs at midnight
// On app pause/close
scheduler?.stop();
```

---

## File Structure

```
lib/chronicle/
├── models/
│   ├── chronicle_layer.dart          # Layer enum + extension
│   ├── chronicle_aggregation.dart    # Aggregation model
│   └── query_plan.dart               # QueryPlan + QueryIntent + DateTimeRange
│
├── storage/
│   ├── raw_entry_schema.dart         # Hive schema for Layer 0
│   ├── layer0_repository.dart        # Layer 0 storage (Hive)
│   ├── layer0_populator.dart         # Extract from JournalEntry
│   ├── aggregation_repository.dart   # Layers 1-3 storage (Files)
│   └── changelog_repository.dart     # Synthesis history
│
├── synthesis/
│   ├── synthesis_engine.dart         # Orchestrator
│   ├── monthly_synthesizer.dart      # Layer 1 synthesis (EXAMINE)
│   ├── yearly_synthesizer.dart       # Layer 2 synthesis (INTEGRATE)
│   ├── multiyear_synthesizer.dart    # Layer 3 synthesis (LINK)
│   └── pattern_detector.dart         # Pattern analysis
│
├── query/
│   ├── query_router.dart             # Intent classification + routing
│   ├── context_builder.dart          # Format aggregations for prompts
│   └── drill_down_handler.dart       # Cross-layer navigation
│
├── scheduling/
│   ├── synthesis_scheduler.dart       # Tier-based cadence
│   └── background_tasks.dart          # @Deprecated (use VeilChronicleScheduler)
│
└── integration/
    ├── veil_stage_models.dart         # VEIL stage enums and models
    ├── chronicle_narrative_integration.dart  # VEIL-framed synthesis
    └── veil_chronicle_factory.dart    # Factory for unified scheduler

lib/echo/rhythms/
└── veil_chronicle_scheduler.dart      # Unified VEIL-CHRONICLE scheduler
```

---

## Usage Examples

### Example 1: Manual Synthesis

```dart
// Initialize components
final layer0Repo = Layer0Repository();
await layer0Repo.initialize();

final aggregationRepo = AggregationRepository();
final changelogRepo = ChangelogRepository();

final synthesisEngine = SynthesisEngine(
  layer0Repo: layer0Repo,
  aggregationRepo: aggregationRepo,
  changelogRepo: changelogRepo,
);

// Synthesize monthly aggregation (EXAMINE stage)
final aggregation = await synthesisEngine.synthesizeLayer(
  userId: 'user123',
  layer: ChronicleLayer.monthly,
  period: '2025-01',
);
```

### Example 2: VEIL Cycle Execution

```dart
// Initialize narrative integration
final narrativeIntegration = ChronicleNarrativeIntegration(
  synthesisEngine: synthesisEngine,
  changelogRepo: changelogRepo,
);

// Run complete VEIL cycle
final result = await narrativeIntegration.runVeilCycle(
  userId: 'user123',
  tier: SynthesisTier.premium,
);

// result.stagesExecuted = [VeilStage.examine, VeilStage.integrate]
// result.details contains summaries for each stage
```

### Example 3: Query Routing

```dart
final router = ChronicleQueryRouter();

// Route a query
final plan = await router.route(
  query: 'Tell me about my year',
  userContext: {'userId': 'user123'},
);

// plan.intent = QueryIntent.temporalQuery
// plan.layers = [ChronicleLayer.yearly]
// plan.usesChronicle = true
```

---

## Configuration

### Tier Configuration

Tiers are configured in `SynthesisCadence.forTier()`:

```dart
// Free tier: No synthesis
SynthesisCadence.forTier(SynthesisTier.free)
  → enableMonthly: false
  → layer0RetentionDays: 0

// Basic tier: Monthly only (EXAMINE)
SynthesisCadence.forTier(SynthesisTier.basic)
  → monthlyInterval: Duration(days: 1)
  → layer0RetentionDays: 30

// Premium tier: Monthly + Yearly (EXAMINE + INTEGRATE)
SynthesisCadence.forTier(SynthesisTier.premium)
  → monthlyInterval: Duration(days: 1)
  → yearlyInterval: Duration(days: 7)
  → layer0RetentionDays: 90

// Enterprise tier: All layers (EXAMINE + INTEGRATE + LINK)
SynthesisCadence.forTier(SynthesisTier.enterprise)
  → monthlyInterval: Duration(days: 1)
  → yearlyInterval: Duration(days: 7)
  → multiYearInterval: Duration(days: 30)
  → layer0RetentionDays: 365
```

### Storage Locations

**Layer 0 (Hive)**:
- Box name: `chronicle_raw_entries`
- Location: Hive default directory

**Layers 1-3 (Files)**:
- Base: `{appDocuments}/chronicle/`
- Monthly: `chronicle/monthly/YYYY-MM.md`
- Yearly: `chronicle/yearly/YYYY.md`
- Multi-Year: `chronicle/multiyear/YYYY-YYYY.md`
- Changelog: `chronicle/changelog/changelog.json`

---

## Testing

### Unit Tests

**Location**: `test/chronicle/`

**Coverage**:
- ✅ `Layer0Repository` - Storage operations
- ✅ `PatternDetector` - Pattern analysis
- ✅ `MonthlySynthesizer` - Monthly synthesis
- ✅ `YearlySynthesizer` - Yearly synthesis
- ✅ `QueryRouter` - Query routing logic

**Run Tests**:
```bash
flutter test test/chronicle/
```

---

## Future Enhancements

### Phase 6: UI Components (Planned)
- CHRONICLE timeline view
- Aggregation editor
- VEIL cycle status dashboard
- Layer navigation UI

### Phase 7: Advanced Features (Planned)
- User-editable aggregations
- Custom synthesis prompts
- Export/import aggregations
- Cross-user pattern analysis

### Phase 8: Optimization (Planned)
- Incremental synthesis (only changed entries)
- Parallel synthesis execution
- Caching layer
- Compression optimization

---

## Troubleshooting

### Common Issues

**1. Hive Adapter Not Registered**
```
Error: Adapter not registered for typeId 110
```
**Solution**: Run `build_runner` to generate adapters.

**2. CHRONICLE Context Not Available**
```
Warning: CHRONICLE context not available, falling back to raw entries
```
**Solution**: Check if aggregations exist for the period. Trigger synthesis if needed.

**3. Synthesis Fails Silently**
**Solution**: Check `ChangelogRepository` for error logs. Verify Layer 0 has entries.

**4. VEIL Cycle Not Running**
**Solution**: Verify `VeilChronicleScheduler` is initialized and started. Check tier configuration.

---

## Performance Considerations

### Synthesis Performance
- **Monthly**: ~5-10 seconds per month (depends on entry count)
- **Yearly**: ~10-20 seconds per year
- **Multi-Year**: ~20-30 seconds per 5-year period

### Query Performance
- **Intent Classification**: ~1-2 seconds (LLM call)
- **Context Loading**: <100ms (file read)
- **Total Query Overhead**: ~1-2 seconds

### Storage Considerations
- **Layer 0**: ~1KB per entry (Hive)
- **Monthly Aggregation**: ~5-10KB per month
- **Yearly Aggregation**: ~20-50KB per year
- **Multi-Year**: ~50-200KB per 5-year period

---

## Security & Privacy

### Data Isolation
- All aggregations are user-scoped (`userId` field)
- Layer 0 entries filtered by `userId`
- File storage per-user (future: encryption)

### PRISM Integration
- CHRONICLE aggregations can be depersonalized via PRISM
- Future: PRISM adapter for aggregations

---

## Conclusion

CHRONICLE provides a robust temporal aggregation system that significantly reduces context requirements while enabling deep biographical analysis. The implementation is modular, testable, and designed for graceful degradation.

**Key Achievements**:
- ✅ 4-layer hierarchical architecture
- ✅ VEIL cycle integration (EXAMINE → INTEGRATE → LINK)
- ✅ Intelligent query routing
- ✅ Tier-based synthesis scheduling
- ✅ Seamless integration with existing LUMARA system
- ✅ Comprehensive error handling and logging

**Next Steps**:
- UI components for viewing/editing aggregations
- User migration tools
- Performance optimization
- Advanced pattern detection

---

**Document Version**: 2.0  
**Last Updated**: January 2025  
**Maintainer**: ARC Development Team
