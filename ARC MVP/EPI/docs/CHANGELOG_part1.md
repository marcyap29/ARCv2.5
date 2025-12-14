# EPI ARC MVP - Changelog (Part 1: December 2025)

**Version:** 2.1.53
**Last Updated:** December 13, 2025
**Coverage:** December 2025 releases

---

## [2.1.53] - December 13, 2025

### **Jarvis-Style Voice Chat UI (Phase 1)** - ✅ Complete

#### Glowing Voice Indicator Widget
- **NEW**: `lib/shared/widgets/glowing_voice_indicator.dart`
- ChatGPT-style multi-layer pulsing glow animation
- State-based colors: Red (listening), Orange (thinking), Green (speaking), Gray (idle)
- Customizable: size, speed, intensity, glow radius
- Supports custom icons or images
- **Bonus**: `SoundWaveIndicator` variant with animated bars

#### Voice Chat UI Integration
- Added microphone button to LUMARA chat AppBar (top-right)
- Replaced basic MicButton with `GlowingVoiceIndicator` in `VoiceChatPanel`
- Simplified bottom sheet with centered glowing orb
- Enhanced state visualization with color-coded feedback
- Improved control flow (tap orb to start/stop, End Session button)

#### Voice System (Already Existed, Now Exposed)
- ✅ Speech-to-Text (on-device via `speech_to_text` plugin)
- ✅ Text-to-Speech (via `flutter_tts`)
- ✅ Intent routing: Journal (create/append/query), Chat, Files
- ✅ PII scrubbing (Mode A pipeline)
- ✅ Context memory across conversation turns
- ✅ Auto-resume loop (LUMARA speaks → automatically listens for response)

#### How to Use
1. Open LUMARA chat
2. Tap 🎤 mic button in AppBar
3. Grant microphone permission (first time)
4. Tap the glowing orb to start talking
5. Say: "Create a new journal" / "How am I feeling?" / "Summarize my week"
6. Tap orb again to stop and process
7. LUMARA responds with voice + text

#### Files Changed
- NEW: `lib/shared/widgets/glowing_voice_indicator.dart`
- MODIFIED: `lib/arc/chat/ui/lumara_assistant_screen.dart` (mic button in AppBar)
- MODIFIED: `lib/arc/chat/ui/voice_chat_panel.dart` (glowing indicator integration)

**Status**: ✅ Complete  
**Branch**: `dev-voice-updates`

---

## [2.1.52] - December 13, 2025

### **Settings Reorganization & Health Integration** - ✅ Complete

#### Unified Settings Structure
- **Advanced Settings** screen consolidates all power-user features
- **Combined Analysis** view merges Phase Analysis + Advanced Analytics (6 tabs)
- Simplified LUMARA section with inline Therapeutic Depth slider and Web Search toggle
- Removed separate "LUMARA Settings" screen (functionality moved inline)

#### Phase Tab Cleanup
- Removed "Analysis" menu item (now in Settings → Advanced)
- Removed "Advanced Analytics" menu item (merged into Analysis)
- Menu simplified to: Arcforms | Timeline | Settings

#### Music Feature Removal
- Removed Ethereal Music background player
- Removed Music Control Section from Settings
- Removed AudioService and related code

#### Health→LUMARA Integration
- Created HealthDataService for persisting sleep/energy data
- Connected Medical tab data to LUMARA control state
- **Health Settings UI**: Added sliders for sleep quality and energy level
- **Save Button**: Persist health status with visual feedback
- **Effect Preview**: Real-time text shows how health affects LUMARA
- Health signals now influence LUMARA behavior:
  - Low sleep quality → Higher warmth, lower challenge
  - Low energy → Lower verbosity, Companion persona
  - High energy + readiness → May trigger Strategist/Challenger

