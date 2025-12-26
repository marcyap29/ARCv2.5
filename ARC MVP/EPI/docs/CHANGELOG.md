# EPI ARC MVP - Changelog

**Version:** 2.1.68
**Last Updated:** January 8, 2025

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.53 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [2.1.68] - January 8, 2025

### **Subscription-Based Favorites Limits & Attachment Menu Fix** - ✅ Complete

- **Subscription-Based Favorites Limits**: Favorites system now enforces different limits based on subscription tier:
  - **Premium/Paying Users**: 40 favorites per category (answers, chats, journal entries)
  - **Free Users**: 25 favorites per category (answers, chats, journal entries)
  - **Dynamic Limit Display**: All UI components now dynamically fetch and display the correct limit based on user's subscription tier
  - **Async Limit Checking**: `FavoritesService.getCategoryLimit()` is now async and checks subscription tier in real-time
- **Attachment Menu Button Fix**: Fixed issue where menu options were not clickable due to journal entry's GestureDetector intercepting taps:
  - **Overlay-Based Menu**: Switched from Stack-based positioning to `OverlayEntry` to render menu in a separate layer above all content
  - **Backdrop Dismissal**: Added transparent backdrop that dismisses menu when tapping outside
  - **Proper Gesture Handling**: Menu items now use `GestureDetector` with `HitTestBehavior.opaque` to ensure taps are captured correctly
  - **Prevents Gesture Interception**: Menu is now rendered above the journal entry's GestureDetector, preventing tap interception
- **Implementation**:
  - `lib/arc/chat/services/favorites_service.dart`: Added subscription-based limit constants and async `getCategoryLimit()` method
  - `lib/arc/ui/widgets/attachment_menu_button.dart`: Replaced Stack-based menu with OverlayEntry implementation
  - `lib/shared/ui/settings/favorites_management_view.dart`: Updated to fetch and display dynamic limits
  - `lib/shared/ui/settings/settings_view.dart`: Updated to display dynamic limits in subtitle
  - `lib/ui/journal/widgets/inline_reflection_block.dart`: Updated error messages to use dynamic limits
  - `lib/arc/chat/chat/ui/session_view.dart`: Updated error messages to use dynamic limits
  - `lib/arc/chat/ui/lumara_assistant_screen.dart`: Updated error messages to use dynamic limits
  - `lib/arc/ui/timeline/widgets/interactive_timeline_view.dart`: Updated error messages to use dynamic limits
  - `lib/mira/store/mcp/import/mcp_pack_import_service.dart`: Updated to await async `getCategoryLimit()`
