# EPI MVP - Bug Tracker (Part 1: December 2025 - January 2026)

**Version:** 2.1.76  
**Last Updated:** January 1, 2026  
**Coverage:** December 2025 - January 2026 releases (v2.1.43 - v2.1.76)

---

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

---

## Resolved Issues (v2.1.76)

### Stripe Subscription Upgrade UNAUTHENTICATED Error
- **Issue**: Users encountered "Error starting upgrade process: [firebase_functions/unauthenticated] UNAUTHENTICATED" when trying to upgrade their subscription via Stripe checkout
- **Root Cause**: 
  1. Firebase Cloud Functions (`createCheckoutSession`, `createPortalSession`) required authentication but didn't have proper `invoker: "public"` permissions
  2. Client-side `SubscriptionService` wasn't refreshing ID tokens before calling Stripe functions
  3. Underlying "failed-precondition" errors due to missing Stripe secrets in Firebase Secret Manager were masked by authentication errors
- **Resolution**:
  1. Added `invoker: "public"` to `createCheckoutSession` and `createPortalSession` function definitions
  2. Added explicit authentication checks (`isSignedIn`, `isAnonymous`) in `SubscriptionService.createStripeCheckoutSession`
  3. Implemented forced ID token refresh (`currentUser.getIdToken(true)`) before calling Firebase functions
  4. Added comprehensive error handling for missing Stripe secrets with user-friendly error messages
  5. Improved logging to distinguish between authentication and configuration errors
- **Impact**: 
  - Users can now successfully upgrade subscriptions via Stripe
  - Clear error messages when Stripe is not configured
  - Proper authentication flow for payment processing
- **Files Modified**: 
  - `functions/index.js` - Added public invoker permissions and secret validation
  - `lib/services/subscription_service.dart` - Added authentication checks and token refresh
- **Status**: ✅ Fixed

### Sign-Out Not Redirecting to Login Screen
- **Issue**: After signing out, users remained on the main app screen with premium status still displayed, instead of being redirected to the sign-in screen
- **Root Cause**: 
  1. Sign-out logic in `SettingsView` wasn't clearing the navigation stack
  2. Subscription cache wasn't being cleared on sign-out, causing premium status to persist
  3. Navigation wasn't using `pushNamedAndRemoveUntil` to clear all previous routes
- **Resolution**:
  1. Modified `SettingsView.signOut()` to use `Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false)` to clear navigation stack
  2. Added `SubscriptionService.instance.clearCache()` to `FirebaseAuthService.signOut()` method
  3. Added `AssemblyAIService.instance.clearCache()` to ensure all caches are cleared
  4. Ensured sign-out properly clears all user state before navigation
- **Impact**: 
  - Users are now properly redirected to sign-in screen after sign-out
  - Premium status no longer persists after sign-out
  - Clean state on sign-out prevents data leakage between accounts
- **Files Modified**: 
  - `lib/shared/ui/settings/settings_view.dart` - Fixed navigation on sign-out
  - `lib/services/firebase_auth_service.dart` - Added cache clearing on sign-out
- **Status**: ✅ Fixed

### AssemblyAI Service Instance Not Found
- **Issue**: Build error: `Error: Member not found: 'instance'. AssemblyAIService.instance.clearCache();`
- **Root Cause**: `AssemblyAIService` was a singleton but didn't expose a static `instance` getter, making it inaccessible from other services
- **Resolution**:
  1. Added static getter `static AssemblyAIService get instance => _instance;` to `AssemblyAIService` class
  2. Ensured singleton pattern is properly exposed for cross-service access
- **Impact**: 
  - `AssemblyAIService` can now be accessed from other services (e.g., `FirebaseAuthService`)
  - Cache clearing works properly on sign-out
  - No more compilation errors
- **Files Modified**: 
  - `lib/services/assemblyai_service.dart` - Added static instance getter
- **Status**: ✅ Fixed

### App Stuck on White Screen
- **Issue**: App appeared to be stuck on a white screen after installation
- **Root Cause**: Incomplete app installation rather than a code error
- **Resolution**: 
  - User resolved by ensuring app installation completed fully
  - No code changes required
- **Impact**: 
  - Confirmed issue was environmental, not code-related
  - App functions correctly after proper installation
- **Status**: ✅ Resolved (No code fix needed)

### Export Failed: No Space Left on Device
- **Issue**: Users encountering "FileSystemException: writeFrom failed, path = '...' (OS Error: No space left on device, errno = 28)" when trying to export ARCX backups
- **Root Cause**: 
  1. Export process requires 2-3x the final archive size in temporary space
  2. Device storage nearly full before export starts
  3. Multiple exports accumulating in `Documents/Exports/` directory
  4. No automatic cleanup of old exports
  5. Full backups every time (no incremental backup option) causing redundant data
