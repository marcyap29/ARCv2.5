# Error Fix Assignment - Task Breakdown

**Date:** 2024-12-19  
**Current Status:** 833 errors remaining (87.1% complete - 5,639 errors fixed)  
**Starting Point:** 6,472 errors

## Overview

This document breaks down the remaining 833 Dart analyzer errors into discrete, assignable sections. Each section can be handled by a separate agent or developer in parallel.

---

## SECTION 1: Missing Model Classes & Placeholders
**Estimated Errors:** ~50  
**Priority:** High  
**Difficulty:** Medium

### Tasks:
1. **RivetReducer** (~14 errors)
   - Files affected: `test/rivet/rivet_reducer_test.dart`, others
   - Action: Create `RivetReducer` class or import from correct location
   - Search: `grep -r "RivetReducer" lib/ test/`

2. **PhaseRecommender** (~12 errors)
   - Files affected: Various test and lib files
   - Action: Create `PhaseRecommender` class or import from correct location
   - Search: `grep -r "PhaseRecommender" lib/ test/`

3. **McpExportScope** (~11 errors)
   - Files affected: MCP export service files
   - Action: Create `McpExportScope` enum/class or import from correct location
   - Search: `grep -r "McpExportScope" lib/`

4. **McpEntryProjector** (~11 errors)
   - Files affected: MCP import/export files
   - Action: Create `McpEntryProjector` class or import from correct location
   - Search: `grep -r "McpEntryProjector" lib/`

5. **ChatJournalDetector** (~9 errors)
   - Files affected: MCP import service files
   - Action: Create placeholder class or import from correct location

### Command to find all files:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep -E "(RivetReducer|PhaseRecommender|McpExportScope|McpEntryProjector|ChatJournalDetector)" | \
cut -d':' -f1 | sort -u
```

---

## SECTION 2: MCP Constructor Syntax Issues
**Estimated Errors:** ~20  
**Priority:** High  
**Difficulty:** Low

### Tasks:
1. **McpProvenance Constructor** (~10 errors)
   - Issue: Using `McpProvenance(...)` as function instead of constructor
   - Files: Test files, possibly import service
   - Action: Change `McpProvenance(...)` to `const McpProvenance(...)` or fix instantiation
   - Example fix: Ensure using `const McpProvenance(source: 'x', device: 'y')`

2. **McpNode Constructor** (~10 errors)
   - Issue: Using `McpNode(...)` as function instead of constructor
   - Files: Test files
   - Action: Ensure proper constructor syntax with all required parameters
   - Check: `lib/core/mcp/models/mcp_schemas.dart` for correct signature

### Command to find:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep -E "(McpProvenance|McpNode).*isn't defined" | cut -d':' -f1 | sort -u
```

---

## SECTION 3: Missing URI Targets (Import Paths)
**Estimated Errors:** ~65  
**Priority:** High  
**Difficulty:** Low-Medium

### Tasks:
1. **Find all missing URI targets:**
   ```bash
   cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
   dart analyze 2>&1 | grep "Target of URI doesn't exist" | cut -d':' -f1 | sort -u
   ```

2. **Fix strategies:**
   - Convert relative imports to absolute `package:my_app/...` imports
   - Verify file actually exists (may need stub/placeholder)
   - Update import path to correct location
   - Create missing stub files if needed

3. **Common patterns to fix:**
   - `../mcp/...` → `package:my_app/core/mcp/...`
   - `../../features/...` → `package:my_app/arc/ui/...`
   - Missing processor files (create stubs if intentional placeholders)

---

## SECTION 4: Missing Methods & Getters
**Estimated Errors:** ~60  
**Priority:** Medium  
**Difficulty:** Medium

### Tasks:
1. **_getNodeById in EnhancedMiraMemoryService** (~11 errors)
   - File: `lib/mira/memory/enhanced_mira_memory_service.dart`
   - Action: Add `_getNodeById(String id)` private method or public getter
   - Check existing methods for similar functionality

2. **MiraWriter.writeNode** (1 error)
   - File: `lib/core/mcp/orchestrator/multimodal_mcp_orchestrator.dart:406`
   - Action: Add `writeNode` method to `MiraWriter` class or fix method name

3. **McpDescriptor missing getters** (~9 errors)
   - Files: `lib/core/mcp/orchestrator/ui/multimodal_ui_components.dart`
   - Missing: `duration`, `sizeBytes` getters
   - Action: Add getters to `McpDescriptor` class or fix property access

4. **ValidationResult.warnings** (~4 errors)
   - File: `lib/core/mcp/validation/enhanced_mcp_validator.dart`
   - Action: Add `warnings` getter/parameter to `ValidationResult` class

5. **MLKit classes** (TextRecognizer, MobileScannerController, InputImage) (~8 errors)
   - Files: `lib/core/mcp/orchestrator/real_ocp_orchestrator.dart`
   - Action: These are MLKit dependencies - either comment out/disable or add proper imports