- **Features**:
  - Premium users get 40 favorites per category (60% increase from 25)
  - Free users maintain 25 favorites per category
  - All UI components show correct limits based on subscription
  - Attachment menu is now fully functional and clickable
  - Menu dismisses when tapping outside for better UX

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/services/favorites_service.dart` - Subscription-based limits
- `lib/arc/ui/widgets/attachment_menu_button.dart` - Overlay-based menu
- `lib/shared/ui/settings/favorites_management_view.dart` - Dynamic limits
- `lib/shared/ui/settings/settings_view.dart` - Dynamic limits
- `lib/ui/journal/widgets/inline_reflection_block.dart` - Dynamic error messages
- `lib/arc/chat/chat/ui/session_view.dart` - Dynamic error messages
- `lib/arc/chat/ui/lumara_assistant_screen.dart` - Dynamic error messages
- `lib/arc/ui/timeline/widgets/interactive_timeline_view.dart` - Dynamic error messages
- `lib/mira/store/mcp/import/mcp_pack_import_service.dart` - Async limit checking

---

## [2.1.67] - January 8, 2025

### **LUMARA Response Length & Conversation Context Improvements** - ✅ Complete

- **Removed Response Length Limits**: LUMARA responses now have no length restrictions - responses flow naturally to completion without artificial paragraph limits
- **Removed Generic Extension Questions**: LUMARA no longer ends responses with generic extension questions like "Is there anything else you want to explore here?" - personas now ask questions only when genuinely relevant, not as a default ending
- **Weighted Conversation Context for In-Journal Conversations**: New intelligent context weighting system that creates natural back-and-forth conversations:
  - **Decreasing Weight by Recency**: Most recent exchange gets highest weight (1.0), with exponential decrease for older exchanges (0.8, 0.6, 0.4, etc.)
  - **Recent Exchanges in Full Detail**: Last 3 exchanges included in full detail, older exchanges summarized (100-char preview)
  - **Original Entry Text Weight Reduction**: Original entry text weight decreases as conversation grows (0.7 → 0.5 → 0.3) and is truncated to 500 chars for long conversations
  - **Natural Back-and-Forth**: LUMARA now responds to the most recent 1-2 exchanges instead of re-summarizing the entire conversation from beginning to end
  - **Context-Aware Instructions**: Clear weight indicators and instructions guide LUMARA to focus on recent exchanges while using older context only when relevant
- **Document Analysis Guidance**: Added comprehensive document/technical analysis handling for explicit requests:
  - Focus exclusively on provided content (not unrelated journal entries)
  - Provide detailed, substantive analysis with no length limits
  - Identify specific strengths, weaknesses, gaps, and risks
  - Offer concrete recommendations
  - No generic extension questions
- **Implementation**:
  - `lib/ui/journal/journal_screen.dart`: Implemented weighted context system in `_buildRichContext` with decreasing weights and summarization
  - `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`: Added "In-Journal Conversation Context (Weighted by Recency)" section, removed length limits, removed extension question guidance
  - `lib/arc/chat/services/enhanced_lumara_api.dart`: Removed all length restrictions and extension hints from prompt constructions
  - `functions/src/functions/sendChatMessage.ts`: Removed length limits, added document analysis guidance, removed extension questions
  - `functions/src/functions/generateJournalReflection.ts`: Removed all length restrictions and extension hints
- **Features**:
  - No artificial response length limits - responses flow naturally
  - Natural conversation flow with 1-2 turns of context
  - Weighted context system prevents awkward re-summarization
  - Personas ask questions only when genuinely relevant
  - Document analysis provides comprehensive, detailed feedback
  - Original entry text appropriately weighted based on conversation length

**Status**: ✅ Complete  
**Files Modified**:
- `lib/ui/journal/journal_screen.dart` - Weighted context system
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Removed limits, added weighted context instructions
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Removed length restrictions
- `functions/src/functions/sendChatMessage.ts` - Removed limits, added document analysis
- `functions/src/functions/generateJournalReflection.ts` - Removed length restrictions

---

## [2.1.66] - January 8, 2025

### **LUMARA Explicit Request & Support Detection** - ✅ Complete

- **Explicit Request Mode**: LUMARA now detects when users explicitly ask for opinions, recommendations, or critical analysis and responds directly with substantive feedback instead of defaulting to reflection-only
- **Enhanced Persona Selection for Advice Requests**: When explicit advice is requested, the system automatically selects Strategist or Challenger persona to provide more direct, actionable feedback
- **Support Request Detection**: New intelligent detection system that routes users to appropriate personas based on support type:
  - **Emotional Support** (feeling overwhelmed, anxious, sad) → Therapist (high distress) or Companion (moderate)
  - **Practical Support** (how to do something, what steps) → Strategist (action needed) or Companion (general guidance)
  - **Accountability Support** (need to be pushed, held accountable) → Challenger
- **Process & Task-Friendly**: LUMARA now focuses on helping users accomplish their goals when explicitly asked, providing direct opinions, critical analysis, and concrete recommendations
- **Improved Context Relevance**: When providing explicit advice, LUMARA focuses on the current request rather than pulling in irrelevant historical journal entries
- **Implementation**:
  - `lib/arc/chat/services/lumara_control_state_builder.dart`: Enhanced persona auto-detection with explicit request and support pattern recognition
  - `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`: Added "Explicit Request Mode" section (Section 5) with comprehensive detection patterns and response guidelines
  - `functions/src/functions/sendChatMessage.ts`: Added explicit request handling instructions to system prompt
- **Features**:
  - Detects explicit advice requests: "Tell me your thoughts", "Give me the hard truth", "What's your opinion", "Am I missing anything", "Give me recommendations", etc.
  - Routes "hard truth" requests to Challenger persona
  - Routes other explicit advice to Strategist persona
  - Detects support requests and routes to appropriate persona (Therapist/Companion/Strategist/Challenger)
  - Provides direct opinions, critical analysis, and concrete recommendations when explicitly requested
  - Focuses on current request context, not irrelevant historical entries

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/services/lumara_control_state_builder.dart` - Enhanced persona detection
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Added explicit request mode
- `functions/src/functions/sendChatMessage.ts` - Added explicit request handling