#### Files Changed
- NEW: `lib/shared/ui/settings/advanced_settings_view.dart`
- NEW: `lib/shared/ui/settings/combined_analysis_view.dart`
- NEW: `lib/services/health_data_service.dart`
- MODIFIED: `lib/shared/ui/settings/settings_view.dart`
- MODIFIED: `lib/ui/phase/phase_analysis_view.dart`
- MODIFIED: `lib/arc/chat/services/lumara_control_state_builder.dart`
- MODIFIED: `lib/arc/ui/health/health_settings_dialog.dart` (Health Signals UI)
- DELETED: `lib/shared/ui/settings/lumara_settings_view.dart`
- DELETED: `lib/shared/ui/settings/music_control_section.dart`
- DELETED: `lib/core/services/audio_service.dart`

**Status**: ✅ Complete  
**Branch**: `dev-lumara-endprompt`

---

## [2.1.51] - December 12, 2025

### **LUMARA Persona System** - ✅ Complete

#### 4 Distinct Personality Modes
- **Auto** (🔄): Adapts personality based on context - sentinel alerts, emotional tone, readiness, time of day
- **The Companion** (🤝): Warm, supportive presence for daily reflection
- **The Therapist** (💜): Deep therapeutic support with gentle pacing, ECHO+SAGE
- **The Strategist** (🎯): Sharp, analytical insights with 5-section structured output
- **The Challenger** (⚡): Direct feedback that pushes growth

#### Auto-Detection Logic
- Sentinel alerts → Therapist (safety override)
- Deep therapeutic mode → Therapist
- Emotional distress (distressed/anxious/sad) → Therapist
- High readiness + morning + high energy → Challenger
- High readiness + afternoon → Strategist
- Analytical/curious emotional tone → Strategist
- Evening/night or low energy → Companion
- Default → Companion

#### Strategist 5-Section Format
When in Strategist mode, LUMARA uses structured operational output:
1. Signal Separation (short-window vs long-horizon patterns)
2. Phase Determination (with confidence basis)
3. Interpretation (system terms: load, capacity, risk)
4. Phase-Appropriate Actions (2-4 concrete steps)
5. Optional Reflection (only if reduces ambiguity)

#### UI Integration
- Settings → LUMARA → LUMARA Persona (above LUMARA Settings)
- Radio button selection with icons and descriptions
- Loading state indicator during persona changes

#### Files Modified
- `lib/arc/chat/services/lumara_reflection_settings_service.dart` - LumaraPersona enum + persistence
- `lib/arc/chat/services/lumara_control_state_builder.dart` - Auto-detection + behavioral overrides
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Section 7: Persona behaviors
- `lib/shared/ui/settings/settings_view.dart` - Persona picker UI

**Status**: ✅ Complete  
**Branch**: `dev-lumara-endprompt`

---

## [2.1.50] - December 12, 2025

### **Scroll Navigation UX Enhancement** - ✅ Complete

#### Visible Floating Scroll Buttons
- **Scroll-to-Top Button (⬆️)**: Up-arrow FAB appears when scrolled down
  - Tapping scrolls to top of content
  - Gray background with white icon
- **Scroll-to-Bottom Button (⬇️)**: Down-arrow FAB appears when not at bottom
  - Tapping scrolls to bottom of content
  - Stacked below scroll-to-top button
- **Available in**: LUMARA Chat, Journal Timeline, Journal Entry Editor

#### Implementation Details
- **Dual State Tracking**: `_showScrollToTop` and `_showScrollToBottom` state variables
- **Scroll Listener**: `_onScrollChanged()` monitors position
- **Threshold**: Buttons appear when >100px from respective ends
- **Animation**: Smooth 300ms scroll with easeOut curve
- **Positioning**: Buttons stack vertically on right side of screen

#### Files Modified
- `lib/arc/chat/ui/lumara_assistant_screen.dart` - Chat scroll navigation
- `lib/arc/ui/timeline/timeline_view.dart` - Timeline scroll navigation
- `lib/ui/journal/journal_screen.dart` - Entry editor scroll navigation

**Status**: ✅ Complete  
**Branch**: `uiux-updates`

---

## [2.1.49] - December 12, 2025

### **Splash Screen & Bug Reporting Enhancements** - ✅ Complete

