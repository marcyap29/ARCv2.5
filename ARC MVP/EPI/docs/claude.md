# EPI Documentation Context Guide

**Version:** 2.1.50
**Last Updated:** December 12, 2025
**Current Branch:** `uiux-updates`

---

## Quick Reference

| Document | Purpose | Path |
|----------|---------|------|
| **README.md** | Project overview | `/docs/README.md` |
| **ARCHITECTURE.md** | System architecture | `/docs/ARCHITECTURE.md` |
| **FEATURES.md** | Comprehensive features | `/docs/FEATURES.md` |
| **UI_UX.md** | UI/UX documentation | `/docs/UI_UX.md` |
| **CHANGELOG.md** | Version history | `/docs/CHANGELOG.md` |
| **git.md** | Git history & commits | `/docs/git.md` |
| **backend.md** | Backend architecture | `/docs/backend.md` |

---

## Core Documentation

### 📖 EPI Documentation
Main overview: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/README.md`
- Read to understand what the software does

### 🏗️ Architecture
Adhere to: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/ARCHITECTURE.md`
- 5-module system (ARC, PRISM, MIRA, ECHO, AURORA)
- Technical stack and data flow

### 📋 Features Guide
Reference: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/FEATURES.md`
- All key features for context
- Core capabilities and integrations

### 🎨 UI/UX Documentation
Review before changes: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/UI_UX.md`
- Prevents reinventing the wheel
- Current UI patterns and components

---

## Version Control

### 📝 Git History
Location: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/git.md`
- Key commits, pushes, merges
- Branch structure and backup strategy

### 📜 Changelog
Location: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/CHANGELOG.md`
- Split into parts for manageability:
  - `CHANGELOG_part1.md` - December 2025 (v2.1.43 - v2.1.50)
  - `CHANGELOG_part2.md` - November 2025 (v2.1.28 - v2.1.42)
  - `CHANGELOG_part3.md` - Earlier versions

---

## Backend & Infrastructure

### 🔧 Backend Documentation
Location: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/backend.md`

### Firebase Functions
- Functions: `/Users/mymac/Software Development/ARCv.04/functions`
- Config: `/Users/mymac/Software Development/ARCv.04/.firebaserc`
- Settings: `/Users/mymac/Software Development/ARCv.04/firebase.json`

---

## Bug Tracking

### 🐛 Bugtracker
Location: `/Users/mymac/Software Development/ARCv.04/ARC MVP/EPI/docs/bugtracker`
- All bugs encountered and fixes
- `bug_tracker.md` - Main tracker
- `records/` - Individual bug records

---

## Priority Implementation Status

### ✅ Priority 3 Complete (v2.1.46)
- Firebase Authentication (Anonymous, Google, Email/Password)
- Per-entry rate limiting (5 LUMARA comments per entry)
- Per-chat rate limiting (20 LUMARA messages per chat)
- Admin privileges system

### ✅ Priority 2 Complete (v2.1.45)
- Firebase API Proxy implementation
- API keys secured in Cloud Functions
- On-device LUMARA with full journal access

### Archive (in `/docs/archive/priority2-testing/`)
- `PRIORITY_2_API_REFACTOR.md`
- `PRIORITY_2_AUTH_TODO.md`
- `PRIORITY_1_1.5_TESTING.md`
- `PRIORITY_1.5_COMPLETION_SUMMARY.md`
- `UI_INTEGRATION_COMPLETE.md`

---

## Recent Updates (v2.1.50)

### Scroll Navigation
- **Visible scroll buttons** (up/down arrows) for all scrollable screens
- Available in: LUMARA Chat, Journal Timeline, Journal Entry Editor
- Stacked vertically on right side of screen

### Previous Updates (v2.1.49)
- Animated splash screen with spinning 3D phase
- Shake to report bug feature
- Consolidation lattice edge fix

### Phase System (v2.1.48)
- RIVET-based phase calculation
- 10-day rolling window for phase regimes
- 4-button navigation layout (LUMARA | Phase | Journal | +)
- Interactive phase timeline with entry navigation

---

## Documentation Update Rules

When asked to update documentation:
1. Update all documents listed in this file
2. Version documents as necessary
3. Replace outdated context
4. Archive deprecated content to `/docs/archive/`
5. Keep changelog split into parts if too large

---

## Key Services

### Subscription Management
- Service: `lib/services/subscription_service.dart`
- UI Widget: `lib/ui/subscription/lumara_subscription_status.dart`
- Access Control: `lib/services/phase_history_access_control.dart`

### Phase System
- Phase Analysis: `lib/ui/phase/phase_analysis_view.dart`
- Phase Regime: `lib/services/phase_regime_service.dart`
- RIVET Service: `lib/services/rivet_sweep_service.dart`

### Scroll Navigation
- Chat: `lib/arc/chat/ui/lumara_assistant_screen.dart`
- Timeline: `lib/arc/ui/timeline/timeline_view.dart`
- Journal: `lib/ui/journal/journal_screen.dart`

---

*Last synchronized: December 12, 2025 | Version: 2.1.50*
