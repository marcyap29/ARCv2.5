# Code Simplifier Metrics

**Project:** EPI  
**Metrics Date:** 2026-02-25  
**Reference:** `DOCS/CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md`, `DOCS/CODE_SIMPLIFIER_SCAN_REPORT.md`

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Lines removed** | ~50–80 (unused imports + quick-actions consolidation) |
| **Files removed** | 0 |
| **Files modified** | 26+ (23 import, 2 quick-actions, 1 scan report created) |
| **Test result** | 511 passed, 193 failed (failures pre-existing) |

---

## Today's Run (2026-02-25) — Work Package Metrics

| Work Package | Files Modified | Lines Removed | Description |
|--------------|----------------|---------------|-------------|
| **P1-IMPORTS** | 23 | ~30–70 | Unused imports removed across lib |
| **P1-QUICK** | 2 | ~10 | widget_quick_actions_service, widget_quick_actions_integration — use QuickActionsService |
| **Scan** | 1 created | — | CODE_SIMPLIFIER_SCAN_REPORT.md |

### Changed Files (Today's Run)

**P1-IMPORTS (23 files — analyzer-driven unused imports):**  
*(Per scan report: import-related issues addressed in 2026-02-25 run.)*

**P1-QUICK:**
- `lib/arc/ui/widget_quick_actions_service.dart`
- `lib/arc/ui/widget_quick_actions_integration.dart`

**Scan:**
- `DOCS/CODE_SIMPLIFIER_SCAN_REPORT.md` (new)

---

## Rollback Steps (per work package)

| Package | Rollback |
|---------|----------|
| **P1-IMPORTS** | `git revert` the commit(s) that removed unused imports. Re-run `dart analyze` or `flutter analyze` to confirm. |
| **P1-QUICK** | Revert commits affecting `widget_quick_actions_service.dart` and `widget_quick_actions_integration.dart`. Restore previous imports (if they pointed to a duplicate QuickActionsService). Verify widget/quick-actions UI. |
| **Scan** | Delete `DOCS/CODE_SIMPLIFIER_SCAN_REPORT.md` if no longer needed. |

---

## Test Run Summary (2026-02-25)

**Command:** `flutter test --no-pub`  
**Result:** 511 passed, 193 failed  
**Exit code:** 1

### Pre-existing failures (not attributed to today's run)

| Area | Tests | Cause |
|------|-------|-------|
| **RIVET** | rivet_service_test, rivet_reducer_test | Concurrent modification during iteration; reset/state expectations; gate discipline thresholds |
| **debrief_to_journal_mapper** | debrief_to_journal_mapper_test | Missing lib: `debrief_to_journal_mapper.dart`, `debrief_models.dart` |
| **MCP exporter** | mcp_exporter_golden_test | HiveError (box not initialized); ServicesBinding not initialized |
| **Pointer models** | pointer_models_test | NoSuchMethodError: Map subscript on model classes (ImageDescriptor, AudioDescriptor, etc.) |
| **MCP import CLI** | mcp_import_cli_test | Tests did not complete (timeout / did not complete) |

No regressions attributed to P1-IMPORTS or P1-QUICK consolidation.

---

## Consolidated Patterns (reference)

Single sources of truth and access patterns are documented in:
- **ARCHITECTURE.md** § Code Simplifier consolidated patterns
- **CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md** § 4–5 (metrics, rollback)

---

*Generated for Code Simplifier P3 run 2026-02-25.*
