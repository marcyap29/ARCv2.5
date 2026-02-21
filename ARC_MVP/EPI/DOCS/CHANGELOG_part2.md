# EPI ARC MVP - Changelog (Part 2: November 2025)

**Version:** 2.1.48
**Last Updated:** December 11, 2025
**Coverage:** November 2025 releases (v2.1.28 - v2.1.42)

---

## [2.1.42] - November 29, 2025

### **LUMARA In-Journal Comments Persistence** - Complete

#### Core Persistence Fixes
- **Added `lumaraBlocks` Field to JournalEntry Model**: 
  - Added `@HiveField(27)` for `lumaraBlocks: List<InlineBlock>` in JournalEntry
  - Updated `copyWith`, `toJson`, `fromJson` to include lumaraBlocks
  - Regenerated Hive adapters to support new field
- **Made InlineBlock a Hive Type**: 
  - Added `@HiveType(typeId: 103)` to InlineBlock class
  - Stored `attributionTraces` as JSON string for Hive compatibility
  - Regenerated InlineBlockAdapter for proper serialization
- **Fixed Migration Code**: 
  - `_normalize()` now properly migrates `metadata.inlineBlocks` → `lumaraBlocks`
  - Persists migrated entries immediately during `getAllJournalEntries()`
  - Removes `inlineBlocks` from metadata after migration to use `lumaraBlocks` as single source of truth
- **Fixed Persistence Methods**: 
  - `updateJournalEntry()` now removes `inlineBlocks` from metadata
  - `_persistLumaraBlocksToEntry()` in journal_screen.dart saves blocks correctly
  - `getJournalEntryById()` is now async and normalizes entries with migration

#### Import/Export Fixes
- **MCP Import Service**: 
  - `_parseLumaraBlocks()` correctly converts `inlineBlocks` to `lumaraBlocks`
  - Removes `inlineBlocks` from metadata during import
  - Properly saves blocks to dedicated field
- **ARCX Import Service**: 
  - Added `await` to all `getJournalEntryById()` calls
  - Ensures blocks are properly loaded and migrated

#### UI Improvements
- **LUMARA Tag in Timeline**: 
  - Added `hasLumaraBlocks` field to `TimelineEntry` model
  - Purple "LUMARA" tag appears on entries with LUMARA blocks
  - Tag displays in timeline view with proper styling

#### Performance Improvements
- **UI Thread Yielding**: 
  - Added `Future.microtask` every 20 entries during normalization
  - Prevents white screen blocking during data loading
  - Deferred timeline loading to avoid blocking startup

### Breaking Changes
- `getJournalEntryById()` is now async - all call sites must use `await`
- `getAllJournalEntries()` is async - all call sites must use `await`

---

## [2.1.41] - November 2025

### **Chat UI Improvements & Data Persistence Fixes** - Complete

#### Chat Input Improvements
- **Scrollable Text Input**: Made chat text input scrollable with max height constraint
  - TextField wrapped in ConstrainedBox with maxHeight: 120px (~5 lines)
  - Prevents send button from being blocked when pasting large text
  - Text scrolls internally when content exceeds 5 lines
  - Proper button alignment with CrossAxisAlignment.end
- **Auto-Minimize on Outside Click**: Added ChatGPT-like auto-minimize behavior
  - Input area automatically minimizes when clicking outside chat area
  - Only minimizes if text field is empty
  - Maintains input visibility when text is present

#### Chat History Import Fixes
- **Enhanced Import Logging**: Added comprehensive logging for chat import debugging
  - Logs file discovery, chat details, message counts, and import status
  - Tracks processed, imported, skipped, and error counts
- **Archived Chat Handling**: Fixed imported chats being archived by default
  - Only archives chats if explicitly marked as archived in export
  - Ensures imported chats are visible in active chat list

#### Journal Entry Persistence
- **LUMARA Blocks Saving**: Fixed LUMARA comments and user responses not persisting
  - Blocks now properly saved to entry metadata when saving/updating
  - Preserves existing blocks when updating entries (unless explicitly cleared)
- **Timeline Entry Protection**: Made timeline entries read-only by default
  - Entries from timeline open in view-only mode
  - Edit button in app bar to unlock for editing
  - Prevents accidental edits when viewing saved entries

---

## [2.1.40] - November 2025

### **Web Access Safety Layer & Attribution Display Improvements** - Complete

#### Web Access Feature
- **Web Access Safety Layer**: Added comprehensive web access safety prompt to LUMARA Master Prompt
  - Primary source priority: Always prioritizes user's personal context first
  - Explicit need check: Only searches web when information unavailable internally
  - Content safety boundaries: Automatic filtering of violent, graphic, or harmful content
  - Research mode filter: Prioritizes peer-reviewed sources for research queries
  - Containment framing: Safe handling of sensitive topics (mental health, trauma)
- **Web Access Settings**: Added opt-in web access toggle in LUMARA Settings
  - Default: Disabled (opt-in by default for safety)
  - Safety information displayed when enabled

