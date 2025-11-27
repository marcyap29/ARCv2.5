# EPI MVP - Comprehensive Features Guide

**Version:** 1.0.7
**Last Updated:** November 25, 2025

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
- **Automatic Phase Detection**: Phase automatically detected from content using versioned inference pipeline
- **Phase Display**: Phase shown in timeline and entry editor with Auto/Manual indicators
- **User Overrides**: Manual phase selection available for existing entries via dropdown
- Draft management with auto-save

**Multimodal Journaling**
- **Photo Capture**: Camera integration with OCR
- **Photo Selection**: Gallery access with thumbnails
- **Voice Recording**: Audio capture with transcription
- **Video Capture**: Video recording and analysis
- **Location Tagging**: Automatic and manual location

**Entry Management**
- **Timeline View**: Chronological organization
- **Edit Entries**: Text, date, time, location, phase editing
- **Delete Entries**: Confirmation dialogs and undo
- **Search & Filter**: Keyword and date-based filtering
- **Entry Metadata**: Date, time, location, phase, keywords
- **Original Creation Time Preservation**: `createdAt` never changes when updating entries
- **Edit Tracking**: `updatedAt` tracks last modification, `isEdited` flag indicates edits

### Timeline

**Chronological Organization**
- Grouped by date with newest first
- Visual timeline with entry cards
- Quick actions (edit, delete, share)
- Empty state handling

**Timeline Features**
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
- **Unified Action Buttons**: Both in-chat and in-journal LUMARA bubbles expose the identical toolbar (Regenerate, Soften tone, More depth, Continue thought, Explore conversation), simplifying UI patterns and making advanced conversation actions more discoverable.

---

## AI Features

### LUMARA Assistant

**Chat Interface**
- Persistent chat memory across sessions
- Context-aware responses
- Phase-aware reflections
- Multimodal understanding
- **Reflective Queries**: Three EPI-standard anti-harm queries
  - "Show me three times I handled something hard" - Finds resilience examples with SAGE filtering
  - "What was I struggling with around this time last year?" - Temporal struggle analysis
  - "Which themes have softened in the last six months?" - Theme frequency comparison
- **Query Detection**: Automatic recognition of reflective query patterns
- **Safety Filtering**: VEIL integration, trauma detection, night mode handling

**Memory System**
- **Automatic Persistence**: Chat history automatically saved
- **Cross-Session Continuity**: Remembers past discussions
- **Rolling Summaries**: Map-reduce summarization every 10 messages
- **Memory Commands**: /memory show, forget, export

**Notification System** (Backend Ready)
- **Time Echo Reminders**: Periodic reflective reminders at 1 month, 3 months, 6 months, 1 year, 2 years, 5 years, 10 years
- **Active Window Detection**: Automatically learns user's natural reflection times from journal patterns
- **Sleep Protection**: Detects and respects sleep windows (default 22:00-07:00)
- **Abstinence Windows**: User-configurable quiet periods
- **Circadian Awareness**: AURORA integration for timing-aware notifications
- **Note**: Requires notification plugin integration for full functionality

**Response Features**
- **Context-Aware**: Uses journal entries and chat history
- **Phase-Aware**: Adapts to user's current phase
- **Multimodal**: Understands text, images, audio, video
- **Reflective**: Provides thoughtful reflections and insights

**In-Journal LUMARA Priority & Context Rules**
- **Question-First Detection**: Detects questions first and prioritizes direct answers
- **Answer First, Then Clarify**: Gives direct, decisive answers before asking clarifying questions
- **Decisiveness Rules**: Uses confident, grounded statements without hedging, speculation, or vague language

**Unified LUMARA UI/UX**
- **Consistent Header**: LUMARA icon and text header in both in-journal and in-chat bubbles
- **Unified Button Placement**: Copy/delete buttons positioned at lower left in both interfaces
- **Selectable Text**: In-journal LUMARA text is selectable and copyable
- **Quick Copy**: Copy icon button for entire LUMARA answer
- **Message Deletion**: Delete individual messages in-chat with confirmation dialog
- **Unified Loading Indicator**: Same "LUMARA is thinking..." design across both interfaces

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

**Phase Timeline**
- Visual timeline with phase regimes
- Phase change indicators
- Confidence badges
- Duration display

**Phase Analysis**
- **RIVET Sweep**: Automated phase detection
- **SENTINEL Analysis**: Risk monitoring
- **Phase Recommendations**: Change readiness
- **Phase Statistics**: Phase distribution and trends

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
- **Real-Time Analysis**: As user types
- **6 Categories**: Places, Emotions, Feelings, States of Being, Adjectives, Slang
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

**Data Protection**
- **PII Detection**: Automatic detection of sensitive data
- **PII Masking**: Real-time masking in UI
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

---

## Data Management Features

### MCP Export/Import

**Export Features**
- **Dual Format Support**: Choose between Secure Archive (.arcx) with encryption or standard ZIP (.zip) for compatibility
- **Complete Content Export**: Both formats export all data types:
  - Journal entries with full metadata
  - Media (photos, videos, audio, files)
  - Chat sessions and messages
  - Health data streams
  - Phase Regimes
  - RIVET state
  - Sentinel state
  - ArcForm timeline snapshots
  - LUMARA Favorites (all categories: answers, chats, journal entries)
- **Media Pack Organization**: Media files organized into packs for efficient storage:
  - Configurable pack size (50-500 MB, default 200 MB)
  - Media organized into `/Media/packs/pack-XXX/` directories
  - `media_index.json` file tracks all packs and media items
  - Pack linking (prev/next) for sequential access
  - Deduplication support within packs
  - Available for both ARCX and ZIP export formats
- **Date Range Filtering**: Export entries, chats, and media within custom date ranges
- **Extended Data**: All extended data exported to `extensions/` directory in ZIP format
- **Privacy Protection**: PII detection and flagging
- **Deterministic Exports**: Same input = same output

**Import Features**
- **Format Support**: MCP v1 compliant ZIP files and ARCX encrypted archives
- **Extended Data Import**: Full support for importing Phase Regimes, RIVET state, Sentinel state, ArcForm timeline, and LUMARA Favorites
- **Category Preservation**: Favorite categories (answers, chats, journal entries) are preserved during import
- **Capacity Management**: Import respects category-specific limits (25 answers, 25 chats, 25 journal entries)
- **Timeline Integration**: Automatic timeline refresh after import
- **Media Handling**: Photo and media import with deduplication
- **Duplicate Detection**: Prevents duplicate entries and favorites

### ARCX Encryption

**Encryption Features**
- **AES-256-GCM**: Symmetric encryption
- **Ed25519**: Digital signatures
- **Optional Encryption**: User choice for exports
- **Key Management**: Secure key storage

### Data Portability

**Export Formats**
- **Secure Archive (.arcx)**: Encrypted with AES-256-GCM and Ed25519 signing
- **ZIP (.zip)**: Standard unencrypted ZIP archive for compatibility
- Both formats include identical content (entries, media, chats, extended data)
- JSON (legacy support)

**Import Formats**
- **MCP bundles (.zip)**: Standard ZIP files with full extended data support
- **ARCX archives (.arcx)**: Encrypted archives with signature verification
- Both formats restore all content types including Phase Regimes, RIVET state, and LUMARA Favorites
- Legacy formats (with conversion)

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

---

**Features Guide Status:** ✅ Complete
**Last Updated:** November 25, 2025
**Version:** 1.0.7

