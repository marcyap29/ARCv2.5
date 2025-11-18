# EPI MVP - Comprehensive Features Guide

**Version:** 1.0.4  
**Last Updated:** January 2025

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
- **Automatic Phase Hashtag Assignment**: Phase hashtags (e.g., `#discovery`, `#transition`) are automatically added based on Phase Regimes - no manual tagging required
- Phase detection and suggestions
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

### Timeline

**Chronological Organization**
- Grouped by date with newest first
- Visual timeline with entry cards
- Quick actions (edit, delete, share)
- Empty state handling

**Timeline Features**
- **Date Navigation**: Jump to specific dates
- **Entry Selection**: Multi-select for batch operations
- **Entry Viewing**: Full entry view with media
- **Entry Editing**: Inline editing capabilities
- **Adaptive ARCForm Preview**: Timeline chrome collapses and the phase legend appears only when the ARCForm timeline rail is expanded, giving users a full-height preview when they need it and a clean journal canvas otherwise.

---

## AI Features

### LUMARA Assistant

**Chat Interface**
- Persistent chat memory across sessions
- Context-aware responses
- Phase-aware reflections
- Multimodal understanding

**Memory System**
- **Automatic Persistence**: Chat history automatically saved
- **Cross-Session Continuity**: Remembers past discussions
- **Rolling Summaries**: Map-reduce summarization every 10 messages
- **Memory Commands**: /memory show, forget, export

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

**Phase Transition Detection**
- **Current Phase Display**: Shows current detected phase with color-coded visualization
- **Imported Phase Support**: Uses imported phase regimes from ARCX/MCP files
- **Phase History**: Displays when current phase started (if ongoing)
- **Fallback Logic**: Shows most recent phase if no current ongoing phase
- **Always Visible**: Card always displays even if there are errors

**Phase Analysis**
- **RIVET Integration**: Uses RIVET state for phase transition readiness
- **Phase Statistics**: Comprehensive phase timeline statistics
- **Phase Regimes**: Timeline of life phases (Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough)
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

**Real-Time Detection**
- **Phase Detector Service**: Keyword-based detection
- **Multi-Tier Scoring**: Exact, partial, content matches
- **Confidence Calculation**: 0.0-1.0 scale
- **Adaptive Window**: Temporal or count-based

**Phase Analysis**
- **RIVET Integration**: Evidence-based validation
- **SENTINEL Monitoring**: Risk assessment
- **Phase Transitions**: Change point detection
- **Phase Regimes**: Timeline-based phase segments

**Automatic Phase Hashtag System**
- **Phase Regime-Based Assignment**: Phase hashtags automatically assigned based on which Phase Regime the entry's date falls into
- **No Manual Input Required**: Users no longer need to manually type `#phase` hashtags - system handles it automatically
- **Consistent Tagging**: All entries within the same time period (same regime) receive the same phase hashtag
- **Automatic Updates**: When phase changes occur at regime level, all affected entries' hashtags are updated automatically
- **Import Support**: ARCX imported entries automatically receive phase hashtags based on their import date's regime
- **Color Integration**: Entry colors automatically update when phase hashtags change, as colors are derived from hashtags

### Insights

**Unified Insights View**
- **Dynamic Tab Layout**: 2 tabs (Phase, Settings) when Advanced Analytics OFF, 4 tabs (Phase, Health, Analytics, Settings) when ON
- **Adaptive Sizing**: Larger icons (24px) and font (17px) when 2 tabs, smaller (16px icons, 13px font) when 4 tabs
- **Automatic Centering**: TabBar automatically centers 2-tab layout
- **Advanced Analytics Toggle**: Settings control to show/hide Health and Analytics tabs
- **Sentinel Integration**: Sentinel moved to Analytics page as expandable card

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

### Export/Import System

**MCP Export**
- **Memory Bundle**: Complete memory graph export in MCP format
- **Phase Regimes**: Phase timeline export
- **System States**: RIVET state, Sentinel state, ArcForm timeline export
- **Chat History**: Complete chat session export
- **Media References**: Media item references in export

**ARCX Export**
- **Encrypted Archive**: AES-256-GCM encryption with Ed25519 signatures
- **Structured Payload**: Organized directory structure (Entries, Media, Chats, PhaseRegimes)
- **System State Backup**: Complete system state backup in PhaseRegimes/ directory
- **Import Tracking**: Detailed import completion with counts for all data types

**Import Features**
- **Phase Regime Import**: Restores phase timeline from exports
- **System State Import**: Restores RIVET state, Sentinel state, ArcForm timeline
- **Progress Tracking**: Real-time import progress with detailed counts
- **Error Handling**: Graceful error handling with detailed warnings

## Data Management Features

### MCP Export/Import

**Export Features**
- **Single File Format**: .zip only for simplicity
- **Storage Profiles**: Minimal, balanced, hi-fidelity
- **SAGE Integration**: Situation, Action, Growth, Essence extraction
- **Privacy Protection**: PII detection and flagging
- **Deterministic Exports**: Same input = same output

**Import Features**
- **Format Support**: MCP v1 compliant
- **Timeline Integration**: Automatic timeline refresh
- **Media Handling**: Photo and media import
- **Duplicate Detection**: Prevents duplicate entries

### ARCX Encryption

**Encryption Features**
- **AES-256-GCM**: Symmetric encryption
- **Ed25519**: Digital signatures
- **Optional Encryption**: User choice for exports
- **Key Management**: Secure key storage

### Data Portability

**Export Formats**
- MCP (Memory Container Protocol)
- ARCX (encrypted MCP)
- JSON (legacy support)

**Import Formats**
- MCP bundles
- ARCX archives
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
**Last Updated:** November 17, 2025  
**Version:** 1.0.3

