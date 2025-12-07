# EPI Documentation

**Last Updated:** December 7, 2025  
**Version:** 2.1.45

---

## Overview

Welcome to the EPI (Evolving Personal Intelligence) documentation. This directory contains comprehensive documentation for the EPI MVP intelligent journaling application.

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

**Current Version:** 2.1.45
**Last Major Update:** December 7, 2025 (Priority 2 Complete: Firebase API Proxy)

### Recent Highlights

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
- **Privacy-First**: On-device processing, PII detection, and encryption
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

**Status**: ✅ Production Ready
**Last Updated**: December 7, 2025
**Version**: 2.1.45
