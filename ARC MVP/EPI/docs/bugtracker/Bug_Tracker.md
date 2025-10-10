# Bug Tracker - EPI Project

**Last Updated:** October 10, 2025
**Current Branch:** `star-phases`
**Status:** Active Development

---

## <¯ Current Status

###  Recently Resolved

1. **Framework 'Pods_Runner' not found** (Oct 10, 2025)
   - **Issue:** iOS build failing with missing CocoaPods framework
   - **Resolution:** Ran `pod install` to install all iOS dependencies (15 dependencies, 19 total pods)
   - **Status:**  RESOLVED - Project builds successfully

2. **Branch Merge Conflicts** (Oct 10, 2025)
   - **Issue:** Documentation conflicts during `on-device-inference` ’ `main` ’ `star-phases` merge
   - **Resolution:** Successfully merged 52 commits from `on-device-inference` including:
     - 88% repository cleanup (4.6GB saved)
     - Documentation reorganization (52 files ’ `docs/` structure)
     - ChatGPT LUMARA mobile optimizations
     - Performance optimizations (5s faster responses)
   - **Status:**  RESOLVED - All merges complete

3. **Documentation Organization** (Oct 10, 2025)
   - **Issue:** "Overview Files" folder needed reorganization
   - **Resolution:** Restored complete documentation structure:
     - `docs/architecture/` - System architecture
     - `docs/archive/` - Archived documents (31 files)
     - `docs/bugtracker/` - Bug tracking (8 files)
     - `docs/changelog/` - Change logs (2 files)
     - `docs/guides/` - User guides (2 files)
     - `docs/project/` - Project documentation
     - `docs/reports/` - Status reports (5 files)
     - `docs/status/` - Project status (3 files)
   - **Status:**  RESOLVED

---

## =€ Recent Enhancements

### Constellation Arcform Renderer (Oct 10, 2025)

**New Features:**
- `ConstellationArcformRenderer`: Main renderer for constellation visualization
- `ConstellationLayoutService`: Polar coordinate layout system with geometric masking
- `ConstellationPainter`: Custom painter for star rendering and connections
- `PolarMasks`: Geometric masking system for intelligent star placement
- `GraphUtils`: Utility functions for graph calculations and layout
- `ConstellationDemo`: Demo/test implementation

**Files Added:**
- `lib/features/arcforms/constellation/constellation_arcform_renderer.dart`
- `lib/features/arcforms/constellation/constellation_layout_service.dart`
- `lib/features/arcforms/constellation/constellation_painter.dart`
- `lib/features/arcforms/constellation/polar_masks.dart`
- `lib/features/arcforms/constellation/graph_utils.dart`
- `lib/features/arcforms/constellation/constellation_demo.dart`

**Files Modified:**
- `lib/features/arcforms/arcform_renderer_cubit.dart`
- `lib/features/arcforms/arcform_renderer_state.dart`
- `lib/features/arcforms/arcform_renderer_view.dart`

**Commit:** `071833a` - 2,357 insertions, 23 deletions

---

## =Ë Known Issues

### Non-Critical

1. **llama.cpp Submodule Changes**
   - **Issue:** Deleted file `build-xcframework.sh` showing as modified in submodule
   - **Impact:** Low - Does not affect functionality
   - **Workaround:** Ignore submodule changes
   - **Status:**   TRACKED - Can be safely ignored

2. **Test Failures**
   - **Issue:** Some test failures due to mock setup
   - **Impact:** Low - Tests need mock configuration updates
   - **Next Steps:** Update mock setup for affected tests
   - **Status:**   TRACKED

---

## = Recent Commits (Last 10)

```
071833a feat: add constellation arcform renderer with polar layout system
382c4d0 chore: update flutter plugins dependencies after merge
2ebe9ac Merge main into star-phases: Bring in 52 commits from on-device-inference
5986871 docs: restore documentation organization - 52 files restructured
32dbbe1 fix: model recognition and UI state synchronization
8437a10 docs: comprehensive documentation update for Oct 9 optimizations
d4d0e04 feat: implement ChatGPT LUMARA-on-mobile optimizations
7eade8f perf: aggressive speed optimizations - 5s faster responses
d30bd62 perf: optimize on-device LLM inference performance
5e08ed6 DOCS: Complete documentation organization - 52 files restructured
```

---

## =Ê Repository Health

### Branch Status
- **Current Branch:** `star-phases`
- **Ahead of origin:** 56 commits (ready to push)
- **Build Status:**  Passing
- **Tests:**   Some failures (non-critical)

### Recent Optimizations
- **Repository Cleanup:** 88% size reduction (4.6GB saved)
- **Performance:** 90% faster inference (5-10s ’ 0.5-1.5s)
- **GPU Utilization:** 100% (28/28 layers on Metal)
- **Documentation:** Complete reorganization with 52 files restructured

---

## = Bug Reporting Guidelines

When reporting bugs, please include:

1. **Environment:**
   - Device type (e.g., iPhone 16 Pro, simulator)
   - iOS version
   - Flutter version
   - Build configuration (debug/profile/release)

2. **Steps to Reproduce:**
   - Clear, numbered steps
   - Expected behavior
   - Actual behavior

3. **Logs/Screenshots:**
   - Relevant error messages
   - Console output
   - Screenshots if applicable

4. **Impact Assessment:**
   - Critical: Blocks functionality
   - High: Major feature affected
   - Medium: Minor feature affected
   - Low: Cosmetic or non-blocking

---

## =Þ Support Resources

- **Documentation:** `/docs/` directory structure
- **Architecture:** `/docs/architecture/EPI_Architecture.md`
- **Project Brief:** `/docs/project/PROJECT_BRIEF.md`
- **Changelog:** `/docs/changelog/CHANGELOG.md`

---

**Maintained By:** EPI Development Team
**Version:** 0.5.0-alpha
