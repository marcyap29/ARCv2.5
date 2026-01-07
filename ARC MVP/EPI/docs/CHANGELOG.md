# EPI ARC MVP - Changelog

**Version:** 2.1.85
**Last Updated:** January 7, 2026

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.53 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [2.1.85] - January 7, 2026

### **LUMARA Entry Classification System** - ✅ Complete

**Problem Solved**: LUMARA was over-synthesizing simple factual questions, turning "Does Newton's calculus predict or calculate movement?" into lengthy therapy sessions instead of direct answers.

**Solution**: Intelligent pre-processing classification system that determines entry type before LUMARA synthesis.

#### Features
- **5 Entry Types**: Factual, Reflective, Analytical, Conversational, Meta-Analysis
- **Pre-Processing Classification**: Classification happens before master prompt to prevent over-synthesis
- **Response Mode Optimization**: Different word limits and context scoping per type
- **Pattern Detection**: Emotional density, first-person indicators, technical markers, meta-analysis cues
- **Analytics & Monitoring**: Firebase-based logging for classification accuracy tracking

#### Technical Implementation
- **Files Added**:
  - `lib/services/lumara/entry_classifier.dart` - Core classification logic
  - `lib/services/lumara/response_mode.dart` - Response configuration
  - `lib/services/lumara/classification_logger.dart` - Analytics
  - `lib/services/lumara/lumara_classifier_integration.dart` - Integration helper
  - `test/services/lumara/entry_classifier_test.dart` - Comprehensive tests
- **Integration**: Enhanced `enhanced_lumara_api.dart` with classification pipeline
- **Methods Added**: `_generateFactualResponse()`, `_generateConversationalResponse()`

#### Response Examples
- **Factual**: "Does Newton's calculus predict or calculate?" → Direct 100-word answer
- **Conversational**: "Had coffee with Sarah" → "Thanks for sharing that with me."
- **Reflective**: Weight/goal entries → Full LUMARA synthesis (unchanged)
- **Meta-Analysis**: "What patterns do you see?" → 600-word comprehensive analysis

#### User Experience
- **No User Interface Changes**: Classification happens transparently
- **Settings Preserved**: Existing LUMARA settings still apply after classification
- **Backward Compatible**: All existing functionality maintained
- **Performance**: Classification adds <100ms to response time

---

## [2.1.84] - January 4, 2026

### **Enhanced Incremental Backup System** - ✅ Complete

- **Text-Only Incremental Backup Option**:
  - New `excludeMedia` parameter in `exportIncremental()` method
  - Option to create space-efficient text-only backups (entries + chats, no media)
  - Reduces backup size by 90%+ for frequent incremental backups
  - Media can be backed up separately when needed

- **Improved Error Handling**:
  - Enhanced error detection for disk space errors (errno 28) vs permission errors (errno 13)
  - Clear, actionable error messages with specific guidance
  - Error dialogs instead of snackbars for better readability
  - Shows required space in MB and provides steps to free up space
  - Detects and warns about restricted backup locations (iCloud Drive)

- **UI Improvements**:
  - Two backup buttons: "Text Only" (fast, small) and "Backup All" (includes media)
  - Warning banner when new media items would be included
  - Helpful tip suggesting text-only for frequent backups
  - Better visual feedback during backup process

- **Technical Implementation**:
  - Added `excludeMediaFromIncremental` option to `ARCXExportOptions`
  - Updated `exportIncremental()` to support media exclusion
  - Improved error messages in `arcx_export_service_v2.dart`
  - Enhanced `LocalBackupSettingsView` with dual backup options

- **User Experience**:
  - Faster, smaller backups for daily use (text-only)
  - Full backups with media when needed
  - Clear error messages help users resolve issues quickly
  - Better guidance on backup folder selection

---

## [2.1.83] - January 2, 2026

### **Temporal Notifications System** - ✅ Complete