6. **RivetService methods** (Already fixed - verify)
   - `apply()`, `edit()`, `delete()` methods
   - Should already be implemented

### Find other undefined methods/getters:
   ```bash
   cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
   dart analyze 2>&1 | grep -E "(The method|The getter).*isn't defined" | \
   cut -d'-' -f3 | sed 's/^ //' | sort | uniq -c | sort -rn | head -20
   ```

---

## SECTION 5: Const Initialization Errors
**Estimated Errors:** ~12  
**Priority:** Low  
**Difficulty:** Low

### Tasks:
1. **Find remaining const errors:**
   ```bash
   cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
   dart analyze 2>&1 | grep "Const variables must be initialized"
   ```

2. **Common fixes:**
   - Change `const` to `final` if using non-const expressions
   - Ensure list literals are `const` when needed: `const [...])`
   - Remove `const` from non-const constructors

---

## SECTION 6: Test File Errors
**Estimated Errors:** ~443 (out of 833 total)  
**Priority:** Medium  
**Difficulty:** Low-Medium  
**Files Affected:** ~175 unique test files

### Tasks:
1. **Test-specific imports:**
   - Fix import paths from `prism/mcp/...` to `core/mcp/...`
   - Fix import paths from `mcp/...` to `core/mcp/...`
   - Fix import paths from relative `../../lib/...` to `package:my_app/...`

2. **Test constructor calls:**
   - Fix `McpNode` constructor calls (add `provenance` parameter)
   - Fix `McpProvenance` constructor calls
   - Ensure `DateTime` types instead of `String` for timestamps

3. **Test dependencies:**
   - Add missing imports for test utilities
   - Fix mock/stub implementations

### Command to find test files:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep "error -" | grep "^test/" | cut -d':' -f1 | sort -u
```

---

## SECTION 7: Type Mismatches & API Incompatibilities
**Estimated Errors:** ~150  
**Priority:** Medium  
**Difficulty:** Medium-High  
**Lib Files Affected:** ~41 unique files

### Top affected lib files:
- `lib/core/mcp/orchestrator/ui/multimodal_ui_components.dart` (13 errors)
- `lib/core/models/reflective_entry_data.dart` (12 errors)
- `lib/core/mcp/orchestrator/multimodal_orchestrator_bloc.dart` (10 errors)
- `lib/ui/import/import_bottom_sheet.dart` (8 errors)
- `lib/shared/ui/settings/mcp_bundle_health_view_old.dart` (8 errors)
- `lib/ui/journal/journal_screen.dart` (7 errors)
- `lib/data/models/arcform_snapshot.g.dart` (7 errors)
- `lib/core/mcp/orchestrator/real_ocp_orchestrator.dart` (7 errors)

### Tasks:
1. **Parameter type mismatches:**
   - Find methods called with wrong parameter types
   - Fix enum vs String mismatches
   - Fix DateTime vs String mismatches

2. **Return type mismatches:**
   - Methods returning wrong types
   - Async/sync mismatches

3. **Generic type arguments:**
   - `MediaPackMetadata` as type argument issues
   - Other generic type mismatches

### Command to analyze:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep -E "(type.*isn't a|can't be used as)" | head -20
```

---

## SECTION 8: PIIType Duplicate Definition Resolution
**Estimated Errors:** ~24  
**Priority:** Medium  
**Difficulty:** Low

### Tasks:
1. **Identify duplicate definitions:**
   - `lib/privacy_core/models/pii_types.dart` (preferred)
   - `lib/privacy_core/pii_detection_service.dart` (duplicate?)

2. **Fix strategy:**
   - Remove duplicate enum from one location
   - Update all imports to use single source
   - Ensure consistent usage

3. **Find affected files:**
   ```bash
   cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
   dart analyze 2>&1 | grep "The name 'PIIType' is defined" | cut -d':' -f1 | sort -u
   ```

---

## SECTION 9: When/Directory Function Issues
**Estimated Errors:** ~16  
**Priority:** Low  
**Difficulty:** Low

### Tasks:
1. **`when` function undefined** (~8 errors)
   - Likely missing import: `package:bloc_test/bloc_test.dart` or similar
   - Or missing `package:freezed_annotation/freezed_annotation.dart`
   - Action: Add correct import or fix usage

2. **`Directory` function undefined** (~8 errors)
   - Missing `dart:io` import
   - Action: Add `import 'dart:io';`