---

## [2.1.65] - January 8, 2025

### **LUMARA Reflection Enhancements** - ✅ Complete

- **Expanded Response Length**: LUMARA now provides comprehensive, detailed reflections of 5-6 paragraphs (15-25 sentences) for standard reflections, and 6-8 paragraphs (20-30 sentences) for deep reflections
- **Enhanced Historical Context**: LUMARA actively references and draws connections to past journal entries, showing patterns, themes, and evolution across journal history
- **Re-integrated Prompt Variants**: All reflection action buttons are now available in the expandable menu:
  - Regenerate: Rebuild reflection with different rhetorical focus
  - Soften tone: Gentler, slower rhythm with permission language
  - More depth: Extensive 6-8 paragraph exploration with deeper introspection
  - Continue thought: Resume interrupted reflections
  - Explore conversation options: Access to all conversation modes (ideas, think, perspective, next steps, reflect deeply)
- **Reflection Discipline Framework**: New comprehensive framework that preserves narrative dignity while allowing personas to express their natural guidance styles:
  - Reflection-first approach: Guidance emerges naturally from reflection
  - Persona integration: Each persona (Companion, Therapist, Strategist, Challenger) expresses guidance in their characteristic style
  - Proactive guidance: LUMARA can offer goal/habit suggestions when patterns suggest helpful directions
  - Temporal memory: Reference past entries for continuity and to suggest helpful directions
  - Question discipline: Natural ending questions are encouraged when they feel helpful
- **Persona-Guidance Integration**: Personas work WITH reflection discipline, not against it:
  - **Companion**: Gentle, warm guidance ("This might be a good time to...")
  - **Therapist**: Very gentle, permission-based guidance ("If it feels right, you might...")
  - **Strategist**: Direct, concrete actions (2-4 steps based on pattern analysis)
  - **Challenger**: Direct feedback, accountability, growth-pushing questions
- **Implementation**:
  - `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`: Added Section 9 "Reflection Discipline" with persona integration
  - `lib/arc/chat/services/enhanced_lumara_api.dart`: Updated all prompt variants with reflection discipline and expanded length requirements
  - `lib/ui/journal/widgets/inline_reflection_block.dart`: Re-integrated all action buttons in expandable menu
  - `functions/src/functions/generateJournalReflection.ts`: Updated Firebase function with reflection discipline rules
- **Features**:
  - Comprehensive 5-6 paragraph reflections (standard) or 6-8 paragraphs (deep)
  - Active use of historical journal entries for pattern recognition
  - All prompt variants accessible from journal reflection UI
  - Guidance that emerges naturally from reflection
  - Persona-specific guidance styles maintained
  - Natural ending questions when appropriate
  - Silence as valid ending when reflection feels complete

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Added reflection discipline section
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Updated all prompt variants
- `lib/ui/journal/widgets/inline_reflection_block.dart` - Re-integrated action buttons
- `functions/src/functions/generateJournalReflection.ts` - Updated reflection prompts

---

## [2.1.64] - January 8, 2025

### **Google Drive Backup Integration** - ✅ Complete

