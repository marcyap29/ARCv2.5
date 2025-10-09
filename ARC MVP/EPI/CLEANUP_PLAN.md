# Repository Cleanup Plan - Lead Software Engineer Review

## Executive Summary
The repository contains **5.2GB** of data with significant bloat from build artifacts, redundant files, and orphaned code. This cleanup will reduce repository size by ~3.5GB and improve maintainability.

## Critical Issues Identified

### 1. 🚨 **MASSIVE BUILD ARTIFACTS** (3.5GB+)
**Location**: `third_party/llama.cpp/build-*`
**Size**: ~3.5GB total
**Issue**: Multiple platform build artifacts that should be in .gitignore

**Build Directories to Remove**:
- `build-ios-device` (207M)
- `build-ios-sim` (584M) 
- `build-macos` (584M)
- `build-tvos-device` (207M)
- `build-tvos-sim` (584M)
- `build-visionos` (208M)
- `build-visionos-sim` (587M)
- `build-ios-ninja` (24K)
- `build-ios-device-metal` (1.2M)

### 2. 🧪 **ORPHANED TEST FILES** (53 test files)
**Location**: Root directory and scattered throughout
**Issue**: Test files in wrong locations, duplicate test patterns

**Files to Review/Remove**:
- `test_lumara_integration.dart`
- `test_native_bridge.dart`
- `test_qwen_integration.dart`
- `test_mcp_export.dart`
- `test_pattern_analysis.dart`
- `test_arc_mvp.dart`
- `test_force_quit_recovery.dart`
- `test_phase_quiz_fix.dart`
- `test_attribution_simple.dart`
- `test_spiral_debug.dart`

### 3. 📚 **REDUNDANT DOCUMENTATION** (50+ MD files)
**Location**: `Overview Files/` and scattered
**Issue**: Multiple versions of same docs, archived duplicates

**Areas to Clean**:
- `Overview Files/Archive/` - Likely contains outdated docs
- Duplicate success reports
- Multiple changelog versions

### 4. 🔧 **ORPHANED SCRIPTS** 
**Location**: Root directory
**Issue**: One-off scripts that should be in proper directories

**Files to Review**:
- `download_*.py` scripts
- `fix_*.sh` scripts
- `update_*.sh` scripts
- `recovery_script.dart`

### 5. 🗂️ **DUPLICATE WORKSPACE FILES**
**Issue**: Multiple `.code-workspace` files
**Files**:
- `EPI_v1.code-workspace`
- `EPI_v1a.code-workspace` 
- `EPI_1vb.code-workspace`

## Cleanup Actions

### Phase 1: Immediate Cleanup (Safe)
1. **Remove Build Artifacts**
   ```bash
   rm -rf third_party/llama.cpp/build-*
   ```

2. **Update .gitignore**
   ```gitignore
   # Build artifacts
   third_party/llama.cpp/build-*
   build/
   *.framework
   *.dSYM
   ```

3. **Consolidate Workspace Files**
   - Keep only `EPI_1vb.code-workspace`
   - Remove `EPI_v1.code-workspace` and `EPI_v1a.code-workspace`

### Phase 2: Code Organization
1. **Move Test Files to Proper Location**
   - Move root-level `test_*.dart` files to `test/` directory
   - Organize by feature area

2. **Consolidate Scripts**
   - Move all `*.py` and `*.sh` scripts to `scripts/` directory
   - Remove one-off scripts that are no longer needed

3. **Clean Documentation**
   - Archive outdated docs in `Overview Files/Archive/`
   - Keep only current, relevant documentation
   - Remove duplicate success reports

### Phase 3: Code Quality
1. **Remove Dead Code**
   - Unused imports
   - Commented-out code blocks
   - Unused functions/classes

2. **Consolidate Duplicate Code**
   - Merge similar utility functions
   - Remove redundant service implementations

## Expected Results

### Size Reduction
- **Before**: 5.2GB
- **After**: ~1.7GB
- **Savings**: ~3.5GB (67% reduction)

### Improved Organization
- Cleaner directory structure
- Proper test organization
- Consolidated documentation
- Removed build artifacts from version control

### Better Maintainability
- Easier to navigate codebase
- Reduced clone time
- Cleaner git history
- Better separation of concerns

## Implementation Priority

1. **HIGH**: Remove build artifacts (immediate 3.5GB savings)
2. **HIGH**: Update .gitignore to prevent future bloat
3. **MEDIUM**: Organize test files
4. **MEDIUM**: Consolidate documentation
5. **LOW**: Remove dead code

## Risk Assessment

**LOW RISK**:
- Build artifacts removal (can be regenerated)
- Documentation cleanup
- Script organization

**MEDIUM RISK**:
- Test file reorganization (need to verify test runner still works)
- Dead code removal (need to verify no hidden dependencies)

**HIGH RISK**:
- None identified

## Next Steps

1. **Backup current state** (git commit)
2. **Execute Phase 1** (immediate cleanup)
3. **Test build process** to ensure nothing broken
4. **Execute Phase 2** (organization)
5. **Execute Phase 3** (code quality)
6. **Update documentation** with new structure