#### Attribution Display Improvements
- **Expanded by Default**: Attribution drop-down references now expanded by default
- **Web Source Support**: Enhanced attribution display for web references
  - Web reference icon (🌐) and color coding
  - Integration with enhanced attribution system

---

## [2.1.39] - November 2025

### **Video Playback Fixes & Advanced Analytics Updates** - Complete

#### Video Playback Improvements
- **Crash Prevention**: Fixed app crashes when playing videos by adding comprehensive error handling
  - Added 3-second timeout to MethodChannel calls to prevent hanging
  - Added `.catchError()` handlers to gracefully handle method failures
- **Video Thumbnail Support**: Added video thumbnail display functionality
  - Displays thumbnails from `thumbnailPath` if available
  - Falls back to placeholder icon if thumbnail isn't available

#### Advanced Analytics Updates
- **Added Medical Tab**: Medical tracking now integrated as 5th tab in Advanced Analytics
  - Medical tab shows full HealthView with Overview, Details, and Medications
  - Includes 30/60/90 day health data import options
- **5-Part Horizontal Tab System**: Updated from 4 to 5 tabs
  - Patterns, AURORA, VEIL, SENTINEL, Medical

---

## [2.1.38] - November 2025

### **Advanced Analytics View with Horizontal Tabs** - Complete

#### New Feature
- **Advanced Analytics Access**: New "Advanced Analytics" option in Insights 3-dot menu (⋮)
- **5-Part Horizontal Tab System**: Horizontally scrollable tabs for Patterns, AURORA, VEIL, SENTINEL, and Medical
- **Swipe Navigation**: PageView enables smooth swiping between analytics sections
- **Tab Selection Sync**: Tab selection and page navigation are synchronized

#### Tab Content
- **Patterns Tab**: Your Patterns visualization card (wordCloud, network, timeline, radial)
- **AURORA Tab**: Circadian Intelligence card
- **VEIL Tab**: AI Prompt Intelligence card + VEIL Policy card
- **SENTINEL Tab**: Emotional risk detection and pattern analysis
- **Medical Tab**: Health data tracking with Overview, Details, and Medications

---

## [2.1.37] - November 25, 2025

### **LUMARA Favorites System Fixes & Upgrades** - Complete

#### Bug Fixes
- **Fixed Incorrect Limit Detection**: Resolved issue where users with 20 favorites total couldn't add new LUMARA answer favorites
  - Updated to use category-specific limit checking: `isCategoryAtCapacity('answer')`
  - Fixed three instances of legacy `isAtCapacity()` usage

#### Feature Upgrades
- **Consistent Favorite Limits**: Upgraded all favorite categories to 25-item limit
  - LUMARA Answers: 25 (unchanged)
  - Saved Chats: 25 (upgraded from 20)
  - Favorite Journal Entries: 25 (upgraded from 20)

---

## [2.1.36] - November 23, 2025

### **LUMARA Reflective Queries & Notification System** - Complete

#### Reflective Query System
- **Three EPI-Standard Queries**: Anti-harm mechanisms countering anxiety, depression, loneliness, and loss of agency
  - Query 1: "Show me three times I handled something hard"
  - Query 2: "What was I struggling with around this time last year?"
  - Query 3: "Which themes have softened in the last six months?"
- **Query Detection**: Automatic pattern recognition in LUMARA chat interface
- **Safety Integration**: VEIL filtering, trauma detection, night mode handling

#### Notification System Foundation
- **Time Echo Reminders**: Periodic reflective reminders (1 month, 3 months, 6 months, 1 year, 2 years, 5 years, 10 years)
- **Active Window Detection**: Learns user's natural reflection windows from journal entry patterns
- **Sleep Protection**: Automatic sleep window detection and abstinence period management

#### Data Integrity Fixes
- **CreatedAt Preservation**: `createdAt` field now never changes when updating entries
- **Original Creation Time**: Stored in metadata as `originalCreatedAt` for safety

---

## [2.1.35] - November 2025

### **Phase Detection Refactor with Versioned Inference** - Complete

#### Versioned Phase Inference Pipeline
- **New Service**: `PhaseInferenceService` provides pure phase inference ignoring hashtags and legacy tags
- **Version Tracking**: `CURRENT_PHASE_INFERENCE_VERSION = 1` tracks inference pipeline version
- **Migration Support**: `PhaseMigrationService` enables on-demand phase recomputation

#### Phase Detection Architecture
- **Auto Phase Detection**: Always the default source of truth for each entry
- **User Overrides**: Explicit manual override via dropdown, only available after entry is saved
- **Hashtag Independence**: Inline hashtags never control phase assignment

#### New Phase Fields in JournalEntry
- `autoPhase` (String?) - Model-detected phase, authoritative
- `autoPhaseConfidence` (double?) - Confidence score 0.0-1.0
- `userPhaseOverride` (String?) - Manual override via dropdown
- `isPhaseLocked` (bool) - If true, don't auto-overwrite
- `legacyPhaseTag` (String?) - From old phase field or imports (reference only)

