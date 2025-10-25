# EPI Documentation

**Last Updated:** January 25, 2025
**Status:** Production Ready ✅ - RIVET Sweep Phase System Complete, MCP Phase Export/Import, Timeline-Based Phase Architecture, Clean UI Design, Full-Featured Journal Editor, ARCForm Keyword Integration, All Build Errors Resolved

This directory contains comprehensive documentation for the EPI (Evolving Personal Intelligence) project - an 8-module intelligent journaling system built with Flutter.

## 🆕 Latest Updates (January 25, 2025)

  **📝 Full-Featured Journal Editor Integration**

  Upgraded journal entry creation to use the complete JournalScreen with all modern capabilities:
  - **Media Support** - Camera, gallery, voice recording integration
  - **Location Picker** - Add location data to journal entries
  - **Phase Editing** - Change phase for existing entries
  - **LUMARA Integration** - In-journal LUMARA assistance and suggestions
  - **OCR Text Extraction** - Extract text from photos automatically
  - **Keyword Discovery** - Automatic keyword extraction and management
  - **Metadata Editing** - Edit date, time, location, and phase for existing entries
  - **Draft Management** - Auto-save and recovery functionality
  - **Smart Save Behavior** - Only prompts to save when changes are detected

  **🎯 ARCForm Keyword Integration Fix**

  Fixed ARCForm visualization to use actual keywords from journal entries:
  - **MCP Bundle Integration** - ARCForms now update with real keywords when loading MCP bundles
  - **Phase Regime Detection** - Properly detects phases from MCP bundle phase regimes
  - **Journal Entry Filtering** - Filters journal entries by phase regime date ranges
  - **Real Keyword Display** - Shows actual emotion and concept keywords from user's writing
  - **Fallback System** - Graceful fallback to recent entries if no phase regime found

*For detailed technical information, see [Phase Visualization with Actual Keywords](./updates/Phase_Visualization_Actual_Keywords_Jan2025.md)*

## Previous Updates (January 24, 2025)

  **🎨 Phase Visualization with Actual Journal Keywords + Aggregation**

  Enhanced phase constellation visualization to display real emotion keywords and concept keywords from user's journal entries:
  - **Personal Keyword Display** - User's current phase shows actual emotion keywords extracted from their journal entries
  - **Concept Keyword Aggregation** - Extracts higher-level concepts from phrase patterns (e.g., "I did this" → Innovation)
  - **Demo/Example Phases** - Other phases continue to use hardcoded keywords for showcase purposes
  - **Smart Blank Nodes** - Maintains consistent 20-node helix structure, filling blanks as keywords are discovered
  - **Progressive Enhancement** - Constellation becomes richer as user writes more journal entries
  - **Phase-Aware Filtering** - Keywords filtered by phase association (Discovery, Expansion, etc.)
  - **Dual Keyword System** - Combines emotion keywords with aggregated concept keywords
  - **10 Concept Categories** - Innovation, Breakthrough, Awareness, Growth, Challenge, Achievement, Connection, Transformation, Recovery, Exploration
  - **Timeline Visualization Fixes** - Fixed "TODAY" label cut-off with optimized spacing and font sizing
  - **Phase Management** - Delete duplicate phases with confirmation dialog and proper cleanup
  - **Clean UI Design** - Moved Write and Calendar buttons to Timeline app bar for better UX
  - **Simplified Navigation** - Removed elevated Write tab, streamlined bottom navigation
  - **Fixed Tab Arrangement** - Corrected tab mapping after Write tab removal
  - **Graceful Fallback** - Returns blank nodes if keyword extraction fails, preventing crashes

*For detailed technical information, see [Phase Visualization with Actual Keywords](./updates/Phase_Visualization_Actual_Keywords_Jan2025.md)*

## Previous Updates (January 22, 2025)

**🌟 RIVET Sweep Phase System - Timeline-Based Architecture**

Complete implementation of next-generation phase management with timeline-based architecture:
- **PhaseRegime Timeline System** - Phases are now timeline segments rather than entry-level labels
- **RIVET Sweep Algorithm** - Automated phase detection using change-point detection and semantic analysis
- **MCP Phase Export/Import** - Full compatibility with phase regimes in MCP bundles
- **PhaseIndex Service** - Efficient timeline lookup for phase resolution at any timestamp
- **Segmented Phase Backfill** - Intelligent phase inference across historical entries
- **Phase Timeline UI** - Visual timeline interface for phase management and editing
- **RIVET Sweep Wizard** - Guided interface for automated phase detection and review
- **Backward Compatibility** - Legacy phase fields preserved during migration
- **Chat History Integration** - LUMARA chat histories fully supported in MCP bundles
- **Phase Regime Service** - Complete CRUD operations for phase timeline management
- **Build System Fixed** - All compilation errors resolved, iOS build successful
- **MCP Schema Compatibility** - Fixed constructor parameter mismatches and type issues
- **ReflectiveNode Integration** - Updated MCP bundle parser for new node types

