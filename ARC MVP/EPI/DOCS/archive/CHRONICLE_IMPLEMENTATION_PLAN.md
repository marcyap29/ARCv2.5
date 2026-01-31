# CHRONICLE Architecture Implementation Plan

## Executive Summary

This plan implements CHRONICLE - a temporal aggregation memory architecture that enables LUMARA to maintain longitudinal biographical intelligence by progressively consolidating journal entries into hierarchical temporal layers (Layer 0: Raw, Layer 1: Monthly, Layer 2: Yearly, Layer 3: Multi-Year).

**Key Innovation:** Reduces context requirements by 50-75% for temporal queries while enabling biographical analysis across unlimited time horizons.

**Critical Principle:** This is a fundamental upgrade that will eventually replace raw entry synthesis as the primary context path, but implemented with dual-path safety during Phase 1.

---

## Architecture Overview

### Current State Integration Points

| Component | Current Implementation | CHRONICLE Integration |
|-----------|------------------------|----------------------|
| Journal storage | Hive `journal_entries`, `JournalEntry` model | → Layer 0 raw JSON (new Hive box) |
| Phase history | Hive `phase_history_v1`, `PhaseHistoryEntry` | → Layer 0 analysis data |
| Context selection | `LumaraContextSelector` (time window + sampling) | → Replaced by `ChronicleContextService` for non-specific queries |
| Prompt building | `EnhancedLumaraApi` + `LumaraMasterPrompt` | → Add mode selection + CHRONICLE context injection |
| Patterns | On-the-fly `PatternsDataService` | → Pre-computed in Layer 1/2/3 aggregations |
| PRISM | `PrismAdapter` for raw entries | → Extend for aggregation depersonalization |

### New Component Structure

```
lib/chronicle/
├── models/
│   ├── chronicle_layer.dart          # Enum: Layer0, Monthly, Yearly, MultiYear
│   ├── chronicle_aggregation.dart    # Model for aggregation metadata + content
│   ├── query_plan.dart               # Router output: intent, layers, strategy
│   └── raw_entry_schema.dart         # Layer 0 JSON schema
├── storage/
│   ├── layer0_repository.dart        # Hive box for raw JSON entries (30-90 day retention)
│   ├── aggregation_repository.dart  # Markdown + YAML for Layers 1-3
│   └── changelog_repository.dart    # Synthesis history
├── synthesis/
│   ├── synthesis_engine.dart         # Orchestrates LLM calls + algorithms
│   ├── monthly_synthesizer.dart     # Layer 1 synthesis
│   ├── yearly_synthesizer.dart      # Layer 2 synthesis
│   ├── multiyear_synthesizer.dart    # Layer 3 synthesis
│   └── pattern_detector.dart         # Theme clustering, chapter detection
├── query/
│   ├── query_router.dart             # Intent classification + layer selection
│   ├── context_builder.dart          # Formats aggregations for prompt
│   └── drill_down_handler.dart       # Cross-layer navigation
├── scheduling/
│   ├── synthesis_scheduler.dart      # Tier-based cadence management
│   └── background_tasks.dart         # Integration with app lifecycle
├── privacy/
│   └── chronicle_privacy.dart        # PRISM extension for aggregations
└── ui/
    ├── chronicle_viewer.dart         # View all layers
    ├── aggregation_editor.dart       # Edit aggregations
    ├── chronicle_debug_panel.dart    # Phase 1 debug controls
    └── changelog_view.dart              # Synthesis history
```

---

## Implementation Phases

### Phase 1: Core Infrastructure Setup (Week 1-2)

**Goal:** Create directory structure, models, and Layer 0 storage with Hive integration.

#### Task 1.1: Create CHRONICLE Directory Structure
- **Files:** Create `lib/chronicle/` with all subdirectories
- **Action:** Set up empty directory structure matching the architecture above