- **Automatic Cloud Backups**: Users can now automatically backup their journal data to Google Drive
- **OAuth Authentication**: Secure Google account connection with limited scope (`drive.file` - only files created by app)
- **Folder Selection**: Users can choose a specific Google Drive folder for backups
- **Backup Format Options**: Choose between ARCX (encrypted) or MCP/ZIP format
- **Scheduled Backups**: Configure automatic backups (daily/weekly/monthly) at a specific time
- **Manual Backup Trigger**: One-tap manual backup from settings
- **Background Uploads**: Backups upload in the background with progress tracking
- **Retry Logic**: Automatic retry with exponential backoff on upload failures
- **Export Integration**: Automatic upload trigger after manual exports (if enabled and format matches)
- **Implementation**:
  - `lib/services/google_drive_service.dart`: Google Drive API integration with OAuth
  - `lib/services/backup_upload_service.dart`: Backup creation and upload orchestration
  - `lib/services/scheduled_backup_service.dart`: Periodic backup scheduling
  - `lib/services/google_drive_backup_settings_service.dart`: Persistent settings storage
  - `lib/shared/ui/settings/google_drive_backup_settings_view.dart`: Settings UI
  - `lib/main/bootstrap.dart`: Scheduled backup initialization on app startup
  - `lib/ui/export_import/mcp_export_screen.dart`: Export completion upload trigger
  - `lib/shared/ui/settings/settings_view.dart`: Settings integration
- **Features**:
  - Connect/disconnect Google account
  - Select backup folder from Google Drive
  - Choose backup format (ARCX or MCP/ZIP)
  - Enable/disable scheduled backups
  - Set backup frequency (daily/weekly/monthly)
  - Set backup time (HH:mm format)
  - Manual backup trigger
  - Last backup timestamp display
  - Progress tracking during upload
  - Error notifications
  - Automatic token refresh on authentication failures

**Status**: ✅ Complete  
**Dependencies Added**:
- `googleapis: ^13.0.0`
- `googleapis_auth: ^1.6.0`

---

## [2.1.63] - January 8, 2025

### **LUMARA Bible Reference Retrieval** - ✅ Complete

- **Bible API Integration**: LUMARA now automatically retrieves Bible verses, chapters, and commentary using the HelloAO Bible API (`bible.helloao.org`)
- **Intelligent Detection**: Comprehensive Bible terminology library detects Bible-related queries (books, characters, prophets, concepts, events)
- **Automatic Verse Fetching**: When users ask about Bible topics, LUMARA automatically fetches relevant verses and includes them in context
- **Character-to-Book Resolution**: Automatically resolves prophet/character names (e.g., "Habakkuk") to their corresponding Bible books and fetches chapter 1
- **Privacy Protection**: Bible names whitelisted in PRISM to prevent false PII scrubbing
- **Transformation Bypass**: Bible questions automatically skip correlation-resistant transformation to preserve verse context and instructions
- **Implementation**:
  - `lib/arc/chat/services/bible_api_service.dart`: HTTP client for HelloAO Bible API
  - `lib/arc/chat/services/bible_retrieval_helper.dart`: Detection and fetching logic
  - `lib/arc/chat/services/bible_terminology_library.dart`: Comprehensive terminology database (66 books, characters, prophets, events, concepts)
  - `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`: Bible retrieval instructions for LUMARA
  - `lib/core/prompts_arc.dart`: Enhanced system prompts with Bible handling
  - `lib/services/llm_bridge_adapter.dart`: Critical pre-prompt injection for Bible questions
  - `lib/services/gemini_send.dart`: Auto-skip transformation for Bible context
  - `lib/echo/privacy_core/pii_detection_service.dart`: Bible names whitelist
- **Features**:
  - Supports all 66 Bible books (Old and New Testament)
  - Handles book abbreviations (e.g., "Jn" → "John")
  - Detects prophets, apostles, biblical characters, events, concepts
  - Fetches specific verses (e.g., "John 3:16"), chapters, or entire books
  - Provides context about biblical topics when specific references aren't given
  - Multiple translation support (default: BSB)
  - Error handling with fallback to general context

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/services/bible_api_service.dart` - New file
- `lib/arc/chat/services/bible_retrieval_helper.dart` - New file
- `lib/arc/chat/services/bible_terminology_library.dart` - New file
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Added Bible retrieval section
- `lib/core/prompts_arc.dart` - Enhanced Bible instructions
- `lib/services/llm_bridge_adapter.dart` - Critical pre-prompt injection
- `lib/services/gemini_send.dart` - Auto-skip transformation
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` - Bible context integration
- `lib/echo/privacy_core/pii_detection_service.dart` - Bible names whitelist

