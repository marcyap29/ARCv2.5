# EPI ARC MVP - Changelog

**Version:** 2.1.51
**Last Updated:** December 12, 2025

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.51 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [2.1.51] - December 12, 2025

### **LUMARA Persona System** - ✅ Complete

4 distinct personality modes for LUMARA:
- **Auto** (🔄): Adapts based on context - sentinel alerts, emotional tone, readiness
- **The Companion** (🤝): Warm, supportive presence for daily reflection
- **The Therapist** (💜): Deep therapeutic support with gentle pacing
- **The Strategist** (🎯): Sharp, analytical insights with 5-section structured output
- **The Challenger** (⚡): Direct feedback that pushes growth

**UI**: Settings → LUMARA → LUMARA Persona (radio selection)

**Status**: ✅ Complete  
**Branch**: `dev-lumara-endprompt`

---

## [2.1.50] - December 12, 2025

### **Scroll Navigation UX Enhancement** - ✅ Complete

Visible floating scroll buttons added across all scrollable screens.

#### Highlights

**⬆️ Scroll-to-Top Button**
- Up-arrow FAB appears when scrolled down from top
- Gray background with white icon
- Stacked above scroll-to-bottom button

**⬇️ Scroll-to-Bottom Button**
- Down-arrow FAB appears when not at bottom
- Smooth 300ms animation with easeOut curve
- Both buttons on right side of screen

**Available In**: LUMARA Chat, Journal Timeline, Journal Entry Editor

#### Files Modified
- `lib/arc/chat/ui/lumara_assistant_screen.dart`
- `lib/arc/ui/timeline/timeline_view.dart`
- `lib/ui/journal/journal_screen.dart`

**Status**: ✅ Complete  
**Branch**: `uiux-updates`

---

## [2.1.49] - December 12, 2025

### **Splash Screen & Bug Reporting Enhancements** - ✅ Complete

- **Animated Splash Screen**: 8-second spinning 3D phase visualization
- **Shake to Report Bug**: Native iOS shake detection for feedback
- **Consolidation Fix**: Lattice edges properly connected

---

## [2.1.48] - December 11, 2025

### **Phase System Overhaul & UI/UX Improvements** - ✅ Complete

- **RIVET-Based Phase Calculation**: Sophisticated analysis with 10-day windows
- **Phase Persistence Fixes**: Dropdown changes now persist properly
- **Content Cleanup**: Disabled automatic hashtag injection
- **Navigation Bar Redesign**: 4-button layout (LUMARA | Phase | Journal | +)
- **Phase Tab Restructuring**: Cards moved from Journal to Phase tab
- **Interactive Timeline**: Tappable phase segments with entry navigation
- **Code Consolidation**: Unified 3D viewer across screens

**Status**: ✅ Complete  
**Branch**: `dev-uiux-improvements`

---

## Recent Release Summary

### [2.1.47] - December 10, 2025
**Google Sign-In Configuration (iOS)** - Fixed OAuth client and URL scheme to prevent crashes.

### [2.1.46] - December 9, 2025
**Priority 3 Complete: Authentication & Security** - Firebase Auth, per-entry/per-chat rate limiting, admin privileges.

### [2.1.45] - December 7, 2025
**Priority 2 Complete: Firebase API Proxy** - API keys secured in Firebase Functions while LUMARA runs on-device.

### [2.1.42] - November 29, 2025
**LUMARA Persistence** - Fixed in-journal comments persistence with dedicated `lumaraBlocks` field.

### [2.1.35] - November 2025
**Phase Detection Refactor** - Versioned inference pipeline with expanded keyword detection.

---

## Quick Links

- **Current Release**: [v2.1.48 Details](CHANGELOG_part1.md#2148---december-11-2025)
- **Authentication**: [v2.1.46 Details](CHANGELOG_part1.md#2146---december-9-2025)
- **Firebase Proxy**: [v2.1.45 Details](CHANGELOG_part1.md#2145---december-7-2025)
- **LUMARA Persistence**: [v2.1.42 Details](CHANGELOG_part2.md#2142---november-29-2025)
- **Phase Detection**: [v2.1.35 Details](CHANGELOG_part2.md#2135---november-2025)

---

## Version History

| Version | Date | Key Feature |
|---------|------|-------------|
| 2.1.51 | Dec 12, 2025 | LUMARA Persona System |
| 2.1.50 | Dec 12, 2025 | Scroll Navigation UX |
| 2.1.49 | Dec 12, 2025 | Splash Screen & Bug Reporting |
| 2.1.48 | Dec 11, 2025 | Phase System Overhaul & UI/UX |
| 2.1.47 | Dec 10, 2025 | Google Sign-In iOS Fix |
| 2.1.46 | Dec 9, 2025 | Authentication & Security |
| 2.1.45 | Dec 7, 2025 | Firebase API Proxy |
| 2.1.44 | Dec 4, 2025 | LUMARA Auto-Scroll UX |
| 2.1.43 | Dec 3-4, 2025 | Subject Drift & Endings Fixes |
| 2.1.42 | Nov 29, 2025 | LUMARA Persistence |
| 2.1.41 | Nov 2025 | Chat UI & Data Persistence |
| 2.1.40 | Nov 2025 | Web Access Safety Layer |
| 2.1.35 | Nov 2025 | Phase Detection Refactor |
| 2.1.30 | Nov 2025 | Saved Chats Restoration |
| 2.1.20 | Oct 2025 | Automatic Phase Hashtags |
| 2.1.16 | Oct 2025 | LUMARA Favorites System |
| 2.1.9 | Feb 2025 | Memory Attribution & PII Scrubbing |
| 2.0.0 | Oct 2025 | RIVET & SENTINEL Extensions |