- **Resolution**:
  1. Documented space requirements and recommendations in `BACKUP_SYSTEM.md`
  2. Recommended using date range filtering for incremental backups
  3. Recommended exporting media separately from entries/chats
  4. Recommended cleaning up old exports regularly
  5. Recommended exporting to cloud storage when possible
- **Impact**: 
  - Users have clear guidance on managing export space
  - Recommendations provided for space-saving strategies
  - Future incremental backup feature planned
- **Files Modified**: 
  - `docs/Export and Import Architecture/BACKUP_SYSTEM.md` - Comprehensive documentation added
- **Status**: ✅ Documented (Future feature: Incremental backups)

### Phase Sharing Image Capture Failures
- **Issue**: Multiple "Failed to capture arcform image" errors when trying to share phases
- **Root Cause**: 
  1. `repaintBoundaryKey` not accessible after navigating to `ArcformShareCompositionScreen`
  2. Image capture attempted after navigation, when widget tree was no longer accessible
  3. No fallback capture methods implemented
- **Resolution**:
  1. Implemented pre-capture: Capture Arcform image *before* navigating to composition screen
  2. Pass captured image bytes directly to `ArcformShareCompositionScreen`
  3. Added multiple fallback capture methods in composition screen
  4. Implemented offscreen capture using `OverlayEntry` for sharing-specific zoom levels
  5. Added 100ms delay before capture to ensure widget is fully rendered
- **Impact**: 
  - Phase sharing now works reliably
  - Image capture happens at correct zoom levels
  - Multiple fallback methods ensure capture success
- **Files Modified**: 
  - `lib/ui/phase/simplified_arcform_view_3d.dart` - Pre-capture before navigation
  - `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` - Pre-capture and offscreen capture
  - `lib/arc/arcform/share/arcform_share_composition_screen.dart` - Fallback capture methods
- **Status**: ✅ Fixed

### LUMARA Favorites Not Importing from ARCX
- **Issue**: LUMARA favorites (chats, answers, journal entries) were not being imported from ARCX files
- **Root Cause**: 
  1. Import service was looking for `lumara_favorites.json` in `PhaseRegimes/` directory, but export writes it to `extensions/`
  2. Import logic had restrictive condition preventing import if destination category lists were not empty
- **Resolution**:
  1. Updated `_importLumaraFavorites` to check `extensions/` directory first, with fallback to `PhaseRegimes/` for backward compatibility
  2. Removed restrictive import policy - now imports with deduplication regardless of existing favorites
  3. Ensured import proceeds even if favorites already exist (deduplication handles duplicates)
- **Impact**: 
  - LUMARA favorites now import correctly from ARCX files
  - Backward compatibility maintained for older export formats
  - Deduplication prevents duplicate favorites
- **Files Modified**: 
  - `lib/mira/store/arcx/services/arcx_import_service_v2.dart` - Fixed import path and policy
- **Status**: ✅ Fixed

### Phase Information Missing from ARCX Exports
- **Issue**: LUMARA favorites exported in ARCX format were not including phase information, making it impossible to use phase context when importing
- **Root Cause**: Export service wasn't enriching favorites with phase regime information before export
- **Resolution**:
  1. Implemented `_enrichFavoritesWithPhaseInfo` function to look up active phase regime for each favorite's timestamp
  2. Added `phase` and `phase_regime_id` fields to exported favorite data
  3. Updated export version to `1.2` to reflect phase information inclusion
- **Impact**: 
  - LUMARA favorites now include phase context when exported
  - Enables phase-aware favorite restoration (e.g., "You felt this way when you wrote this")
  - Better context preservation across exports/imports
- **Files Modified**: 
  - `lib/mira/store/arcx/services/arcx_export_service_v2.dart` - Added phase enrichment
- **Status**: ✅ Fixed

---

## Resolved Issues (v2.1.73 - v2.1.75)

### Phase Sharing Image Capture and Layout Issues
- **Issue**: Multiple issues with phase sharing image generation:
  1. "Failed to capture arcform image" errors when sharing
  2. Images appearing squished on Instagram Story and Feed formats
  3. LinkedIn layout not centered, white background instead of black
  4. Zoom levels incorrect (too zoomed out for LinkedIn, too close for preview)
  5. Yellow underlining on labels (user concern, though no actual underlining in code)
  6. Labels visible by default (privacy concern for public networks)
- **Root Cause**: 
  1. Image capture attempted after navigation when widget tree was inaccessible
  2. Aspect ratio not preserved when drawing Arcform images to canvas
  3. Background color and layout not matching design specifications
  4. Zoom levels inconsistent between preview and capture
  5. Labels enabled by default without privacy consideration