**Feature Enhancement**: Enables LUMARA to provide accurate, API-sourced Bible content instead of generic responses, with automatic detection and retrieval of relevant verses.

---

## [2.1.62] - December 20, 2025

### **Phase Assignment Fix & Logo Fix** - ✅ Complete

- **Fixed missing phase assignment**: `saveEntryWithKeywords` now calls `_inferAndSetPhaseForEntry()` to assign `autoPhase` when entries are saved
- **Root cause**: `saveEntryWithKeywords` was missing the phase inference call that `saveEntry` had, causing entries to not get `autoPhase` assigned
- **Impact**: Phase Analysis now correctly uses `autoPhase` values from entries (checks `entry.autoPhase` first before falling back to `PhaseRecommender.recommend()`)
- **Logo fix**: Fixed ARC logo reference from `ARC-Logo-White.png` to `ARC-Logo.png` in splash screen
- **Implementation**:
  - `lib/arc/core/journal_capture_cubit.dart`: Added `await _inferAndSetPhaseForEntry(entry);` call in `saveEntryWithKeywords()` after entry save
  - `lib/arc/chat/ui/lumara_splash_screen.dart`: Updated logo asset path to use existing `ARC-Logo.png` file

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/core/journal_capture_cubit.dart` - Added phase inference call to `saveEntryWithKeywords`
- `lib/arc/chat/ui/lumara_splash_screen.dart` - Fixed logo asset reference

**Bug Fix**: Ensures all entries get `autoPhase` assigned when saved, enabling Phase Analysis to work correctly with recommended phases.

---

## [2.1.61] - December 19, 2025

### **ARC Code Consolidation - Internal Architecture Organization** - ✅ Complete

- **Code cleanup and reorganization**: Consolidated ARC codebase to reflect internal 5-module architecture
- **New internal module structure**: Created `lib/arc/internal/` directory with PRISM, MIRA, AURORA, and ECHO submodules
- **Removed duplicates**: Eliminated duplicate files (media capture, keyword extraction, etc.)
- **Barrel exports**: Created module-level exports for cleaner imports (`prism_internal.dart`, `mira_internal.dart`, etc.)
- **Backward compatibility**: Maintained via re-exports from old paths to new locations
- **Implementation**:
  - **PRISM Internal** (`internal/prism/`): Theme analysis, keyword extraction, media processing
  - **MIRA Internal** (`internal/mira/`): Memory loading, storage, semantic matching, journal repository
  - **AURORA Internal** (`internal/aurora/`): Active window detection, sleep protection, notifications
  - **ECHO Internal** (`internal/echo/`): PII scrubbing, correlation-resistant transformation, privacy redaction
- **Documentation**: Updated ARCHITECTURE.md and ARC_INTERNAL_ARCHITECTURE.md to reflect new structure

**Status**: ✅ Complete  
**Files Modified**:
- Created `lib/arc/internal/` directory structure with 4 submodules
- Moved 20+ files to appropriate internal module locations
- Deleted 8 duplicate files
- Updated imports across 30+ files
- Created barrel export files for each internal module

**Architecture Improvement**: Better reflects EPI's 5-module architecture internally, making code organization clearer and more maintainable.

---

## [2.1.60] - December 19, 2025

### **Fixed LUMARA Greeting Issue in Journal Mode** - ✅ Complete

- **Fixed greeting responses**: LUMARA was responding with "Hello, I'm LUMARA..." instead of journal reflections
- **Root cause**: Entire user prompt (including instructions) was being transformed to JSON, causing LUMARA to receive JSON instead of natural language
- **Solution**: Abstract entry text BEFORE building prompt, then skip transformation to preserve natural language instructions
- **Implementation**:
  - `enhanced_lumara_api.dart`: Abstracts entry text first, uses semantic summary in prompt
  - `gemini_send.dart`: Added `skipTransformation` flag for journal entries
  - Journal entries now use abstract descriptions while preserving natural language instructions
- **Flow**: Entry text → PRISM scrub → Transform → Get semantic summary → Build natural language prompt → Skip transformation → LUMARA receives natural language

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Abstract entry text before building prompt
- `lib/services/gemini_send.dart` - Added skipTransformation parameter
- `lib/arc/chat/voice/voice_journal/correlation_resistant_transformer.dart` - Improved semantic summary generation

**Bug Fix**: Resolves issue where correlation-resistant PII protection caused LUMARA to default to greeting messages instead of providing journal reflections.

---

## [2.1.59] - December 18, 2025

### **Correlation-Resistant PII Protection System** - ✅ Complete

- **Enhanced privacy protection**: Added correlation-resistant transformation layer on top of PRISM scrubbing
- **Rotating aliases**: PRISM tokens (e.g., `[EMAIL_1]`) now transformed to rotating aliases (e.g., `PERSON(H:7c91f2, S:⟡K3)`)
- **Structured JSON payloads**: Replaced verbatim text transmission with structured JSON abstractions
- **Session-based rotation**: Identifiers rotate per session to prevent cross-call linkage
- **Universal protection**: Applied to voice journal, regular journal, chat, and summary generation
- **Two-block output system**:
  - Block A: LOCAL-ONLY audit blocks (never transmitted)
  - Block B: CLOUD-PAYLOAD structured JSON (safe to transmit)
- **Enhanced security validation**: `isSafeToSend()` now validates both PRISM tokens and alias format
- **Implementation details**:
  - Voice journal: `VoiceJournalConversation.processTurn()` uses transformer
  - Chat system: `geminiSend()` updated to use transformer
  - Journal summaries: `JournalCaptureCubit._generateSummary()` uses transformer
  - Regular journal: `EnhancedLumaraApi` automatically benefits via `geminiSend()`

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/voice/voice_journal/correlation_resistant_transformer.dart` - New transformer module
- `lib/arc/chat/voice/voice_journal/prism_adapter.dart` - Added `transformToCorrelationResistant()` method
- `lib/arc/chat/voice/voice_journal/gemini_client.dart` - Updated to accept `CloudPayloadBlock`
- `lib/services/gemini_send.dart` - Integrated correlation-resistant transformation
- `lib/arc/core/journal_capture_cubit.dart` - Updated summary generation to use transformer
- `docs/CORRELATION_RESISTANT_PII.md` - Comprehensive documentation

