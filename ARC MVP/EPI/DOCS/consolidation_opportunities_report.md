# Code Consolidation Opportunities Report

**Date:** January 11, 2026
**Branch:** dev
**Analysis Scope:** Post-Code Simplifier Consolidation
**Project:** EPI (Enhanced Personal Intelligence)

---

## Executive Summary

Following the successful Claude Code Simplifier run that eliminated 168 lines across 24 functions, this analysis identifies **major consolidation opportunities** that could eliminate an additional **930-970 lines (30% of remaining codebase)** through strategic file merging and component abstraction.

The primary opportunity lies in the **Insights cards layer**, where 4 nearly identical files contain 1,057 lines of duplicated code that could be reduced to ~300 lines through a generic card widget approach.

---

## Current Codebase State

### Post-Simplifier Metrics
- **Total Lines Analyzed:** 3,197
- **Total Dart Files:** 15
- **Recently Simplified:** 5 files, 168 lines reduced, 24 functions improved
- **Architecture:** Well-structured but repetitive patterns

### File Distribution
| Component Type | Files | Lines | % of Codebase |
|----------------|-------|-------|---------------|
| **Insight Cards** | 4 | 1,057 | 33.1% |
| **Service Layer** | 3 | ~400 | 12.5% |
| **Models & Utilities** | 3 | ~300 | 9.4% |
| **Other Components** | 5 | ~1,440 | 45.0% |

---

## Major Consolidation Opportunities

### 1. **Critical Priority: Insight Cards Unification** 🎯

#### Files Affected
- `lib/features/insights/cards/pairs_on_rise_card.dart` (262 lines)
- `lib/features/insights/cards/phase_drift_card.dart` (333 lines)
- `lib/features/insights/cards/precursors_card.dart` (239 lines)
- `lib/features/insights/cards/themes_card.dart` (223 lines)

#### Duplication Analysis
**99% Identical Structure:**
- Loading state implementation (30 lines × 4 = 120 lines)
- Empty state implementation (45 lines × 4 = 180 lines)
- Container + decoration patterns (12+ instances)
- Header row structure (8 lines × 4 = 32 lines)
- Error handling patterns (identical across all)

**Example Duplication:**
```dart
// Found in ALL 4 files - identical 30-line loading implementation
Widget _buildLoadingCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kcSurfaceAltColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kcSecondaryTextColor.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [...]), // Identical except icon + title
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator(...)),
      ],
    ),
  );
}
```

#### Consolidation Strategy
**Create Generic `InsightCard<T>` Widget:**
```dart
class InsightCard<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Future<List<T>> dataFuture;
  final Widget Function(T item) itemBuilder;
  final String emptyMessage;

  // Reduces 4 files (1,057 lines) → 1 widget (~200 lines) + config (~100 lines)
}
```

**Impact:**
- **Lines Eliminated:** 700+ lines (66% reduction)
- **Maintainability:** Single source of truth for card behavior
- **Extensibility:** Easy to add new insight types
- **Consistency:** Uniform empty/loading/error states

---

### 2. **High Priority: Service Layer Consolidation** ⚙️

#### A. Duplicate Keyword Weight Calculations
**File:** `lib/core/mira/mira_service.dart`

**Duplicated Logic:**
- `topKeywords()` (lines 187-215)
- `breakthroughPrecursors()` (lines 386-419)

**Identical 15-line calculation block:**
```dart
final keywordWeights = <String, double>{};
for (final edge in mentionEdges) {
  if (edge.updatedAt.isAfter(cutoff)) {
    final delta = DateTime.now().difference(edge.updatedAt);
    final decay = _config.calculateDecay(delta);
    final weight = edge.wFreq * decay * edge.wConfidence;
    keywordWeights[edge.dstId] = (keywordWeights[edge.dstId] ?? 0.0) + weight;
  }
}
// Exact duplication in both methods
```

**Consolidation:** Extract `_calculateKeywordWeights()` private method
**Impact:** 40-50 lines eliminated

#### B. Redundant Edge Getter Methods
**File:** `lib/core/mira/mira_repo.dart`

**7 Nearly Identical Methods (lines 77-181):**
- `getEdgesByKind()` → `_edges.values.where((e) => e.kind == kind)`
- `getEdgesFromNode()` → `_edges.values.where((e) => e.srcId == nodeId)`
- `getEdgesToNode()` → `_edges.values.where((e) => e.dstId == nodeId)`
- `getMentionEdges()` → `_edges.values.where((e) => e.kind == 'mentions')`
- `getPhaseTagEdges()` → `_edges.values.where((e) => e.kind == 'taggedAs')`
- `getEmotionEdges()` → `_edges.values.where((e) => e.kind == 'expresses')`
- `getPeriodEdges()` → `_edges.values.where((e) => e.kind == 'inPeriod')`

