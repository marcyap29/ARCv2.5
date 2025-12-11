# EPI ARC MVP - Changelog

**Version:** 2.1.48
**Last Updated:** December 11, 2025

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.48 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [2.1.48] - December 11, 2025

### **Phase System Overhaul & UI/UX Improvements** - ✅ Complete

This major release includes comprehensive improvements to the Phase system, navigation, and user experience.

#### Highlights

**🔬 RIVET-Based Phase Calculation**
- Replaced simple phase counting with sophisticated RIVET analysis
- Entry dropdown corrections ("chisel") now feed into RIVET calculations
- Consistent trend detection across Phase tab and Analysis sections
- 10-day rolling window for phase regimes

**🔧 Phase Persistence Fixes**
- Fixed phase dropdown changes not persisting after save/overwrite
- ARCX import now properly restores all phase-related fields
- Added `_currentEntryOverride` state management for local changes

**🧹 Content Cleanup**
- **Disabled** automatic `#consolidation`, `#discovery` hashtag injection
- User content stays clean - phase tracked via proper fields instead

**🎨 Navigation Bar Redesign**
- 4-button layout: LUMARA | Phase | Journal | +
- Removed active highlights, gray backgrounds
- LUMARA uses gold logo icon

**📱 Phase Tab Restructuring**
- Moved "Phase Transition Readiness" card from Journal to Phase tab
- Moved "Change Phase" button from Journal to Phase tab
- Added "Past Phases" and "Example Phases" sections
- Entire tab now scrollable

**🔗 Interactive Timeline**
- Phase timeline bars are now tappable
- Shows phase details, entry count, date range
- Entries hyperlinked for direct navigation

**✅ Sign-In Enhancement**
- Added back navigation AppBar to Sign-In screen

**🔄 Code Consolidation**
- Unified 3D viewer (`FullScreenPhaseViewer`) shared between Journal and Phase
- Text standardization: "ARCForm" → "Phase" across UI

#### Files Modified
See [CHANGELOG_part1.md](CHANGELOG_part1.md) for complete file list.

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