#### Animated Phase Shape on Splash
- **Spinning 3D Phase Visualization**: App launch now displays animated phase shape
  - Uses authentic `layout3D()` and `generateEdges()` from existing system
  - Each phase shows its unique wireframe structure spinning horizontally
  - Discovery: DNA helix, Expansion: petal rings, Transition: bridge/fork
  - Consolidation: geodesic lattice, Recovery: pyramid, Breakthrough: supernova
- **Accurate Phase Display**: Uses `PhaseRegimeService` for current phase
  - Same source as Phase tab for consistency
  - Falls back to most recent regime if no ongoing one
- **8-Second Duration**: Extended splash to admire animation (tap to skip)
- **Phase Label**: Subtle phase name displayed below animation

#### Shake to Report Bug Feature
- **Native iOS Shake Detection**: Shake device to open bug report dialog
  - Custom `ShakeDetectingWindow` for motion detection
  - `ShakeDetectorPlugin` with event channel to Flutter
  - Haptic feedback on shake detection
- **Bug Report Dialog**: Modal bottom sheet for feedback
  - Text field for bug description
  - Option to include device information
  - Local storage with console logging
- **Settings Toggle**: Enable/disable in Settings → LUMARA section

#### Consolidation Phase Fix
- **Fixed Missing Edges**: Consolidation lattice now shows connected wireframe
  - Increased `maxDist` from 1.8 to 3.0 for larger node spread
  - Increased `maxEdgesPerNode` from 4 to 5 for denser lattice

---

## [2.1.48] - December 11, 2025

### **Phase System Overhaul & UI/UX Improvements** - ✅ Complete

#### Phase Calculation (RIVET Integration)
- **Advanced RIVET-Based Analysis**: Replaced simple phase counting with sophisticated RIVET analysis
  - Uses `PhaseRecommender.recommend()` for content-based phase prediction
  - Compares early vs recent predictions for accurate trend detection
  - Entry dropdown corrections ("chisel") feed into RIVET as `refPhase`
- **Consistent Calculation**: Same RIVET-based trend calculation across:
  - Phase tab → Phase Transition Readiness card
  - Analysis → Phase Alignment Snapshot → Transition Trend
- **10-Day Rolling Window**: Phase regimes now use 10-day windows for better granularity

#### Phase Persistence Fixes
- **Entry Phase Override Persistence**: Fixed phase dropdown changes not persisting
  - Added `_currentEntryOverride` state variable in `journal_screen.dart`
  - Updated `_getCurrentEntryForContext()` to use local override state
  - Preserved `userPhaseOverride` and `isPhaseLocked` in `updateEntryWithKeywords()`
- **ARCX Import Enhancement**: Import now properly reads:
  - `userPhaseOverride` - Manual phase selection
  - `isPhaseLocked` - Phase lock status
  - `autoPhase` - Automatically detected phase
  - `autoPhaseConfidence` - Detection confidence
  - `legacyPhaseTag` - Backward compatibility

#### Content Cleanup
- **Disabled Auto-Hashtag Injection**: Stopped automatic `#consolidation`, `#discovery`, etc. in content
  - Phase now tracked via `autoPhase`, `userPhaseOverride`, and phase regimes
  - User content remains clean
  - Modified `_ensurePhaseHashtagInContent()` in `journal_capture_cubit.dart`

#### Navigation Bar Redesign
- **4-Button Layout**: Changed from 3 tabs + floating FAB to 4 inline buttons
  - New order: LUMARA | Phase | Journal | +
  - "+" button now centered within its slot
- **Simplified Styling**:
  - Removed active highlight (purple gradient) from selected tabs
  - Gray background for LUMARA, Phase, Journal buttons
  - LUMARA uses gold `lumara_logo.png` icon

#### Phase Tab Restructuring
- **Phase Transition Readiness Card**: Moved from Journal to Phase tab
  - Always displays (shows "stable" state if no trend)
  - Uses RIVET-based calculation for accuracy