**Consolidation:** Generic `_filterEdges(bool Function(Edge) predicate)` method
**Impact:** 50-60 lines eliminated

#### C. Passthrough Cubit Methods
**File:** `lib/core/mira/mira_cubit.dart`

**4 Identical Wrapper Methods (lines 144-205):**
```dart
Future<List<MiraKeywordStat>> getTopKeywords({...}) async {
  try {
    return await _miraService.topKeywords(window: window ?? _defaultWindow, limit: limit);
  } catch (e) {
    print('Error getting top keywords: $e');
    return [];
  }
}
// Pattern repeated 4x with different service method names
```

**Consolidation:** Generic async wrapper method
**Impact:** 40-50 lines eliminated

---

### 3. **Medium Priority: Utility Function Deduplication** 🛠️

#### A. Keyword Normalization (5 Different Implementations)
**Current Locations:**
1. `lib/core/mira/mira_models.dart:102` → `_normalizeKeywordId()`
2. `lib/core/mira/mira_service.dart:523` → `_normalizeKeywordId()` (duplicate)
3. `lib/features/insights/cards/pairs_on_rise_card.dart:252` → `_normalizeKeyword()`
4. `lib/features/insights/cards/precursors_card.dart:165` → inline normalization
5. `lib/features/insights/cards/themes_card.dart:160` → inline normalization

**Consolidation:** Create `lib/shared/utils/keyword_utils.dart`
```dart
/// Normalize keyword to display format
String normalizeKeywordDisplay(String keyword) { /* unified implementation */ }

/// Normalize keyword to ID format
String normalizeKeywordId(String keyword) { /* unified implementation */ }
```

**Impact:** 30 lines eliminated + 2 function definitions removed

#### B. Feature Flags Consolidation
**File:** `lib/core/mira/mira_feature_flags.dart`

**10 Hardcoded Methods with Identical Pattern:**
```dart
static bool get miraEnabled => true;
static bool get showDebugInfo => true;
static bool get verboseLogging => true;
// ... 7 more identical methods
```

**Consolidation:** Configuration-driven approach
```dart
static const Map<String, bool> _flags = {
  'miraEnabled': true,
  'showDebugInfo': true,
  // ... all flags
};
static bool get miraEnabled => _getFlag('miraEnabled');
```

**Impact:** 30-40 lines eliminated

---

## Consolidation Impact Analysis

### Quantitative Impact
| Consolidation Type | Current Lines | Potential Savings | Effort | Risk Level |
|-------------------|---------------|------------------|--------|------------|
| **Insight Cards** | 1,057 | 700+ | 2-3 days | Low |
| **Service Methods** | ~150 | 50-60 | 4 hours | Very Low |
| **Weight Calculations** | ~50 | 40-50 | 1 day | Medium |
| **Cubit Wrappers** | ~60 | 40-50 | 4 hours | Low |
| **Utility Functions** | ~60 | 30 | 2 hours | Very Low |
| **Feature Flags** | ~40 | 30-40 | 2 hours | Very Low |
| **TOTAL** | **~1,417** | **930-970** | **4-5 days** | **Low-Medium** |

### Qualitative Benefits
- **Maintainability:** Single source of truth eliminates update burden
- **Consistency:** Uniform behavior across similar components
- **Extensibility:** Easier to add new insight types or service methods
- **Testing:** Fewer files to test, centralized logic
- **Onboarding:** New developers understand patterns faster

---

## Risk Assessment

### Low Risk Consolidations (Recommended First)
1. **Utility Functions** - Pure functions, easy to test
2. **Service Edge Getters** - Simple filtering logic
3. **Cubit Wrappers** - Straightforward passthrough elimination
4. **Feature Flags** - Configuration change only

### Medium Risk Consolidations
1. **Insight Cards** - Requires careful parameterization but high reward
2. **Weight Calculations** - Business logic extraction needs thorough testing

### Risk Mitigation
- **Comprehensive Testing:** Unit tests for all extracted logic
- **Incremental Approach:** Consolidate one component type at a time
- **Backward Compatibility:** Maintain existing APIs during transition
- **Feature Flags:** Use feature flags to control rollout of consolidated components

---

## Recommended Execution Roadmap

### **Phase 1: Quick Wins (Days 1-2)**
**Goal:** Build confidence with low-risk, high-visibility improvements