- **Multi-Cadence Notification System**:
  - **Daily Resonance Prompts**: Surface relevant themes, callbacks, and patterns
  - **Monthly Thread Review**: Synthesize emotional threads and phase status
  - **6-Month Arc View**: Show developmental trajectory with phase visualization
  - **Yearly Becoming Summary**: Full narrative of transformation

- **Notification Settings UI**:
  - Created `TemporalNotificationSettingsView` with comprehensive controls
  - Toggle switches for each notification cadence
  - Time picker for daily notification time
  - Day selector for monthly notification day
  - Quiet hours configuration (start/end time)
  - Temporal callbacks toggle
  - Auto-saves preferences and reschedules notifications
  - Accessible from Settings → Preferences → Temporal Notifications

- **App Initialization Integration**:
  - Service initializes automatically on app startup (after Firebase Auth)
  - Schedules notifications for authenticated users
  - Non-blocking initialization (errors don't crash app)
  - Integrated into `bootstrap.dart` initialization flow

- **Deep Linking for Notification Taps**:
  - Global navigator key added to `MaterialApp` for navigation from anywhere
  - Notification tap handler routes to appropriate screens:
    - Daily resonance → Opens JournalScreen with prompt text
    - Monthly review → Navigates to Phase tab
    - 6-Month arc view → Navigates to Phase tab
    - Yearly summary → Navigates to Phase tab
  - Handles notification payload parsing and routing

- **Technical Implementation**:
  - Models: `ResonancePrompt`, `ThreadReview`, `ArcView`, `BecomingSummary`, `NotificationPreferences`
  - Services: `TemporalNotificationService`, `NotificationContentGenerator`
  - Uses `flutter_local_notifications` and `timezone` packages
  - Leverages existing ARC systems: SENTINEL, ATLAS, RIVET, LUMARA
  - Privacy-first: All processing happens locally

- **User Experience**:
  - Developmentally-aware notifications that reflect user's phase and history
  - Not vanity metrics - always developmental insights
  - Natural language notifications that feel like a thoughtful friend
  - Graceful degradation for users with few entries

---

## [2.1.82] - January 2, 2026

### **Removed SimpleKeywordExtractor - Unified on EnhancedKeywordExtractor** - ✅ Complete

- **Removed SimpleKeywordExtractor Class**:
  - Completely removed `SimpleKeywordExtractor` from codebase
  - All keyword extraction now uses `EnhancedKeywordExtractor` exclusively
  - Eliminated duplicate keyword extraction logic

- **Enhanced Keyword Extraction**:
  - All journal entries now use curated keyword library with intensities
  - Keywords come from `EnhancedKeywordExtractor` which includes:
    - **Curated keywords** with semantic categories (100+ keywords)
    - **Emotion amplitude map** with intensity values (0.0-1.0)
    - **Phase-specific keyword lists** (Recovery, Transition, Breakthrough, Discovery, Expansion, Consolidation)
    - **RIVET gating** for quality control
  - No more generic word extraction - only library-based keywords

- **Technical Changes**:
  - Removed `SimpleKeywordExtractor` class from `arcform_mvp_implementation.dart`
  - Updated `journal_capture_cubit.dart` to use `EnhancedKeywordExtractor` via `_extractKeywordsFromLibrary()` helper
  - Updated test file to use `EnhancedKeywordExtractor`
  - Updated usage examples in code comments

- **User Experience**:
  - More semantically meaningful keywords for better analysis
  - Keywords include intensity values for emotional analysis
  - Phase-aware keyword selection based on current developmental phase
  - Quality-controlled keywords through RIVET gating

---

## [2.1.81] - January 2, 2026

### **Simplified LUMARA Action Buttons** - ✅ Complete

- **Removed "More Depth" Button**:
  - Removed from in-journal LUMARA reflection action buttons
  - Simplified UI/UX by removing redundant functionality
  - Users can still request more depth through conversation or by adjusting response length settings

- **Removed "Soften Tone" Button**:
  - Removed from in-journal LUMARA reflection action buttons
  - Simplified UI/UX by removing redundant functionality
  - Tone adjustments can be made through LUMARA Persona settings if needed

- **Updated Action Button Set**:
  - **Regenerate**: Regenerate the current reflection
  - **Continue thought**: Continue the current reflection thread
  - **Explore options**: Open LUMARA conversation options
  - Cleaner, more focused interface with essential actions only

- **Technical Changes**:
  - Removed `onMoreDepth` and `onSoften` callbacks from `InlineReflectionBlock` widget
  - Removed `_onMoreDepthReflection()` and `_onSoftenReflection()` methods from `JournalScreen`
  - Simplified action button row in journal reflection blocks

- **User Experience**:
  - Cleaner, less cluttered action button interface
  - Focus on essential actions: Regenerate, Continue, Explore
  - Reduced cognitive load and decision fatigue
  - All functionality still accessible through other means (settings, conversation)

---

## [2.1.80] - January 2, 2026

### **Journal Entry Overview Feature** - ✅ Complete

- **Automatic Overview Generation**:
  - Every journal entry with LUMARA comments now gets a 3-5 sentence overview
  - Overview summarizes the entire entry: user content + all LUMARA reflections
  - Generated automatically in the background when LUMARA blocks are saved
  - Uses EnhancedLumaraApi with specialized prompt for concise summaries

- **Overview Display**:
  - Overview appears at the top of journal entries (after metadata, before photo gallery)
  - Styled card with "Overview" label and summarize icon
  - Selectable text for easy copying
  - Only displays when entry has LUMARA blocks and overview exists

- **Technical Implementation**:
  - New `overview` field in `JournalEntry` model (HiveField 28)
  - Overview generation integrated into `_persistLumaraBlocksToEntry()` flow
  - Overview generation function ensures 3-5 sentence length
  - Graceful error handling - entry saves even if overview generation fails

- **User Experience**:
  - Quick reference when returning to entries
  - Helps users understand entry content at a glance
  - Overview is generated automatically - no user action required
  - Seamlessly integrated into existing journal entry UI

---

## [2.1.79] - January 2, 2026

### **LUMARA Response Length Controls** - ✅ Complete

- **New Response Length Settings Card**:
  - Added "LUMARA Length of Response" card in Settings → LUMARA → LUMARA Persona
  - Positioned between LUMARA Persona and Therapeutic Depth cards
  - Toggle between "Auto" (default) and "Off" modes
  - When "Auto": LUMARA chooses appropriate length based on question complexity
  - When "Off": Manual controls become active

- **Manual Response Length Controls** (when Auto is Off):
  - **Sentence Number Slider**: Set total number of sentences (3, 5, 10, 15, or ∞ infinity)
  - **Sentences per Paragraph Slider**: Set paragraph structure (3, 4, or 5 sentences per paragraph)
  - LUMARA reformats responses to fit limits without cutting off mid-thought
  - Sentence length itself is not limited - only total count and paragraph structure

- **Technical Implementation**:
  - New settings in `LumaraReflectionSettingsService`: `isResponseLengthAuto()`, `getMaxSentences()`, `getSentencesPerParagraph()`
  - Control state integration: Added `responseLength` section to LUMARA Control State JSON
  - Master prompt updated: New "RESPONSE LENGTH AND DETAIL" section with priority rules
  - UI card with toggle and sliders, grayed out when Auto mode is active

- **User Experience**:
  - Default behavior unchanged (Auto mode) - LUMARA adapts naturally
  - Manual mode provides precise control for users who want specific response lengths
  - Responses are reformatted, not truncated, ensuring completeness

---

## [2.1.78] - January 2, 2026

### **Subscription Authentication Fix & Automatic Token Refresh** - ✅ Complete

- **Fixed Subscription Authentication Error**:
  - Removed `invoker: "public"` from `createCheckoutSession` and `createPortalSession` Firebase Functions
  - Functions now properly require authentication, allowing auth tokens to be passed correctly
  - Fixed UNAUTHENTICATED error when subscribing to premium from non-premium accounts
  - Updated subscription service to use `FirebaseService.getFunctions()` for proper region configuration

- **Automatic Token Refresh System**:
  - Implemented `idTokenChanges()` listener in `FirebaseAuthService` for automatic token refresh
  - Added `refreshTokenIfNeeded()` method that uses Firebase's automatic token lifecycle
  - Token refresh on app resume via `AppLifecycleManager` to ensure fresh tokens
  - Improved token handling efficiency by letting Firebase handle token lifecycle automatically
  - Users now stay authenticated seamlessly without manual re-authentication

- **Backend Updates**:
  - Updated `firebase-functions` from 7.0.0 to 7.0.2 (latest version)
  - Fixed 4 high severity security vulnerabilities in functions dependencies via `npm audit fix`
  - All security vulnerabilities resolved (0 found)

---

## [2.1.77] - January 1, 2026

### **Incremental Backup System & UI Reorganization** - ✅ Complete

- **Incremental Backup System**:
  - **ExportHistoryService**: New service to track export history using SharedPreferences
  - **Incremental Export**: Only exports new/changed entries since last backup (90%+ size reduction)
  - **Media Deduplication**: Skips media files already exported using SHA-256 hash tracking
  - **Export History Tracking**: Maintains record of all exports with entry IDs, chat IDs, and media hashes
  - **Full Backup Option**: Still available for complete backups
  - **Backup History Management**: View statistics, clear history to force full backup
  
- **Local Backup UI Improvements**:
  - **Quick Backup Card**: Shows preview of new entries, chats, and media before backup
  - **Full Backup Card**: Option to create complete backups
  - **Backup History Card**: Displays export statistics and last full backup date
  - **Folder Selection Guidance**: Info card explaining where to save backups (recommended locations)
  - **"Use App Documents" Button**: One-tap setup for safe backup folder
  - **Path Validation**: Detects and warns about restricted locations (iCloud Drive)
  - **Write Permission Testing**: Validates folder permissions before starting export
  
- **Import/Export UI Reorganization**:
  - **Moved Import Data**: Now directly accessible from Settings → Import & Export (no need to navigate to Advanced Export)
  - **Renamed Sections**: "Import/Export Data" → "Advanced Export" for clarity
  - **Clearer Purpose**: Local Backup for regular backups, Advanced Export for custom exports
  - **Streamlined Navigation**: Three clear options in Settings:
    - Local Backup: Regular automated backups with incremental tracking
    - Import Data: Direct access to restore from backup files
    - Advanced Export: Custom exports with date filtering, multi-select, sharing
  
- **Export Service Enhancements**:
  - **Directory Validation**: Ensures output directory exists and is writable before export
  - **Path Cleaning**: Trims trailing spaces and normalizes paths
  - **Better Error Messages**: Clear feedback for permission issues and folder problems
  - **Incremental Export Methods**: `exportIncremental()` and `exportFullBackup()` methods
  - **Export Preview**: `getIncrementalExportPreview()` for UI display

**Status**: ✅ Complete  
**Files Created**:
- `lib/services/export_history_service.dart` - Export history tracking service

**Files Modified**:
- `lib/mira/store/arcx/services/arcx_export_service_v2.dart` - Added incremental export methods and options
- `lib/shared/ui/settings/local_backup_settings_view.dart` - Added incremental backup UI and folder guidance
- `lib/shared/ui/settings/settings_view.dart` - Reorganized Import/Export section, added direct import access
- `lib/ui/screens/mcp_management_screen.dart` - Removed import section, clarified export purpose

**Expected Results**:
- Backup size reduction: ~477MB → ~30-50MB per incremental backup (90%+ reduction)
- Improved user experience: Clear guidance on where to save backups
- Better organization: Separated regular backups from advanced exports

---

## [2.1.76] - January 1, 2026

### **Stripe Integration Setup & Documentation** - ✅ Complete

- **Stripe Secrets Configuration**:
  - Fixed UNAUTHENTICATED errors in Stripe checkout by adding proper authentication checks
  - Added comprehensive error handling for missing Stripe secrets
  - Implemented token refresh before Stripe function calls
  - Added clear error messages for users when Stripe is not configured
  
- **Firebase Functions Updates**:
  - Updated `createCheckoutSession` with proper secret validation
  - Added graceful error handling for missing secrets
  - Improved logging for Stripe initialization
  - Set API version to `2023-10-16` (basil) for stability
  
- **Documentation Organization**:
  - Created `docs/stripe/` directory for all Stripe-related documentation
  - Moved all Stripe setup guides to centralized location
  - Created comprehensive README for Stripe documentation
  - Added visual guides for webhook setup and secret retrieval
  
- **Setup Guides Created**:
  - `STRIPE_SECRETS_SETUP.md` - Complete step-by-step setup guide
  - `STRIPE_WEBHOOK_SETUP_VISUAL.md` - Visual webhook configuration guide
  - `STRIPE_TEST_VS_LIVE.md` - Test vs Live mode explanation
  - `FIND_TEST_MODE.md` - How to find Test Mode toggle
  - `GET_WEBHOOK_SECRET.md` - Webhook secret retrieval guide
  - `STRIPE_DIRECT_TEST_MODE.md` - Direct URL method for Test Mode

**Status**: ✅ Complete  
**Files Created**:
- `docs/stripe/README.md` - Stripe documentation index
- `docs/stripe/STRIPE_SECRETS_SETUP.md` - Main setup guide
- `docs/stripe/STRIPE_WEBHOOK_SETUP_VISUAL.md` - Webhook visual guide
- `docs/stripe/STRIPE_TEST_VS_LIVE.md` - Mode comparison guide
- `docs/stripe/FIND_TEST_MODE.md` - Test Mode location guide
- `docs/stripe/GET_WEBHOOK_SECRET.md` - Secret retrieval guide
- `docs/stripe/STRIPE_DIRECT_TEST_MODE.md` - Direct URL guide

**Files Modified**:
- `functions/index.js` - Improved Stripe initialization and error handling
- `lib/services/subscription_service.dart` - Added authentication checks and token refresh
- `lib/services/firebase_auth_service.dart` - Added subscription cache clearing on sign out
- `lib/shared/ui/settings/settings_view.dart` - Fixed sign-out navigation to login screen

**Files Moved**:
- All Stripe documentation moved to `docs/stripe/` directory

---

## [2.1.75] - December 29, 2025

### **Engagement Discipline System** - ✅ Complete

- **User-Controlled Engagement Modes**:
  - **Reflect Mode** (Default): Surface patterns and stop - minimal follow-up, best for journaling without exploration
  - **Explore Mode**: Surface patterns and invite deeper examination - may ask one connecting question per response
  - **Integrate Mode**: Synthesize across domains and time horizons - most active engagement posture
  
- **Cross-Domain Synthesis Controls**:
  - Faith & Work synthesis toggle
  - Relationships & Work synthesis toggle
  - Health & Emotions synthesis toggle
  - Creative & Intellectual synthesis toggle
  - Protected domains feature to prevent unwanted synthesis
  
- **Response Discipline Settings**:
  - Max Temporal Connections (1-5, default: 2) - controls historical references per response
  - Max Questions (0-2, default: 1) - limits exploratory questions (EXPLORE/INTEGRATE only)
  - Allow Therapeutic Language toggle (default: false) - permits therapy-style phrasing
  - Allow Prescriptive Guidance toggle (default: false) - permits direct advice
  - Response Length preference (Concise/Moderate/Detailed, default: Moderate)
  
- **Integration with LUMARA Control State**:
  - Engagement settings integrated into LUMARA's Control State JSON system
  - Mode-specific instructions in system prompt
  - Automatic filtering of prohibited patterns (therapeutic questions, dependency-forming language)
  
- **Advanced Settings UI**:
  - Engagement Discipline section in Advanced Settings menu
  - Black background with white text and purple icons/toggles (consistent with other Advanced Settings cards)
  - Radio button selection for engagement modes
  - Toggle switches for synthesis preferences and language permissions
  - Sliders for numeric settings
  
- **Settings Persistence**:
  - Engagement settings saved via SharedPreferences
  - Integrated with existing LUMARA reflection settings service
  - Default mode: Reflect (minimal engagement)

**Status**: ✅ Complete  
**Files Created**:
- `lib/models/engagement_discipline.dart` - Engagement mode models and settings
- `docs/Engagement_Discipline.md` - Comprehensive documentation

**Files Modified**:
- `lib/shared/ui/settings/advanced_settings_view.dart` - Engagement Discipline UI with updated styling
- `lib/arc/chat/services/lumara_control_state_builder.dart` - Integration with Control State
- `lib/arc/chat/services/lumara_reflection_settings_service.dart` - Settings persistence

---

## [2.1.74] - December 29, 2025

### **Phase Sharing Layout Refinements** - ✅ Complete

- **Phase Preview Zoom Adjustment**:
  - Zoomed out Phase Preview window by double (from 1.6 to 0.8) for wider view of phase visualization
  
- **Instagram Image Generation Improvements**:
  - Removed bottom border by reducing watermark padding
  - Reduced bottom canvas length by 2/3 for both Instagram Story and Feed formats
  - Caption and metrics positioned closer to bottom edge for more compact layout
  - Phase visualization now uses more of the available vertical space
  
- **LinkedIn Image Generation Improvements**:
  - Reduced left and right canvas margins by 2/3 (effective width now 86.67% of canvas)
  - Reduced bottom canvas by 1/2 (caption moved from 80% to 90% of height)
  - All content elements (Arcform, timeline, caption) use narrower effective width
  - More compact layout with less wasted space on sides and bottom

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` - Phase Preview zoom adjustment
- `lib/arc/arcform/share/arcform_share_image_generator.dart` - Instagram and LinkedIn layout refinements
- `docs/ARCHITECTURE.md` - Updated VEIL submodule documentation and version

---

## [2.1.73] - January 28, 2025

### **Phase Sharing Improvements & Privacy Enhancements** - ✅ Complete

- **Image Generation Fixes**:
  - Fixed aspect ratio preservation for Instagram Story and Feed formats to prevent image squishing
  - Increased magnification for LinkedIn layout (zoom level 1.6 for optimal detail)
  - Cropped LinkedIn layout sides 2x and bottom by 1/2 for tighter composition
  - Increased separation between text and phase visualization in LinkedIn layout
  - Trimmed borders on all platforms to make phase visualization appear larger
  
- **Visual Design Updates**:
  - Changed background from white to black for all share formats
  - Updated all text colors to white/light colors for black background
  - Centered composition for LinkedIn Feed layout
  - Adjusted zoom levels: Preview uses 1.6 (was too close at 3.5), capture uses same 1.6 for consistency
  
- **Privacy & Label Controls**:
  - Labels hidden by default for privacy on public networks (Instagram, LinkedIn)
  - Added "Show Labels" toggle in Optional Information section
  - Users can opt-in to show keyword labels if desired
  - Re-capture functionality respects label toggle setting when generating images
  
- **Share Error Fixes**:
  - Fixed `sharePositionOrigin` error by adding proper coordinate calculation
  - Improved capture reliability with proper widget rendering delays
  
- **LUMARA Favorites Import Fix**:
  - Updated import service to check `extensions/` directory first (with fallback to `PhaseRegimes/`)
  - Removed restrictive "only if empty" import policy - now imports with deduplication regardless of existing favorites

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/arcform/share/arcform_share_image_generator.dart` - Black background, aspect ratio fixes, layout improvements
- `lib/arc/arcform/share/arcform_share_composition_screen.dart` - Label toggle, re-capture with settings, share error fix
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` - Zoom fixes, label privacy, arcform data passing
- `lib/ui/phase/simplified_arcform_view_3d.dart` - Zoom fixes, label privacy, arcform data passing
- `lib/mira/store/arcx/services/arcx_import_service_v2.dart` - Import path fix and policy update

---

## [2.1.72] - January 28, 2025

### **LUMARA Favorites Export with Phase Information** - ✅ Complete

- **Phase Enrichment**: LUMARA favorites are now enriched with phase information during ARCX exports, enabling temporal context references
- **Export Format Update**: 
  - `lumara_favorites.json` version updated to `1.2` to indicate phase information inclusion
  - Each favorite now includes optional `phase` and `phase_regime_id` fields when available
- **Phase Lookup Logic**:
  - First checks favorite metadata for existing phase info
  - If missing, looks up phase from phase regime service using the favorite's timestamp
  - Adds phase name (e.g., "discovery", "expansion", "transition") and phase regime ID
- **Use Cases**: Enables LUMARA to reference temporal context like:
  - "You felt this way when you wrote this"
  - "You were in the same phase when you encountered something similar"
- **Export Coverage**: LUMARA favorites with phase information are exported in all ARCX export paths:
  - `_exportTogether()` - All groups together
  - `_exportEntriesChatsTogetherMediaSeparate()` - Entries+Chats together, Media separate
  - `_exportGroup()` - Individual group exports
- **Implementation**:
  - `lib/mira/store/arcx/services/arcx_export_service_v2.dart`: Added `_enrichFavoritesWithPhaseInfo()` method to enrich favorites with phase data before export, updated `_exportLumaraFavorites()` to always export favorites (independent of phase regimes), added `_getPhaseLabelName()` helper method
  - Favorites are always exported regardless of whether phase regimes are included
  - Phase information is included in `extensions/lumara_favorites.json` within ARCX archives

**Status**: ✅ Complete  
**Files Modified**:
- `lib/mira/store/arcx/services/arcx_export_service_v2.dart` - Added phase enrichment for LUMARA favorites export

---

## [2.1.71] - January 8, 2025

### **Removed "Remove Duplicate Entries" Setting** - ✅ Complete

- **Removed Menu Item**: Removed "Remove Duplicate Entries" option from Timeline view's Settings popup menu
- **Code Cleanup**: Removed unused `_removeDuplicateEntries()` method and related handler code
- **Implementation**:
  - `lib/arc/ui/timeline/timeline_view.dart`: Removed "Remove Duplicate Entries" menu item, removed case handler for `'remove_duplicates'`, removed unused `_removeDuplicateEntries()` method, removed unused `JournalRepository` import
- **Rationale**: This feature is no longer needed as duplicate entry management is handled automatically by the system

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/ui/timeline/timeline_view.dart` - Removed "Remove Duplicate Entries" setting and related code

---

## [2.1.70] - January 8, 2025

### **Subscription-Based LUMARA Settings & Additional API Providers** - ✅ Complete

- **Subscription-Based Settings Visibility**: LUMARA settings now adapt based on subscription tier:
  - **Free Users**: Only see basic settings (Context Scope, Reflection Settings, Therapeutic Presence, Web Access)
  - **Pro/Paying Users**: See all settings including AI Provider Selection and API Keys cards
  - **Automatic Selection Removed**: Removed "Automatic Selection" toggle for all users - free users use Gemini only, paying users choose their provider
- **Expanded API Provider Support**: Added support for additional API providers:
  - **Venice AI**: Added as new API provider option for paying users
  - **OpenRouter**: Added as new API provider option for paying users
  - **Provider Selection**: Paying users can now choose from 5 providers: Gemini, Anthropic, ChatGPT (OpenAI), Venice AI, and OpenRouter
- **API Keys Card Updates**: 
  - Free users no longer see API Keys card (backend handles API keys automatically)
  - Paying users see all 5 API key fields with individual Save buttons
  - Display names updated: "ChatGPT" for OpenAI, "Anthropic" for Anthropic, "Venice AI" and "OpenRouter" for new providers
- **Implementation**:
  - `lib/arc/chat/ui/lumara_settings_screen.dart`: Added subscription tier checking, conditional card visibility, removed automatic selection toggle, added Venice AI and OpenRouter to provider lists
  - `lib/arc/chat/config/api_config.dart`: Added `venice` and `openrouter` to LLMProvider enum, added API configurations with base URLs
  - `lib/arc/chat/llm/llm_provider_factory.dart`: Mapped Venice AI and OpenRouter to OpenAI-compatible API handling
- **Features**:
  - Simplified experience for free users (no API key management needed)
  - Full provider control for paying users
  - Support for 5 different API providers
  - Clear subscription-based feature differentiation
  - Better organization of settings based on user tier

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/ui/lumara_settings_screen.dart` - Subscription-based visibility, removed automatic selection, added Venice AI and OpenRouter
- `lib/arc/chat/config/api_config.dart` - Added Venice AI and OpenRouter providers
- `lib/arc/chat/llm/llm_provider_factory.dart` - Added provider mappings for Venice AI and OpenRouter

---

## [2.1.69] - January 8, 2025

### **LUMARA Natural Openings and Endings** - ✅ Complete

- **Natural Opening Paragraphs**: LUMARA now avoids formulaic restatements of user questions:
  - Starts with insight, observation, or direct answer rather than paraphrasing
  - Jumps into the substance when the question is clear
  - Uses acknowledgment phrases only when they add context or show deeper understanding
  - Prohibits patterns like "It sounds like you're actively seeking my perspective on..."
- **Natural Response Endings**: Strengthened prohibition on generic ending questions:
  - Explicitly prohibits "Does this resonate with you?" and similar formulaic phrases
  - Responses end naturally when the thought is complete
  - Silence is a valid and often preferred ending
  - Ending questions only used when they genuinely deepen reflection and connect to specific insights
- **Removed Response Truncation**: Fixed `autoTightenToEcho` function:
  - Removed 4-sentence limit that was cutting off responses
  - Removed forced ending question logic
  - Now only applies minimal fixes (removes exclamations, fixes "we" → "you") without truncating
- **Firebase Functions Prompt Update**: Added Section 9 "Natural Response Endings" to cloud-based chat prompt:
  - Aligns Firebase Functions prompt with master prompt guidelines
  - Prohibits generic ending questions
  - Encourages natural completion
- **Implementation**:
  - `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`: Added "NATURAL OPENING PARAGRAPHS" section, strengthened "Question Discipline" section with explicit prohibitions
  - `lib/arc/chat/services/lumara_response_scoring.dart`: Removed 4-sentence limit and forced ending question logic from `autoTightenToEcho`, removed unused `_getTherapeuticClosingPhrase` function
  - `lib/arc/chat/services/enhanced_lumara_api.dart`: Updated to remove "Does this resonate?" from allowed endings
  - `functions/src/functions/sendChatMessage.ts`: Added Section 9 "Natural Response Endings" with comprehensive guidelines
- **Features**:
  - More natural, conversational opening paragraphs
  - Responses end naturally without forced questions
  - No artificial truncation of responses
  - Consistent behavior across all prompt systems (master prompt and Firebase Functions)
  - Better user experience with more authentic, less robotic responses

**Status**: ✅ Complete  
**Files Modified**:
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Natural openings and endings guidelines
- `lib/arc/chat/services/lumara_response_scoring.dart` - Removed truncation and forced endings
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Updated ending question guidance
- `functions/src/functions/sendChatMessage.ts` - Added Section 9 on natural endings
- `lib/arc/chat/prompts/README_MASTER_PROMPT.md` - Updated documentation

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