**Security Improvements**:
- Prevents re-identification through rotating identifiers
- Prevents cross-call linkage via session-based rotation
- Eliminates verbatim text transmission (uses abstractions)
- Maintains capability while maximizing privacy

---

## [2.1.58] - December 18, 2025

### **LUMARA Journal Context Order Fix** - ✅ Complete

- **Fixed reverse reading flow issue**: LUMARA was focusing on text below its position instead of above, causing users to read from bottom-up to understand the flow
- **Chronological context ordering**: LUMARA now only sees and references content that appears ABOVE its position in the entry
- **Original text tracking**: Added `_originalEntryTextBeforeBlocks` to track entry text before any blocks are added
- **Context building improvements**:
  - When `currentBlockIndex > 0`, uses original entry text instead of current text (which may contain text written after blocks)
  - Only includes LUMARA responses and user comments from blocks with index < currentBlockIndex
  - Explicit instructions that content BELOW the current block position is NOT included
- **Enhanced context labeling**: 
  - Context section labeled as "CONTENT ABOVE THIS LUMARA RESPONSE (CHRONOLOGICAL ORDER)"
  - Clear warnings that content below is not visible
  - Position-aware instructions (e.g., "You are responding at position X - you can ONLY see content from positions 1-X-1")
- **Previous LUMARA responses included**: All previous LUMARA responses above the current position are now included in context, ensuring conversation continuity

**Status**: ✅ Complete  
**Files Modified**:
- `lib/ui/journal/journal_screen.dart` - Added original text tracking, modified context building to use chronological order, updated instructions

---

## [2.1.57] - December 13, 2025

### **LUMARA Web Access Safety Layer Enhancement** - ✅ Complete