#### Task 1.2: Implement Core Models
- **File:** `lib/chronicle/models/chronicle_layer.dart`
  ```dart
  enum ChronicleLayer {
    layer0,    // Raw entries
    monthly,   // Layer 1: Monthly aggregations
    yearly,    // Layer 2: Yearly aggregations
    multiyear, // Layer 3: Multi-year aggregations
    
    String get displayName {
      switch (this) {
        case ChronicleLayer.layer0: return 'Raw Entries';
        case ChronicleLayer.monthly: return 'Monthly';
        case ChronicleLayer.yearly: return 'Yearly';
        case ChronicleLayer.multiyear: return 'Multi-Year';
      }
    }
  }
  ```

- **File:** `lib/chronicle/models/chronicle_aggregation.dart`
  ```dart
  class ChronicleAggregation {
    final ChronicleLayer layer;
    final String period; // "2025-01" for monthly, "2025" for yearly
    final DateTime synthesisDate;
    final int entryCount;
    final double compressionRatio;
    final String content; // Markdown content
    final List<String> sourceEntryIds;
    final bool userEdited;
    final int version;
  }
  ```

- **File:** `lib/chronicle/models/query_plan.dart`
  ```dart
  enum QueryIntent {
    specificRecall,
    patternIdentification,
    developmentalTrajectory,
    historicalParallel,
    inflectionPoint,
    temporalQuery,
  }
  
  class QueryPlan {
    final QueryIntent intent;
    final List<ChronicleLayer> layers;
    final String strategy;
    final bool usesChronicle;
    final bool drillDown;
    final DateTimeRange? dateFilter;
  }
  ```

#### Task 1.3: Implement Layer 0 Hive Storage
- **File:** `lib/chronicle/storage/layer0_repository.dart`
  - Create `ChronicleRawEntry` Hive model (typeId: 10)
  - Hive box name: `chronicle_raw_entries`
  - Schema matches specification (entry_id, timestamp, content, metadata, analysis)
  - Methods:
    - `getEntriesForMonth(userId, month)` - Query by month
    - `getEntriesInRange(start, end)` - Query by date range
    - `queryByTheme(theme)` - Query by theme
    - `queryByPhase(phase)` - Query by phase
    - `cleanupOldEntries(retentionDays)` - Retention policy (30-90 days)

#### Task 1.4: Create Aggregation Storage System
- **File:** `lib/chronicle/storage/aggregation_repository.dart`
  - File-based storage in `chronicle/monthly/`, `chronicle/yearly/`, `chronicle/multiyear/`
  - Markdown + YAML frontmatter format
  - Methods:
    - `saveMonthly(userId, aggregation)`
    - `saveYearly(userId, aggregation)`
    - `saveMultiYear(userId, aggregation)`
    - `loadLayer(userId, layer, period)`
    - `getAllForLayer(userId, layer)`

- **File:** `lib/chronicle/storage/changelog_repository.dart`
  - Track synthesis history, errors, metadata
  - Methods:
    - `log(userId, layer, action, metadata)`
    - `getLastSynthesis(userId, layer)`
    - `getSynthesisHistory(userId, layer)`

#### Task 1.5: Integrate Layer 0 Population with Journal Save
- **File:** `ARC MVP/EPI/lib/arc/internal/mira/journal_repository.dart`
  - Modify `createJournalEntry()` to populate Layer 0 after save
  - Extract data from:
    - `JournalEntry` (content, timestamp, metadata)
    - `PhaseHistoryEntry` (phase scores, reason) - fetch by journalEntryId
    - SENTINEL/RIVET calculations (if available)
    - Existing theme/keyword extractors

---

### Phase 2: Synthesis Engine Implementation (Week 2-3)

**Goal:** Build monthly, yearly, and multi-year synthesizers with LLM integration.

#### Task 2.1: Implement MonthlySynthesizer
- **File:** `lib/chronicle/synthesis/monthly_synthesizer.dart`
  - Algorithm:
    1. Load all Layer 0 entries for month
    2. Extract themes using LLM (top 3-5, with confidence)
    3. Calculate phase distribution
    4. Calculate SENTINEL trends
    5. Identify significant events (outliers in SENTINEL, phase transitions)
    6. Detect behavioral patterns (meta-analysis)
    7. Find cross-references to similar historical periods
    8. Generate markdown with YAML frontmatter
    9. Validate compression ratio (target: 10-20%)
    10. Save aggregation
    11. Log to changelog