**🔧 Phase Dropdown & Auto-Capitalization**

Enhanced user experience with structured phase selection and automatic capitalization:
- **Phase Dropdown Implementation** - Replaced phase text field with structured dropdown containing all 6 ATLAS phases
- **Data Integrity** - Prevents typos and invalid phase entries by restricting selection to valid options
- **User Experience** - Clean, intuitive interface for phase selection in journal editor
- **Phase Options** - Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough
- **Auto-Capitalization** - Added TextCapitalization.sentences to journal text field and chat inputs
- **Word Capitalization** - Added TextCapitalization.words to location, phase, and keyword fields
- **Comprehensive Coverage** - Applied to all major text input fields across the application

**🔧 Timeline Ordering & Timestamp Fixes**

Fixed critical timeline ordering issues caused by inconsistent timestamp formats:
- **Timestamp Format Standardization** - All MCP exports now use consistent ISO 8601 UTC format with 'Z' suffix
- **Robust Import Parsing** - Import service handles both old malformed timestamps and new properly formatted ones
- **Timeline Chronological Order** - Entries now display in correct chronological order (oldest to newest)
- **Group Sorting Logic** - Timeline groups sorted by newest entry, ensuring recent entries appear at top
- **Backward Compatibility** - Existing exports with malformed timestamps automatically corrected during import
- **Export Service Enhancement** - Added `_formatTimestamp()` method ensuring all future exports have proper formatting
- **Import Service Enhancement** - Added `_parseTimestamp()` method with robust error handling and fallbacks
- **Corrected Export File** - Created `journal_export_20251020_CORRECTED.zip` with fixed timestamps for testing

**📦 MCP Export/Import System - Ultra-Simplified & Streamlined**

Completely redesigned the MCP (Memory Container Protocol) system for maximum simplicity:
- **Single File Format** - All data exported to one `.zip` file only (no more .mcpkg or .mcp/ folders)
- **Simplified UI** - Clean management screen with two main actions: Create Package, Restore Package
- **No More Media Packs** - Eliminated complex rolling media pack system and confusing terminology
- **Direct Photo Handling** - Photos stored directly in the package with simple file paths
- **iOS Compatibility** - Uses .zip extension for perfect iOS Files app integration
- **Legacy Cleanup** - Removed 9 complex files and 2,816 lines of legacy code
- **Better Performance** - Faster export/import with simpler architecture
- **User-Friendly** - Clear navigation to dedicated export/import screens
- **Ultra-Simple** - Only .zip files - no confusion, no complex options

**🌟 LUMARA v2.0 - Multimodal Reflective Engine Complete**

Transformed LUMARA from placeholder responses to a true multimodal reflective partner:
- **Multimodal Intelligence** - Indexes journal entries, drafts, photos, audio, video, and chat history
- **Semantic Similarity** - TF-IDF based matching with recency, phase, and keyword boosting
- **Phase-Aware Prompts** - Contextual reflections that adapt to Recovery, Breakthrough, Consolidation phases
- **Historical Connections** - Links current thoughts to relevant past moments with dates and context
- **Cross-Modal Patterns** - Detects themes across text, photos, audio, and video content
- **Visual Distinction** - Formatted responses with sparkle icons and clear AI/user text separation
- **Graceful Fallback** - Helpful responses when no historical matches found
- **MCP Bundle Integration** - Parses and indexes exported data for reflection
- **Full Configuration UI** - Complete settings interface with similarity thresholds and lookback periods
- **Performance Optimized** - < 1s response time with efficient similarity algorithms

