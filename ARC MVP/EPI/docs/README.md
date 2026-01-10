# EPI Documentation

**Last Updated:** January 2, 2026  
**Version:** 2.1.82

---

## Overview

Welcome to the EPI (Evolving Personal Intelligence) documentation. This directory contains comprehensive documentation for the EPI MVP intelligent journaling application.

### Recent Highlights (v2.1.83)

- **🔔 Temporal Notifications System**: Multi-cadence notification system with phase-aware insights
  - Daily resonance prompts, monthly thread reviews, 6-month arc views, yearly becoming summaries
  - Comprehensive settings UI for configuring all notification preferences
  - Deep linking routes notification taps to appropriate screens
  - Privacy-first: All processing happens locally
- **🔑 Enhanced Keyword Extraction**: Removed SimpleKeywordExtractor, unified on EnhancedKeywordExtractor with curated library
  - All keywords now come from curated library with intensity values
  - Phase-aware keyword selection based on current developmental phase
  - RIVET gating for quality control
- **🎯 Simplified LUMARA Actions**: Removed "More Depth" and "Soften Tone" buttons for cleaner UI
  - Focus on essential actions: Regenerate, Continue thought, Explore options

### Previous Highlights (v2.1.61)

- **🏗️ Code Consolidation**: ARC internal architecture reorganized to mirror EPI's 5-module structure
- **📦 Internal Modules**: New `lib/arc/internal/` structure with PRISM, MIRA, AURORA, and ECHO submodules
- **🧹 Code Cleanup**: Removed duplicates, consolidated services, improved organization

### Previous Highlights (v2.1.54)

- **📦 Export Format Standardization**: Unified ZIP and ARCX with date-bucketed file structure
- **🔄 Import Backward Compatibility**: Supports both new bucketed and legacy flat structures
- **🎤 Jarvis-Style Voice Chat**: Talk to LUMARA with glowing, throbbing voice indicator
- **💊 Health→LUMARA Integration**: Sleep quality and energy level influence LUMARA's tone
- **⚙️ Settings Reorganization**: Unified Advanced Settings with Combined Analysis view
- **🎭 LUMARA Persona**: Choose response style - Companion, Grounded, Strategist, or Challenger

## Documentation Structure

### 📄 Core Documentation Files

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete system architecture overview
  - 5-module architecture (ARC, PRISM, MIRA, ECHO, AURORA)
  - Technical stack and deployment
  - Data flow and integration patterns
  - Security and privacy architecture

- **[FEATURES.md](FEATURES.md)** - Comprehensive features guide
  - Core journaling features
  - AI features (LUMARA assistant with web access)
  - Visualization features (ARCForm constellations)
  - Analysis features (phase detection, pattern recognition)
  - Privacy & security features
  - Data management (export/import)

- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes
  - Complete changelog with version history
  - Recent updates and improvements
  - Bug fixes and enhancements

- **[BUGTRACKER.md](BUGTRACKER.md)** - Bug tracking and issue management
  - Resolved issues
  - Known issues
  - Bug resolution history

### 📁 Additional Resources

- **`/bugtracker/`** - Active bug tracking
  - `bug_tracker.md` - Main bug tracker
  - `records/` - Individual bug records
  - `archive/` - Archived bug reports

- **`/archive/`** - Archived documentation
  - Historical documentation
  - Legacy architecture docs
  - Previous versions and updates

---

## Quick Start

### For Developers

1. **Architecture**: Start with [ARCHITECTURE.md](ARCHITECTURE.md) to understand the system design
2. **Features**: Review [FEATURES.md](FEATURES.md) to understand capabilities
3. **Recent Changes**: Check [CHANGELOG.md](CHANGELOG.md) for latest updates

### For Users

1. **Features**: See [FEATURES.md](FEATURES.md) for available features
2. **Updates**: Check [CHANGELOG.md](CHANGELOG.md) for new features and improvements

---

## Version Information

**Current Version:** 2.1.83
**Last Major Update:** January 2, 2026 (Temporal Notifications System - Multi-Cadence Phase-Aware Notifications)

### Recent Highlights

- 📜 **Scroll Navigation (v2.1.50)**: Visible floating scroll buttons
  - Up-arrow button to scroll to top (appears when scrolled down)
  - Down-arrow button to scroll to bottom (appears when not at bottom)
  - Available in Chat, Timeline, and Entry Editor
- 🎉 **Phase System Overhaul (v2.1.48)**: Comprehensive Phase improvements
  - RIVET-based phase calculation for accurate trend detection
  - 10-day rolling window for phase regimes
  - "Chisel" effect: Entry overrides feed into RIVET
  - Navigation redesign: 4-button layout (LUMARA | Phase | Journal | +)
  - Phase Transition Readiness and Change Phase moved to Phase tab
  - Interactive timeline with hyperlinked entries
  - Disabled automatic phase hashtag injection
