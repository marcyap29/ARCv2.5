# EPI Documentation

**Last Updated:** January 12, 2025
**Status:** Production Ready ✅

This directory contains comprehensive documentation for the EPI (Evolving Personal Intelligence) project - an 8-module intelligent journaling system built with Flutter.

## 🆕 Latest Updates (January 12, 2025)

**System Reversion - Stable Journal Editor**

Reverted to stable journal editor with large photo boxes for optimal user experience:
- **Large Photo Display** - Photos display as detailed boxes at bottom of entries with full analysis
- **Date/Time/Location Editor** - Editing controls positioned at top of entry when editing existing entries
- **Stable Text Editing** - Normal TextField with visible cursor and reliable text selection
- **Photo Analysis** - Complete iOS Vision analysis with clickable thumbnails and detailed information
- **Timeline Integration** - Photos persist and display correctly when viewing from timeline
- **Clean Layout** - Eliminated spacing issues and complex inline systems for predictable behavior

*For detailed technical information, see [Changelog - System Reversion](../changelog/CHANGELOG.md#system-reversion---stable-journal-editor---january-12-2025)*

**Timeline Editor Elimination - Full Journal Integration**

Eliminated the limited timeline editor and integrated full journal functionality:
- **Limited Editor Removal** - Removed restricted `JournalEditView` from timeline navigation
- **Full Journal Access** - Timeline entries now navigate directly to complete `JournalScreen`
- **Feature Consistency** - Same capabilities whether creating new entries or editing existing ones
- **Code Simplification** - Eliminated duplicate journal editor implementations (3,362+ lines removed)
- **Enhanced UX** - Users get complete journaling experience with LUMARA integration and multimodal support

*For detailed technical information, see [Changelog - Timeline Editor Elimination](../changelog/CHANGELOG.md#timeline-editor-elimination---full-journal-integration---january-12-2025)*

**LUMARA Cloud API Enhancement - Reflective Intelligence Core**

Enhanced the cloud API (Gemini) with the comprehensive LUMARA Reflective Intelligence Core system prompt:
- **EPI Framework Integration** - Full integration with all 8 EPI systems (ARC, PRISM, ATLAS, MIRA, AURORA, VEIL)
- **Developmental Orientation** - Focus on trajectories and growth patterns rather than judgments
- **Narrative Dignity** - Core principles for preserving user agency and psychological safety
- **Integrative Reflection** - Enhanced output style for coherent, compassionate insights
- **Reusable Templates** - Created modular prompt system for cloud APIs

*For detailed technical information, see [Bug Tracker - LUMARA Cloud API Enhancement](../bugtracker/Bug_Tracker.md#lumara-cloud-api-prompt-enhancement)*

**UI/UX Critical Fixes**

Resolved multiple critical UI/UX issues affecting core journal functionality:
- **Text Cursor Alignment** - Fixed cursor misalignment in journal text input field with proper styling
- **Gemini API Integration** - Fixed JSON formatting errors preventing cloud API usage
- **Model Management** - Restored delete buttons for downloaded models in LUMARA settings
- **LUMARA Integration** - Fixed text insertion and cursor management for AI insights
- **Keywords System** - Verified and maintained working Keywords Discovered functionality
- **Provider Selection** - Fixed automatic provider selection and error handling
- **Error Prevention** - Added proper validation to prevent RangeError and other crashes

*For detailed technical information, see [UI_UX_FIXES_JAN_2025.md](../bugtracker/UI_UX_FIXES_JAN_2025.md)*

**Drafts Feature Implementation**

Comprehensive draft management system for journal entries:
- **Auto-Save Functionality** - Continuous auto-save every 2 seconds while typing
- **App Lifecycle Integration** - Drafts saved on app pause, close, or crash
- **Multi-Select Operations** - Select and delete multiple drafts at once
- **Draft Management UI** - Dedicated screen for managing all saved drafts
- **Seamless Integration** - Drafts button in journal screen for easy access
- **Draft Recovery** - Automatic recovery of drafts on app restart
- **Content Overwriting** - Same draft continuously updated with new content
- **Rich Metadata** - Draft preview with date, attachments, and emotions
- **Navigation Flow** - Click any draft to open in journal format
- **Auto-Cleanup** - Old drafts automatically cleaned up (7-day retention)
- **Crash Protection** - Drafts persist through app crashes and force-quits

---

**RIVET Deterministic Recompute System**

Major enhancement implementing true undo-on-delete behavior with deterministic recompute pipeline:
- **Deterministic Recompute** - Complete rewrite using pure reducer pattern for mathematical correctness
- **Undo-on-Delete** - True rollback capability for any event deletion with O(n) performance
- **Undo-on-Edit** - Complete state reconstruction for event modifications
- **Enhanced Models** - RivetEvent with eventId/version, RivetState with gate tracking
- **Event Log Storage** - Complete history persistence with checkpoint optimization
- **Enhanced Telemetry** - Recompute metrics, operation tracking, clear explanations
- **Comprehensive Testing** - 12 unit tests covering all scenarios
- **Mathematical Correctness** - All ALIGN/TRACE formulas preserved exactly
- **Bounded Indices** - All values stay in [0,1] range
- **Monotonicity** - TRACE only increases when adding events
- **Independence Tracking** - Different day/source boosts evidence weight
- **Novelty Detection** - Keyword drift increases evidence weight
- **Sustainment Gating** - Triple criterion (thresholds + sustainment + independence)
- **Transparency** - Clear "why not" explanations for debugging
- **Safety** - Graceful degradation if recompute fails
- **Performance** - O(n) recompute with optional checkpoints
- **User Experience** - True undo capability for journal entries
- **Data Integrity** - Complete state reconstruction ensures correctness
- **Debugging** - Enhanced telemetry provides clear insights
- **Maintainability** - Pure functions make testing and debugging easier

---

**LUMARA Settings Lockup Fix**

Critical UI stability fix for LUMARA settings screen:
- **Root Cause Fixed** - Missing return statement in `_checkInternalModelAvailability` method
- **Timeout Protection** - Added 10-second timeout to prevent hanging during API config refresh
- **Error Handling** - Improved error handling to prevent UI lockups
- **UI Stability** - LUMARA settings screen no longer locks up when Llama is downloaded
- **Model Availability** - Proper checking of downloaded models
- **User Experience** - Smooth navigation in LUMARA settings

---

**ECHO Integration + Dignified Text System**

Production-ready ECHO module integration with dignified text generation and user dignity protection:
- **ECHO Module Integration** - All user-facing text uses ECHO for dignified generation
- **6 Core Phases** - Reduced from 10 to 6 non-triggering phases for user safety
- **DignifiedTextService** - Service for generating dignified text using ECHO module
- **Phase-Aware Analysis** - Uses ECHO for dignified system prompts and suggestions
- **Discovery Content** - ECHO-generated popup content with gentle fallbacks
- **Trigger Prevention** - Removed potentially harmful phase names and content
- **Fallback Safety** - Dignified content even when ECHO fails
- **User Dignity** - All text respects user dignity and avoids triggering phrases

**Previous: Native iOS Photos Framework Integration + Universal Media Opening System**

Production-ready native iOS Photos framework integration for all media types:
- **Native iOS Photos Integration** - Direct media opening in iOS Photos app for all media types
- **Universal Media Support** - Photos, videos, and audio files with native iOS framework
- **Smart Media Detection** - Automatic media type detection and appropriate handling
- **Broken Link Recovery** - Comprehensive broken media detection and recovery system
- **Multi-Method Opening** - Native search, ID extraction, direct file, and search fallbacks
- **Cross-Platform Support** - iOS native methods with Android fallbacks
- **Method Channels** - Flutter ↔ Swift communication for media operations
- **PHAsset Search** - Native iOS Photos library search by filename

**Previous: Complete Multimodal Processing System + Thumbnail Caching**

Production-ready multimodal processing with comprehensive photo analysis:
- **iOS Vision Integration** - Pure on-device processing using Apple's Core ML + Vision Framework
- **Thumbnail Caching System** - Memory + file-based caching with automatic cleanup
- **Clickable Photo Thumbnails** - Direct photo opening in iOS Photos app
- **Keypoints Visualization** - Interactive display of feature analysis details
- **MCP Format Integration** - Structured data storage with pointer references
- **Cross-Platform UI** - Works in both journal screen and timeline editor

## 📚 Documentation Structure

### 📋 [Project](./project/)
Core project documentation and briefs
- **PROJECT_BRIEF.md** - Main project overview and current status
- **README.md** - Project-level documentation
- **Status_Update.md** - Project status snapshots
- **ChatGPT_Mobile_Optimizations.md** - Mobile optimization documentation
- **Model_Recognition_Fixes.md** - Model detection fixes
- **Speed_Optimization_Guide.md** - Performance optimization guide
- **MCP_Multimodal_Expansion_Status.md** - Multimodal MCP expansion plan
  - Chat message model enhancements
  - MCP export/import for multimodal content
  - llama.cpp multimodal integration
  - UI/UX enhancements for media attachments

### 🏗️ [Architecture](./architecture/)
System architecture and design documentation
- **EPI_Architecture.md** - Complete 8-module EPI system architecture
  - ARC (Journaling), PRISM (Multi-Modal), ECHO (Response Layer)
  - ATLAS (Phase Detection), MIRA (Narrative Intelligence), AURORA (Circadian)
  - VEIL (Self-Pruning), RIVET (Risk Validation)
  - On-Device LLM Architecture (llama.cpp + Metal)
  - Navigation & UI Architecture
- **MIRA_Basics.md** - Instant phase & themes answers without LLM
  - Quick Answers System (sub-second responses)
  - Phase Detection & Geometry Mapping
  - Streak Tracking & Recent Entry Summaries
  - MMCO (Minimal MIRA Context Object)
- **Constellation_Arcform_Renderer.md** - Polar coordinate visualization system
  - Phase-Specific Layouts (spiral, flower, weave, glow core, fractal, branch)
  - k-NN Edge Weaving Algorithm
  - 3-Controller Animation System
  - 8-Color Emotion Palette

### 🐛 [Bug Tracker](./bugtracker/)
Bug tracking and resolution documentation
- **Bug_Tracker.md** - Current bug tracker (main file)
- **Bug_Tracker Files/** - Historical bug tracker snapshots
  - Bug_Tracker-1.md through Bug_Tracker-8.md (chronological)
  - Tracks all resolved issues from critical to enhancement-level

### 📊 [Status](./status/)
Current status and session documentation
- **STATUS.md** - Current project status
- **STATUS_UPDATE.md** - Status updates and progress
- **SESSION_SUMMARY.md** - Development session summaries

### 📝 [Changelog](./changelog/)
Version history and change documentation
- **CHANGELOG.md** - Main changelog
- **Changelogs/** - Historical changelog files
  - CHANGELOG1.md - Earlier version history

### 📖 [Guides](./guides/)
User and developer guides
- **Arc_Prompts.md** - ARC journaling prompts and templates
- **MVP_Install.md** - Installation and setup guide
- **MULTIMODAL_INTEGRATION_GUIDE.md** - Complete multimodal processing system guide
- **Model_Download_System.md** - On-device AI model management
  - Python CLI Download Manager
  - Flutter Download State Service
  - Resumable Downloads & Checksum Verification
  - Model Manifest & Metadata

### 📄 [Reports](./reports/)
Success reports and technical achievements
- **LLAMA_CPP_MODERNIZATION_SUCCESS_REPORT.md** - Modern C API integration
- **LLAMA_CPP_UPGRADE_STATUS_REPORT.md** - Upgrade progress tracking
- **LLAMA_CPP_UPGRADE_SUCCESS_REPORT.md** - Complete upgrade documentation
- **MEMORY_MANAGEMENT_SUCCESS_REPORT.md** - Memory management fixes
- **ROOT_CAUSE_FIXES_SUCCESS_REPORT.md** - Root cause analysis and fixes

### 🗄️ [Archive](./archive/)
Archived documentation and historical records
- **ARCHIVE_ANALYSIS.md** - Archive organization documentation
- **Archive/** - Historical project documentation
  - ARC MVP Implementation reports
  - Reference documents (LUMARA, MCP, Memory Features)
  - Development tools and configuration

## 🎯 Quick Start

1. **New to EPI?** Start with [PROJECT_BRIEF.md](./project/PROJECT_BRIEF.md)
2. **Understanding Architecture?** Read [EPI_Architecture.md](./architecture/EPI_Architecture.md)
3. **Troubleshooting?** Check [Bug_Tracker.md](./bugtracker/Bug_Tracker.md)
4. **Installation?** Follow [MVP_Install.md](./guides/MVP_Install.md)
5. **Status Updates?** See [STATUS.md](./status/STATUS.md)

## 🏆 Current Status

**Production Ready** - October 10, 2025

### Latest Achievements
- ✅ MIRA Basics (Instant phase/themes without LLM)
- ✅ Constellation Arcform Renderer (Polar Coordinate System)
- ✅ Model Download System (Resumable downloads with verification)
- ✅ Multimodal MCP Expansion (In Progress on `multimodal` branch)
- ✅ Branch Consolidation (52 commits merged, 88% repo cleanup)
- ✅ On-Device LLM (llama.cpp + Metal)
- ✅ All Critical Issues Resolved
- ✅ Modern C API Integration Complete
- ✅ Memory Management Fixes Complete

### Key Features
- Complete 8-module architecture (ARC→PRISM→ECHO→ATLAS→MIRA→AURORA→VEIL→RIVET)
- On-device AI inference with llama.cpp + Metal acceleration
- MIRA Basics: Quick answers without LLM (300x faster)
- Constellation visualization with 6 phase-specific layouts
- Model download system with resumable downloads
- Privacy-first design with local processing
- MCP Memory System for conversation persistence
- Advanced prompt engineering system

## 📖 Reading Path

### For Developers
1. [PROJECT_BRIEF.md](./project/PROJECT_BRIEF.md) - Get project context
2. [EPI_Architecture.md](./architecture/EPI_Architecture.md) - Understand system design
3. [Bug_Tracker.md](./bugtracker/Bug_Tracker.md) - Learn from issues
4. [Reports](./reports/) - Review technical achievements

### For Users
1. [PROJECT_BRIEF.md](./project/PROJECT_BRIEF.md) - Overview and current status
2. [MVP_Install.md](./guides/MVP_Install.md) - Installation instructions
3. [Arc_Prompts.md](./guides/Arc_Prompts.md) - Journaling guidance

### For Contributors
1. [STATUS.md](./status/STATUS.md) - Current project state
2. [CHANGELOG.md](./changelog/CHANGELOG.md) - Version history
3. [Bug_Tracker.md](./bugtracker/Bug_Tracker.md) - Known issues and resolutions
4. [EPI_Architecture.md](./architecture/EPI_Architecture.md) - System architecture

## 🔧 Technical Documentation

### MIRA Basics System
- **Quick Answers**: [MIRA_Basics.md](./architecture/MIRA_Basics.md)
- **MMCO Building**: Minimal MIRA Context Object construction
- **Phase Detection**: Automatic phase determination from history
- **Streak Tracking**: Daily journaling streak computation
- **Performance**: 300-500x faster than LLM for common queries

### On-Device LLM System
- **llama.cpp Integration**: [EPI_Architecture.md](./architecture/EPI_Architecture.md#on-device-llm-architecture)
- **Model Download**: [Model_Download_System.md](./guides/Model_Download_System.md)
- **Metal Acceleration**: Lines 13-51 in EPI_Architecture.md
- **Model Management**: Lines 138-175 in EPI_Architecture.md
- **Provider Selection**: Lines 176-206 in EPI_Architecture.md

### Constellation Visualization
- **Complete System**: [Constellation_Arcform_Renderer.md](./architecture/Constellation_Arcform_Renderer.md)
- **Polar Layout Algorithm**: Phase-specific coordinate generation
- **k-NN Edge Weaving**: Graph-based connection system
- **Animation System**: Three independent controllers (twinkle, fade-in, selection pulse)
- **ATLAS Phase Integration**: 6 phases with geometric mapping (spiral, flower, weave, glow core, fractal, branch)
- **Emotion Palette**: 8-color emotional visualization system

### Multimodal MCP System
- **Expansion Plan**: [MCP_Multimodal_Expansion_Status.md](./project/MCP_Multimodal_Expansion_Status.md)
- **Chat Message Enhancement**: Adding multimodal attachments support
- **MCP Export/Import**: Handling images, audio, video in bundles
- **llama.cpp Integration**: Multimodal model support

### Privacy Architecture
- **On-Device Processing**: All inference happens locally
- **PII Detection**: Automatic redaction of sensitive data
- **Privacy Guardrails**: Module-specific privacy adaptations
- **MCP Export**: Privacy-preserving data export

## 📞 Support

- **Issues**: Check [Bug_Tracker.md](./bugtracker/Bug_Tracker.md) for known issues
- **Status**: See [STATUS.md](./status/STATUS.md) for current project state
- **Updates**: Follow [CHANGELOG.md](./changelog/CHANGELOG.md) for version history

---

**Project**: EPI (Evolving Personal Intelligence)
**Framework**: Flutter (Cross-platform iOS/Android)
**Architecture**: 8-Module System with On-Device AI
**Status**: Production Ready ✅