#### Expanded Keyword Detection
- **Recovery**: Expanded from 19 to 60+ keywords
- **Discovery**: Expanded from 17 to 80+ keywords
- **Expansion**: Expanded from 18 to 90+ keywords
- **Transition**: Expanded from 15 to 70+ keywords
- **Consolidation**: Expanded from 15 to 100+ keywords
- **Breakthrough**: Expanded from 21 to 120+ keywords

---

## [2.1.34] - November 2025

### **Media Packs for ZIP Exports & Configuration UI** - Complete

#### Media Pack Support for ZIP Exports
- **Feature**: ZIP exports now support media packs, matching ARCX export functionality
- **Organization**: Media files are organized into `/Media/packs/pack-XXX/` directories
- **Pack Structure**: Media items grouped into packs based on target size (default 200MB)
- **Backward Compatibility**: Legacy direct media directories still created if packs disabled

#### Media Pack Configuration UI Restored
- **Restored**: Media Pack Target Size slider in Advanced Export Options
- **Configuration**: Range 50-500 MB with 9 divisions (default 200MB)

---

## [2.1.33] - November 2025

### **ZIP Export Option & Export UI Improvements** - Complete

#### Unencrypted ZIP Export Option
- **Feature**: Added unencrypted ZIP export option alongside secure ARCX format
- **User Choice**: Users can now choose between Secure Archive (.arcx) with encryption or standard ZIP (.zip)
- **Same Content**: ZIP exports include all the same content as ARCX exports

#### Export UI Simplification
- **Removed**: Media Pack Target Size card (no longer user-configurable)
- **Removed**: Size measurement from Export Summary card (was inaccurate)
- **Fixed**: Custom date range export now correctly includes all entries/media on the selected end date

---

## [2.1.32] - November 2025

### **Timeline UI Improvements & Date Navigation Fixes** - Complete

#### Calendar & Arcform Preview Clipping Fix
- **Problem**: The calendar week header and arcform preview containers were clipping into each other
- **Solution**: Increased calendar header height from 76px to 108px, added proper container wrapper

#### Date Jumping Accuracy Fix
- **Problem**: When selecting a date, the timeline would jump to an incorrect date
- **Root Cause**: Date jumping logic was using unfiltered entries, while displayed timeline uses filtered entries
- **Solution**: Updated `_jumpToDate` to use same filtering and deduplication logic

---

## [2.1.31] - November 2025

### **LUMARA & Phase Analysis Updates** - Complete

#### LUMARA External Access
- **Core Rule Update**: Updated LUMARA's core rules to explicitly allow access to external resources for biblical, factual, and scientific data
- **Safety**: Maintained strict "no-politics/news" filter while enabling broader knowledge access

#### LUMARA Chat UI Refinements
- **Simplified Intro**: The initial "Hello, I'm LUMARA..." message now appears as a simple greeting without action buttons

#### ARCForm Visualization Cleanup
- **UI Simplification**: Removed the "3D View" button and "Refresh" icon from the ARCForm Visualizations header

---

## [2.1.30] - November 2025

### **Saved Chats Restoration & Continuation** - Complete

#### Auto-Restore Archived Sessions
- **Feature**: Saved chats with archived sessions now automatically restore when opened
- **User Experience**: No more "Unavailable" errors - all saved chats are accessible

#### Continue Conversations from Archived Sessions
- **Feature**: Users can continue conversations from archived sessions, like Gemini and ChatGPT
- **Auto-Restore on Message**: Sending a message to an archived session automatically restores it

---

## [2.1.29] - November 2025

### **LUMARA Prompt Feature & Saved Chats Fix** - Complete

#### Empty Entry Writing Prompts
- **Feature**: When writing for the first time in a journal entry, clicking the LUMARA head icon provides intelligent writing prompts
- **Context-Aware Generation**: System analyzes past 30 days of journal entries, recent chat sessions, current phase
- **Traditional Prompts**: Includes 10 general writing prompts for variety

#### Saved Chats Display Fix
- **Problem**: Saved chats card showed count but clicking displayed "No saved chats yet" screen
- **Solution**: Updated `SavedChatsScreen` to show all saved chats using `listAll(includeArchived: true)`

#### LUMARA Icon Replacement
- **Custom Logo**: Replaced `Icons.psychology` with custom golden circular LUMARA logo
- **Reusable Widget**: Created `LumaraIcon` widget that loads `assets/images/lumara_logo.png`

---

## [2.1.28] - November 2025

### **Build System Fixes** - Complete

#### Type Inference Fix
- **Dart Compilation Error**: Fixed type inference issue in `lumara_assistant_cubit.dart`
- **Explicit Typing**: Added explicit type annotation `List<LumaraMessage>`

#### CocoaPods Synchronization Fix
- **Podfile.lock Sync Issue**: Resolved "The sandbox is not in sync with the Podfile.lock" error
- **Encoding Fix**: Ran `pod install` with proper UTF-8 encoding

---

## Navigation

- **[CHANGELOG.md](CHANGELOG.md)** - Index and overview
- **[CHANGELOG_part1.md](CHANGELOG_part1.md)** - December 2025
- **[CHANGELOG_part3.md](CHANGELOG_part3.md)** - January-October 2025 and earlier

