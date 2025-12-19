# EPI MVP - Bug Tracker

**Version:** 2.1.60  
**Last Updated:** December 19, 2025

## Resolved Issues (v2.1.60)

### LUMARA Greeting Issue in Journal Mode
- **Issue**: LUMARA was responding with "Hello! I'm LUMARA, your personal assistant..." greeting messages instead of providing journal reflections when using correlation-resistant PII protection system
- **Root Cause**: 
  1. Entire user prompt (including natural language instructions) was being transformed into structured JSON payload
  2. LUMARA received JSON instead of natural language instructions
  3. LUMARA couldn't parse JSON as a journal reflection request and defaulted to greeting
- **Resolution**:
  1. **Pre-abstract entry text**: Transform entry text BEFORE building the prompt in `enhanced_lumara_api.dart`
  2. **Use semantic summary**: Replace verbatim entry text with abstract description (e.g., "brief entry about emotional reflection")
  3. **Preserve natural language**: Keep all instructions in natural language format
  4. **Skip transformation**: Added `skipTransformation` flag to `geminiSend()` for journal entries
  5. **Improved semantic summary**: Enhanced abstraction to create true theme-based descriptions instead of truncated text
- **Impact**:
  - LUMARA now receives natural language prompts with abstracted entry descriptions
  - Journal reflections work correctly with correlation-resistant PII protection
  - No more greeting messages in journal mode
  - Privacy protection maintained while preserving functionality
- **Files Modified**: 
  - `lib/arc/chat/services/enhanced_lumara_api.dart` - Abstract entry text before building prompt
  - `lib/services/gemini_send.dart` - Added skipTransformation parameter
  - `lib/arc/chat/voice/voice_journal/correlation_resistant_transformer.dart` - Improved semantic summary generation
- **Status**: ✅ Fixed

## Resolved Issues (v2.1.43)

### LUMARA Subject Drift and Repetitive Endings
- **Issue**: LUMARA would sometimes focus on unrelated historical journal entries instead of the current entry, and consistently ended responses with the same "Would it help to name one small step" phrase
- **Root Cause**:
  1. **Subject Drift**: Current journal entry had no priority marking and was mixed equally with 19 historical entries
  2. **Repetitive Endings**: Hardcoded fallback phrase in `lumara_response_scoring.dart` auto-fix mechanism
- **Resolution**:
  1. **Current Entry Priority**: Added explicit `**CURRENT ENTRY (PRIMARY FOCUS)**` marking in context building
  2. **Context Restructuring**: Reduced historical entries to 15 and marked as "REFERENCE ONLY"
  3. **Focus Instructions**: Added clear directives across all conversation modes to focus on current entry
  4. **Master Prompt Enhancement**: Updated core LUMARA system with current entry priority rules
  5. **Therapeutic Closings**: Replaced hardcoded phrase with existing therapeutic presence data (24+ varied endings)
  6. **Time-Based Rotation**: Implemented dynamic selection to prevent repetition patterns
- **Impact**:
  - LUMARA now maintains strict focus on the current journal entry's subject
  - Eliminated repetitive ending phrases with therapeutically appropriate variety
  - Improved response relevance and user experience
  - Better contextual appropriateness of responses
- **Files Modified**: `enhanced_lumara_api.dart`, `lumara_master_prompt.dart`, `lumara_response_scoring.dart`
- **Status**: ✅ Fixed

### Build Error: Missing FirebaseAuth Import
- **Issue**: iOS build failing with error: `The getter 'FirebaseAuth' isn't defined for the type '_JournalScreenState'` at line 611 in `journal_screen.dart`
- **Root Cause**: Missing import statement for `firebase_auth` package in `journal_screen.dart`. The code was using `FirebaseAuth.instance` but the import was not present.
- **Resolution**:
  1. Added missing import: `import 'package:firebase_auth/firebase_auth.dart';` to `journal_screen.dart`
  2. Import added after `cloud_functions` import to maintain logical grouping
