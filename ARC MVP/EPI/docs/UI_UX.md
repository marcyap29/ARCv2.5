# EPI MVP - UI/UX Feature Documentation

**Version:** 2.1.53
**Last Updated:** December 13, 2025
**Status:** ✅ Comprehensive Feature Analysis Complete

---

## Overview

The EPI (Evolving Personal Intelligence) Flutter application provides a sophisticated, multimodal personal journaling and AI companion experience. This document details all key UI/UX features, design patterns, and interaction systems implemented throughout the application.

---

## Table of Contents

1. [Navigation & Core Layout](#1-navigation--core-layout)
2. [Design System & Theming](#2-design-system--theming)
3. [Journaling Interface (ARC Module)](#3-journaling-interface-arc-module)
4. [LUMARA Chat Interface](#4-lumara-chat-interface)
5. [Timeline & Data Visualization](#5-timeline--data-visualization)
6. [ARCForm 3D Visualization](#6-arcform-3d-visualization)
7. [Phase Detection & Analytics](#7-phase-detection--analytics)
8. [Settings & Configuration](#8-settings--configuration)
9. [User Onboarding](#9-user-onboarding)
10. [Notifications & Feedback](#10-notifications--feedback)
11. [Accessibility Features](#11-accessibility-features)
12. [Export/Import Interfaces](#12-exportimport-interfaces)
13. [Animation & Motion Design](#13-animation--motion-design)
14. [Reusable UI Components](#14-reusable-ui-components)
15. [Form Handling & Input](#15-form-handling--input)
16. [Authentication UI](#16-authentication-ui)
17. [Phase Tab (v2.1.48)](#17-phase-tab-v2148)
18. [Journal Updates (v2.1.48)](#18-journal-updates-v2148)
19. [Splash Screen (v2.1.49)](#19-splash-screen-v2149)
20. [Bug Reporting (v2.1.49)](#20-bug-reporting-v2149)
21. [Scroll Navigation (v2.1.50)](#21-scroll-navigation-v2150)
22. [LUMARA Persona (v2.1.51)](#22-lumara-persona-v2151)
23. [Advanced Settings (v2.1.52)](#23-advanced-settings-v2152)
24. [Health→LUMARA Integration (v2.1.52)](#24-healthlumara-integration-v2152)
25. [Voice Chat - Jarvis Mode (v2.1.53)](#25-voice-chat---jarvis-mode-v2153)

---

## 1. Navigation & Core Layout

### Primary Navigation Structure

#### 🏠 Home View Container
**File:** `lib/shared/ui/home/home_view.dart`

**Features:**
- **4-Button Bottom Navigation:** LUMARA | Phase | Journal | + (as of v2.1.48)
- **Inline Create Button:** "+" button integrated into tab row
- **Sacred Atmosphere:** Ethereal music with fade-in/out effects
- **Gradient Background:** Navy (#0C0F14) with subtle texture

**User Interaction Flow:**
1. Launch → Ethereal music fade-in (2s)
2. Tab selection → Smooth transition (250ms)
3. Create button (+) → Journal entry creation
4. Status toggles → Mode activation with visual feedback

#### 🎯 Custom Tab Bar System (v2.1.48)
**File:** `lib/shared/tab_bar.dart`

**Implementation Details:**
- **4-Button Layout:** All buttons in single row (removed floating FAB)
- **Gray Background:** LUMARA, Phase, Journal buttons use `kcSurfaceAltColor`
- **Purple "+" Button:** Primary accent, centered within slot
- **No Active Highlight:** Removed purple gradient on selected tabs
- **Smooth Transitions:** 250ms animation duration

**Tab Configuration:**
1. **LUMARA Tab** → `LumaraAssistantScreen` (AI companion with gold logo icon)
2. **Phase Tab** → `PhaseAnalysisView` (Phase visualization and analysis)
3. **Journal Tab** → `UnifiedJournalView` → `TimelineView`
4. **+ Button** → Journal entry creation

### Navigation Patterns
- **Hierarchical Navigation:** Back button preservation with app bar
- **Hero Transitions:** Smooth element transitions between screens
- **Bottom Sheet Navigation:** Modal overlays for contextual actions
- **Drawer Navigation:** Side panel access (where implemented)

---

## 2. Design System & Theming

### 🎨 Color Palette
**File:** `lib/shared/app_colors.dart`

| Usage | Color | Hex Value | Description |
|-------|--------|-----------|-------------|
| **Background** | Dark Navy | `#0C0F14` | Primary app background |
| **Surface** | Navy Gray | `#121621` | Card and container background |
| **Surface Alt** | Light Navy | `#171C29` | Alternative container surface |
| **Primary** | Gradient | `#4F46E5 → #7C3AED` | Buttons, highlights, selected states |
| **Accent** | Light Purple | `#D1B3FF` | Secondary highlights and icons |
| **Success** | Mint Green | `#6BE3A0` | Success states and positive feedback |
| **Warning** | Golden Yellow | `#F7D774` | Warnings and caution states |
| **Danger** | Red | `#FF6B6B` | Error states and destructive actions |
| **Text Primary** | White | `#FFFFFF` | Primary text content |
| **Text Secondary** | Gray | `#A0AEC0` | Secondary text and metadata |
| **Border** | Dark Gray | `#2D3748` | Dividers and input borders |

### 📝 Typography System
**File:** `lib/shared/text_style.dart`

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| **Heading1** | 32px | W600 | Main page titles |
| **Heading2** | 28px | W600 | Section headers |
| **Heading3** | 24px | W600 | Card titles |
| **Heading4** | 20px | W600 | Small headers |
| **Body** | 16px | W400 | Standard content |
| **Caption** | 14px | W500 | Secondary information |
| **Button** | 16px | W600 | CTA text |
| **Label** | 12px | W500 | Tags and timestamps |
| **Supporting** | 13px | W400 | Descriptions |
| **Primary Action** | 18px | W700 | Prominent buttons |
| **Secondary Action** | 16px | W600 | Secondary buttons |

### 🎭 Component Variants

#### Button System
**File:** `lib/shared/button.dart`

- **Primary:** Gradient background with white text
- **Secondary:** Accent color background
- **Outline:** Border-based styling with accent color
- **Dimensions:** 48px height, 10px rounded corners
- **States:** Default, Loading (spinner), Disabled
- **Features:** Icon support with 8px spacing, full-width option

#### Card System
**File:** `lib/shared/card.dart`

- **Elevated:** Drop shadow with dark surface background
- **Outlined:** Border with surface color background
- **Filled:** Semi-transparent primary color fill
- **Dimensions:** 12px rounded corners, customizable padding
- **Interactions:** Tap-enabled with Material ripple effect

### 🌙 Dark Mode Implementation
- **Consistent Dark Theme:** All screens optimized for dark backgrounds
- **High Contrast Text:** White text on dark surfaces for readability
- **Graduated Surfaces:** Multiple gray levels for visual hierarchy
- **Accent Preservation:** Vibrant colors maintained for highlights

---

## 3. Journaling Interface (ARC Module)

### ✍️ Journal Entry Creation
**File:** `lib/ui/journal/journal_screen.dart`

#### Core Features
- **Rich Text Editing:** AI-enhanced text field with real-time suggestions
- **Multimodal Capture:** Photos, videos, audio recording
- **Emotion & Context Selection:** Guided picker workflows
- **Keyword Analysis:** Automatic extraction with visualization
- **Draft Auto-Save:** Session caching with recovery
- **Location Integration:** Geocoding with privacy controls
- **LUMARA Inline API:** Real-time writing assistance with enhanced context focus
  - **Current Entry Priority:** Explicit focus on the entry being written (prevents subject drift)
  - **Context Hierarchy:** Current entry marked as "PRIMARY FOCUS" with historical context as "REFERENCE ONLY"
  - **Simplified Formatting:** Fixed 2 sentences per paragraph for consistent mobile readability
  - **Varied Response Endings:** 24+ therapeutic closings prevent repetitive phrases
  - **Contextual Appropriateness:** Endings match emotional tone and therapeutic needs

#### User Interaction Flow
```
Entry Creation → Text Input → Emotion Selection → Reason Selection →
Media Capture → Keyword Analysis → Save to Timeline
```

**Text Input Features:**
- **AI Suggestions:** Contextual writing prompts via LUMARA
- **Real-time Processing:** Keyword extraction during typing
- **Draft Persistence:** Auto-save every 30 seconds
- **Character Count:** Visual indicator with threshold warnings
- **Formatting Support:** Basic text formatting options

### 🎭 Emotion & Context Selection
**File:** `lib/arc/ui/widgets/emotion_selection_view.dart`

#### Emotion Selection Interface
- **Screen-Based Picker:** Full-screen emotion selection experience
- **Animated Transitions:** 800ms fade between selection stages
- **PageView Flow:** Emotion → Reason → Keywords (3-stage process)
- **Visual Feedback:** Selection confirmation with 300ms delay
- **Back Navigation:** Breadcrumb-style navigation between stages

**Emotion Picker Widget:**
- **File:** `lib/arc/ui/widgets/emotion_picker.dart`
- **Grid Layout:** Organized emotion categories with icons
- **Fade Animation:** Smooth entrance and selection feedback
- **State Tracking:** Multi-step form state management

### 📸 Media Capture & Management
**File:** `lib/arc/ui/media/media_capture_sheet.dart`

#### Media Capture Sheet
- **Bottom Sheet Interface:** Swipe-up modal with drag handle
- **Capture Options:** Camera, Gallery, Audio recording
- **Permission Handling:** Runtime permissions for camera/microphone
- **OCR Integration:** Text extraction from images (iOS Vision)
- **Processing States:** Loading indicators with status messages

#### Media Strip Display
**File:** `lib/arc/ui/media/media_strip.dart`
- **Horizontal Carousel:** Scrollable 80x80px thumbnails
- **Rounded Corners:** Consistent with card design (8px radius)
- **Delete Overlay:** X button on hover/long-press
- **Read-only Mode:** Viewing-only state for saved entries
- **Accessibility:** Semantic labels for screen readers

#### Full-Screen Photo Viewer
**File:** `lib/ui/journal/widgets/full_screen_photo_viewer.dart`
- **Gesture Controls:** Pinch-to-zoom, swipe navigation
- **Hero Animations:** Smooth transition from thumbnail
- **Double-tap Zoom:** Quick zoom toggle functionality
- **Context Preservation:** Maintains position in media collection

### 🤖 LUMARA Integration

#### Suggestion Sheet
**File:** `lib/ui/journal/widgets/lumara_suggestion_sheet.dart`

**5 Reflection Intents:**
1. **"Suggest some ideas"** 💡 - Creative brainstorming
2. **"Help me think this through"** 🧠 - Analytical processing
3. **"Offer a different perspective"** 👁️ - Alternative viewpoints
4. **"Suggest next steps"** ➡️ - Action planning
5. **"Reflect more deeply"** 🔍 - Deeper introspection

**Features:**
- **Bottom Sheet Modal:** Dismissible with drag handle
- **Icon-Based Interface:** Visual intent selection
- **Context Mapping:** Maps to `ConversationMode` enum for LLM

#### LUMARA FAB (Floating Action Button)
**File:** `lib/ui/journal/widgets/lumara_fab.dart`

**Animation States:**
- **Idle Pulse:** 300ms cycle, repeating every 7 seconds
- **Nudge Animation:** Triggered when user types ≥ threshold
- **Reduced Motion:** Respects accessibility preferences
- **Visual Design:** Gold background with auto_stars icon
- **Positioning:** Bottom-right with hero transition support

### 📝 Enhanced Text Input
**File:** `lib/ui/widgets/rich_text_field.dart`

**Rich Text Field Features:**
- **TextEditingController Integration:** Standard Flutter text handling
- **Focus Management:** FocusNode for keyboard control
- **Styling:** White text (16px) on dark background
- **Line Height:** 1.4x for improved readability
- **Hint Text:** Gray placeholder with 60% opacity

**AI-Enhanced Text Field:**
- **File:** `lib/ui/widgets/ai_enhanced_text_field.dart`
- **LUMARA Integration:** Inline suggestions during typing
- **Context Awareness:** Analyzes content for relevant prompts

### 📋 Draft Management
**File:** `lib/ui/journal/drafts_screen.dart`

**Features:**
- **Draft List View:** Chronological list with timestamps
- **Multi-Select Mode:** Batch operations with selection toggle
- **Bulk Actions:** Delete multiple drafts with confirmation
- **Auto-Recovery:** Restore drafts on app restart
- **Individual Editing:** Resume draft composition

---

## 4. LUMARA Chat Interface

### 💬 Main Chat Experience
**File:** `lib/arc/chat/ui/lumara_assistant_screen.dart`

#### Core Components
- **Message List:** Auto-scrolling ListView with smooth animations
- **Input System:** TextEditingController with send button
- **Voice Integration:** Optional voice input with live transcript
- **Audio Output:** Text-to-Speech for AI responses
- **Message Editing:** In-place editing with state tracking
- **Dynamic Visibility:** Context-aware input field display
- **Enhanced Text Formatting:** Professional paragraph formatting for LUMARA responses
  - **Chat-Specific Rules:** Fixed 3 sentences per paragraph for consistent readability
  - **Simplified Processing:** Streamlined paragraph logic for improved performance
  - **Varied Response Endings:** 24+ therapeutic closings from existing system (grounded_containment, reflective_echo, etc.)
  - **Time-Based Rotation:** Dynamic selection prevents repetitive ending phrases

#### 🔄 Auto-Scroll Thinking Interface
**Files:** `lib/ui/journal/journal_screen.dart`, `lib/arc/chat/chat/ui/session_view.dart`

**Visual Components:**
- **Auto-Scroll Animation:** Smooth 300ms scroll to bottom when LUMARA activated
- **Thinking Indicator:** "LUMARA is thinking..." appears in free space at bottom
- **Unified Behavior:** Consistent experience across journal and chat interfaces
- **Professional Animation:** easeOut curve for polished user experience

**User Experience:**
- **Immediate Visual Feedback:** Page scrolls to show exactly where response will appear
- **Clear Context:** Users understand LUMARA is processing without confusion
- **Consistent Interface:** Identical behavior whether in journal or chat mode
- **Reduced Cognitive Load:** Eliminates guessing about response placement
- **Auto-Close:** Dismisses automatically when processing completes or errors
- **Cross-Platform:** Used in both journal reflections and chat generation

#### User Interactions
```
Text Input → Send (Enter) | Voice Input → Transcript → Send
Tap Response → Context Menu (Copy/Favorite/Delete)
Long Press → Edit Mode | Scroll Up → Load History
```

### 🎨 Chat Bubble Design

**Message Styling:**
- **User Messages:** Right-aligned with primary gradient background
- **Assistant Messages:** Left-aligned with surface color background
- **Corner Radius:** 16px with subtle chat tail indicator
- **Typography:** Body text style with 1.4 line height
- **Timestamps:** Caption style below messages
- **Status Indicators:** Read receipts and delivery confirmation

### 🎯 Enhanced Chat Features
**File:** `lib/arc/chat/chat/ui/enhanced_chats_screen.dart`

- **Message Threading:** Visual conversation organization
- **Category System:** Topic-based chat grouping
- **Favorites/Bookmarks:** Save important responses
- **History Management:** Chat archive and search
- **Export Options:** Chat history export functionality

### 🎮 Quick Interaction Tools

#### Quick Palette
**File:** `lib/arc/chat/ui/lumara_quick_palette.dart`
- **Template Responses:** Pre-configured conversation starters
- **Follow-up Prompts:** Context-aware suggestions
- **Visual Icons:** Mode-based iconography
- **Quick Access:** Swipe-up or button activation

#### Voice Chat Panel
**File:** `lib/arc/chat/ui/voice_chat_panel.dart`
- **Microphone Control:** Start/stop recording with visual feedback
- **Waveform Visualization:** Real-time audio level display
- **Recording Duration:** Live timer during voice input
- **Transcript Preview:** Real-time speech-to-text display
- **Cancel/Confirm:** User control over voice submission

### ⚙️ Chat Settings & Configuration
**File:** `lib/arc/chat/ui/lumara_settings_screen.dart`

#### Model Configuration
- **Provider Selection:** Anthropic, Gemini, Llama, Qwen, OpenAI
- **Parameter Tuning:** Temperature, context window, response length
- **Context Scope:** Memory integration and conversation history
- **Response Format:** Tone, style, and formatting preferences

#### Memory & Persistence
- **Memory Mode Settings:** Cross-session conversation memory
- **Context Retention:** How long to maintain conversation context
- **Data Export:** Chat history and memory export options

### 🏷️ Attribution & Sources
**Widgets:**
- **Simple Attribution:** `attribution_display_widget.dart`
- **Enhanced Attribution:** `enhanced_attribution_display_widget.dart`
- **Features:** Source provenance, memory attribution, interactive links

### 🏥 Health Integration
**File:** `lib/arc/chat/ui/widgets/health_preview_sheet.dart`
- **Contextual Health Data:** Display relevant health metrics in chat
- **Wearable Integration:** Real-time sensor data
- **Quick Metrics:** Heart rate, activity, sleep data overview

---

## 5. Timeline & Data Visualization

### 📅 Interactive Timeline
**File:** `lib/arc/ui/timeline/widgets/interactive_timeline_view.dart`

#### Core Features
- **Chronological List:** Scrollable journal entries with timestamps
- **Auto-Scroll:** Automatic scroll-to-bottom for new entries
- **Jump Navigation:** AutoScrollController for date-specific navigation
- **Selection Mode:** Multi-select with batch operations
- **Search & Filter:** Entry filtering and content search
- **ARCForm Toggle:** Switch between list and constellation views

#### Entry Rendering
- **Truncated Preview:** Expandable text with "read more" functionality
- **Media Thumbnails:** Horizontal strip of attached media
- **Metadata Tags:** Emotion, reason, and phase indicators
- **Favorite Toggle:** Star button for marking important entries
- **Timestamp Display:** Relative and absolute time formatting

#### Visual Design
- **Card-Based Layout:** Each entry in elevated card container
- **Fade Transitions:** 300ms animations between states
- **Loading States:** Skeleton screens while fetching data
- **Empty States:** Guidance when no entries exist

### 📊 Calendar Week View
**File:** `lib/arc/ui/timeline/widgets/calendar_week_timeline.dart`

**Features:**
- **Weekly Grid:** 7-day column layout with date headers
- **Entry Indicators:** Dot markers on dates with entries
- **Quick Navigation:** Tap date to jump to entries
- **Week Synchronization:** ValueNotifier for week changes
- **Visual Density:** Compact view showing activity patterns

### 🎭 Current Phase Preview
**File:** `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart`

- **Live Phase Display:** Shows active life phase constellation
- **Auto-Refresh:** Updates when phase detection changes
- **Duration Indicator:** Shows time spent in current phase
- **Quick Access:** Tap to open full phase analysis
- **Visual Consistency:** Matches full ARCForm styling

### 📑 Entry Content Rendering
**File:** `lib/arc/ui/timeline/widgets/entry_content_renderer.dart`

**Content Processing:**
- **Rich Text Display:** Formatted text with proper typography
- **Inline Media:** Embedded photos and videos
- **Keyword Highlighting:** Emphasized discovered keywords
- **Link Detection:** Automatic URL recognition and tap handling
- **Reflection Blocks:** Special formatting for LUMARA insights

---

## 6. ARCForm 3D Visualization

### 🌌 3D Constellation Renderer
**File:** `lib/arc/ui/arcforms/widgets/constellation_3d_arcform.dart`

#### Interactive Features
- **3D Rotation:** Multi-touch gesture support for orbit control
- **Auto-Rotation:** 25-second cycle with pause/resume toggle
- **Pinch-to-Zoom:** Scale transformation with limits
- **Pan Translation:** Single-finger camera movement
- **Node Selection:** Tap nodes for detail view with pulse animation
- **Geometry Switching:** 6 layouts (Spiral, Flower, Branch, Weave, Glow Core, Fractal)

#### Visual Elements
- **Starfield Background:** Twinkling star particles (3s cycle)
- **Node Spheres:** Colored by emotional valence
- **Connection Edges:** Lines between related keywords/concepts
- **Glow Effects:** Subtle shadows and lighting
- **Selection Feedback:** Pulse animation (800ms cycle)

#### Animation System
- **Smooth Transitions:** 300ms for scale/rotation changes
- **Camera Movements:** Fluid camera position adjustments
- **Continuous Rotation:** Linear animation for auto-rotation
- **Twinkling Stars:** Repeating opacity animation
- **Selection Pulse:** Rhythmic scale animation for selected nodes

### 🎭 Phase ARCForm Viewer
**File:** `lib/ui/phase/phase_arcform_3d_screen.dart`

**Features:**
- **Full-Screen View:** Immersive 3D constellation experience
- **Phase-Specific Generation:** Constellation tailored to user's phase
- **User Data Integration:** Real journal data or demo fallback
- **Gesture Controls:** Full 3D manipulation capabilities
- **Performance Optimization:** Efficient rendering for mobile devices

### 📊 Simplified ARCForm Views
**2D Version:** `lib/ui/phase/simplified_arcform_view.dart`
**3D Version:** `lib/ui/phase/simplified_arcform_view_3d.dart`

- **Compact Display:** Card-sized constellation representations
- **Geometry Icons:** Visual indicators for different layouts
- **Quick Preview:** Tap to expand to full view
- **Performance:** Optimized for list/card contexts

### 🎨 Emotional Valence System
**File:** `lib/arc/ui/arcforms/services/emotional_valence_service.dart`

**Color Mapping:**
- **Positive Emotions:** Green gradients
- **Neutral Emotions:** Blue gradients
- **Reflective Emotions:** Purple gradients
- **Dynamic Assignment:** Real-time color calculation based on sentiment analysis

### 🔧 ARCForm Data Model
**File:** `lib/arc/ui/arcforms/arcform_mvp_implementation.dart`

**SimpleArcform Structure:**
- **Geometry Type:** Spatial arrangement algorithm
- **Nodes:** Keywords with emotional valence scores
- **Edges:** Connections between related concepts
- **Colors:** Gradient palette for visualization
- **Metadata:** Title, timestamp, and generation details

**Node Arrangement Algorithms:**
1. **Spiral:** Fibonacci-based radial arrangement
2. **Flower:** Petal-based symmetric layout
3. **Branch:** Tree-like hierarchical structure
4. **Weave:** Interwoven connection patterns
5. **Glow Core:** Central focus with radiating elements
6. **Fractal:** Self-similar recursive patterns

---

## 7. Phase Detection & Analytics

### 📈 Phase Analysis Dashboard
**File:** `lib/ui/phase/phase_analysis_view.dart`

#### Three-Tab Interface
1. **ARCForms Tab:** Constellation visualizations for each phase
2. **Timeline Tab:** Phase progression with regime integration
3. **Analysis Tab:** Advanced metrics and AI recommendations

#### Features
- **Current Phase Detection:** Real-time life phase identification
- **Phase Regime Management:** Stable transition tracking
- **RIVET Sweep Integration:** Risk validation and evidence tracking
- **Change Readiness Assessment:** Predictive analysis for phase transitions
- **Historical Analysis:** Pattern recognition over time

### 🔍 Advanced Analytics View
**File:** `lib/ui/phase/advanced_analytics_view.dart`

**Analytical Components:**
- **Phase Metrics:** Detailed statistics for each life phase
- **Transition Analysis:** Timing and triggers for phase changes
- **Pattern Visualization:** Visual representation of behavioral patterns
- **Recommendation Engine:** AI-driven insights for personal growth
- **Historical Comparisons:** Year-over-year and phase-over-phase analysis

### ⚠️ Sentinel Pattern Analysis
**File:** `lib/ui/phase/sentinel_analysis_view.dart`

**Risk Detection Interface:**
- **Pattern Recognition:** Automated detection of concerning patterns
- **Risk Indicators:** Visual alerts for potential issues
- **Anomaly Visualization:** Graphical representation of unusual patterns
- **Alert System:** Notifications for immediate attention items
- **Trend Analysis:** Long-term pattern evolution tracking

#### Sentinel Pattern Cards
**File:** `lib/ui/phase/sentinel_pattern_card.dart`
- **Individual Pattern Display:** Dedicated card per detected pattern
- **Severity Indicators:** Color-coded risk levels
- **Quick Actions:** Immediate response options
- **Detail Expansion:** Tap to view comprehensive analysis

### 📊 Phase Change Readiness
**File:** `lib/ui/phase/phase_change_readiness_card.dart`

**Readiness Assessment:**
- **Readiness Score:** Numerical assessment (0-100)
- **Progress Visualization:** Circular progress indicator
- **Requirement Checklist:** Prerequisites for phase transition
- **Transition Recommendations:** Personalized guidance
- **Timeline Prediction:** Estimated timeframe for transition

### 🏥 Health Data Integration
**Health Detail Screen:** `lib/ui/health/health_detail_screen.dart`
- **Wearable Data Display:** Real-time sensor integration
- **Metric Charts:** Trend visualization over time
- **Historical Analysis:** Long-term health pattern recognition

**Health Dashboard View:** `lib/arc/ui/health/health_view.dart`
- **Key Metrics Summary:** Quick health status overview
- **Medication Manager:** Prescription and supplement tracking
- **Settings Access:** Health tracking configuration

---

## 8. Settings & Configuration

### ⚙️ Main Settings Interface
**File:** `lib/shared/ui/settings/settings_view.dart`

#### Settings Categories

1. **👤 Account** - Sign in/out and account management
   - Google Sign-In (iOS) configured via OAuth client + URL scheme to prevent consent-screen crashes
2. **👥 Favorites Management** - Saved content organization
3. **🤖 LUMARA Settings** - AI model and behavior configuration
4. **🔒 Privacy Settings** - Data protection and redaction controls
5. **⚡ Throttle** - Developer throttle unlock (password-protected rate limit bypass)
6. **🧠 Memory Mode** - Memory snapshots and lifecycle management
6. **🎵 Music Control** - Audio experience settings
7. **🔄 Sync Settings** - Cloud synchronization and device linking
8. **⚖️ Conflict Management** - Resolution workflow settings
9. **🎨 Personalization** - UI customization and preferences
10. **ℹ️ About** - App information and credits

### 💝 Favorites Management
**File:** `lib/shared/ui/settings/favorites_management_view.dart`

**Organization Features:**
- **LUMARA Responses:** Save meaningful AI interactions
- **Chat Sessions:** Bookmark important conversations
- **Journal Entries:** Mark significant personal entries
- **Category System:** Organize favorites by type and topic
- **Quick Access:** Rapid retrieval of saved content
- **Export Options:** Share or backup favorite content

### 🤖 LUMARA Configuration
**AI Model Settings:**
- **Backend-Managed:** All API keys and model selection handled automatically by Firebase Cloud Functions
- **No User Configuration Required:** Users no longer need to input API keys or select providers
- **Reflection Settings:** Similarity threshold, lookback period, max matches, cross-modal awareness
- **Therapeutic Presence:** Enable/disable with depth levels (Light, Moderate, Deep)
- **Web Access:** Opt-in toggle for safe web search capabilities
- **Context Sources:** Control what data LUMARA can access (journal, phase, ARCForms, voice, media, drafts, chats)

### 🔒 Privacy & Security Settings
**File:** `lib/shared/ui/settings/privacy_settings_view.dart`

**Privacy Controls:**
- **PII Detection:** Automatic personally identifiable information detection
- **Content Redaction:** Selectively hide sensitive information
- **Data Export Controls:** Manage what data can be exported
- **Privacy Mode:** Enhanced protection during sensitive sessions
- **Consent Management:** Granular permission controls
- **Data Deletion:** Secure removal of personal information

### ⚡ Throttle Settings (Developer/Admin Feature)
**File:** `lib/shared/ui/settings/throttle_settings_view.dart`

**Password-Protected Rate Limit Bypass:**
- **Empty Password Field:** Text input with no length hints or character count
- **Obscure Text:** Password field with toggle to show/hide characters
- **Status Display:** Real-time throttle unlock status indicator
  - Green indicator when unlocked
  - Red indicator when locked
  - Loading state during verification
- **Unlock Button:** Submit password to unlock throttle (bypasses rate limits)
- **Lock Button:** Remove throttle unlock (restores rate limiting)
- **Status Check:** Automatic status check on screen load
- **Error Handling:** User-friendly error messages for incorrect passwords
- **Security Features:**
  - Timing-safe password comparison (prevents timing attacks)
  - Firebase Functions secret storage for password
  - No password hints or length indicators
  - Secure backend validation

**UI Components:**
- Password input field with obscure text toggle
- Status card showing current throttle state
- Action buttons (Unlock/Lock) with loading states
- Error message display area
- Settings tile integration in Privacy & Security section

### 🧠 Memory Mode Configuration
**File:** `lib/shared/ui/settings/memory_mode_settings_view.dart`

**Memory Management:**
- **Snapshot Creation:** Manual and automatic memory snapshots
- **Lifecycle Settings:** How long to retain different types of memories
- **Batch Operations:** Bulk memory management actions
- **Storage Status:** Memory usage and capacity monitoring
- **Integration Controls:** How memory integrates with chat and journaling


### 🎨 Personalization Options
**File:** `lib/shared/ui/settings/personalization_view.dart`

**Customization Controls:**
- **Text Scale Slider:** Adjust font size (0.8x to 1.2x multiplier)
- **Tone Selector:** Choose AI interaction style
- **Rhythm Picker:** Set journaling frequency preferences (daily, weekly, etc.)
- **Theme Preferences:** Color scheme and appearance options
- **Language Settings:** Localization and content language

---

## 9. User Onboarding

### 🌟 Onboarding Experience
**File:** `lib/shared/ui/onboarding/onboarding_view.dart`

#### 4-Stage Onboarding Flow

1. **Welcome Screen**
   - App introduction with mission statement
   - Ethereal music fade-in (2s duration)
   - Beautiful visual introduction to EPI concept

2. **Central Word Input**
   - Single text field for life journey central concept
   - Focused, meditative interface design
   - Guidance text explaining the purpose

3. **Phase Grid Selection**
   - Visual grid of 6 Atlas phases
   - Interactive selection with visual feedback
   - Phase descriptions and characteristics

4. **Phase Celebration View**
   - Congratulatory screen with selected phase
   - Phase emoji and description display
   - Completion celebration with music fade-out

#### Onboarding Components

**Central Word Input Widget:**
- **Focused Experience:** Single text field dominates screen
- **Guidance Context:** Clear instructions for meaningful input
- **Validation:** Ensures substantive input before proceeding

**Atlas Phase Grid:**
- **File:** `lib/shared/ui/onboarding/widgets/atlas_phase_grid.dart`
- **6-Phase Selector:** Discovery, Expansion, Transition, Consolidation, Recovery, Reflection
- **Visual Design:** Grid layout with icons and descriptions
- **Selection Feedback:** Clear indication of chosen phase

**Phase Celebration View:**
- **File:** `lib/shared/ui/onboarding/phase_celebration_view.dart`
- **Celebration Animation:** Congratulatory interface with phase details
- **Music Integration:** 2s audio fade-out for closure
- **Transition Preparation:** Setup for main app experience

#### Audio Integration
- **Ethereal Music System:** Background audio for meditative experience
- **Fade Timing:** 2s fade-in at welcome, 2s fade-out before celebration
- **Volume Control:** Respects system volume and audio preferences

### 🎯 Optional Clarification
**Phase Quiz Prompt View:**
- Additional questions for phase clarification if needed
- Branching logic based on user responses
- Refinement of phase selection through guided questions

---

## 10. Notifications & Feedback

### 📬 In-App Notification System
**File:** `lib/shared/in_app_notification.dart`

#### Notification Types
- **✅ Success:** Green background with checkmark icon
- **❌ Error:** Red background with error icon
- **ℹ️ Info:** Gray background with information icon
- **⭐ ARCForm Generated:** Primary gradient with star icon

#### Visual Design
- **Positioning:** Top-of-screen below safe area
- **Animation:** Slide-up entrance with elastic curve
- **Auto-Dismiss:** 3-4 second duration (configurable)
- **User Control:** Manual close button (X icon)
- **Action Button:** Optional quick action (e.g., "View")
- **Exit Animation:** Smooth fade-out transition

#### Notification Behavior
- **Queue Management:** Sequential display of multiple notifications
- **Interruption Handling:** Pause auto-dismiss on user interaction
- **Accessibility:** VoiceOver announcements for screen readers

### 🧠 Memory Attribution Notifications
**File:** `lib/arc/chat/ui/widgets/memory_notification_widget.dart`

**Features:**
- **Source Attribution:** Display data provenance in chat
- **Interactive Links:** Tap to view source material
- **Context Display:** Show relevant memory context
- **Privacy Respect:** Honor privacy settings for sensitive data

### ⚡ Real-Time Feedback
**Snackbars & Toast Messages:**
- **Bottom Positioning:** Material Design compliant placement
- **Action Integration:** Quick actions from notifications
- **Auto-Dismiss:** Configurable timeout with manual control
- **Queue System:** Ordered presentation of multiple messages

---

## 11. Accessibility Features

### ♿ Core Accessibility Implementation

#### Screen Reader Support
- **Semantic Labels:** Comprehensive alt text for images and icons
- **VoiceOver Integration:** Full iOS VoiceOver compatibility
- **Content Description:** Detailed descriptions for complex UI elements
- **Navigation Announcements:** Clear indication of screen changes

#### Touch Target Optimization
- **Minimum Size:** 44x44pt touch targets for all interactive elements
- **Spacing:** Adequate spacing between touch targets
- **Visual Feedback:** Clear indication of touch interactions
- **Gesture Support:** Standard accessibility gestures

#### Visual Accessibility
- **High Contrast:** Text meets WCAG AA standards against backgrounds
- **Color Independence:** Information not conveyed by color alone
- **Text Scaling:** Support for system text size preferences
- **Reduced Motion:** Respect for reduced motion accessibility settings

#### Motion & Animation Accessibility
**Reduced Motion Support:**
- **File:** Accessibility preferences check in animation components
- **FAB Animations:** Respect MediaQuery.boldText and reduced motion flags
- **Transition Control:** Ability to disable non-essential animations
- **Focus Indicators:** Clear focus states for keyboard navigation

### 🗣️ VoiceOver Integration
**File:** `lib/shared/ui/settings/voiceover_preference_service.dart`

**Features:**
- **Preference Storage:** Save VoiceOver user preferences
- **TTS Integration:** Text-to-speech for content reading
- **Navigation Assistance:** Audio cues for interface navigation
- **Content Prioritization:** Focus on most important content first

### ⌨️ Keyboard Navigation
- **Tab Order:** Logical focus progression through interface
- **Focus Management:** Clear visual focus indicators
- **Shortcut Support:** Common keyboard shortcuts where applicable
- **Return Key Handling:** Appropriate actions for Return/Enter key

### 🌍 Internationalization Ready
- **RTL Support:** Right-to-left language compatibility
- **Locale Awareness:** Regional format preferences
- **Text Expansion:** UI accommodates longer translations
- **Cultural Sensitivity:** Appropriate iconography and color choices

---

## 12. Export/Import Interfaces

### 📤 MCP Export System
**File:** `lib/ui/export_import/mcp_export_screen.dart`

#### Export Features
- **Progress Tracking:** Visual progress bar with percentage completion
- **Data Selection:** Choose which data types to include
- **Compression Options:** File size optimization controls
- **Media Inclusion:** Toggle for multimedia content
- **Destination Choice:** File location and naming options

#### User Experience
- **Step-by-Step Flow:** Guided export process
- **Estimation:** File size and time predictions
- **Cancellation:** Ability to cancel mid-process
- **Completion Notification:** Success confirmation with file location

### 📥 MCP Import System
**File:** `lib/ui/export_import/mcp_import_screen.dart`

#### Import Features
- **File Selection:** Browse and select MCP bundles
- **Preview Mode:** Inspect bundle contents before import
- **Conflict Resolution:** Handle data conflicts intelligently
- **Progress Monitoring:** Real-time import progress display
- **Success Confirmation:** Clear completion status

#### Conflict Resolution
- **Automatic Resolution:** Smart conflict detection and resolution
- **User Choice:** Manual resolution options when needed
- **Preview Changes:** Show what will be imported/changed
- **Backup Creation:** Automatic backup before import

### 🔄 ARCX Import Progress
**File:** `lib/mira/store/arcx/ui/arcx_import_progress_screen.dart`

**Features:**
- **Visual Progress:** Circular progress indicator
- **Entry Counter:** Real-time count of imported entries
- **Time Estimation:** Remaining time calculation
- **Cancellation Support:** Safe cancellation with cleanup
- **Error Handling:** Clear error messages and recovery options

### 📊 Data Management
**File:** `lib/ui/screens/mcp_management_screen.dart`

#### Bundle Management
- **Health Overview:** Bundle integrity status
- **Available Bundles:** List of importable data sets
- **Quick Actions:** Export, import, delete operations
- **Storage Monitor:** Disk usage and capacity tracking
- **Maintenance Tools:** Data cleanup and optimization

---

## 13. Animation & Motion Design

### 🎬 Animation System Architecture

#### Animation Controllers
- **Fade Transitions:** `AlwaysStoppedAnimation`, `FadeTransition`
- **Slide Movements:** `SlideTransition` with `Tween<Offset>`
- **Scale Effects:** `ScaleTransition` with `Tween<double>`
- **Rotation:** `Transform.rotate` with continuous animation
- **Staggered Sequences:** Coordinated entry animations with delays

#### Timing & Curves
**Standard Curves:**
- **`Curves.elasticOut`** - Bouncy reveals (ARCForm intro)
- **`Curves.easeInOut`** - Smooth transitions (tab changes)
- **`Curves.easeOut`** - Quick entrances (notifications)
- **`Curves.easeInBack`** - Smooth exits (modal dismissals)
- **`Curves.linear`** - Continuous rotation and progress

#### Duration Patterns
- **Quick Feedback:** 200-300ms for immediate responses
- **Screen Transitions:** 600-800ms for major navigation
- **Idle Animations:** 3-7s cycles for ambient effects
- **Auto-Dismiss:** 3-4s for temporary notifications
- **Loading States:** Indefinite with smooth looping

### ✨ Signature Animations

#### ARCForm Intro Animation
**File:** `lib/shared/arcform_intro_animation.dart`

**5-Stage Sequence:**
1. **Backdrop Fade-in** (0-800ms) - Dark overlay appearance
2. **Scale-in** (300-1500ms) - Constellation emerges with elastic curve
3. **Rotation** (300ms+) - Gentle continuous spinning
4. **Particle Effects** (800-2300ms) - Accent elements fade in
5. **Text Reveal** - Title and metadata display
6. **Auto-Dismiss** (3s total) - Smooth reverse animation

#### FAB Pulse Animation
- **Idle State:** 300ms scale pulse every 7 seconds
- **Nudge State:** Attention-grabbing animation when user reaches typing threshold
- **Accessibility:** Respects reduced motion preferences

#### Message Transitions
- **Chat Bubbles:** Slide-in with fade for new messages
- **Timeline Entries:** Staggered appearance in lists
- **Selection States:** Scale and color transitions for selected items

### 🔄 Performance Optimization
- **Vsync Integration:** `TickerProviderStateMixin` for frame synchronization
- **Value Listeners:** Efficient frame-by-frame updates
- **Disposal Management:** Proper cleanup to prevent memory leaks
- **Conditional Animation:** Disable animations when appropriate (reduced motion)

---

## 14. Reusable UI Components

### 🖼️ Media Components

#### Cached Thumbnail Widget
**File:** `lib/ui/widgets/cached_thumbnail.dart`

**Features:**
- **Async Loading:** Progressive image loading with placeholder
- **Caching System:** Efficient thumbnail cache via `ThumbnailCacheService`
- **Error States:** Graceful handling of missing or corrupted media
- **Tap Indicators:** Visual feedback for interactive thumbnails
- **Customizable Sizing:** Flexible dimensions and fit options

#### Full Image Viewer
**File:** `lib/ui/widgets/full_image_viewer.dart`

**Gesture Support:**
- **Pinch-to-Zoom:** Multi-touch scale transformation
- **Double-Tap Toggle:** Quick zoom in/out functionality
- **Swipe-to-Dismiss:** Gesture-based modal dismissal
- **Aspect Preservation:** Maintains original image proportions

### 🗺️ Location Components

#### Location Picker Dialog
**File:** `lib/ui/widgets/location_picker_dialog.dart`

**Functionality:**
- **Map Integration:** Interactive map for location selection
- **Reverse Geocoding:** Convert coordinates to human-readable addresses
- **Current Location:** Quick selection of user's current position
- **Confirmation Flow:** Clear accept/cancel options

### 🏷️ Content Components

#### Keywords Discovered Widget
**File:** `lib/ui/widgets/keywords_discovered_widget.dart`

**Features:**
- **Chip Display:** Keywords shown as interactive chips
- **Frequency Visualization:** Visual indication of keyword importance
- **Sentiment Indicators:** Color coding based on emotional valence
- **Interactive Selection:** Tap to focus or filter by keyword

#### Discovery Popup
**File:** `lib/ui/widgets/discovery_popup.dart`

**Behavior:**
- **Floating Presentation:** Non-intrusive overlay for new insights
- **Auto-Dismiss:** Configurable timeout with manual close option
- **Animation:** Smooth entrance and exit transitions
- **Position Management:** Smart positioning to avoid UI overlap

### 📊 Status & Feedback Components

### 🎭 Interactive Components

#### Rich Form Elements
- **Date Pickers:** Material Design date selection
- **Time Pickers:** Standard time input with validation
- **Dropdown Menus:** Searchable selection lists
- **Slider Controls:** Continuous value input (e.g., text scale)
- **Toggle Switches:** Boolean preference controls

#### Loading & Progress
- **Skeleton Screens:** Placeholder content during loading
- **Shimmer Effects:** Animated loading placeholders
- **Progress Bars:** Linear progress for operations with known duration
- **Spinners:** Circular progress for indeterminate operations

---

## 15. Form Handling & Input

### 📝 Text Input Components

#### Rich Text Field
**File:** `lib/ui/widgets/rich_text_field.dart`

**Features:**
- **TextEditingController:** Standard Flutter text handling
- **Focus Management:** `FocusNode` for keyboard control
- **Typography:** White text (16px) with 1.4 line height
- **Placeholder Support:** Gray hint text with 60% opacity
- **Event Handling:** Text change listeners and validation

#### AI-Enhanced Text Field
**File:** `lib/ui/widgets/ai_enhanced_text_field.dart`

**AI Integration:**
- **LUMARA Suggestions:** Real-time writing assistance
- **Context Analysis:** Content-aware prompt generation
- **Inline Feedback:** Suggestions appear as overlay or inline text

### 🎮 Input Patterns & Keyboard Types

#### Specialized Keyboards
- **Email Input:** `TextInputType.emailAddress` with validation
- **Phone Numbers:** `TextInputType.phone` with formatting
- **Numeric Input:** `TextInputType.number` with range validation
- **Multiline Text:** `TextInputType.multiline` for journal entries
- **URL Input:** `TextInputType.url` with protocol validation

#### Action Mapping
- **Next Field:** Return key advances to next input
- **Done Action:** Completes form and dismisses keyboard
- **Search Action:** Triggers search functionality
- **Send Action:** Submits content (chat, journal entry)

### 🎯 Selection & Picker Components

#### Emotion & Reason Pickers
**Emotion Picker Implementation:**
- **Grid Layout:** Visual emotion categories with icons
- **Multi-Stage Flow:** Emotion → Reason → Keywords progression
- **Animation Transitions:** Smooth navigation between stages
- **State Persistence:** Maintains selections throughout flow

**Reason Picker Features:**
- **Context Awareness:** Reasons filtered by selected emotion
- **Visual Feedback:** Clear selection indication
- **Quick Selection:** Single-tap choice with confirmation

#### Geometry & Preference Selectors
- **ARCForm Geometry:** Visual selection of constellation layouts
- **Theme Preferences:** Color scheme and appearance options
- **Frequency Settings:** Journal rhythm and notification timing

### 📋 Form Validation & Feedback

#### Validation Patterns
- **Real-Time Validation:** Immediate feedback during input
- **Error States:** Clear indication of validation failures
- **Success States:** Positive feedback for valid input
- **Helper Text:** Guidance and format requirements

#### Error Handling
- **Inline Messages:** Error text below input fields
- **Color Coding:** Red borders and text for errors
- **Icon Indicators:** Visual symbols for error states
- **Accessibility:** Screen reader announcements for errors

### 🔄 Form State Management

#### Draft Systems
- **Auto-Save:** Periodic saving of form progress
- **Recovery:** Restore unsaved changes on app restart
- **Version Control:** Track changes and allow reversion
- **Conflict Resolution:** Handle concurrent editing scenarios

#### Submission Flows
- **Progress Indication:** Visual feedback during submission
- **Success Confirmation:** Clear indication of successful submission
- **Error Recovery:** Options to retry or modify on failure
- **Data Persistence:** Ensure data is saved before navigation

---

## Technical Implementation Notes

### 🛠️ Development Patterns

#### State Management
- **BLoC Pattern:** Business logic separation with reactive UI
- **Cubit Implementation:** Simplified state management for components
- **Repository Pattern:** Data access abstraction
- **Service Providers:** Singleton services for shared functionality

#### Performance Optimization
- **Lazy Loading:** On-demand data loading for large lists
- **Image Caching:** Efficient media asset management
- **Memory Management:** Proper disposal of controllers and listeners
- **Background Processing:** Heavy operations on separate threads

#### Code Organization
- **Feature-Based Structure:** Organized by functionality (ARC, LUMARA, etc.)
- **Shared Components:** Reusable UI elements in shared directories
- **Design System:** Centralized theming and styling
- **Platform Adaptation:** iOS and Android specific adaptations

### 📱 Platform Integration

#### iOS Specific Features
- **Vision Framework:** OCR text extraction from images
- **HealthKit:** Wearable sensor data integration
- **Metal Acceleration:** GPU-accelerated 3D rendering
- **VoiceOver:** Complete accessibility support

#### Android Adaptations
- **Material Design 3:** Google design language implementation
- **Adaptive Icons:** Dynamic icon theming
- **Permission Handling:** Runtime permission requests
- **Notification Channels:** Categorized notification management

#### Cross-Platform Consistency
- **Unified Design System:** Consistent appearance across platforms
- **Feature Parity:** Same functionality on iOS and Android
- **Performance Standards:** Optimized for both platform architectures

---

## Future UI/UX Enhancements

### 🚀 Planned Improvements

#### Enhanced Accessibility
- **Voice Navigation:** Complete voice control interface
- **Gesture Customization:** User-configurable gesture shortcuts
- **High Contrast Mode:** Enhanced visibility options
- **Dyslexia Support:** Font and spacing optimizations

#### Advanced Interactions
- **Haptic Feedback:** Tactile responses for interactions
- **3D Touch/Force Touch:** Pressure-sensitive interactions (iOS)
- **Contextual Menus:** Rich preview and action menus
- **Drag & Drop:** Content manipulation between sections

#### Personalization
- **Adaptive UI:** Interface that learns user preferences
- **Custom Themes:** User-created color schemes
- **Layout Customization:** Rearrangeable interface elements
- **Accessibility Profiles:** Saved accessibility preference sets

#### Performance & Polish
- **120fps Animation:** High refresh rate device support
- **Micro-Interactions:** Subtle feedback for all user actions
- **Loading Optimization:** Faster app startup and data loading
- **Gesture Polish:** More fluid and responsive gesture recognition

---

---

## 16. Authentication UI

### 🔐 Sign-In Screen
**File:** `lib/ui/auth/sign_in_screen.dart`

**Features:**
- **Mode Toggle**: Switch between Sign In and Sign Up with one tap
- **Google Sign-In**: One-tap authentication with account linking
- **Email/Password Form**: 
  - Email validation
  - Password visibility toggle
  - Confirm password for sign-up
  - Minimum 6 character requirement
- **Forgot Password**: Email-based password reset
- **Error Handling**: Human-readable Firebase error messages
- **Loading States**: Spinner during authentication

**Visual Design:**
- Gradient logo icon (80x80px with 20px border radius)
- Modern form inputs with filled backgrounds
- Accent-colored buttons with 12px border radius
- Error container with danger color border

### 📊 Trial Expired Dialog
**File:** `lib/ui/auth/trial_expired_dialog.dart`

**Trigger**: Shown when free user reaches per-entry or per-chat limit

**Features:**
- **Limit Display**: Shows trial limit that was reached
- **Google Sign-In Button**: Quick one-tap upgrade
- **Email Sign-In Link**: Navigate to full sign-in screen
- **Data Preservation Notice**: Reassures users their data is safe

### 👤 Account Management Tile
**File:** `lib/shared/ui/settings/settings_view.dart`

**States:**
- **Signed Out/Anonymous**: Shows "Sign In" with arrow navigation
- **Signed In**: Shows user profile photo, name, email with sign-out button

**Features:**
- **Profile Photo**: CircleAvatar with network image or fallback icon
- **Sign Out Dialog**: Confirmation with data preservation notice
- **Quick Navigation**: Direct link to sign-in screen
- **Back Navigation**: AppBar with back arrow when navigated from Settings (v2.1.48)

---

## 17. Phase Tab (v2.1.48)

### 📊 Phase Analysis View
**File:** `lib/ui/phase/phase_analysis_view.dart`

The Phase tab (formerly "Insights") provides comprehensive phase visualization and analysis.

#### Header & Navigation
- **AppBar Title**: "Phase" (simplified from "Phase Analysis")
- **Tab Position**: Second tab in bottom navigation (LUMARA | **Phase** | Journal | +)

#### Phase Transition Readiness Card
**Location:** Top of Phase tab, above 3D visualization

**Features:**
- **Always Visible**: Shows even when no trend detected
- **Stable State**: Gray color, flat trend icon, "Your reflection patterns are stable in [phase]"
- **Trending State**: Phase-colored, upward trend icon, percentage and approaching phase
- **Info Button**: Explains what drives phase transitions
- **RIVET Calculation**: Uses sophisticated RIVET analysis for trend detection

**Visual Design:**
- Rounded card with 16px border radius
- Gradient progress bar showing trend percentage
- Phase-specific color coding

#### 3D Phase Visualization
**File:** `lib/ui/phase/simplified_arcform_view_3d.dart`

**Features:**
- **Current Phase Display**: 3D constellation visualization
- **Scrollable Content**: 3D view and all cards scroll together via `footerWidgets`
- **Phase Info Dialog**: "Phase Info" and "About this Phase" text (renamed from ARCForm)
- **No Metadata Chips**: Removed Nodes/Edges/Created chips for cleaner UI

#### Change Phase Button
**Location:** Below 3D visualization, above Past Phases section

**Features:**
- **Purple Outlined Style**: Purple border with black fill
- **Purpose**: Changes last 10 days' phase regime to user's selection
- **Phase Selection**: Modal bottom sheet with all 6 phases
- **Immediate Feedback**: Shows phase change in timeline

#### Past Phases Section
**Features:**
- **Most Recent Instances**: Shows most recent past instance of each distinct phase
- **Excludes Current**: Doesn't show current phase instance
- **Tappable Cards**: Navigate to phase details
- **Empty State**: Minimal space when no past phases

#### Example Phases Section
**Features:**
- **Demo Phases**: Shows phases user hasn't experienced yet
- **Educational**: Helps users understand different phase patterns
- **Tappable Cards**: Preview 3D constellation shapes

### 📈 Current Phase Card (Timeline)
**Location:** Bottom of scrollable Phase content

**Features:**
- **Phase Timeline Bars**: Colored segments representing phase history
- **Interactive Segments**: Tap to view phase details, entry count, date range
- **Visual Hints**: Tap/swipe icon and hint text for discoverability
- **Scrollable**: Horizontal scroll for long timelines (>5 phases or >180 days)
- **Entry Navigation**: Hyperlinked entries for direct navigation to journal

#### Phase Detail Popup
**Trigger:** Tap on timeline segment

**Content:**
- Phase name with icon
- Duration in days
- Entry count
- "View X Entries" button

#### Entries Bottom Sheet
**Trigger:** "View X Entries" button in detail popup

**Features:**
- **Entry List**: All entries within the phase period
- **Tappable Entries**: Navigate directly to journal entry
- **Entry Preview**: Date and content snippet

---

## 18. Journal Tab Updates (v2.1.48)

### 📝 Journal Timeline View
**File:** `lib/arc/ui/timeline/timeline_view.dart`

**Changes:**
- **Header Text**: Changed from "Timeline" to "Journal"
- **Simplified Phase Preview**: Removed Nodes/Edges/Tap to expand text
- **Expanded 3D Preview**: Preview image fills available space

### 🎯 Phase Preview Card
**File:** `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart`

**Changes:**
- **Removed Cards**: Phase Transition Readiness and Change Phase moved to Phase tab
- **Cleaner Card**: No metadata chips, expanded 3D visualization
- **Tappable**: Opens `FullScreenPhaseViewer` (shared with Phase tab)

### 📖 Full Screen Phase Viewer
**File:** `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart`

**Shared Component:** Used by both Journal and Phase tabs

**Features:**
- **Phase Info Dialog**: Shows "Phase Info" and "About this Phase"
- **Share Functionality**: "Share Phase" tooltip
- **3D Controls**: Manual rotation and zoom
- **Empty State**: "No Phase data available" message

---

## 19. Splash Screen (v2.1.49)

### 🚀 Animated Splash Screen
**File:** `lib/arc/chat/ui/lumara_splash_screen.dart`

**Features:**
- **ARC Logo**: White logo on black background, centered
- **Animated Phase Shape**: Spinning 3D wireframe of user's current phase
- **Phase Label**: Subtle phase name displayed below animation
- **8-Second Duration**: Time to admire animation (tap anywhere to skip)
- **Fade-In Animation**: Smooth 800ms fade-in on load

### 🎨 Phase Shape Animation
**File:** `lib/ui/splash/animated_phase_shape.dart`

**Implementation:**
- Uses authentic `layout3D()` from `layouts_3d.dart`
- Uses authentic `generateEdges()` for phase-specific connections
- Lightweight `CustomPainter` for fast performance
- 10-second rotation duration

**Phase Shapes:**
| Phase | Shape | Node Count |
|-------|-------|------------|
| Discovery | DNA Helix (1.5 turns) | 10 |
| Expansion | Petal Rings | 12 |
| Transition | Bridge/Fork | 12 |
| Consolidation | Geodesic Lattice | 20 |
| Recovery | Pyramid | 8 |
| Breakthrough | Supernova Star | 12 |

**Rendering:**
- Y-axis rotation (horizontal spin)
- Depth-based opacity and sizing
- Glow effects for visual appeal
- Small node dots at vertices

### 📡 Phase Source
- Uses `PhaseRegimeService` for accurate current phase
- Same source as Phase tab for consistency
- Checks `currentRegime` first, falls back to most recent regime

---

## 20. Bug Reporting (v2.1.49)

### 📱 Shake to Report Bug
**Files:**
- `lib/services/shake_detector_service.dart` (Flutter service)
- `lib/ui/feedback/bug_report_dialog.dart` (Flutter UI)
- `ios/Runner/ShakeDetectorPlugin.swift` (Native iOS plugin)

**User Flow:**
1. Enable "Shake to Report Bug" in Settings → LUMARA
2. Shake device to trigger bug report dialog
3. Enter bug description
4. Optionally include device information
5. Submit report

**Native iOS Implementation:**
- `ShakeDetectingWindow`: Custom UIWindow subclass for motion detection
- `ShakeDetectorPlugin`: FlutterPlugin with event channel
- Haptic feedback on shake detection
- Method channel for start/stop listening

**Settings Integration:**
- Toggle in Settings → LUMARA section
- Preference stored in SharedPreferences
- Visual feedback with bug icon

---

## 21. Scroll Navigation (v2.1.50)

### 📜 Visible Floating Scroll Buttons
**Implemented In:**
- LUMARA Chat (`lumara_assistant_screen.dart`)
- Journal Timeline (`timeline_view.dart`)
- Journal Entry Editor (`journal_screen.dart`)

**Features:**

#### Scroll-to-Top Button (⬆️)
- **Appearance**: Small FAB with up-arrow icon
- **Color**: `kcSurfaceAltColor` (gray) with white icon
- **Position**: Bottom-right, stacked above scroll-to-bottom button
- **Visibility**: Appears when scrolled >100px from top
- **Behavior**: Taps scrolls to top with smooth 300ms animation

#### Scroll-to-Bottom Button (⬇️)
- **Appearance**: Small FAB with down-arrow icon
- **Color**: `kcSurfaceAltColor` (gray) with white icon
- **Position**: Bottom-right corner (16px padding)
- **Visibility**: Appears when >100px from bottom AND content is scrollable
- **Behavior**: Taps scrolls to bottom with smooth 300ms animation

**Implementation Details:**
```dart
// Dual state tracking
bool _showScrollToTop = false;
bool _showScrollToBottom = false;

// Scroll listener
void _onScrollChanged() {
  if (!_scrollController.hasClients) return;
  final position = _scrollController.position;
  final isNearTop = position.pixels <= 100;
  final isNearBottom = position.pixels >= position.maxScrollExtent - 100;
  
  final shouldShowTop = !isNearTop;
  final shouldShowBottom = !isNearBottom && position.maxScrollExtent > 200;
  
  if (_showScrollToTop != shouldShowTop || _showScrollToBottom != shouldShowBottom) {
    setState(() {
      _showScrollToTop = shouldShowTop;
      _showScrollToBottom = shouldShowBottom;
    });
  }
}
```

**Button Layout:**
```
┌─────────────────────────────┐
│                             │
│         Content             │
│                             │
│                      ⬆️     │  ← Scroll-to-Top (when scrolled down)
│                      ⬇️     │  ← Scroll-to-Bottom (when not at bottom)
└─────────────────────────────┘
```

**Screen-Specific Notes:**
| Screen | Scroll-to-Top | Scroll-to-Bottom |
|--------|---------------|------------------|
| LUMARA Chat | Latest message | Oldest message |
| Journal Timeline | Newest entries | Older entries |
| Journal Entry Editor | Top of entry | Bottom of entry |

---

## 22. LUMARA Persona (v2.1.51)

### 🎭 Personality Mode Selection
**Location:** Settings → LUMARA → LUMARA Persona

**Purpose:** Allow users to choose how LUMARA responds, from warm companion to sharp strategist.

### Available Personas

| Persona | Icon | Description |
|---------|------|-------------|
| **Auto** | 🔄 | Adapts personality based on context automatically |
| **The Companion** | 🤝 | Warm, supportive presence for daily reflection |
| **The Therapist** | 💜 | Deep therapeutic support with gentle pacing |
| **The Strategist** | 🎯 | Sharp, analytical insights with concrete actions |
| **The Challenger** | ⚡ | Direct feedback that pushes growth |

### UI Design

**Card Structure:**
```
┌─────────────────────────────────────────┐
│ 🎭 LUMARA Persona                       │
│    Choose how LUMARA responds to you    │
├─────────────────────────────────────────┤
│ ○ 🔄 Auto                               │
│      Adapts based on context            │
├─────────────────────────────────────────┤
│ ● 🤝 The Companion                      │
│      Warm, supportive presence          │
├─────────────────────────────────────────┤
│ ○ 💜 The Therapist                      │
│      Deep therapeutic support           │
├─────────────────────────────────────────┤
│ ○ 🎯 The Strategist                     │
│      Sharp, analytical insights         │
├─────────────────────────────────────────┤
│ ○ ⚡ The Challenger                     │
│      Direct feedback for growth         │
└─────────────────────────────────────────┘
```

### Auto-Detection Logic (When "Auto" Selected)
1. **Safety Override**: Sentinel alerts → Therapist
2. **Deep Therapeutic Mode**: If enabled → Therapist
3. **Emotional Distress**: Distressed/anxious/sad → Therapist
4. **High Readiness + Morning**: High energy → Challenger
5. **High Readiness + Afternoon**: → Strategist
6. **Analytical Context**: Curious/analytical tone → Strategist
7. **Evening/Night or Low Energy**: → Companion
8. **Default**: → Companion

### Behavioral Differences

| Parameter | Companion | Therapist | Strategist | Challenger |
|-----------|-----------|-----------|------------|------------|
| Warmth | High (0.8) | Very High (0.9) | Low (0.3) | Moderate (0.5) |
| Rigor | Low (0.4) | Very Low (0.3) | Very High (0.9) | High (0.8) |
| Challenge | Very Low (0.2) | Minimal (0.1) | High (0.7) | Very High (0.9) |
| Output Style | Conversational | Conversational | Structured 5-Section | Conversational |

### Strategist 5-Section Format
When in Strategist mode, responses follow this operational structure:
1. **Signal Separation** - Short-window vs long-horizon patterns
2. **Phase Determination** - With confidence basis
3. **Interpretation** - System terms (load, capacity, risk)
4. **Phase-Appropriate Actions** - 2-4 concrete steps
5. **Optional Reflection** - Only if reduces ambiguity

### Implementation Files
- `lumara_reflection_settings_service.dart` - Persona enum + persistence
- `lumara_control_state_builder.dart` - Auto-detection + behavioral overrides
- `lumara_master_prompt.dart` - Section 7: Persona behaviors
- `settings_view.dart` - Persona picker UI

---

## 23. Advanced Settings (v2.1.52)

### Overview
Unified settings screen consolidating power-user features and analytics.

**Location:** Settings → LUMARA → Advanced Settings

### Structure
```
┌─────────────────────────────────────────┐
│ ← Advanced Settings                     │
├─────────────────────────────────────────┤
│ 📊 Analysis & Insights                  │
│    Combined analysis view (6 tabs)      │
│                                    →    │
├─────────────────────────────────────────┤
│ 🔧 LUMARA Engine                        │
│    Memory lookback, matching precision  │
├─────────────────────────────────────────┤
│ Memory Lookback     [====|====] 5 yrs   │
│ Matching Precision  [====|====] 0.55    │
│ Max Similar Entries [====|====] 5       │
│ ☑ Include Media     ☐ Auto-Adapt Depth  │
└─────────────────────────────────────────┘
```

### Combined Analysis View (6 Tabs)
1. **Phase Analysis** - RIVET sweep, phase statistics, current detection
2. **Patterns** - Pattern recognition and theme analysis
3. **AURORA** - Advanced insight generation
4. **VEIL** - Safety and moderation settings
5. **SENTINEL** - Alert configuration
6. **Medical** - Health data with LUMARA integration

### Implementation Files
- `advanced_settings_view.dart` - Main advanced settings screen
- `combined_analysis_view.dart` - 6-tab analysis interface

---

## 24. Health→LUMARA Integration (v2.1.52)

### Overview
Health signals influence LUMARA's behavior and response style.

**Location:** Health Tab → Settings (⚙️) → LUMARA Health Signals

### UI Design
```
┌─────────────────────────────────────────┐
│ 🧠 LUMARA Health Signals               │
│    These values influence how LUMARA    │
│    responds to you.                     │
├─────────────────────────────────────────┤
│ 🛏️ Sleep Quality          [====|====] 70% │
│     Poor ──────────────────────── Great │
│                                         │
│ ⚡ Energy Level           [====|====] 70% │
│     Low ───────────────────────── High  │
├─────────────────────────────────────────┤
│  ┌──────────────────────────────────┐   │
│  │ 💾 Save Health Status            │   │
│  └──────────────────────────────────┘   │
│                                         │
│ ℹ️ LUMARA will adapt to your state.    │
└─────────────────────────────────────────┘
```

### Health Effects on LUMARA

| Sleep + Energy | LUMARA Behavior |
|----------------|-----------------|
| Both < 40% | Extra gentle and supportive (Companion) |
| Either < 60% | Warm, balanced tone |
| Both > 70% | May offer direct insights/challenges |

### Color Coding
- 🔴 **Red** (0-39%): Low/Poor
- 🟠 **Orange** (40-59%): Moderate
- 🟢 **Green** (60-100%): Good/High

### Effect Preview
Real-time text updates showing how current health status affects LUMARA:
- "LUMARA will be extra gentle and supportive today."
- "LUMARA will maintain a warm, balanced tone."
- "LUMARA may offer more direct insights and challenges."

### Data Persistence
- Values saved to SharedPreferences via `HealthDataService`
- Data older than 24 hours treated as stale (defaults used)
- SnackBar confirmation on successful save

### Implementation Files
- `health_settings_dialog.dart` - Health signals UI
- `health_data_service.dart` - Persistence service
- `lumara_control_state_builder.dart` - Reads health data

---

## 25. Voice Chat - Jarvis Mode (v2.1.53)

### Overview
ChatGPT-style voice interface for hands-free LUMARA conversations. Features glowing, pulsing voice indicator with state-based colors.

**Location:** LUMARA Chat → 🎤 Mic Button (AppBar, top-right)

### UI Design - Voice Chat Panel (Bottom Sheet)
```
┌─────────────────────────────────────────┐
│        Voice Chat                       │
│                                         │
│            ╔═══════╗                    │
│           ║         ║                   │
│          ║    ●     ║  ← Glowing orb   │
│           ║         ║     (pulsing)    │
│            ╚═══════╝                    │
│                                         │
│        Listening...                     │
│                                         │
├─────────────────────────────────────────┤
│ 📝 "Create a new journal about..."     │  ← Partial transcript
├─────────────────────────────────────────┤
│  ┌──────────────────────────────────┐   │
│  │ 🛑 End Session                   │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### State Colors & Animations

| State | Orb Color | Glow | Animation | User Sees |
|-------|-----------|------|-----------|-----------|
| **Idle** | Gray | Gray | Static | "Ready to listen" |
| **Listening** | 🔴 Red | Red Accent | Fast pulse | "Listening..." |
| **Thinking** | 🟠 Orange | Orange Accent | Medium pulse | "Processing..." |
| **Speaking** | 🟢 Green | Green Accent | Slow pulse | "LUMARA is speaking" |
| **Error** | Red Accent | Red | Slow pulse | "Error - Try again" |

### Animation Details
- **Multi-layer glow**: 3 concentric rings with fading opacity
- **Pulse timing**: 1.5s cycle (customizable)
- **Scale range**: 0.95 → 1.05 (subtle throb)
- **Smooth curves**: easeInOut for natural feel

### Interaction Flow
1. **Tap 🎤 in AppBar** → Bottom sheet appears (gray orb)
2. **Tap orb** → Starts listening (red glow, fast pulse)
3. **Speak your message** → Partial transcript shows in real-time
4. **Tap orb again** → Stops and processes (orange glow)
5. **LUMARA responds** → Text + voice (green glow)
6. **Auto-resume** → Orb turns red again, ready for follow-up
7. **Tap "End Session"** → Closes voice chat

### Voice Pipeline (On-Device Security)
```
┌─────────────────────────────────────────┐
│ 1. Speech-to-Text (On-Device)          │
│    ↓ No audio sent to cloud            │
├─────────────────────────────────────────┤
│ 2. PII Scrubbing (Mode A)              │
│    ↓ Names/Places masked               │
├─────────────────────────────────────────┤
│ 3. Intent Classification               │
│    • Journal (create/append/query)      │
│    • Chat (questions/reflections)       │
│    • Files (export/share)               │
│    ↓                                    │
├─────────────────────────────────────────┤
│ 4. LUMARA Processing                   │
│    ↓ Phase-aware, persona-adapted      │
├─────────────────────────────────────────┤
│ 5. PII Restoration                     │
│    ↓ Original names/places returned    │
├─────────────────────────────────────────┤
│ 6. Text-to-Speech (On-Device)          │
│    → Natural voice output               │
└─────────────────────────────────────────┘
```

### Example Voice Commands
**Journal Creation:**
- "Create a new journal about my day"
- "Start a journal entry about my meeting"
- "Write about how I'm feeling"

**Reflective Queries:**
- "How am I feeling lately?"
- "What patterns do you see in my entries?"
- "Summarize my week"
- "Show me resilience examples"

**Journal Queries:**
- "What did I write about last Tuesday?"
- "Find entries about work stress"
- "Read my journal from yesterday"

**File Operations:**
- "Export my data"
- "Share my journal as PDF"

### AppBar Mic Button
```
┌─────────────────────────────────────────┐
│ ≡ LUMARA [Premium]         🎤  ⋮        │ ← Mic button added
└─────────────────────────────────────────┘
```

### Permissions Handling
**First Time:**
```
┌─────────────────────────────────────────┐
│ 🎤 Microphone Permission                │
│                                         │
│ ARC needs microphone access for         │
│ voice chat with LUMARA.                 │
│                                         │
│ ┌──────────┐  ┌──────────────────────┐ │
│ │ Cancel   │  │ Open Settings        │ │
│ └──────────┘  └──────────────────────┘ │
└─────────────────────────────────────────┘
```

### Technical Implementation

**Widget:** `GlowingVoiceIndicator`
```dart
GlowingVoiceIndicator(
  icon: Icons.mic,
  primaryColor: Colors.red,      // State-based
  glowColor: Colors.redAccent,   // State-based
  size: 80,
  isActive: true,                // Controls animation
  onTap: () => startListening(),
)
```

**Alternative Widget:** `SoundWaveIndicator`
- ChatGPT-style animated bars (5 bars)
- Staggered animations for natural feel
- Currently not used (orb is primary)

### Files & Components
- **NEW**: `lib/shared/widgets/glowing_voice_indicator.dart` - Animated voice widget
- **MODIFIED**: `lib/arc/chat/ui/voice_chat_panel.dart` - Voice UI panel
- **MODIFIED**: `lib/arc/chat/ui/lumara_assistant_screen.dart` - Mic button integration
- **Backend**: Voice system (already existed, now exposed in UI)
  - `voice_chat_service.dart` - Speech recognition
  - `push_to_talk_controller.dart` - State management
  - `voice_permissions.dart` - Permission handling
  - `audio_io.dart` - Audio I/O
  - `PiiScrubber` - On-device PII masking

### Design Philosophy
- **Familiar**: ChatGPT-inspired orb for instant recognition
- **Reassuring**: State colors provide clear feedback
- **Smooth**: Professional animations (1.5s cycles, easeInOut curves)
- **Private**: On-device transcription, PII scrubbing
- **Hands-free**: Auto-resume loop for natural conversation
- **Accessible**: Large touch target (80px orb)

---

*This comprehensive UI/UX documentation reflects the current state of the EPI Flutter application as of December 13, 2025. The interface combines sophisticated AI integration with thoughtful human-centered design to create a meaningful personal journaling and life insight experience.*