1. **Consolidate Keyword Utilities** (2 hours)
   - Create `lib/shared/utils/keyword_utils.dart`
   - Update 5 import locations
   - **Impact:** 30 lines + 2 duplicate functions eliminated

2. **Merge Edge Getter Methods** (3 hours)
   - Create generic `_filterEdges()` in `mira_repo.dart`
   - Refactor 7 methods to use it
   - **Impact:** 50-60 lines eliminated

3. **Replace Cubit Passthrough Methods** (4 hours)
   - Create generic async wrapper in `mira_cubit.dart`
   - Maintain public API for backward compatibility
   - **Impact:** 40-50 lines eliminated

4. **Consolidate Feature Flags** (2 hours)
   - Replace hardcoded getters with configuration map
   - **Impact:** 30-40 lines eliminated

**Phase 1 Total:** 150-180 lines eliminated, 11 hours effort

### **Phase 2: Major Impact (Days 3-5)**
**Goal:** Tackle the largest consolidation opportunity

5. **Extract Keyword Weight Calculations** (1 day)
   - Create shared calculation method in `mira_service.dart`
   - Update `topKeywords()` and `breakthroughPrecursors()` to use it
   - **Impact:** 40-50 lines eliminated

6. **Design Generic Insight Card** (4 hours)
   - Define `InsightCard<T>` interface and configuration
   - Plan migration strategy for existing cards

7. **Implement Generic Insight Card** (2-3 days)
   - Create reusable card widget
   - Migrate existing cards one by one
   - Update integration points
   - **Impact:** 700+ lines eliminated

**Phase 2 Total:** 740-750 lines eliminated, 4-5 days effort

### **Phase 3: Polish & Optimization (Days 6-7)**
8. **Extract Common Item Widgets** (1 day)
   - Create reusable `InsightItemTile` component
   - **Impact:** 80-100 lines eliminated

9. **Testing & Documentation** (1 day)
   - Comprehensive test coverage for new consolidated components
   - Update documentation and architectural diagrams

**Phase 3 Total:** 80-100 lines eliminated, 2 days effort

---

## Success Metrics

### Immediate Metrics (Post-Consolidation)
- **Lines of Code:** 3,197 → ~2,250 (30% reduction)
- **Files Count:** 15 → 12 (20% reduction)
- **Duplicate Functions:** 15 → 3 (80% reduction)
- **Component Reusability:** 4 card types → 1 generic + configs

### Long-term Metrics (3-6 months)
- **Development Velocity:** Faster feature additions to insights
- **Bug Density:** Reduced due to centralized logic
- **Maintenance Effort:** Lower update burden for UI changes
- **Code Coverage:** Improved through focused testing

---

## Alternative Approaches Considered

### Option A: Incremental Consolidation (Recommended)
- **Pros:** Lower risk, easier to validate, maintains momentum
- **Cons:** Takes longer to see full benefits
- **Timeline:** 6-7 days

### Option B: Big Bang Refactor
- **Pros:** Immediate maximum impact
- **Cons:** High risk, difficult to test incrementally
- **Timeline:** 3-4 days but higher failure risk

### Option C: Conservative Approach (Utilities Only)
- **Pros:** Minimal risk
- **Cons:** Misses the major opportunity (insight cards)
- **Timeline:** 1-2 days, limited impact

---

## Dependencies & Prerequisites

### Technical Dependencies
- Existing test suite must pass (baseline confidence)
- Feature flags for rollout control
- Backup branch creation before major changes

### Team Dependencies
- Product team review of card consolidation approach
- Design team validation of UI consistency
- QA team testing plan for consolidated components

### Architectural Considerations
- Maintain existing widget tree structure
- Preserve performance characteristics
- Keep existing APIs stable during transition

---

## Conclusion

The analysis reveals **significant consolidation potential** beyond the initial code simplifier improvements. The primary opportunity in the **Insight Cards layer represents a 66% reduction** in that component with minimal risk.

**Recommended approach:** Execute the **incremental consolidation roadmap** to achieve:
- **930-970 lines eliminated (30% total reduction)**
- **Improved maintainability** through centralized logic
- **Enhanced extensibility** for future insights
- **Better developer experience** with unified patterns

The consolidation represents a **one-time architectural investment** that will pay dividends in reduced maintenance burden and accelerated feature development, particularly for the insights dashboard.

**Next Steps:**
1. Validate approach with team stakeholders
2. Create feature branch for consolidation work
3. Begin with Phase 1 quick wins to build momentum
4. Execute Phase 2 for maximum impact

---

*Report Generated: January 11, 2026*
*Analysis Scope: 3,197 lines across 15 Dart files*
*Estimated Total Impact: 30% codebase reduction with improved maintainability*