- **Resolution**:
  1. **Pre-capture Implementation**: Capture Arcform image before navigating to composition screen
  2. **Aspect Ratio Preservation**: Modified `_drawArcformImage` to preserve aspect ratio using `BoxFit.contain` logic
  3. **Black Background**: Changed background from white gradient to solid black for all formats
  4. **Text Colors**: Updated all text colors to white/light gray for black background
  5. **Centered LinkedIn Layout**: Redesigned LinkedIn Feed layout to be centered composition
  6. **Zoom Consistency**: Set `initialZoom: 1.6` for both preview and capture (was 3.5 for preview, causing issues)
  7. **Offscreen Capture**: Implemented offscreen capture using `OverlayEntry` for sharing-specific zoom levels
  8. **Label Privacy**: Set `enableLabels: false` by default for image capture, added "Show Labels" toggle
  9. **Layout Refinements**: Reduced borders, adjusted canvas sizes for Instagram and LinkedIn formats
- **Impact**: 
  - Phase sharing now works reliably with proper image capture
  - Images display correctly without squishing
  - Professional black background design implemented
  - Privacy controls for label visibility
  - Consistent zoom levels across preview and sharing
- **Files Modified**: 
  - `lib/arc/arcform/share/arcform_share_image_generator.dart` - Black background, aspect ratio, layout fixes
  - `lib/arc/arcform/share/arcform_share_composition_screen.dart` - Label toggle, fallback capture methods
  - `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` - Pre-capture, offscreen capture, zoom fixes
  - `lib/ui/phase/simplified_arcform_view_3d.dart` - Pre-capture, offscreen capture, zoom fixes
- **Status**: ✅ Fixed

### ARCX Export Not Including LUMARA Favorites
- **Issue**: ARCX exports were not properly exporting LUMARA favorites (chats, answers, and journal entries)
- **Root Cause**: `_exportLumaraFavorites` function was only being called when `includePhaseRegimes` was true, causing favorites to be skipped in many export scenarios
- **Resolution**:
  1. Modified export logic to ensure `_exportLumaraFavorites` is always called in all export paths
  2. Updated `_exportTogether`, `_exportEntriesChatsTogetherMediaSeparate`, and `_exportGroup` to always export favorites
  3. Ensured favorites are written to `extensions/lumara_favorites.json` regardless of other export options
- **Impact**: 
  - LUMARA favorites are now consistently exported in all ARCX exports
  - Users can restore their saved favorites when importing backups
  - Export completeness improved
- **Files Modified**: 
  - `lib/mira/store/arcx/services/arcx_export_service_v2.dart` - Fixed export logic to always include favorites
- **Status**: ✅ Fixed

### Phase Information Missing from LUMARA Favorites Export
- **Issue**: LUMARA favorites exported in ARCX format were not including phase information, making it impossible to use phase context when importing
- **Root Cause**: Export service wasn't enriching favorites with phase regime information before export
- **Resolution**:
  1. Implemented `_enrichFavoritesWithPhaseInfo` function to look up active phase regime for each favorite's timestamp
  2. Added `phase` and `phase_regime_id` fields to exported favorite data
  3. Updated export version to `1.2` to reflect phase information inclusion
- **Impact**: 
  - LUMARA favorites now include phase context when exported
  - Enables phase-aware favorite restoration (e.g., "You felt this way when you wrote this")
  - Better context preservation across exports/imports
- **Files Modified**: 
  - `lib/mira/store/arcx/services/arcx_export_service_v2.dart` - Added phase enrichment
- **Status**: ✅ Fixed

### Share Button Navigation Errors
- **Issue**: Multiple share buttons leading to errors:
  1. Share button next to phase name in phase view → Error
  2. Share button in Phase Preview (upper right) → Error
  3. Both should navigate to same share screen
- **Root Cause**: 
  1. Share buttons were using legacy `showArcformShareSheet` which no longer exists
  2. Image capture attempted after navigation when widget tree was inaccessible
  3. No consistent sharing flow across different entry points
- **Resolution**:
  1. Updated all share buttons to navigate to `ArcformShareCompositionScreen`
  2. Implemented pre-capture: Capture Arcform image before navigating
  3. Pass captured image bytes directly to composition screen
  4. Added `arcformData` parameter to allow regeneration with different settings
  5. Unified sharing flow across all entry points
- **Impact**: 
  - All share buttons now work correctly
  - Consistent sharing experience regardless of entry point
  - Image capture happens reliably before navigation
- **Files Modified**: 
  - `lib/ui/phase/simplified_arcform_view_3d.dart` - Updated share button flow
  - `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` - Updated share button flow
  - `lib/arc/arcform/share/arcform_share_composition_screen.dart` - Added fallback capture methods
- **Status**: ✅ Fixed

---

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
- **Related Record**: [lumara-subject-drift-and-repetitive-endings.md](records/lumara-subject-drift-and-repetitive-endings.md)

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

---

**Status**: ✅ Complete  
**Last Updated**: January 1, 2026