### Command:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep -E "(The function 'when'|The function 'Directory')" | cut -d':' -f1 | sort -u
```

---

## SECTION 10: Miscellaneous & Cleanup
**Estimated Errors:** ~60  
**Priority:** Low  
**Difficulty:** Variable

### Tasks:
1. **Color constant issues:**
   - Some `kcTextSecondary` references may remain
   - Verify all imports from `package:my_app/shared/app_colors.dart`

2. **Undefined variables:**
   - `bundleDir` undefined in some contexts
   - Fix variable scoping

3. **General cleanup:**
   - Fix any remaining simple syntax errors
   - Verify fixes from previous sections
   - Run final `dart analyze` to catch edge cases

---

## Assignment Strategy

### Recommended Parallelization:

1. **Agent 1:** Sections 1 (Missing Models) + 4 (Missing Methods)  
   **Estimated Time:** 2-3 hours  
   **Errors:** ~110  
   - Requires code understanding, may need to create classes
   - Focus on understanding existing patterns before creating new classes

2. **Agent 2:** Sections 2 (MCP Constructors) + 5 (Const Errors)  
   **Estimated Time:** 1 hour  
   **Errors:** ~32  
   - Straightforward syntax fixes
   - Quick wins, high completion rate

3. **Agent 3:** Section 3 (Missing URIs)  
   **Estimated Time:** 1-2 hours  
   **Errors:** ~65  
   - Import path fixes, file verification
   - May need to create stub files for placeholders

4. **Agent 4:** Section 6 (Test Files) - Primary focus  
   **Estimated Time:** 3-4 hours  
   **Errors:** ~443  
   - Largest section, can be done in parallel with others
   - Mostly repetitive import path fixes
   - Batch processing recommended

5. **Agent 5:** Sections 7 (Type Mismatches) + 8 (PIIType)  
   **Estimated Time:** 2-3 hours  
   **Errors:** ~174  
   - Requires understanding of API contracts
   - May need to coordinate with Agent 1 for model changes

6. **Agent 6:** Sections 9 (When/Directory) + 10 (Misc)  
   **Estimated Time:** 1 hour  
   **Errors:** ~76  
   - Quick fixes and cleanup
   - Good for final polish phase

---

## Verification Commands

### Check total error count:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep -c "error -"
```
Target: **0 errors**

### Check progress by error type:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep "error -" | cut -d'-' -f3 | sed 's/^ //' | cut -d'.' -f1 | sort | uniq -c | sort -rn
```

### Check progress by file:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
dart analyze 2>&1 | grep "error -" | cut -d':' -f1 | sort | uniq -c | sort -rn | head -20
```

### Test file vs lib file breakdown:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI" && \
echo "Lib files:" && dart analyze 2>&1 | grep "error -" | grep "^lib/" | cut -d':' -f1 | sort -u | wc -l && \
echo "Test files:" && dart analyze 2>&1 | grep "error -" | grep "^test/" | cut -d':' -f1 | sort -u | wc -l
```

---

## Notes

- Always run `dart analyze` after making changes
- Use `read_lints` tool before and after edits
- Prefer creating placeholders over commenting out code
- Maintain backward compatibility when adding methods
- Document any API changes in code comments

---

## Success Criteria

- ✅ All 833 errors resolved
- ✅ `dart analyze` returns 0 errors
- ✅ No new errors introduced
- ✅ Code compiles successfully
- ✅ Tests can run (even if some fail - that's separate from syntax)

---

**Last Updated:** 2024-12-19  
**Next Review:** After each section completion

---

## Quick Reference Summary

| Section | Errors | Files | Priority | Agent |
|---------|--------|-------|----------|-------|
| 1. Missing Models | ~50 | ~20 | High | Agent 1 |
| 2. MCP Constructors | ~20 | ~10 | High | Agent 2 |
| 3. Missing URIs | ~65 | ~30 | High | Agent 3 |
| 4. Missing Methods | ~60 | ~15 | Medium | Agent 1 |
| 5. Const Errors | ~12 | ~8 | Low | Agent 2 |
| 6. Test Files | ~443 | ~175 | Medium | Agent 4 |
| 7. Type Mismatches | ~150 | ~41 | Medium | Agent 5 |
| 8. PIIType | ~24 | ~15 | Medium | Agent 5 |
| 9. When/Directory | ~16 | ~10 | Low | Agent 6 |
| 10. Misc | ~60 | ~30 | Low | Agent 6 |
| **TOTAL** | **833** | **~354** | - | - |

### Priority Order (Sequential if needed):
1. Sections 1-3 (High Priority) - Blocks compilation
2. Sections 4, 6 (Medium Priority) - Core functionality
3. Sections 7-8 (Medium Priority) - API consistency
4. Sections 5, 9-10 (Low Priority) - Polish and cleanup

### Parallel Execution Strategy:
- **Round 1 (Can run simultaneously):** Agents 1, 2, 3
- **Round 2 (Can run simultaneously):** Agent 4 (large, independent)
- **Round 3 (After Round 1):** Agent 5 (may depend on Agent 1)
- **Round 4 (Final cleanup):** Agent 6

### Estimated Total Time:
- **Sequential:** ~12-15 hours
- **Parallel (6 agents):** ~4-5 hours
- **Optimized Parallel (3 rounds):** ~3-4 hours