#### Task 2.2: Implement YearlySynthesizer
- **File:** `lib/chronicle/synthesis/yearly_synthesizer.dart`
  - Algorithm:
    1. Load all monthly aggregations for year
    2. Detect chapters (phase transition boundaries + theme shifts)
    3. Find sustained patterns (appear in 6+ months)
    4. Identify inflection points
    5. Compare to previous years
    6. Generate yearly markdown
    7. Validate compression (target: 5-10%)

#### Task 2.3: Implement MultiYearSynthesizer
- **File:** `lib/chronicle/synthesis/multiyear_synthesizer.dart`
  - Similar to yearly but synthesizes across multiple year summaries
  - Extract: life chapters, meta-patterns, developmental arcs, identity evolution
  - Target compression: 1-2%

#### Task 2.4: Create SynthesisEngine Orchestrator
- **File:** `lib/chronicle/synthesis/synthesis_engine.dart`
  - Coordinates LLM calls
  - Manages synthesis workflow
  - Handles errors gracefully
  - Logs to changelog

#### Task 2.5: Implement PatternDetector
- **File:** `lib/chronicle/synthesis/pattern_detector.dart`
  - Theme clustering algorithms
  - Chapter detection
  - Pattern identification

---

### Phase 3: Query Router and Context Builder (Week 3-4)

**Goal:** Build intelligent query routing system to determine which layers to access.

#### Task 3.1: Implement QueryIntent Classification
- **File:** `lib/chronicle/query/query_router.dart`
  - LLM-based classifier for 6 intent types
  - Fallback logic if classification fails

#### Task 3.2: Implement Layer Selection Logic
- **File:** `lib/chronicle/query/query_router.dart`
  - Decision tree mapping intents to layers:
    - `specificRecall` → [] (use raw entries)
    - `temporalQuery` → monthly/yearly based on period
    - `patternIdentification` → monthly + yearly
    - `developmentalTrajectory` → multiyear + yearly
    - `historicalParallel` → multiyear + yearly + monthly
    - `inflectionPoint` → yearly + monthly

#### Task 3.3: Create ContextBuilder
- **File:** `lib/chronicle/query/context_builder.dart`
  - Formats aggregations for prompt injection
  - Handles cross-layer navigation
  - Builds drill-down paths

#### Task 3.4: Implement DrillDownHandler
- **File:** `lib/chronicle/query/drill_down_handler.dart`
  - Cross-layer navigation when user requests evidence
  - Load specific entries mentioned in aggregations

---

### Phase 4: Master Prompt Integration (Week 4-5)

**Goal:** Integrate CHRONICLE with LumaraMasterPrompt and EnhancedLumaraApi.

#### Task 4.1: Add LumaraPromptMode Enum
- **File:** `ARC MVP/EPI/lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
  ```dart
  enum LumaraPromptMode {
    chronicleBacked,  // Uses CHRONICLE aggregations (primary path)
    rawBacked,        // Uses raw entries (fallback)
    hybrid,           // Uses both (rare)
  }
  ```

#### Task 4.2: Modify getMasterPrompt() for Mode Support
- **File:** `ARC MVP/EPI/lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
  - Update method signature:
    ```dart
    static String getMasterPrompt({
      required String controlStateJson,
      required LumaraPromptMode mode,
      String? entryText,
      String? baseContext,          // Required if mode = rawBacked
      String? chronicleContext,     // Required if mode = chronicleBacked
      List<ChronicleLayer>? chronicleLayers,
      String? modeSpecificInstructions,
      List<Map<String, dynamic>>? recentEntries,
    })
    ```
  - Build context section per mode
  - Add attribution rules per mode
  - Add layer-specific guidance