- **Restored comprehensive web access safety layer**: Restored all 10 original safety rules for LUMARA's web search capability
- **Safety rules implemented**:
  1. Primary Source Priority - Prioritize user's personal context first
  2. Explicit Need Check - Internal reasoning before searching
  3. Opt-In by User Intent - Interpret user requests as permission when appropriate
  4. Content Safety Boundaries - Avoid violent, graphic, extremist content
  5. Research Mode Filter - Prioritize peer-reviewed sources for research
  6. Containment Framing for Sensitive Topics - High-level summaries for mental health/trauma topics
  7. No Passive Browsing - Web access must be tied to user requests
  8. Transparent Sourcing - Summarize findings, state external info was used
  9. Contextual Integration - Relate web info back to user's ARC themes and patterns
  10. Fail-Safe Rule - Refuse unsafe content and offer alternatives
- **Combined with explicit capability statements**: Clear instructions that LUMARA has Google Search available when `webAccess.enabled` is true, with matter-of-fact usage approach
- **Explicit prohibition**: Never tell users "I can only work with journal/chat" when web access is enabled

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Restored comprehensive safety layer rules with explicit web access instructions

---

## [2.1.56] - December 13, 2025

### **LUMARA Internet Access & Bug Fixes** - ✅ Complete

- **Enabled Google Search in proxyGemini**: Added `tools: [{ googleSearch: {} }]` to Gemini model configuration, enabling LUMARA to access the internet when the internet toggle is enabled
- **Fixed Shake to Report multiple dialogs**: Added static flag to prevent multiple bug report dialogs from opening simultaneously
- **Fixed Throttle Lock firebase_functions import**: Updated logger imports to use `firebase-functions/v2` instead of `firebase-functions` to resolve import errors
- **Fixed Journal Entry Summary Generation**: 
  - Regular journal mode: Now properly sets LUMARA API on JournalCaptureCubit for summary generation
  - Voice mode: Added safety check to ensure LUMARA API is set during initialization
  - Enhanced logging: Added comprehensive logging to `_generateSummary` method for better debugging
  - Summaries are automatically prepended to journal entries (>50 words) in format: `## Summary\n\n{summary}\n\n---\n\n{content}`

**Status**: ✅ Complete  
**Files Modified**:
- `functions/index.js` - Enabled Google Search tool in proxyGemini
- `lib/ui/feedback/bug_report_dialog.dart` - Added dialog prevention flag
- `functions/lib/functions/unlockThrottle.js` - Fixed logger imports
- `functions/src/functions/unlockThrottle.ts` - Fixed logger imports in source
- `lib/ui/journal/journal_screen.dart` - Set LUMARA API on cubit creation
- `lib/arc/core/journal_capture_cubit.dart` - Enhanced summary generation logging
- `lib/arc/chat/voice/voice_journal/unified_voice_service.dart` - Added LUMARA API safety check

---

## [2.1.55] - December 13, 2025

### **AssemblyAI Universal Streaming v3 Migration** - ✅ Complete

- **Migrated from v2 Realtime API to Universal Streaming v3**: Complete migration to AssemblyAI's latest streaming API
- **WebSocket endpoint updated**: Changed from `wss://api.assemblyai.com/v2/realtime/ws` to `wss://streaming.assemblyai.com/v3/ws`
- **Authentication method updated**: API key now passed as query parameter (`?token=...`) instead of Authorization header
- **Audio format fixed**: Changed from base64-encoded JSON to raw binary audio data (v3 requirement)
- **Message handling updated**: Added support for v3 "Turn" message type (replaces PartialTranscript/FinalTranscript)
- **Session management**: Added `_sessionReady` flag to ensure audio is only sent after receiving "Begin" message
- **Inactivity timeout**: Added `inactivity_timeout=30` parameter to prevent premature WebSocket closure
- **Firebase Functions integration**: `getAssemblyAIToken` now returns raw API key for v3 (no token generation needed)
- **Real-time transcription working**: Full bidirectional streaming with partial and final transcripts

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/voice/transcription/assemblyai_provider.dart` - Complete v3 migration, Turn message handling, raw binary audio
- `functions/index.js` - Updated `getAssemblyAIToken` to return API key directly for v3

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
| 2.1.57 | Dec 13, 2025 | LUMARA Web Access Safety Layer Enhancement |
| 2.1.56 | Dec 13, 2025 | LUMARA Internet Access & Bug Fixes |
| 2.1.55 | Dec 13, 2025 | AssemblyAI Universal Streaming v3 Migration |
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