*For detailed technical information, see [Changelog - LUMARA v2.0](../changelog/CHANGELOG.md#lumara-v20-multimodal-reflective-engine---january-20-2025)*

## Previous Updates (October 19, 2025)

**🐛 Draft Creation Bug Fix - Smart View/Edit Mode**

Fixed critical bug where viewing timeline entries automatically created unwanted drafts:
- **View-Only Mode** - Timeline entries now open in read-only mode by default
- **Smart Draft Creation** - Drafts only created when actively writing/editing content
- **Edit Mode Switching** - Users can switch from viewing to editing with "Edit" button
- **Clean Drafts Folder** - No more automatic draft creation when just reading entries
- **Crash Protection** - Drafts still saved when editing and app crashes/closes
- **Better UX** - Clear distinction between viewing and editing modes
- **Backward Compatibility** - Existing writing workflows unchanged

*For detailed technical information, see [Bug Tracker - Draft Creation Fix](../bugtracker/Bug_Tracker.md#draft-creation-bug-fix---january-19-2025)*

## Previous Updates (January 17, 2025)

**🔄 RIVET & SENTINEL Extensions - Unified Reflective Analysis**

Complete implementation of unified reflective analysis system extending RIVET and SENTINEL to process all reflective inputs:
- **Extended Evidence Sources** - RIVET now processes `draft` and `lumaraChat` evidence sources alongside journal entries
- **ReflectiveEntryData Model** - New unified data model supporting journal entries, drafts, and chat conversations
- **Source Weighting System** - Different confidence weights for different input types (journal=1.0, draft=0.6, chat=0.8)
- **Draft Analysis Service** - Specialized processing for draft journal entries with phase inference and confidence scoring
- **Chat Analysis Service** - Specialized processing for LUMARA conversations with context keywords and conversation quality
- **Unified Analysis Service** - Comprehensive analysis across all reflective sources with combined recommendations
- **Enhanced SENTINEL Analysis** - Source-aware pattern detection with weighted clustering, persistent distress, and escalation detection
- **Backward Compatibility** - Existing journal-only workflows remain unchanged
- **Phase Inference** - Automatic phase detection from content patterns and context
- **Confidence Scoring** - Dynamic confidence calculation based on content quality and recency
- **Build Success** - All type conflicts resolved, iOS build working with full integration ✅

*For detailed technical information, see [Changelog - RIVET & SENTINEL Extensions](../changelog/CHANGELOG.md#rivet--sentinel-extensions---january-17-2025)*

**🧠 MIRA v0.2 - Enhanced Semantic Memory System**

Complete implementation of next-generation semantic memory with advanced privacy controls, multimodal support, and intelligent retrieval:
- **ULID-based Identity** - Deterministic, sortable IDs replacing UUIDs throughout the system
- **Provenance Tracking** - Complete audit trail with source, agent, operation, and trace ID
- **Privacy-First Design** - Domain scoping with 5-level privacy classification and PII protection
- **Intelligent Retrieval** - Composite scoring with phase affinity, hard negatives, and memory caps
- **Multimodal Support** - Unified text/image/audio pointers with embedding references
- **CRDT Sync** - Conflict-free replicated data types for multi-device synchronization
- **VEIL Integration** - Automated memory lifecycle management with decay and deduplication
- **MCP Bundle v1.1** - Enhanced export with Merkle roots, selective export, and integrity verification
- **Migration System** - Seamless v0.1 to v0.2 migration with backward compatibility
- **Observability** - Comprehensive metrics, golden tests, and health monitoring
- **Documentation** - Complete API docs with examples and developer guides

*For detailed technical information, see [MIRA v0.2 Documentation](../architecture/EPI_Architecture.md#mira-v02---enhanced-semantic-memory-architecture)*

**🔄 RIVET & SENTINEL Extensions - Unified Reflective Analysis**

Complete implementation of unified reflective analysis system extending RIVET and SENTINEL to process all reflective inputs:
- **Extended Evidence Sources** - RIVET now processes `draft` and `lumaraChat` evidence sources alongside journal entries
- **ReflectiveEntryData Model** - New unified data model supporting journal entries, drafts, and chat conversations
- **Source Weighting System** - Different confidence weights for different input types (journal=1.0, draft=0.6, chat=0.8)
- **Draft Analysis Service** - Specialized processing for draft journal entries with phase inference and confidence scoring
- **Chat Analysis Service** - Specialized processing for LUMARA conversations with context keywords and conversation quality
- **Unified Analysis Service** - Comprehensive analysis across all reflective sources with combined recommendations
- **Enhanced SENTINEL Analysis** - Source-aware pattern detection with weighted clustering, persistent distress, and escalation detection
- **Backward Compatibility** - Existing journal-only workflows remain unchanged
- **Phase Inference** - Automatic phase detection from content patterns and context
- **Confidence Scoring** - Dynamic confidence calculation based on content quality and recency
- **Build Success** - All type conflicts resolved, iOS build working with full integration ✅

*For detailed technical information, see [Changelog - RIVET & SENTINEL Extensions](../changelog/CHANGELOG.md#rivet--sentinel-extensions---january-17-2025)*

**🛡️ Comprehensive App Hardening & Stability (January 16, 2025)**

Complete implementation of production-ready stability improvements:
- **Null Safety & Type Casting** - Fixed all null cast errors with safe JSON utilities and type conversion helpers
- **Hive Database Stability** - Added ArcformPhaseSnapshot adapter with proper JSON string storage for geometry data
- **RIVET Map Normalization** - Fixed Map type casting issues with safe conversion utilities
- **Timeline Performance** - Eliminated RenderFlex overflow errors and reduced rebuild spam with buildWhen guards
- **Model Registry** - Created comprehensive model validation to eliminate "Unknown model ID" errors
- **MCP Media Extraction** - Unified media key handling across MIRA/MCP systems
- **Photo Persistence** - Enhanced photo relinking with localIdentifier storage and metadata matching
- **Comprehensive Testing** - 100+ unit, widget, and integration tests covering all critical functionality
- **Build System** - Resolved all naming conflicts and syntax errors for clean builds

**📸 Lazy Photo Relinking System**

Complete implementation of intelligent photo persistence with on-demand relinking:
- **Lazy Relinking** - Photos are only relinked when users open entries, not during import or timeline loads
- **Comprehensive Content Fallback** - Importer now uses content.narrative → content.text → metadata.content fallback chain
- **iOS Native Bridge** - New PhotoLibraryBridge with photoExistsInLibrary and findPhotoByMetadata methods
- **Timestamp-Based Recovery** - Extracts creation dates from placeholder IDs for intelligent photo matching
- **Cross-Device Support** - Photos can be recovered across devices using metadata matching
- **Performance Optimized** - Only relinks photos when needed, improving app performance
- **Cooldown Protection** - 5-minute cooldown prevents excessive relinking attempts
- **Graceful Fallback** - Shows "Photo unavailable" placeholders when photos cannot be relinked

*For detailed technical information, see [Changelog - Lazy Photo Relinking System](../changelog/CHANGELOG.md#lazy-photo-relinking-system---january-16-2025)*

**VEIL-EDGE Phase-Reactive Restorative Layer**

Complete implementation of VEIL-EDGE - a fast, cloud-orchestrated variant of VEIL that maintains restorative rhythm without on-device fine-tuning:
- **Phase Group Routing** - D-B (Discovery↔Breakthrough), T-D (Transition↔Discovery), R-T (Recovery↔Transition), C-R (Consolidation↔Recovery)
- **ATLAS → RIVET → SENTINEL Pipeline** - Intelligent routing through confidence, alignment, and safety states
- **Hysteresis & Cooldown Logic** - 48-hour cooldown and stability requirements prevent phase thrashing
- **SENTINEL Safety Modifiers** - Watch mode (safe variants, 10min cap), Alert mode (Safeguard+Mirror only)
- **RIVET Policy Engine** - Alignment tracking, phase change validation, stability analysis
- **Prompt Registry v0.1** - Complete phase families with system prompts, styles, and block templates
- **LUMARA Integration** - Seamless chat system integration with VEIL-EDGE routing
- **Privacy-First Design** - Echo-filtered inference only, no raw journal data leaves device
- **Edge Device Compatible** - Designed for iPhone-class and other computationally constrained environments
- **API Contract** - Complete REST API with /route, /log, /registry endpoints

*For detailed technical information, see [VEIL-EDGE Architecture Documentation](./architecture/VEIL_EDGE_Architecture.md)*

**Media Persistence & Inline Photo System**

Complete media handling system with chronological photo flow:
- **Media Persistence** - Photos with analysis data now persist when saving journal entries
- **Hyperlink Text Retention** - `*Click to view photo*` and `📸 **Photo Analysis**` text preserved in content
- **Inline Photo Insertion** - Photos insert at cursor position instead of bottom for natural storytelling
- **Chronological Flow** - Photos appear exactly where placed in text with compact thumbnails
- **Clickable Thumbnails** - Tap thumbnails to open full photo viewer with complete analysis
- **UI/UX Improvements** - Date/time/location editor moved to top, auto-capitalization added
- **Media Conversion System** - `MediaConversionUtils` converts between attachment types and `MediaItem`

*For detailed technical information, see [Changelog - Media Persistence & Inline Photo System](../changelog/CHANGELOG.md#media-persistence--inline-photo-system---january-12-2025)*

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
