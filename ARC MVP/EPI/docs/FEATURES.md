# EPI MVP - Comprehensive Features Guide

**Version:** 3.3.13
**Last Updated:** January 26, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Core Features](#core-features)
3. [AI Features](#ai-features)
4. [Visualization Features](#visualization-features)
5. [Analysis Features](#analysis-features)
6. [Privacy & Security Features](#privacy--security-features)
7. [Data Management Features](#data-management-features)

---

## Overview

EPI MVP provides a comprehensive set of features for intelligent journaling, AI assistance, pattern recognition, and data visualization. This guide provides detailed information about all available features.

### Feature Categories

- **Core Features**: Journaling, timeline, entry management
- **AI Features**: LUMARA assistant, memory system, on-device AI
- **Visualization Features**: ARCForm 3D constellations, phase visualization
- **Analysis Features**: Phase detection, pattern recognition, insights
- **Privacy & Security**: On-device processing, encryption, PII protection
- **Data Management**: Export/import, MCP format, ARCX encryption

---

## Core Features

### Journaling Interface

**Text Journaling**
- Rich text entry with auto-capitalization
- Real-time keyword analysis
- **Automatic Phase Detection**: Phase automatically detected from content using RIVET-based inference
- **Phase Display**: Phase shown in timeline and entry editor with Auto/Manual indicators
- **User Overrides**: Manual phase selection available for existing entries via dropdown ("chisel" effect)
- **Clean Content**: No automatic phase hashtags injected into content (v2.1.48)
- Draft management with auto-save

**Multimodal Journaling**
- **Photo Capture**: Camera integration with OCR
- **Photo Selection**: Gallery access with thumbnails
- **Voice Recording**: Audio capture with transcription
- **Video Capture & Playback**: Complete video functionality with:
  - Video selection from gallery with automatic duration extraction
  - Full-screen video player with play/pause controls and progress scrubbing
  - Video preview in media attachment dialog with professional playback interface
  - Auto-play functionality and proper aspect ratio handling
  - Error handling for corrupted or unsupported video files
- **Location Tagging**: Automatic and manual location

**Entry Management**
- **Timeline View**: Chronological organization
- **Edit Entries**: Text, date, time, location, phase editing
- **Delete Entries**: Confirmation dialogs and undo
- **Search & Filter**: Keyword and date-based filtering
- **Entry Metadata**: Date, time, location, phase, keywords
- **Original Creation Time Preservation**: `createdAt` never changes when updating entries
- **Edit Tracking**: `updatedAt` tracks last modification, `isEdited` flag indicates edits
- **Read-Only Protection**: Entries from timeline open read-only by default with Edit button to unlock
- **LUMARA Blocks Persistence**: LUMARA comments and user responses properly saved and restored
  - Dedicated `lumaraBlocks` field in JournalEntry model (HiveField 27)
  - Automatic migration from legacy `metadata.inlineBlocks` format
  - Purple "LUMARA" tag displayed in timeline for entries with LUMARA comments
  - Blocks persist across app restarts and imports/exports
  - User comments in continuation fields properly saved

### Timeline

**Chronological Organization**
- Grouped by date with newest first
- Visual timeline with entry cards
- Quick actions (edit, delete, share)
- Empty state handling

**Timeline Features**
- **Pagination**: Loads 20 entries at a time for optimal performance
  - Fast initial load (only first 20 entries)
  - Automatic loading of next batch when scrolling through ~75% of loaded entries
  - Reduces memory usage and improves responsiveness for large entry collections
- **Date Navigation**: Jump to specific dates with accurate positioning
- **Entry Selection**: Multi-select for batch operations
- **Entry Viewing**: Full entry view with media
- **Entry Editing**: Inline editing capabilities
- **Adaptive ARCForm Preview**: Timeline chrome collapses and the phase legend appears only when the ARCForm timeline rail is expanded, giving users a full-height preview when they need it and a clean journal canvas otherwise
- **Calendar Header**: Month display above weekly calendar for better date context
- **UI Layout**: Calendar header and arcform preview properly spaced to prevent clipping

### Timeline Navigation & LUMARA Links

- **Calendar Week Sync**: The calendar week view now highlights the week containing the journal entry currently visible in the timeline list, and tapping a day scrolls the list to that entry. **Enhanced in v2.1.27**: Synchronization logic is now precision-tuned to prevent visual jumps, ensuring the calendar always reflects the exact date being viewed.
- **Tab Bar Action Center**: The + journal action now shares the bottom navigation bar surface, sitting centered above the Journal | LUMARA | Insights tabs so it stays visible without floating over content.
- **Unified Action Buttons**: Both in-chat and in-journal LUMARA bubbles expose a streamlined toolbar (Regenerate, Analyze, Deep Analysis), providing essential actions while maintaining a clean, focused interface.

### Scroll Navigation (v2.1.50)

- **Visible Floating Scroll Buttons**: Two FABs for easy navigation
  - **⬆️ Scroll-to-Top**: Up-arrow button appears when scrolled down
  - **⬇️ Scroll-to-Bottom**: Down-arrow button appears when not at bottom
  - Buttons stack vertically on right side of screen
  - Gray background with white icons
  - Smooth 300ms animation with easeOut curve
- **Available In**: LUMARA Chat, Journal Timeline, Journal Entry Editor

---

## AI Features

### LUMARA Assistant

**Chat Interface**
- Persistent chat memory across sessions
- Context-aware responses
- Phase-aware reflections
- Multimodal understanding

**Voice Chat - Jarvis Mode (v2.1.53)**
- **Glowing Voice Indicator**: ChatGPT-style pulsing animation with multi-layer glow
- **State-Based Colors**: 
  - Red (Listening) - Recording your voice
  - Orange (Thinking) - Processing with LUMARA
  - Green (Speaking) - LUMARA is responding
  - Gray (Idle) - Ready to listen
- **Microphone Button**: Tap 🎤 in LUMARA chat AppBar to activate
- **Speech-to-Text**: On-device transcription (no audio sent to cloud)
- **Text-to-Speech**: Natural voice responses from LUMARA
- **Intent Routing**: Automatically handles journal creation, chat queries, and file operations
- **PII Protection**: Mode A scrubbing pipeline (on-device)
- **Auto-Resume Loop**: LUMARA speaks → automatically listens for your response
- **Context Memory**: Maintains conversation state across voice turns
- **How to Use**:
  1. Tap 🎤 mic button in LUMARA chat
  2. Grant microphone permission (first time)
  3. Tap the glowing orb to start talking
  4. Say: "Create a new journal" / "How am I feeling?" / "Summarize my week"
  5. Tap orb again to stop and process
  6. LUMARA responds with voice + text

**Companion-First LUMARA System (v2.1.87)**
- **Backend-Only Personas**: No manual persona selection - all decisions automated based on entry classification and user state
- **Companion-First Default**: 50-60% usage target with warm, supportive responses for most interactions
- **The Companion**: Warm, supportive presence for daily reflection (primary persona)
- **The Therapist**: Deep therapeutic support for high distress or low readiness situations
- **The Strategist**: Structured analytical responses when users press "Think through" or "Suggest steps"
- **The Challenger**: Direct feedback when users press "Different perspective" and have high readiness
- **Safety Escalation Hierarchy**: Sentinel alerts → High distress → User intent buttons → Entry type → Default Companion
- **Anti-Over-Referencing**: Maximum 1 past reference for personal content, maximum 3 for project content
- **Personal vs. Project Detection**: Intelligent analysis distinguishing personal reflections from technical discussions
- **Simplified Settings**: Essential controls only (Memory Focus, Web Access, Include Media) with advanced options moved to separate screen

**Health→LUMARA Integration (v2.1.52)**
- **Sleep Quality Signal**: 0-100% slider affects LUMARA's warmth and challenge level
- **Energy Level Signal**: 0-100% slider affects verbosity and persona selection
- **Settings Location**: Health Tab → Settings (⚙️) → LUMARA Health Signals
- **Effect Preview**: Real-time feedback shows how health affects LUMARA's behavior
- **Adaptive Behavior**:
  - Low sleep/energy → LUMARA is more gentle and supportive
  - Moderate levels → Balanced tone
  - High sleep + energy → May offer more direct insights and challenges

**Entry Classification System (v2.1.85)**
- **Intelligent Classification**: Automatically classifies user entries to optimize LUMARA responses
- **5 Entry Types**:
  - **Factual** (≤100 words): Direct answers to questions and clarifications
  - **Reflective** (≤300 words): Full LUMARA synthesis for personal growth and emotional processing
  - **Analytical** (≤250 words): Intellectual engagement with ideas and theoretical frameworks
  - **Conversational** (≤30 words): Brief acknowledgment of mundane updates and simple observations
  - **Meta-Analysis** (≤600 words): Comprehensive pattern recognition across journal history
- **Pre-Processing Classification**: Classification happens before LUMARA synthesis to prevent over-analysis
- **Pattern Detection**: Uses emotional density, first-person indicators, technical markers, and meta-analysis cues
- **Response Optimization**: Different response modes with appropriate context scoping and word limits
- **Examples**:
  - "Does Newton's calculus predict or calculate movement?" → Factual (direct answer)
  - "204.3 lbs this morning. Heaviest I've been. My goal is to lose 30 pounds." → Reflective (full synthesis)
  - "Had coffee with Sarah this morning." → Conversational (brief acknowledgment)
  - "What patterns do you see in my weight loss attempts?" → Meta-Analysis (comprehensive review)
- **User Control**: Existing LUMARA settings still modify responses; classification optimizes initial processing

- **Scrollable Text Input**: Text input scrolls when content exceeds 5 lines, send button always accessible
- **Auto-Minimize**: Input area automatically minimizes when clicking outside (ChatGPT-like behavior)
- **Auto-Scroll UX**: Unified scroll behavior across journal and chat interfaces
  - **Immediate Feedback**: Page automatically scrolls to bottom when LUMARA activated
  - **Thinking Indicator**: "LUMARA is thinking..." appears in free space at bottom
  - **Smooth Animation**: Professional 300ms scroll with easeOut curve for polished feel
  - **Consistent Experience**: Identical behavior in both journal and chat modes
- **Reflective Queries**: Three EPI-standard anti-harm queries
  - "Show me three times I handled something hard" - Finds resilience examples with SAGE filtering
  - "What was I struggling with around this time last year?" - Temporal struggle analysis
  - "Which themes have softened in the last six months?" - Theme frequency comparison
- **Query Detection**: Automatic recognition of reflective query patterns
- **Safety Filtering**: VEIL integration, trauma detection, night mode handling
- **Saved Chats Navigation**: Direct navigation from favorites, automatic session restoration

**Memory System**
- **Automatic Persistence**: Chat history automatically saved
- **Cross-Session Continuity**: Remembers past discussions
- **Rolling Summaries**: Map-reduce summarization every 10 messages
- **Memory Commands**: /memory show, forget, export

**Temporal Notifications System** (v2.1.83)
- **Daily Resonance Prompts**: Surface relevant themes, callbacks, and patterns from recent entries
- **Monthly Thread Review**: Synthesize emotional threads and phase status over the past month
- **6-Month Arc View**: Show developmental trajectory with phase visualization
- **Yearly Becoming Summary**: Full narrative of transformation over the year
- **Notification Settings**: Comprehensive UI for configuring all notification preferences
  - Toggle each cadence on/off
  - Set preferred times (daily notification time, quiet hours)
  - Select monthly notification day
  - Enable/disable temporal callbacks
- **Deep Linking**: Notification taps route to appropriate screens (Journal, Phase tab)
- **Privacy-First**: All processing happens locally, no notification content leaves device
- **Phase-Aware**: Notifications reflect current developmental phase
- **Natural Language**: Notifications feel like a thoughtful friend, not a robot

**Engagement Discipline System (v2.1.75)**
- **User-Controlled Engagement Modes**:
  - **Reflect Mode** (Default): Surface patterns and stop - minimal follow-up, best for journaling without exploration
  - **Explore Mode**: Surface patterns and invite deeper examination - may ask one connecting question per response
  - **Integrate Mode**: Synthesize across domains and time horizons - most active engagement posture
- **Cross-Domain Synthesis Controls**: Toggle synthesis between Faith & Work, Relationships & Work, Health & Emotions, Creative & Intellectual
- **Response Discipline Settings**:
  - Max Temporal Connections (1-5) - controls historical references per response
  - Max Questions (0-2) - limits exploratory questions (EXPLORE/INTEGRATE only)
  - Allow Therapeutic Language toggle - permits therapy-style phrasing (default: false)
  - Allow Prescriptive Guidance toggle - permits direct advice (default: false)
  - Response Length preference (Concise/Moderate/Detailed)
- **Settings Location**: Settings → Advanced Settings → Engagement Discipline
- **Automatic Pattern Filtering**: Prohibits therapeutic questions, dependency-forming language, and prescriptive guidance by default

**Response Features**
- **Context-Aware**: Uses journal entries and chat history
- **Phase-Aware**: Adapts to user's current phase
- **Multimodal**: Understands text, images, audio, video
- **Reflective**: Provides thoughtful reflections and insights
- **Enhanced Subject Focus & Contextual Relevance**: LUMARA maintains strict focus on current journal entry
  - **Current Entry Priority**: Explicit `**CURRENT ENTRY (PRIMARY FOCUS)**` marking in context building
  - **Historical Context Balance**: Background entries marked as "REFERENCE ONLY" to prevent subject drift
  - **Context Weighting**: Current entry receives maximum attention in response generation
  - **Topic Consistency**: Prevents LUMARA from shifting focus to unrelated historical content

- **Diverse Response Endings**: Eliminated repetitive closing phrases with therapeutic variety
  - **24+ Therapeutic Closings**: Integration with existing therapeutic presence data system
  - **Contextual Appropriateness**: Endings match emotional tone and user needs (grounded_containment, reflective_echo, etc.)
  - **Time-Based Rotation**: Dynamic selection prevents repetition patterns
  - **Professional Quality**: Varied phrases like "What you've written already holds part of the answer"

- **Simplified Paragraph Formatting**: Streamlined text formatting for consistent readability
  - **In-Journal Responses**: Fixed 2 sentences per paragraph (simplified from variable 2-4)
  - **In-Chat Responses**: Fixed 3 sentences per paragraph (simplified from variable 3-5)
  - **Consistent Structure**: Predictable paragraph organization for better mobile reading
  - **Performance Optimization**: Streamlined paragraph logic for improved response generation
- **Bible Reference Retrieval** (v2.1.63): Automatic Bible verse and chapter retrieval using HelloAO Bible API
  - **Intelligent Detection**: Comprehensive terminology library detects Bible-related queries (66 books, prophets, characters, events, concepts)
  - **Automatic Verse Fetching**: When users ask about Bible topics, LUMARA automatically fetches relevant verses from HelloAO API
  - **Character-to-Book Resolution**: Automatically resolves prophet/character names (e.g., "Habakkuk the prophet") to their corresponding Bible books
  - **Multiple Formats Supported**: Handles specific verses ("John 3:16"), chapters ("Genesis 1"), books, or general topics
  - **Translation Support**: Multiple Bible translations available (default: BSB - Berean Study Bible)
  - **Privacy Protection**: Bible names whitelisted in PRISM to prevent false PII scrubbing
  - **Context Preservation**: Bible questions automatically skip correlation-resistant transformation to preserve verse context
  - **Usage Examples**:
    - "Tell me about Habakkuk the prophet" → Fetches Habakkuk chapter 1
    - "What does John 3:16 say?" → Fetches specific verse
    - "What is the book of Romans about?" → Fetches Romans chapter 1
    - "Tell me about the prophet Isaiah" → Fetches Isaiah chapter 1
  - **API Integration**: Uses `bible.helloao.org` API for accurate, authoritative Bible content
  - **Error Handling**: Graceful fallback to general context if API unavailable
- **Web Access** (Opt-In): Safe, scoped web search when information unavailable internally
  - **10-Rule Safety Layer**: Comprehensive safety framework governing all web searches
    1. Primary Source Priority: Always prioritizes user's personal context (journal, chats, patterns) before web search
    2. Explicit Need Check: Internal reasoning to verify web search is necessary
    3. Opt-In by User Intent: Interprets user requests (e.g., "look up", "find information") as permission to search
    4. Content Safety Boundaries: Avoids violent, graphic, extremist, or illegal content
    5. Research Mode Filter: Prioritizes peer-reviewed sources and reliable data for research queries
    6. Containment Framing: Provides high-level summaries for sensitive topics (mental health, trauma) without graphic details
    7. No Passive Browsing: Web access must always be tied to explicit user requests
    8. Transparent Sourcing: Summarizes findings and states when external information was used
    9. Contextual Integration: Relates web-sourced information back to user's ARC themes, ATLAS phase, and personal patterns
    10. Fail-Safe Rule: Refuses unsafe or unverifiable content and offers safe alternatives
  - **Google Search Integration**: Enabled via `tools: [{ googleSearch: {} }]` in Gemini model configuration
  - **Control State Integration**: `webAccess.enabled` flag in control state determines availability
  - **Matter-of-Fact Usage**: Direct, honest approach without defensive explanations
  - **Settings control**: Opt-in toggle in LUMARA Settings (default: disabled)

**In-Journal LUMARA Priority & Context Rules**
- **Question-First Detection**: Detects questions first and prioritizes direct answers
- **Answer First, Then Clarify**: Gives direct, decisive answers before asking clarifying questions
- **Decisiveness Rules**: Uses confident, grounded statements without hedging, speculation, or vague language

**Unified LUMARA UI/UX**
- **Clean Header Design (v2.1.89)**: Streamlined LUMARA chat header with icon and title only
  - **Removed Elements**: PersonaSelectorWidget dropdown removed from header to eliminate UI overlap
  - **Preserved Functionality**: Personas remain accessible via action buttons below chat bubbles
  - **Visual Clarity**: Premium subscription badge no longer obstructed by persona text
- **Consistent Header**: LUMARA icon and text header in both in-journal and in-chat bubbles
- **Unified Button Placement**: Copy/delete buttons positioned at lower left in both interfaces
- **Selectable Text**: In-journal LUMARA text is selectable and copyable
- **Quick Copy**: Copy icon button for entire LUMARA answer
- **Message Deletion**: Delete individual messages in-chat with confirmation dialog
- **Enhanced Thinking Popup**: Prominent "LUMARA is thinking..." dialog appears immediately when LUMARA button is pressed
  - **Instant Feedback**: Dialog shows immediately without requiring scrolling
  - **Consistent Design**: Same visual styling across journal and chat interfaces
  - **Progress Indicators**: Circular spinner and linear progress bar for visual feedback
- **Attribution Display**: Memory source references shown with drop-down details (expanded by default)
  - Shows memory sources, confidence scores, excerpts, and cross-references
  - Web source indicators when external information is used
  - Consistent display in both chat and journal reflection blocks

**LUMARA Context & Text State**
- **Text State Syncing**: Automatically syncs text state before context retrieval to prevent stale text
- **Date Information**: Journal entries include dates in context to help LUMARA identify latest entry
- **Current Entry Marking**: Explicitly marks current entry as "LATEST - YOU ARE EDITING THIS NOW"
- **Chronological Clarity**: Older entries marked with dates and "OLDER ENTRY" label
- **Clarity Over Clinical Tone**: Steady, grounded, emotionally present responses (no cold summaries or canned therapeutic lines)
- **Context Hierarchy**: Uses current entry → recent entries → older history based on slider setting (Tier 1/2/3 structure)
- **ECHO Framework**: All responses use structured ECHO format (Empathize → Clarify → Highlight → Open)
- **SAGE Echo**: Free-writing scenarios extract structured insights (Situation, Action, Growth, Essence)
- **Abstract Register**: Detects conceptual language and adjusts question count accordingly
- **Phase-Based Bias**: Adapts question style and count to ATLAS phase
- **Interactive Modes**: Supports Regenerate, Soften, More Depth, ideas, think, perspective, nextSteps, reflectDeeply
- **Light Presence**: Defaults to minimal presence when no question is asked
- **Emotional Safety**: Conservative context usage to avoid overwhelming users

**LUMARA Favorites Management**
- **Always-Accessible Link**: When adding a favorite, the snackbar always includes a "Manage" link to the Favorites list
- **Quick Access**: Users can immediately navigate to Favorites management from any favorite addition confirmation
- **Consistent Experience**: Same behavior across all favorite addition locations (chat, journal, assistant)

### On-Device AI

**Qwen Models**
- **Qwen 2.5 1.5B Instruct**: Chat model
- **Qwen2.5-VL-3B**: Vision-language model
- **Qwen3-Embedding-0.6B**: Embedding model

**Integration**
- llama.cpp XCFramework with Metal acceleration
- Native Swift bridge for iOS
- Visual status indicators
- Model download and management

### Cloud AI Fallback

**Gemini API**
- Primary cloud LLM provider
- Streaming responses
- Context-aware generation
- Privacy-first design

---

## Visualization Features

### ARCForm 3D Constellations

**3D Visualizations**
- Phase-aware 3D layouts
- Interactive exploration
- Keyword-based star formations
- Emotional mapping

**Constellation Features**
- **Discovery**: Expanding network pattern
- **Expansion**: Radial growth pattern
- **Transition**: Bridge-like structure
- **Consolidation**: Geodesic lattice pattern
- **Recovery**: Core-shell cluster pattern
- **Breakthrough**: Supernova explosion pattern

**Interaction**
- **Manual Rotation**: Gesture-based rotation
- **Zoom Controls**: Pinch to zoom
- **Star Labels**: Keyword labels on stars
- **Color Coding**: Sentiment-based colors

### Phase Visualization

**Phase Timeline (v2.1.48)**
- **Interactive Timeline Bars**: Tappable segments showing phase details
- **10-Day Rolling Window**: Phase regimes calculated in 10-day windows
- **Visual Hints**: Tap/swipe icons for discoverability
- **Scrollable**: Horizontal scroll for long timelines
- **Entry Navigation**: Hyperlinked entries for direct navigation
- **Phase Detail Popup**: Duration, entry count, date range on tap

**Phase Tab (v2.1.48)**
- **Phase Transition Readiness Card**: Always visible, uses RIVET calculation
- **Change Phase Button**: Manual override for last 10 days' phase
- **Past Phases Section**: Most recent past instance of each distinct phase
- **Example Phases Section**: Demo phases for user exploration
- **Scrollable Content**: Entire tab scrolls together

**Phase Analysis**
- **RIVET Sweep**: Automated phase detection with sophisticated analysis
- **SENTINEL Analysis**: Risk monitoring
- **Phase Recommendations**: Change readiness with RIVET-based trends
- **Phase Statistics**: Phase distribution and trends
- **Chisel Effect**: Manual entry overrides feed into RIVET calculations

---

## Analysis Features

### Phase Detection & Transition

**Versioned Phase Inference Pipeline**
- **Auto Phase Detection**: Always the default source of truth for each entry
- **Version Tracking**: All entries track `phaseInferenceVersion` for audit trail
- **Migration Support**: On-demand phase recomputation for eligible entries
- **Hashtag Independence**: Inline hashtags never control phase assignment
- **Legacy Data Handling**: Legacy phase tags preserved as reference but not used for inference

**Phase Transition Detection**
- **Current Phase Display**: Shows current detected phase with color-coded visualization
- **Phase Regimes Integration**: Phase changes aggregated into stable regimes to prevent erratic changes
- **Imported Phase Support**: Uses imported phase regimes from ARCX/MCP files
- **Phase History**: Displays when current phase started (if ongoing)
- **Fallback Logic**: Shows most recent phase if no current ongoing phase
- **Always Visible**: Card always displays even if there are errors

**Phase Analysis**
- **RIVET Integration**: Uses RIVET state for phase transition readiness
- **Enhanced Transition Guidance**: Clear, specific explanations when close to phase transition (e.g., "You're at 99%! Just need 1% more alignment")
- **Context-Aware Messaging**: Different guidance based on which requirement is close (alignment, evidence quality, entries, etc.)
- **Current State Visibility**: Shows exact percentages and gaps so users know exactly what's missing
- **Actionable Tips**: Provides specific suggestions for what to write about to complete phase transition
- **Phase Statistics**: Comprehensive phase timeline statistics
- **Phase Regimes**: Timeline of life phases (Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough)
- **Expanded Keyword Detection**: 60-120 keywords per phase for improved detection accuracy
- **System State Export**: Complete phase-related system state backup (RIVET, Sentinel, ArcForm)
- **Advanced Analytics Toggle**: Settings toggle to show/hide Health and Analytics tabs (default OFF)
- **Dynamic Tab Management**: Insights tabs dynamically adjust based on Advanced Analytics preference

### Pattern Recognition

**Keyword Extraction**
- **Curated Keyword Library**: Uses EnhancedKeywordExtractor with 100+ curated keywords
- **Emotion Amplitude Map**: Keywords include intensity values (0.0-1.0) for emotional analysis
- **Phase-Aware Selection**: Phase-specific keyword lists (Recovery, Transition, Breakthrough, Discovery, Expansion, Consolidation)
- **RIVET Gating**: Quality-controlled keyword selection with evidence-based filtering
- **Real-Time Analysis**: As user types
- **Visual Categorization**: Color-coded with icons
- **Manual Addition**: User can add custom keywords

**Emotion Detection**
- Emotion extraction from text
- Emotional mapping in visualizations
- Emotion trends over time
- Emotion-based insights

### Phase Detection

**Versioned Phase Inference**
- **PhaseInferenceService**: Pure inference service ignoring hashtags and legacy tags
- **Version Tracking**: `CURRENT_PHASE_INFERENCE_VERSION = 1` tracks inference pipeline version
- **Multi-Factor Scoring**: Keyword-based (70% weight), emotion-based, content-based, structure-based
- **Confidence Calculation**: 0.0-1.0 scale with normalization
- **Expanded Keywords**: 60-120 keywords per phase for improved accuracy

**Phase Analysis**
- **RIVET Integration**: Evidence-based validation
- **SENTINEL Monitoring**: Risk assessment
- **Phase Transitions**: Change point detection via PhaseTracker
- **Phase Regimes**: Timeline-based phase segments for stable phase assignment
- **Migration Service**: On-demand recomputation for entries needing phase updates

**User Phase Overrides**
- **Manual Selection**: Dropdown for existing entries (not during composition)
- **Lock Mechanism**: `isPhaseLocked` prevents auto-overwrite of manual overrides
- **Reset to Auto**: Button to clear manual overrides and unlock phase
- **Auto/Manual Indicators**: Visual indicators show phase source

**Automatic Phase Detection**
- **No Hashtag Dependency**: Phase detection ignores inline hashtags completely
- **Content-Based**: Uses entry content, emotion, keywords, and structure
- **Regime-Based Assignment**: Entries derive phase from regime they fall into based on creation date
- **No Manual Input Required**: Users no longer need to manually type `#phase` hashtags - system handles it automatically
- **Consistent Tagging**: All entries within the same time period (same regime) receive the same phase hashtag
- **Automatic Updates**: When phase changes occur at regime level, all affected entries' hashtags are updated automatically
- **Import Support**: ARCX imported entries automatically receive phase hashtags based on their import date's regime
- **Color Integration**: Entry colors automatically update when phase hashtags change, as colors are derived from hashtags

### Insights

**Unified Insights View**
- **Simplified Tab Layout**: 2 tabs (Phase, Settings) for clean interface
- **Advanced Analytics Access**: Available via 3-dot menu (⋮) → Advanced Analytics
- **No Toggle Required**: Advanced Analytics always accessible (toggle removed from Settings)
- **Adaptive Sizing**: Larger icons (24px) and font (17px) for 2-tab layout
- **Automatic Centering**: TabBar automatically centers 2-tab layout

**Pattern Analysis**
- Keyword patterns over time
- Emotion trends
- Phase distribution
- Entry frequency

**Recommendations**
- Phase change readiness
- Reflection prompts
- Pattern insights
- Health recommendations

**Analytics Tools**
- **Patterns**: Keyword and emotion pattern analysis
- **AURORA**: Circadian rhythm and orchestration insights
- **VEIL**: Edge detection and relationship mapping
- **Sentinel**: Emotional risk detection and pattern analysis

**Advanced Analytics View**
- **Access**: Insights → 3-dot menu (⋮) → Advanced Analytics
- **5-Part Horizontal Tabs**: Horizontally scrollable tabs for easy navigation
  - **Patterns**: Your Patterns visualization (wordCloud, network, timeline, radial views)
  - **AURORA**: Circadian Intelligence insights
  - **VEIL**: AI Prompt Intelligence + Policy settings
  - **SENTINEL**: Emotional risk detection and pattern analysis
  - **Medical**: Health data tracking with Overview, Details, and Medications (30/60/90 day import)
- **Swipe Navigation**: Smooth swiping between analytics sections
- **Visual Design**: Selected tab highlighted, intuitive interface
- **No Toggle Required**: Advanced Analytics always accessible via menu (toggle removed from Settings)

---

## Privacy & Security Features

### On-Device Processing

**Primary Processing**
- On-device AI inference
- Local data storage
- No cloud transmission (unless explicitly configured)
- Privacy-first architecture

**Data Protection (v2.1.86)**
- **PII Detection**: Automatic detection of sensitive data
- **PII Masking**: Real-time masking in UI
- **PRISM Scrubbing**: Local PII scrubbing with reversible mapping (device-only)
- **Classification-Aware Privacy (NEW)**: Dual privacy strategy based on content type
  - **Technical/Factual Content**: Preserves semantic content after PII scrubbing for proper cloud processing
  - **Personal/Emotional Content**: Full correlation-resistant transformation with rotating aliases
  - **Enhanced Semantic Analysis**: On-device technical content detection (mathematics, physics, computer science, engineering)
  - **Privacy Guarantee**: No verbatim personal text sent to cloud, all PII scrubbed regardless of content type
- **Correlation-Resistant Transformation**: Rotating aliases and structured JSON payloads for personal content
- **Session-Based Rotation**: Identifiers rotate per session to prevent cross-call linkage
- **Enhanced Semantic Summaries**: Improved on-device abstraction creates descriptive summaries instead of generic ones
- **Encryption**: AES-256-GCM for sensitive data
- **Data Integrity**: Ed25519 signing

### Privacy Controls

**Settings**
- Privacy preferences
- Data sharing controls
- PII detection settings
- Encryption options

**User Control**
- Export/delete data
- Memory management
- Chat history control
- Location privacy

### Authentication & Sign-In (Priority 3)

**User Authentication System**
- **Anonymous Auth**: Auto sign-in on first launch for immediate access
- **Google Sign-In**: One-tap authentication with account linking (iOS configured with OAuth client + URL scheme)
- **Email/Password**: Traditional sign up and sign in with validation
- **Forgot Password**: Email-based password reset functionality
- **Account Linking**: Anonymous session data preserved when upgrading to real account

**Sign-In UI Features**
- **Modern UI**: Gradient logo, proper form validation, loading states
- **Error Messages**: Human-readable Firebase error translations
- **Toggle Mode**: Switch between sign-in and sign-up with one tap
- **Password Visibility**: Toggle to show/hide password
- **Confirm Password**: Required for sign-up with match validation

**Account Management**
- **Settings Integration**: Account tile in Subscription & Account section
- **Profile Display**: User photo, name, and email when signed in
- **Sign Out**: Confirmation dialog with data preservation notice
- **Sign-In Prompt**: Navigate to sign-in when not authenticated

### Subscription & Payment System (v2.1.76)

**Subscription Tiers:**
- **Free Tier**: 20 LUMARA requests/day, 3 requests/minute rate limit, limited phase history
- **Premium Tier**: Unlimited LUMARA requests, no rate limits, full phase history, $30/month or $200/year
- **Founders Commit**: $1,500 upfront for 3 years (one-time payment), premium access plus early access + founder benefits

**Stripe Integration:**
- Secure payment processing via Stripe Checkout
- Monthly and annual subscription options, plus Founders upfront (3-year) option
- Customer Portal for subscription management
- Automatic subscription status updates via webhooks
- Secrets stored securely in Firebase Secret Manager
- Webhook signature verification for security
- **Enhanced Authentication (v2.1.89)**: Robust Google Sign-in enforcement for all subscription access
  - Forces real Google accounts using `hasRealAccount` check
  - Comprehensive debug logging for troubleshooting authentication issues
  - Progress feedback with SnackBar notifications during sign-in process

**Subscription Management UI:**
- Subscription status display with tier badges
- Upgrade prompts for free users
- "Manage Subscription" button for premium users (opens Stripe Customer Portal)
- Clear pricing display with monthly/annual toggle and savings callout
- Founders presented as a separate expandable card (not part of the subscription toggle)
- Toggle optimized for small screens with full-width options and stacked labels
- Cache management for subscription status
- **Authentication UX**: Clear messaging when Google sign-in is required for subscription access

**Setup Documentation:**
- Complete setup guide: `docs/stripe/STRIPE_SECRETS_SETUP.md`
- Webhook configuration: `docs/stripe/STRIPE_WEBHOOK_SETUP_VISUAL.md`
- Test vs Live mode: `docs/stripe/STRIPE_TEST_VS_LIVE.md`
- See `docs/stripe/README.md` for full documentation index

### Per-Feature Rate Limiting

**Usage Limits for Free Tier**
- **In-Journal LUMARA**: 5 comments per journal entry
- **In-Chat LUMARA**: 20 messages per chat session
- **Premium/Admin**: Unlimited access to all features

**Limit Tracking**
- **Per-Entry Tracking**: Usage tracked per journal entry ID
- **Per-Chat Tracking**: Usage tracked per chat session ID
- **Firestore Storage**: Usage counts stored in `usageLimits` collection
- **Real-Time Enforcement**: Limits checked before each API call

### Admin Privileges

**Email-Based Admin Detection**
- **Admin Emails**: Configured in authGuard.ts
- **Auto-Upgrade**: Admin users automatically set to "pro" plan
- **Unlimited Access**: Bypass all rate limits
- **Developer Feature**: Intended for app developers and administrators

### Throttle Unlock (Legacy Developer Feature)

**Password-Protected Rate Limit Bypass**
- **Throttle Settings**: Hidden settings menu option in Privacy & Security section
- **Password Protection**: Secure password verification using timing-safe comparison
- **Empty Password Field**: No password length hints for security
- **Status Display**: Real-time throttle unlock status (locked/unlocked)
- **Lock/Unlock Toggle**: Ability to lock throttle after unlocking
- **Backend Integration**: Firebase Cloud Functions for secure password verification
- **Rate Limit Bypass**: Removes all rate limiting (20/day, 3/minute) when unlocked
- **Developer Feature**: Intended for developers/admins, not regular users

---

## Data Management Features

### MCP Export/Import

**Export Features**
- **Format Support**: Standard ZIP (.zip) format for compatibility
- **Standardized File Structure (v2.1.54)**:
  - Journal entries: `Entries/{YYYY}/{MM}/{DD}/{slug}.json`
  - Chat sessions: `Chats/{YYYY}/{MM}/{DD}/{session-id}.json` (with nested messages)
  - Extended data: `extensions/` directory
- **Complete Content Export**: Both formats export all data types:
  - Journal entries with full metadata (including links, date_bucket, slug)
  - Media (photos, videos, audio, files) with embedded metadata
  - Chat sessions with nested messages, content_parts, and metadata
  - Health data streams and health associations
  - Phase Regimes
  - RIVET state
  - Sentinel state
  - ArcForm timeline snapshots
  - LUMARA Favorites (all categories: answers, chats, journal entries)
  - Edges (relationship tracking via edges.jsonl)
- **Media Pack Organization**: Media files organized into packs for efficient storage:
  - Configurable pack size (50-500 MB, default 200 MB)
  - Media organized into `/Media/packs/pack-XXX/` directories
  - `media_index.json` file tracks all packs and media items
  - Pack linking (prev/next) for sequential access
  - Deduplication support within packs
  - Available for both ARCX and ZIP export formats
- **Date Range Filtering**: Export entries, chats, and media within custom date ranges
- **Robust State Management**: Proper state reset ensures "Export All Entries" works correctly after filtered exports
- **Extended Data**: All extended data exported to `extensions/` directory
- **Privacy Protection**: PII detection and flagging
- **Deterministic Exports**: Same input = same output

**Import Features**
- **Format Support**: MCP v1 compliant ZIP files and ARCX encrypted archives
- **Multi-Select File Loading (v3.2.4)**: Select and import multiple files at once to save time
  - **MCP Import**: Select multiple ZIP files simultaneously for batch processing
  - **ARCX Import**: Select multiple ARCX files simultaneously for batch processing
  - **ZIP Import (Settings)**: Select multiple ZIP files from Settings → Import Data for batch processing
  - **Chat Import**: Select multiple JSON files to merge chat data from multiple exports
  - **Progress Feedback**: Real-time progress indicators showing "File X of Y" during import
  - **Global Import Status Bar (v3.3.13)**: When an import runs in the background, a mini status bar appears below the app bar on the home screen showing message, progress bar, and **percentage (0%–100%)**; includes “You can keep using the app”; the bar disappears when the import completes
  - **Import Status Screen (Settings → Import)**: Tapping **Settings → Import Data** opens the Import screen. When no import is active: “Choose files to import”. When an import is running: overall progress and a **list of files with status** (Pending / In progress / Completed / Failed). When completed or failed: result summary and Done / Import more. Users can navigate to Settings → Import at any time to view progress while the import runs in the background
  - **Sequential Processing**: Files processed one at a time with clear status updates
  - **Chronological Sorting**: Files automatically sorted by creation date (oldest first) before import
    - Ensures data timeline consistency
    - Uses file modification time as sorting key
    - Files processed in chronological order
  - **Error Handling**: Detailed error reporting showing which specific files failed
  - **Success Summary**: Final status message shows total success/failure counts and imported data statistics
- **Backward Compatibility (v2.1.54)**:
  - Supports new date-bucketed structure (`Entries/`, `Chats/`, `extensions/`)
  - Supports legacy flat structure (`nodes/journal/`, `nodes/chat/`, `PhaseRegimes/`)
  - Automatic detection of format version for seamless migration
- **Extended Data Import**: Full support for importing Phase Regimes, RIVET state, Sentinel state, ArcForm timeline, and LUMARA Favorites
- **Category Preservation**: Favorite categories (answers, chats, journal entries) are preserved during import
- **Capacity Management**: Import respects category-specific limits (25 answers, 25 chats, 25 journal entries)
- **Timeline Integration**: Automatic timeline refresh after import
- **Media Handling**: Photo and media import with deduplication
- **Duplicate Detection**: Prevents duplicate entries and favorites
- **First Backup on Import (v3.2.4)**: When importing into an empty app, automatically creates an export record marking the imported data as the first save, ensuring proper tracking for future incremental backups

### Incremental Backup System (v2.1.77)

**Purpose:** Space-efficient backups that only export new/changed data since last backup, reducing backup size by 90%+.

**Quick Backup (Incremental)**
- **Automatic Change Detection**: Only exports entries and chats modified since last backup
- **Dual Backup Options**:
  - **Text-Only Mode**: Excludes all media for space-efficient backups
    - Typical size: < 1 MB (vs hundreds of MB with media)
    - Ideal for frequent daily backups
    - 90%+ size reduction compared to full incremental
  - **Full Mode**: Includes all new entries, chats, and media
    - Media deduplication: Skips media files already exported using SHA-256 hash tracking
    - Typical backup size: ~30-50MB (reduced from ~500MB)
- **Export Preview**: Shows count of new entries, chats, and media before backup
- **Media Warning**: Banner alerts when media would be included, suggests text-only for frequent backups
- **Fast Execution**: Less data to process means faster backup times

**Backup Set Model (v3.2.6)**
- **Unified Backup System**: Full and incremental backups share the same folder with sequential numbering
  - Creates backup set folder: `ARC_BackupSet_YYYY-MM-DD/`
  - Full backup chunks: `ARC_Full_001.arcx`, `ARC_Full_002.arcx`, etc.
  - Incremental backups continue: `ARC_Inc_004_2026-01-17.arcx` (number + date)
  - Clear restore order: Just restore 001 → 002 → 003, etc.
- **Automatic Set Detection**: Quick Backups automatically find and add to existing backup set
- **Type Distinction**: `ARC_Full_` vs `ARC_Inc_` prefix clearly shows backup type
- **Self-Documenting**: Folder structure tells the complete backup story

**Full Backup with Chunked Export (v3.2.5)**
- **Complete Export**: Exports all data regardless of previous exports
- **Automatic Chunking**: Large backups automatically split into ~200MB files
  - Creates backup set folder: `ARC_BackupSet_YYYY-MM-DD/`
  - Files named: `ARC_Full_001.arcx`, `ARC_Full_002.arcx`, etc.
  - Oldest entries first, newest entries last
  - Each chunk is self-contained with its entries + media
- **Better Manageability**: Smaller files easier to transfer, email, or upload
- **Error Recovery**: If one chunk fails, others remain usable
- **History Tracking**: Records full backup date for reference
- **Recommended Frequency**: Monthly or before major changes

**Backup History Management**
- **Export Statistics**: View total exports, entries backed up, last full backup date
- **History Clearing**: Option to clear history and force full backup
- **Export Tracking**: Maintains record of all exports with entry IDs, chat IDs, and media hashes

**UI Features**
- **Quick Backup Card**: Preview and initiate incremental backups with dual options
  - **"Text Only" Button**: Fast, space-efficient text-only backups
  - **"Backup All" Button**: Full incremental backup including media
  - **Media Warning Banner**: Alerts when media would be included
- **Full Backup Card**: Option for complete backups with auto-chunking
  - **Info Banner**: Explains automatic ~200MB file splitting
  - **Progress Feedback**: Shows chunk-by-chunk progress
  - **Completion Dialog**: Lists all created chunk files when multiple chunks generated
- **Backup History Card**: View statistics and manage history
- **Folder Guidance**: Info card explaining recommended backup locations
- **"Use App Documents" Button**: One-tap setup for safe backup folder
- **Path Validation**: Detects and warns about restricted locations (iCloud Drive)
- **Permission Testing**: Validates folder permissions before starting export

**Enhanced Error Handling (v2.1.84)**
- **Smart Error Detection**: Distinguishes disk space errors (errno 28) from permission errors (errno 13)
- **Clear Error Messages**: 
  - Disk space errors: Shows required space in MB, suggests freeing space, links to iPhone Storage settings
  - Permission errors: Explains write permission issues, suggests alternative folders
  - Generic errors: Lists possible causes and actionable solutions
- **Error Dialogs**: Replaced snackbars with scrollable error dialogs for better readability
- **Helpful Guidance**: Step-by-step instructions to resolve common backup issues

**Benefits**
- **Storage Efficiency**: Prevents redundant data in backup files
- **Faster Backups**: Less data to process and encrypt
- **User Guidance**: Clear instructions on where to save backups
- **First Backup Tracking**: Imported backups are automatically tracked for proper incremental backup behavior

### Data Portability

**Export Formats**
- **ZIP (.zip)**: Standard ZIP archive format
- **ARCX (.arcx)**: Encrypted archive format with AES-256-GCM encryption
- Includes all content types: entries, media, chats, extended data
- JSON (legacy support)

**Import Formats**
- **MCP bundles (.zip)**: Standard ZIP files with full extended data support
- **ARCX archives (.arcx)**: Encrypted archives with password protection
- Restores all content types including Phase Regimes, RIVET state, and LUMARA Favorites
- Legacy formats (with conversion)

**Import/Export UI Organization (v2.1.77)**
- **Settings → Local Backup**: Regular automated backups with incremental tracking and scheduling
- **Settings → Import Data**: Opens the Import screen: choose files to restore from backup (.zip, .mcpkg, .arcx), or view current import progress and per-file status (pending / in progress / completed / failed) while import runs in the background
- **First Backup on Import (v3.2.4)**: When importing into an empty app, the system automatically creates an export record marking the imported data as the first save, ensuring future incremental backups correctly identify new vs. imported data

---

## Feature Status

### Production Ready ✅

All core features are production-ready and fully operational:
- Journaling interface
- LUMARA AI assistant
- ARCForm visualizations
- Phase detection and analysis
- MCP export/import
- Privacy and security features

### Planned Features

- Vision-language model integration
- Advanced analytics
- Additional on-device models
- Enhanced constellation geometry
- Performance optimizations

---

## Feature Usage

### Getting Started with Features

1. **Journaling**: Start with creating your first journal entry
2. **LUMARA**: Open LUMARA tab and start a conversation
3. **ARCForms**: View your journal patterns in 3D
4. **Insights**: Check Insights tab for patterns and recommendations
5. **Export**: Export your data in Settings

### Feature Combinations

- **Journal + LUMARA**: Get AI reflections on your entries
- **Journal + ARCForm**: See your patterns visualized
- **Phase + Insights**: Understand your life phases
- **Export + Import**: Backup and restore your data

### Google Drive Backup (v2.1.64)

**Automatic Cloud Backups**
- Connect your Google account to automatically backup journal data to Google Drive
- Secure OAuth authentication with limited scope (only files created by app)
- Choose a specific Google Drive folder for backups
- Automatic token refresh on authentication failures

**Backup Options**
- **Format Selection**: Choose between ARCX (encrypted) or MCP/ZIP format
- **Scheduled Backups**: Configure automatic backups at daily/weekly/monthly intervals
- **Time Selection**: Set specific time for scheduled backups (HH:mm format)
- **Manual Backup**: One-tap manual backup trigger from settings
- **Export Integration**: Automatic upload after manual exports (if enabled and format matches)

**Backup Management**
- **Connection Status**: View connected Google account email
- **Folder Selection**: Browse and select backup folder from Google Drive
- **Last Backup Display**: See timestamp of last successful backup
- **Progress Tracking**: Real-time progress updates during backup creation and upload
- **Error Handling**: Automatic retry with exponential backoff on upload failures
- **Notifications**: Success and error notifications for backup operations

**Privacy & Security**
- Limited OAuth scope (`drive.file` - only files created by app)
- Backup files remain encrypted (ARCX format)
- No data sent to Google beyond backup files
- User can disconnect at any time
- All settings stored locally

---

**Features Guide Status:** ✅ Complete
**Last Updated:** January 11, 2026
**Version:** 3.2.4