- **Impact**: 
  - iOS build now compiles successfully
  - `_checkLumaraConfiguration()` method can now properly access Firebase Auth
  - No functional changes, only missing import added
- **Status**: ✅ Fixed

### In-Journal LUMARA API Key Requirement
- **Issue**: In-journal LUMARA was requiring users to configure a local Gemini API key, even though the backend handles API keys via Firebase Secrets. Users would see "LUMARA needs an API key to work" error messages.
- **Root Cause**: 
  1. `EnhancedLumaraApi` was still using direct `geminiSend()` calls which required a local API key from `LumaraAPIConfig`
  2. `_checkLumaraConfiguration()` was checking for local API keys instead of just verifying Firebase Auth
  3. In-journal LUMARA was not using the backend Cloud Functions infrastructure
- **Resolution**:
  1. Created new `generateJournalReflection` Cloud Function to handle in-journal LUMARA reflections via backend
  2. Updated `EnhancedLumaraApi.generatePromptedReflectionV23()` to call backend Cloud Function instead of `geminiSend()`
  3. Simplified `_checkLumaraConfiguration()` to only check Firebase Auth (backend handles API keys)
  4. Updated error messages to clarify that backend handles API keys automatically
  5. All API keys now managed securely via Firebase Secrets (no local configuration needed)
- **Impact**: 
  - Users no longer need to configure local API keys for in-journal LUMARA
  - Unified backend infrastructure for both chat and in-journal LUMARA features
  - Consistent rate limiting and tier system across all LUMARA features
  - Improved security with centralized API key management
- **Status**: ✅ Fixed

## Resolved Issues (v2.1.32)

### Timeline Date Jumping Inaccuracy
- **Issue**: When selecting a date (e.g., 10/13/2025), the timeline would jump to an incorrect date (e.g., 09/24/2025).
- **Root Cause**: The date jumping logic was using unfiltered entries, while the displayed timeline uses filtered and deduplicated entries, causing index mismatches.
- **Resolution**: 
  1. Updated `_jumpToDate` to use the same filtering and deduplication logic as `InteractiveTimelineView._getFilteredEntries`
  2. Ensures the calculated scroll index matches what's actually displayed in the timeline
  3. Added debug logging for troubleshooting date matching
- **Status**: ✅ Fixed

### Calendar & Arcform Preview Clipping
- **Issue**: The calendar week header and arcform preview containers were clipping into each other when scrolling.
- **Root Cause**: Calendar header height (76px) didn't account for month text display, and arcform preview had insufficient top margin.
- **Resolution**: 
  1. Increased calendar header height from 76px to 108px to properly account for month text
  2. Added proper container wrapper with background color for calendar header
  3. Increased arcform preview top margin from 8px to 16px to prevent clipping with pinned calendar header
- **Status**: ✅ Fixed

## Resolved Issues (v2.1.27)

### Calendar Scroll Sync Desynchronization
- **Issue**: Selecting a date in the "Jump to Date" picker caused the weekly calendar to jump approximately one week ahead of the target date.
- **Root Cause**: 
  1. `_timelineCardHeight` constant (280.0) in `InteractiveTimelineView` was overestimating actual item height, leading to incorrect index calculations.
  2. `CalendarWeekTimeline` was reacting to scroll notifications generated during the programmatic "jump" animation, causing it to drift.
- **Resolution**:
  1. Reduced `_timelineCardHeight` to 180.0 for better accuracy.
  2. Implemented `_isProgrammaticScroll` flag in `TimelineView` to suppress calendar updates during jump animations.
- **Status**: ✅ Fixed

### Saved Chats Navigation Issue
- **Issue**: Clicking on "Saved Chats" in Chat History did not navigate to a list of saved chats, making them inaccessible.
- **Root Cause**: Missing dedicated screen and navigation logic for the saved chats section.
- **Resolution**: Created `SavedChatsScreen` and updated `EnhancedChatsScreen` to navigate to it.
- **Status**: ✅ Fixed