- **Change Phase Button**: Moved from Journal to Phase tab
  - Changes last 10 days' phase regime
  - Purple outlined style with black fill
- **New Sections**:
  - "Past Phases": Most recent past instance of each distinct phase
  - "Example Phases": Demo phases for users to explore
- **Removed Elements**:
  - "Phase Elements" chips (not necessary for users)
  - "Today" text and schedule icon from Phase card
- **Scrollable Content**: Entire Phase tab now scrollable via `footerWidgets`

#### Phase Card Improvements
- **Interactive Timeline**: Phase timeline bars are now tappable
  - Shows phase details, entry count, and date range
  - "View X Entries" button opens entry list
  - Entries are hyperlinked for direct navigation
- **Visual Hints**: Added tap/swipe icons and hint text for discoverability
- **Days Display**: Fixed "0 days" showing incorrectly

#### Sign-In Screen Enhancement
- **Back Navigation**: Added `AppBar` with back arrow when navigating from Settings
- **Removed Redundant Button**: Removed duplicate "Go Back" button at bottom

#### Code Consolidation
- **Unified 3D Viewer**: `FullScreenPhaseViewer` now shared between Journal and Phase screens
- **Text Standardization**: "ARCForm" → "Phase" across UI
  - "ARCForm Info" → "Phase Info"
  - "About this ARCForm" → "About this Phase"
- **Metadata Removal**: Removed Nodes/Edges/Created chips from Phase cards

#### Files Modified

**Phase System:**
- `lib/ui/phase/phase_analysis_view.dart` - RIVET integration, card moves, scrollability
- `lib/ui/phase/simplified_arcform_view_3d.dart` - Past/Example phases, footer widgets
- `lib/ui/phase/phase_change_readiness_card.dart` - Always display, chisel support
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` - Removed cards/button
- `lib/arc/core/journal_capture_cubit.dart` - Disabled auto-hashtags, preserve override
- `lib/ui/journal/journal_screen.dart` - Local override state, persistence fix

**Navigation:**
- `lib/shared/tab_bar.dart` - 4-button layout, styling changes
- `lib/shared/ui/home/home_view.dart` - New tab order and indices

**Authentication:**
- `lib/ui/auth/sign_in_screen.dart` - Back navigation AppBar

**Import/Export:**
- `lib/mira/store/arcx/services/arcx_import_service.dart` - Phase field import

**Status**: ✅ Complete  
**Branch**: `dev-uiux-improvements`

---

## [2.1.47] - December 10, 2025

### **Google Sign-In Configuration (iOS)** - ✅ Complete

#### Fixes & Updates
- Added correct `CLIENT_ID` and `REVERSED_CLIENT_ID` to `GoogleService-Info.plist`
- Added `CFBundleURLTypes` with Google URL scheme to `Info.plist` to prevent sign-in crashes
- Confirmed Firebase Auth Google Sign-In flow working on iOS
- Updated documentation across `docs/` to reflect the configuration

#### Status
- **Branch**: `dev`
- **Impact**: Eliminates Google Sign-In crash; no user-facing behavior changes beyond successful sign-in

---

## [2.1.46] - December 9, 2025

### **Priority 3 Complete: Authentication & Security** - ✅ Complete

#### Objective Achieved
- ✅ **Firebase Authentication** - Anonymous, Google, and Email/Password sign-in
- ✅ **Per-Entry Rate Limiting** - 5 LUMARA in-journal comments per entry (free tier)
- ✅ **Per-Chat Rate Limiting** - 20 LUMARA messages per chat (free tier)
- ✅ **Admin Privileges** - Email-based admin detection with unlimited access
- ✅ **Account Linking** - Anonymous user data preserved when signing in
- ✅ **Complete Sign-In UI** - Full sign up/sign in flow with password reset

#### Authentication System

**Backend Implementation:**
- **authGuard.ts**: Centralized authentication enforcement
  - `enforceAuth()` - Validates Firebase Auth tokens
  - `checkJournalEntryLimit()` - Per-entry usage tracking
  - `checkChatLimit()` - Per-chat usage tracking
  - Admin email detection with automatic pro upgrade
- **proxyGemini.ts**: Updated to check entry/chat limits
- **generateJournalReflection.ts**: Auth integration with entry limit
- **Firestore Rules**: Per-user data isolation

**Frontend Implementation:**
- **sign_in_screen.dart**: Complete sign up/sign in UI
  - Google Sign-In with one-tap
  - Email/Password with validation
  - Forgot Password functionality
  - Toggle between sign-in and sign-up modes
  - Human-readable error messages
- **trial_expired_dialog.dart**: Prompt when free limits reached
- **settings_view.dart**: Account tile with sign-in/sign-out management
- **firebase_auth_service.dart**: Account linking for anonymous users

#### Rate Limiting

| Feature | Free Tier | Premium/Admin |
|---------|-----------|---------------|
| In-Journal LUMARA | 5 per entry | Unlimited |
| In-Chat LUMARA | 20 per chat | Unlimited |

#### Files Modified

**Backend:**
- `functions/src/authGuard.ts` - Authentication and rate limiting
- `functions/src/functions/proxyGemini.ts` - Limit enforcement
- `functions/src/functions/generateJournalReflection.ts` - Auth + limits
- `functions/src/functions/sendChatMessage.ts` - Auth integration
- `functions/src/types.ts` - UserDocument with auth fields
- `firestore.rules` - Security rules

**Frontend:**
- `lib/ui/auth/sign_in_screen.dart` - Sign up/sign in UI
- `lib/ui/auth/trial_expired_dialog.dart` - Trial limit dialog
- `lib/services/firebase_auth_service.dart` - Auth service
- `lib/services/gemini_send.dart` - entryId/chatId params
- `lib/shared/ui/settings/settings_view.dart` - Account management
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` - Chat rate limiting
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Entry ID support
- `lib/ui/journal/journal_screen.dart` - Entry ID tracking