- 🔐 **Google Sign-In Configured (Dec 10, 2025)**: Updated iOS OAuth client and URL scheme
- 🎉 **Priority 3 Complete (v2.1.46)**: Authentication & Security Implementation
  - Firebase Auth: Anonymous, Google, Email/Password sign-in
  - Per-entry rate limiting: 5 LUMARA comments per journal entry (free tier)
  - Per-chat rate limiting: 20 LUMARA messages per chat (free tier)
  - Complete sign-in UI with account management
- 🎉 **Priority 2 Complete (v2.1.45)**: Firebase API Proxy Implementation
  - API keys now securely hidden in Firebase Functions
  - LUMARA runs on-device with full journal access (chat + in-journal reflections)
  - Simple `proxyGemini` function handles API key management
  - No user configuration needed for API access
  - Both LUMARA modes fully functional: Chat assistant and in-journal reflections
  - See [Backend Architecture](backend.md) for details
- 🆕 **Chat UI Improvements**: Scrollable text input, auto-minimize on outside click, send button always accessible
- 🆕 **Chat History Import Fixes**: Enhanced logging, proper archived handling, message verification
- 🆕 **Saved Chats Navigation**: Direct navigation from favorites, session restoration from saved chats
- 🆕 **LUMARA Blocks Persistence (v2.1.42)**: Complete persistence fix for LUMARA in-journal comments
  - Added dedicated `lumaraBlocks` field to JournalEntry model (HiveField 27)
  - Automatic migration from legacy `metadata.inlineBlocks` format
  - Purple "LUMARA" tag displayed in timeline for entries with comments
  - Blocks persist across app restarts and imports/exports
  - Fixed async/await issues across codebase
- 🆕 **Timeline Entry Protection**: Entries open read-only by default with Edit button to unlock
- 🆕 **Video Insertion Functionality**: Complete end-to-end video insertion with duration extraction and playback
- 🆕 **Export Bug Fix**: Resolved issue where "export all entries" would export filtered subsets instead of all entries
- ✅ **Video Playback Fixes**: Crash prevention and thumbnail support for video attachments
- ✅ **Advanced Analytics Updates**: Medical tab added, toggle removed from Settings
- ✅ **Advanced Analytics View**: 5-part horizontal tab system (Patterns, AURORA, VEIL, SENTINEL, Medical)
- ✅ **Medical Tracking**: Full health data integration with Overview, Details, and Medications
- ✅ **LUMARA Reflective Queries**: Three EPI-standard anti-harm queries for resilience, temporal reflection, and theme analysis
- ✅ **Notification System Foundation**: Time Echo reminders and Active Window detection (backend ready)
- ✅ **CreatedAt Preservation**: Original creation time never changes on updates, ensuring historical accuracy
- ✅ **Phase Detection Refactor**: Complete overhaul of phase detection system with versioned inference pipeline
- ✅ **Versioned Phase Inference**: Phase detection now uses versioned pipeline (v1) with full traceability
- ✅ **Phase Regimes Integration**: Phase changes aggregated into stable regimes to prevent erratic day-to-day changes
- ✅ **User Phase Overrides**: Manual phase selection via dropdown for existing entries with lock mechanism
- ✅ **Expanded Keyword Detection**: 60-120 keywords per phase for improved detection accuracy
- ✅ **Export/Import Support**: All phase fields properly exported/imported in ARCX and ZIP formats
- ✅ **Legacy Data Migration**: Automatic migration of older entries with phase inference

---

## Key Features

### Core Capabilities

- **Intelligent Journaling**: Text, voice, photo, and video journaling with OCR
- **AI Assistant (LUMARA)**: Context-aware responses with persistent chat memory
- **Pattern Recognition**: Keyword extraction, phase detection, and emotional mapping
- **3D Visualization**: ARCForm constellations showing journal themes
- **Privacy-First**: On-device processing, PRISM scrubbing, correlation-resistant PII protection, and encryption
- **Data Portability**: MCP export/import for AI ecosystem interoperability

### Export/Import

- **Format Support**: Standard ZIP (.zip) format
- **Complete Content**: All data types exported (entries, media, chats, extended data)
- **Media Pack Organization**: Configurable media packs (50-500 MB) for efficient storage in both formats
- **Extended Data**: Phase Regimes, RIVET state, Sentinel state, ArcForm timeline, LUMARA Favorites
- **Category Preservation**: Favorite categories (answers, chats, journal entries) preserved

---

## Documentation Standards

- All documentation includes version numbers and last updated dates
- Status documents older than 3 months are archived
- Feature documentation is kept current with implementation
- Architecture docs reflect the current system state

---

## Related Links

- [Architecture Overview](ARCHITECTURE.md)
- [Features Guide](FEATURES.md)
- [Changelog](CHANGELOG.md)
- [Bug Tracker](BUGTRACKER.md)

---

**Status**: ✅ Production Ready with Authentication
**Last Updated**: December 13, 2025
**Version**: 2.1.54
