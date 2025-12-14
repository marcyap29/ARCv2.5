# EPI ARC MVP - Changelog

**Version:** 2.1.54
**Last Updated:** December 13, 2025

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.53 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [2.1.54] - December 13, 2025

### **Export Format Alignment & Standardization** - ✅ Complete

- **Aligned ZIP (.zip/.mcpkg) and ARCX (.arcx) export formats**: Both formats now export identical data elements
- **Standardized file structure to date-bucketed format**:
  * Journal entries: `Entries/{YYYY}/{MM}/{DD}/{slug}.json`
  * Chat sessions: `Chats/{YYYY}/{MM}/{DD}/{session-id}.json` (with nested messages)
  * Extended data: `extensions/` directory (unified from `PhaseRegimes/`)
- **Added to MCP/ZIP format**:
  * `links` field: Relationship mapping (media_ids, chat_thread_ids) for navigation
  * `date_bucket` field: Date organization metadata (YYYY/MM/DD format)
  * `slug` field: URL-friendly identifier for entries
  * `content_parts` and `metadata`: Added to chat messages (aligned with ARCX format)
  * Slug generation with collision handling for duplicate titles
- **Added to ARCX format**:
  * `health_association`: Health data association in journal entries (aligned with MCP format)
  * `timestamp`: Additional timestamp field for compatibility
  * `media`: Embedded media metadata array for self-containment (aligned with MCP format)
  * `edges.jsonl`: Relationship edges file (aligned with MCP format)
  * Health stream export: Exports filtered health streams to `streams/health/` directory
- **Import services updated for backward compatibility**:
  * MCP import: Supports both new `Entries/` bucketed structure and legacy `nodes/journal/` flat structure
  * MCP import: Supports both new `Chats/` bucketed structure with nested messages and legacy `nodes/chat/` structure
  * ARCX import: Supports both new `extensions/` directory and legacy `PhaseRegimes/` directory
- **Both formats now include**:
  * All journal entry fields (emotion, keywords, phase, lumaraBlocks, etc.)
  * Chats with content_parts and metadata (nested in session files)
  * Media with full metadata
  * Phase regimes, RIVET state, Sentinel state, ArcForm timeline, LUMARA favorites
  * Health associations and health streams (filtered by journal entry dates)
  * Links for relationship mapping
  * Date buckets for organization
  * Edges for relationship tracking

**Status**: ✅ Complete  
**Files Modified**:
- `lib/mira/store/arcx/services/arcx_export_service_v2.dart` - Added health_association, embedded media, health streams, edges.jsonl, extensions/ directory
- `lib/mira/store/arcx/services/arcx_import_service_v2.dart` - Backward compatibility for extensions/ and PhaseRegimes/
- `lib/mira/store/mcp/export/mcp_pack_export_service.dart` - Added links, date_bucket, slug, date-bucketed structure, nested chat messages
- `lib/mira/store/mcp/import/mcp_pack_import_service.dart` - Backward compatibility for bucketed and legacy structures

### **Voice Journal Mode Enhancements** - ✅ Complete

- **Fixed duplicate LUMARA responses**: Removed markdown text from content when saving (saved as InlineBlocks instead)
- **Fixed keyword saving**: Now reads keywords from KeywordExtractionCubit state (same mechanism as regular journal mode)
- **Fixed summary generation**: Implements JSON creation, PII scrubbing before summary, and PII restoration after
- **Fixed TTS consistency**: Writes LUMARA response to UI first, then TTS the content with proper error handling
- **Microphone state indicators**:
  * Green icon: Ready to transcribe (idle state)
  * Red icon: Listening (active)
  * Yellow/amber icon: Processing (thinking state)
  * Grayed-out icon: Speaking (TTS active, disabled)
- **Disabled microphone during processing/speaking**: Prevents user from pressing mic until transcription and TTS complete
- **Changed flow**: User must wait for transcription/TTS to complete before next input (no auto-resume)
- **LUMARA text color**: Updated to purple in InlineReflectionBlock (matches regular journal mode)
- **Memory attribution support**: Captures and stores attribution traces for LUMARA responses in voice journal mode

**Status**: ✅ Complete  
**Branch**: `dev-voice-updates`  
**Files Modified**:
- `lib/arc/chat/voice/audio_io.dart` - Enhanced sentence capitalization after periods
- `lib/arc/ui/journal_capture_view.dart` - Added textCapitalization.sentences, keyboard dismissal in voice mode
- `lib/arc/chat/ui/voice_chat_panel.dart` - Added state-based microphone button styling
- `lib/arc/chat/voice/push_to_talk_controller.dart` - Added guards to prevent taps during processing
- `lib/arc/chat/voice/voice_orchestrator.dart` - Added speaking state callbacks, fixed TTS flow
- `lib/arc/chat/voice/voice_chat_service.dart` - Fixed summary generation with PII scrubbing
- `lib/arc/chat/voice/voice_chat_pipeline.dart` - Added TTS error handling
- `lib/arc/chat/voice/prism_scrubber.dart` - Added scrubWithMapping and restore methods
- `lib/arc/core/widgets/keyword_analysis_view.dart` - Fixed keyword saving to read from cubit state
- `lib/arc/ui/journal_capture_view.dart` - Fixed duplicate LUMARA responses, removed markdown
- `lib/ui/journal/widgets/inline_reflection_block.dart` - Updated LUMARA text color to purple

### **Onboarding Permissions Page** - ✅ Complete

- Added dedicated permissions page to onboarding flow as the final step
- Requests all necessary permissions upfront (Microphone, Photos, Camera, Location)
- Beautiful UI with icons and explanations for each permission
- "Get Started" button requests all permissions at once
- Ensures ARC appears in all relevant iOS Settings immediately after onboarding
- Optional "Skip for now" option to complete onboarding without granting permissions

**Status**: ✅ Complete  
**Files Modified**:
- `lib/shared/ui/onboarding/onboarding_view.dart` - Added `_OnboardingPermissionsPage` widget
- `lib/shared/ui/onboarding/onboarding_cubit.dart` - Made `completeOnboarding()` public, updated page navigation logic

### **Jarvis-Style Voice Chat UI** - ✅ Complete

- Glowing voice indicator with ChatGPT-style pulsing animation
- Microphone button added to LUMARA chat AppBar
- State-aware colors (Red→Orange→Green)
- Voice system fully functional (STT, TTS, intent routing, PII scrubbing)

**Status**: ✅ Complete  
**Branch**: `dev-voice-updates`

---

## [2.1.52] - December 13, 2025

### **Settings Reorganization & Health Integration** - ✅ Complete

- Unified Advanced Settings screen with combined Analysis (6 tabs)
- Simplified LUMARA section with inline controls
- Health→LUMARA integration (sleep/energy affects behavior)
- Removed background music feature

**Status**: ✅ Complete  
**Branch**: `dev-voice-updates` (merged to main)

---

## [2.1.51] - December 12, 2025

### **LUMARA Persona System** - ✅ Complete

4 distinct personality modes for LUMARA with auto-detection.

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
| 2.1.54 | Dec 13, 2025 | Export Format Standardization |
| 2.1.53 | Dec 13, 2025 | Jarvis-Style Voice Chat UI |
| 2.1.52 | Dec 13, 2025 | Settings Reorganization & Health Integration |
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