#### Task 4.3: Add getVoicePrompt() CHRONICLE Support
- **File:** `ARC MVP/EPI/lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
  - Add `chronicleMiniContext` parameter
  - Create `buildChronicleMinContext()` helper
  - Extract themes/phase/events for 50-100 token summaries

#### Task 4.4: Integrate Query Router in EnhancedLumaraApi
- **File:** `ARC MVP/EPI/lib/arc/chat/services/enhanced_lumara_api.dart`
  - Add `ChronicleQueryRouter` instance
  - Modify `_buildPromptWithContext()`:
    1. Route query using router
    2. Determine mode based on QueryPlan
    3. Load CHRONICLE aggregations or fallback to raw entries
    4. Build appropriate prompt

#### Task 4.5: Add Hybrid Mode Support
- **File:** `ARC MVP/EPI/lib/arc/chat/services/enhanced_lumara_api.dart`
  - Load supporting entries when drillDown is true
  - Format both CHRONICLE context and raw entries

---

### Phase 5: Synthesis Scheduling System (Week 5-6)

**Goal:** Build tier-based cadence management with manual and automatic triggers.

#### Task 5.1: Implement SynthesisScheduler
- **File:** `lib/chronicle/scheduling/synthesis_scheduler.dart`
  - Tier-based cadence:
    - Free: No synthesis
    - Regular: Weekly → Quarterly → Yearly
    - Power: Daily → Monthly → Yearly
    - Founder: Daily → Monthly → Yearly
  - Last synthesis tracking
  - Layer-specific checks

#### Task 5.2: Add Manual Trigger Method
- **File:** `lib/chronicle/scheduling/synthesis_scheduler.dart`
  ```dart
  Future<void> triggerManualSynthesis({
    required String userId,
    required ChronicleLayer layer,
  }) async {
    await _runSynthesis(userId: userId, layer: layer);
  }
  ```

#### Task 5.3: Add Automatic Scheduling with Feature Flag
- **File:** `lib/chronicle/scheduling/synthesis_scheduler.dart`
  ```dart
  Future<void> checkAndRunSynthesis({
    required String userId,
    required UserTier tier,
    bool autoEnabled = false, // FALSE for Phase 1, TRUE for Phase 2+
  }) async {
    if (!autoEnabled) return; // Safety switch
    
    // Normal scheduling logic
  }
  ```

#### Task 5.4: Integrate with Journal Save Lifecycle
- **File:** `ARC MVP/EPI/lib/arc/internal/mira/journal_repository.dart`
  - After Layer 0 population, trigger synthesis check for power users (when autoEnabled)

#### Task 5.5: Create Background Tasks Integration
- **File:** `lib/chronicle/scheduling/background_tasks.dart`
  - Periodic checks (daily for power, weekly for regular)
  - Error handling
  - Logging to changelog

---

### Phase 6: PRISM Privacy Extension (Week 6-7)

**Goal:** Extend PRISM for CHRONICLE aggregation depersonalization.

#### Task 6.1: Create ChroniclePrivacy Service
- **File:** `lib/chronicle/privacy/chronicle_privacy.dart`
  - Extend `PrismAdapter` for aggregations
  - Methods:
    - `depersonalizeAggregation(content)` - Main entry point
    - `replaceNamesWithRoles(content)` - Names → roles
    - `generalizeLocations(content)` - Specific → regions
    - `abstractDates(content)` - Specific dates → periods
    - `generalizeCompanies(content)` - Company names → industries
    - `verifyNoPii(content)` - Assertion check

#### Task 6.2: Integrate with Synthesis Pipeline
- **File:** `lib/chronicle/synthesis/synthesis_engine.dart`
  - Apply depersonalization before saving aggregations
  - Ensure all cloud queries use depersonalized content

---

### Phase 7: UI Components and Debug Tools (Week 7-8)

**Goal:** Build CHRONICLE viewer, editor, and debug panel for Phase 1 validation.

#### Task 7.1: Create CHRONICLE Viewer Screen
- **File:** `lib/chronicle/ui/chronicle_viewer.dart`
  - List all layers (monthly/yearly/multiyear)
  - View specific aggregations
  - Navigate between layers

#### Task 7.2: Create Aggregation Editor
- **File:** `lib/chronicle/ui/aggregation_editor.dart`
  - Edit aggregation content
  - Save with `user_edited` flag
  - Trigger dependent re-synthesis option

#### Task 7.3: Create Debug Panel (Phase 1)
- **File:** `lib/chronicle/ui/chronicle_debug_panel.dart`
  - Manual synthesis triggers (month/year/multi-year)
  - View changelog
  - Inspect compression ratios
  - Validate synthesis quality

#### Task 7.4: Add Changelog Display
- **File:** `lib/chronicle/ui/changelog_view.dart`
  - Timeline view of synthesis history
  - Error logs
  - Synthesis metadata

---

### Phase 8: Testing and Validation (Week 8-9)

**Goal:** Comprehensive testing before production rollout.

#### Task 8.1: Synthesis Quality Tests
- **File:** `test/chronicle/synthesis_test.dart`
  - Validate monthly/yearly/multi-year accuracy
  - Test theme extraction
  - Phase distribution accuracy
  - Pattern detection correctness

#### Task 8.2: Compression Ratio Validation
- **File:** `test/chronicle/compression_test.dart`
  - Verify targets: monthly 10-20%, yearly 5-10%, multi-year 1-2%

#### Task 8.3: Query Routing Tests
- **File:** `test/chronicle/query_routing_test.dart`
  - Intent classification accuracy
  - Layer selection correctness
  - Drill-down navigation

#### Task 8.4: Privacy Compliance Tests
- **File:** `test/chronicle/privacy_test.dart`
  - Verify PRISM integration
  - Test PII detection
  - Validate depersonalization

#### Task 8.5: Performance Benchmarks
- **File:** `test/chronicle/performance_test.dart`
  - Query speed vs naive search
  - Synthesis speed
  - Storage efficiency
  - Token reduction validation (target: 50-75%)

---

## Key Recommendations

### 1. Hive Storage for Layer 0
- **Rationale:** Consistent with existing `journal_entries` and `phase_history_v1` architecture
- **Benefits:** Fast indexed queries, manageable 30-90 day size, debugging still possible
- **Implementation:** Use Hive typeId: 10 for `ChronicleRawEntry`

### 2. Dual-Path Safety (Phase 1)
- **Rationale:**** CHRONICLE must be validated before replacing raw entry path
- **Implementation:** Use `LumaraPromptMode` enum to explicitly separate paths
- **Safety:** CHRONICLE mode only for manually tested queries initially

### 3. Manual + Automatic Triggers
- **Rationale:** Manual for Phase 1 validation, automatic infrastructure ready for production
- **Implementation:** Feature flag `autoEnabled` (false for Phase 1, true for production)
- **Benefits:** Safety during development, production readiness when proven

### 4. Minimal Disruption to Existing Code
- **Rationale:** CHRONICLE should be additive, not replacement
- **Implementation:** EnhancedLumaraApi routes queries but falls back gracefully
- **Safety:** LumaraContextSelector remains for raw mode path

### 5. Layer 0 Population Strategy
- **Rationale:** Layer 0 must be current for synthesis triggers
- **Implementation:** Populate immediately after journal entry save
- **Data Sources:** JournalEntry + PhaseHistoryEntry + SENTINEL/RIVET

### 6. Graceful Degradation
- **Rationale:** Synthesis failures should not block user queries
- **Implementation:** Fallback to raw entry mode if aggregations missing
- **Error Handling:** Log errors to changelog, never crash app

### 7. Lazy Loading of Aggregations
- **Rationale:** Minimize memory usage and improve query speed
- **Implementation:** Only load when `QueryPlan.usesChronicle` is true
- **Optimization:** Use date filters to load only relevant periods

### 8. Personal Validation First
- **Rationale:** Validate aggregation quality before beta rollout
- **Implementation:** Synthesize your own 69+ entries first
- **Process:** Use debug panel extensively, refine prompts iteratively

### 9. Backward Compatibility
- **Rationale:** Existing users without CHRONICLE must continue working
- **Implementation:** CHRONICLE is opt-in enhancement, not breaking change
- **Tier Strategy:** Free tier users have no CHRONICLE access per spec

### 10. Success Metrics Tracking
- **Metrics:**
  - Token reduction (target: 50-75%)
  - Query latency (CHRONICLE vs raw baseline)
  - Synthesis accuracy (user correction frequency)
  - Layer utilization (which layers queried most)
  - Cost savings per user

---

## Critical Considerations

### 1. LLM Dependency for Synthesis
- **Issue:** Monthly/Yearly/MultiYear synthesis requires LLM calls
- **Impact:** Cost implications and rate limiting
- **Solution:** Batch synthesis jobs, implement queuing system for high-volume users

### 2. Aggregation File Management
- **Issue:** Markdown + YAML files need versioning if users edit
- **Impact:** User edits may require re-synthesis
- **Solution:** Consider git-like diff tracking or append-only changelog

### 3. Query Router Accuracy
- **Issue:** LLM-based intent classification may have false positives/negatives
- **Impact:** Wrong layer selection
- **Solution:** Add confidence scores, fallback logic, refine prompts based on usage

### 4. Synthesis Latency
- **Issue:** Monthly synthesis for 28 entries may take 30-60 seconds
- **Impact:** User experience during manual triggers
- **Solution:** Background processing, progress indicators, notifications

### 5. Layer 0 Data Completeness
- **Issue:** Layer 0 requires PhaseHistoryEntry data
- **Impact:** Missing phase data for old entries
- **Solution:** Backfill strategy or graceful handling of missing phase data

### 6. CHRONICLE Transparency
- **Issue:** Users should understand when CHRONICLE vs raw mode is used
- **Impact:** User confusion
- **Solution:** UI indicators or explanations, simpler than debug panel for production

### 7. Multi-Year Synthesis Frequency
- **Issue:** Multi-year synthesis every 1/5/10 years means infrequent updates
- **Impact:** Long gaps between synthesis runs
- **Solution:** Caching strategy, handle long gaps without errors

### 8. PRISM Integration Complexity
- **Issue:** Depersonalizing aggregations while preserving semantic meaning
- **Impact:** PII leakage risk
- **Solution:** Test extensively, verify no PII while maintaining synthesis quality

---

## Success Criteria

### Phase 1 Complete When:
- [ ] Layer 0 populated for all new journal entries
- [ ] Manual synthesis works for monthly aggregations
- [ ] Aggregations saved in correct format
- [ ] Debug panel functional

### Phase 2 Complete When:
- [ ] Monthly synthesis produces quality aggregations (10-20% compression)
- [ ] Yearly synthesis works (5-10% compression)
- [ ] Multi-year synthesis works (1-2% compression)
- [ ] Synthesis prompts refined based on personal validation

### Phase 3 Complete When:
- [ ] Query router classifies intents correctly (>80% accuracy)
- [ ] Layer selection logic works for all intent types
- [ ] Context builder formats aggregations correctly

### Phase 4 Complete When:
- [ ] LumaraMasterPrompt supports all three modes
- [ ] EnhancedLumaraApi routes queries correctly
- [ ] Fallback to raw mode works when aggregations missing
- [ ] Voice mode supports CHRONICLE mini-context

### Phase 5 Complete When:
- [ ] Manual triggers work for all layers
- [ ] Automatic scheduling infrastructure ready (feature flag controlled)
- [ ] Background tasks run without errors

### Phase 6 Complete When:
- [ ] PRISM depersonalization works for aggregations
- [ ] No PII detected in test aggregations
- [ ] Synthesis quality maintained after depersonalization

### Phase 7 Complete When:
- [ ] CHRONICLE viewer displays all layers
- [ ] Aggregation editor allows user corrections
- [ ] Debug panel provides all Phase 1 controls
- [ ] Changelog displays synthesis history

### Phase 8 Complete When:
- [ ] All tests pass
- [ ] Compression ratios meet targets
- [ ] Query routing accuracy >80%
- [ ] Privacy compliance verified
- [ ] Performance benchmarks meet targets (50-75% token reduction)

---

## Next Steps

1. **Review this plan** - Ensure alignment with architecture vision
2. **Confirm storage decisions** - Hive for Layer 0, file-based for aggregations
3. **Set up development branch** - Create `test` branch (already done)
4. **Begin Phase 1** - Start with directory structure and models
5. **Iterate on synthesis prompts** - Personal validation will refine these

---

**This plan is a living document. Update as implementation reveals better approaches.**