**Status**: ✅ Priority 3 Complete  
**Branch**: `dev`

---

## [2.1.45] - December 7, 2025

### **Priority 2 Complete: Firebase API Proxy Implementation** - ✅ Complete

#### Objective Achieved
- ✅ **API keys securely hidden** in Firebase Cloud Functions
- ✅ **LUMARA runs on-device** - maintains full journal access (chat + in-journal)
- ✅ **Simple proxy pattern** - Firebase only handles API key management
- ✅ **No user configuration** - API key management is transparent
- ✅ **Full data access** - LUMARA retains access to local Hive database

#### Latest Fix (Dec 7, 2025 - Evening)
- **Fixed in-journal LUMARA reflections** - Restored on-device reflection logic
- Removed Firebase-only enforcement that was blocking journal reflections
- Both chat LUMARA and in-journal LUMARA now working with Firebase proxy
- All LUMARA features fully functional with secured API key access

#### Architecture Decision
**Initial Approach (Abandoned):**
- Attempted to move all LUMARA logic to Firebase Functions
- **Problem:** Lost access to local journal data stored in Hive

**Final Approach (Implemented):**
- Keep LUMARA running on-device with all its logic
- Create simple `proxyGemini` Firebase Function that only adds API key
- Client sends prompts → Firebase adds key → Gemini API → Response returns

#### Implementation Details

**Client Side Changes:**
- **File:** `lib/services/gemini_send.dart`
- **Change:** Modified `geminiSend()` to call Firebase `proxyGemini` function
- **Benefit:** Transparent API key management, no code changes needed elsewhere

**Server Side Implementation:**
- **File:** `functions/lib/index.js`
- **Function:** `proxyGemini` (pure JavaScript, no TypeScript compilation needed)
- **Parameters:** Accepts `system`, `user`, `jsonExpected`
- **Functionality:** Adds API key, forwards to Gemini, returns response
- **Security:** `invoker: "public"` for MVP (will add proper auth in Priority 3)

**Cloud Run Configuration:**
- Set "Allow public access" in Cloud Run → proxygemini service → Security
- Required to avoid `UNAUTHENTICATED` errors during MVP testing
- IAM permissions: Compute service account needs `Cloud Datastore User` role

#### Files Modified

**Client:**
- `lib/services/gemini_send.dart` - Updated to call Firebase proxy

**Server:**
- `functions/lib/index.js` - Added `proxyGemini` function
- `functions/src/index.ts` - Added export for `proxyGemini`

**Documentation:**
- `docs/backend.md` - New comprehensive backend documentation (NEW)
- `docs/README.md` - Updated with Priority 2 completion
- Archived setup guides moved to `docs/archive/setup/`
- Archived testing docs moved to `docs/archive/priority2-testing/`

**Status**: ✅ Priority 2 Complete - Ready for Production Testing  
**Branch**: `dev-priority-2-api-refactor`  
**Tested**: December 7, 2025

---

## [2.1.44] - December 4, 2025

### **LUMARA Auto-Scroll UX Enhancement** - Complete

#### Feature Overview
- **Unified Auto-Scroll Behavior**: Both in-journal and in-chat LUMARA now automatically scroll to bottom when activated
- **Immediate Visual Feedback**: Users instantly see where LUMARA's response will appear
- **Consistent UX**: Identical scroll behavior across both journal and chat interfaces
- **Smooth Animation**: Professional 300ms scroll animation with easeOut curve

#### In-Journal Auto-Scroll Implementation
- **Trigger**: When user presses LUMARA button in journal screen
- **Behavior**: Page immediately scrolls to bottom showing "LUMARA is thinking..." in free space
- **File**: `lib/ui/journal/journal_screen.dart` - Modified `_generateLumaraReflection()` method
- **Animation**: 300ms duration with `Curves.easeOut` for smooth user experience

#### In-Chat Auto-Scroll Implementation
- **Trigger**: When user sends message in chat session
- **Behavior**: Chat immediately scrolls to bottom showing thinking indicator
- **File**: `lib/arc/chat/chat/ui/session_view.dart` - Modified `_sendMessage()` method
- **Animation**: Same 300ms duration with `Curves.easeOut` for consistency

---

## [2.1.43] - December 3-4, 2025

### **LUMARA Subject Drift and Repetitive Endings Fixes** - Complete

#### Problem Resolution
- **Subject Drift Issue**: Fixed LUMARA focusing on unrelated historical entries instead of current journal entry
- **Repetitive Endings Issue**: Fixed LUMARA always ending with the same "Would it help to name one small step" phrase

#### Subject Drift Fixes
- **Current Entry Priority**: Added explicit `**CURRENT ENTRY (PRIMARY FOCUS)**` marking in context building
- **Historical Context Reduction**: Reduced historical entries from 19 to 15 and marked as "REFERENCE ONLY"
- **Strong Focus Instructions**: Added clear directives for all conversation modes to focus on current entry
- **Master Prompt Enhancement**: Updated core LUMARA system with current entry priority rules

#### Ending Phrase Variety Fixes
- **Therapeutic Presence Integration**: Replaced hardcoded phrase with existing therapeutic presence data system
- **24+ Varied Closings**: Now uses diverse endings from grounded_containment, reflective_echo, restorative_closure, etc.
- **Time-Based Rotation**: Implemented dynamic selection to prevent repetition patterns

### **In-Journal LUMARA Backend Integration** - Complete

#### Backend Cloud Function
- **Created `generateJournalReflection` Cloud Function**:
  - Handles in-journal LUMARA reflections via backend
  - Uses Firebase Secrets for API keys (no local key needed)
  - Supports all reflection options (tone modes, conversation modes, etc.)
  - Enforces rate limits and tier-based model routing

---

*For earlier December 2025 entries, see main CHANGELOG.md*

---

## Navigation

- **[CHANGELOG.md](CHANGELOG.md)** - Index and overview
- **[CHANGELOG_part2.md](CHANGELOG_part2.md)** - November 2025
- **[CHANGELOG_part3.md](CHANGELOG_part3.md)** - January-October 2025 and earlier

