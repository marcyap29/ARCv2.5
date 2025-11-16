# EPI MVP - Comprehensive Guide

**Version:** 1.0.2  
**Last Updated:** November 2025

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Core Features](#core-features)
4. [User Guide](#user-guide)
5. [Developer Guide](#developer-guide)
6. [Architecture Guide](#architecture-guide)
7. [Troubleshooting](#troubleshooting)

---

## Introduction

EPI (Evolving Personal Intelligence) is a Flutter-based intelligent journaling application that provides life-aware assistance through journaling, pattern recognition, and contextual AI responses.

### What is EPI?

EPI is an AI-powered journaling companion that:
- Helps you capture and reflect on your life experiences
- Provides contextual AI assistance through LUMARA
- Visualizes your life patterns through 3D constellations
- Detects life phases and provides insights
- Maintains your privacy with on-device processing

### Key Features

- **Multimodal Journaling**: Text, voice, photos, and video
- **AI Assistant (LUMARA)**: Context-aware responses with persistent memory, unified UI/UX across in-journal and in-chat
- **Pattern Recognition**: Keyword extraction and phase detection
- **3D Visualizations**: ARCForm constellations showing journal themes
- **Privacy-First**: On-device processing with encryption
- **PRISM Scrubbing**: PII scrubbing before cloud API calls with automatic restoration
- **Data Portability**: MCP export/import for data portability

---

## Getting Started

### Installation

1. **Prerequisites**
   - Flutter 3.22.3+ (stable channel)
   - Dart 3.0.3+ <4.0.0
   - iOS Simulator or Android Emulator
   - Xcode (for iOS development)

2. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd ARCv.03/ARC\ MVP/EPI
   ```

3. **Install Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
   ```bash
   flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
   ```

### First Launch

1. **Onboarding**: Complete the 3-step onboarding flow
2. **Permissions**: Grant necessary permissions (camera, microphone, photos)
3. **Settings**: Configure LUMARA and privacy settings
4. **Start Journaling**: Create your first journal entry

---

## Core Features

### Journaling

**Text Journaling**
- Create text entries with rich formatting
- Auto-capitalization enabled
- Real-time keyword analysis
- Phase detection and suggestions

**Multimodal Journaling**
- **Photos**: Capture or select from gallery
- **Audio**: Voice recording with transcription
- **Video**: Video capture and analysis
- **OCR**: Text extraction from images

**Entry Management**
- Timeline view with chronological organization
- Edit existing entries (text, date, time, location, phase)
- Delete entries with confirmation
- Search and filter capabilities

### LUMARA AI Assistant

**Chat Interface**
- Persistent chat memory across sessions
- Context-aware responses
- Phase-aware reflections
- Multimodal understanding

**Memory System**
- Automatic chat persistence
- Cross-session continuity
- Rolling summaries every 10 messages
- Memory commands (/memory show, forget, export)

**Settings**
- On-device AI model selection
- Cloud API fallback configuration
- Similarity thresholds
- Lookback periods
- **Advanced Analytics Toggle**: Show/hide Health and Analytics tabs in Insights (default OFF)

### ARCForm Visualization

**3D Constellations**
- Phase-aware 3D visualizations
- Interactive exploration
- Keyword-based star formations
- Emotional mapping

**Phase Visualization**
- Phase timeline view
- Phase change readiness
- RIVET and SENTINEL analysis
- Phase recommendations

### Insights & Analysis

**Unified Insights View**
- **Dynamic Tab Layout**: 2 tabs (Phase, Settings) when Advanced Analytics OFF, 4 tabs (Phase, Health, Analytics, Settings) when ON
- **Advanced Analytics Toggle**: Settings control to show/hide Health and Analytics tabs (default OFF)
- **Adaptive Sizing**: Larger icons and font when 2 tabs, smaller when 4 tabs
- **Automatic Centering**: 2-tab layout automatically centered

**Pattern Recognition**
- Keyword extraction and categorization
- Emotion detection
- Phase detection
- Trend analysis

**Phase Analysis**
- Real-time phase detection
- RIVET Sweep integration
- Phase timeline visualization
- Current phase display with imported phase regime support

**Analytics Tools** (Available when Advanced Analytics enabled)
- **Patterns**: Keyword and emotion pattern analysis
- **AURORA**: Circadian rhythm and orchestration insights
- **VEIL**: Edge detection and relationship mapping
- **Sentinel**: Emotional risk detection and pattern analysis (moved from Phase Analysis)

**Health Integration** (Available when Advanced Analytics enabled)
- HealthKit integration (iOS)
- Health data visualization
- Circadian rhythm awareness

---

## User Guide

### Creating Journal Entries

1. **Open Journal Screen**: Tap the "+" button or journal icon
2. **Enter Text**: Type your journal entry
3. **Add Media** (optional):
   - Tap camera icon for photos
   - Tap microphone for voice recording
   - Tap gallery for existing photos
4. **Set Metadata** (optional):
   - Date and time
   - Location
   - Phase
   - Keywords
5. **Save**: Tap save button or use auto-save

### Using LUMARA

1. **Open LUMARA Tab**: Navigate to LUMARA tab
2. **Start Conversation**: Type your message
3. **Get Responses**: LUMARA provides context-aware responses
4. **Memory Commands**: Use /memory commands for memory management
5. **Settings**: Configure LUMARA in Settings

### Viewing ARCForms

1. **Open ARCForm Tab**: Navigate to ARCForm tab
2. **View Constellations**: See 3D visualizations of your journal themes
3. **Interact**: Rotate and explore 3D space
4. **Phase Analysis**: View phase timeline and analysis

### Exporting Data

1. **Open Settings**: Navigate to Settings
2. **MCP Export & Import**: Select export option
3. **Choose Profile**: Select storage profile (minimal, balanced, hi-fidelity)
4. **Export**: Save to Files app (.zip format)
5. **Import**: Select import option and choose .zip file

---

## Developer Guide

### Architecture Overview

EPI uses a 5-module architecture:

1. **ARC**: Journaling interface and UX
2. **PRISM**: Multimodal perception and analysis
3. **POLYMETA**: Memory graph and secure store
4. **AURORA**: Circadian orchestration
5. **ECHO**: Response control and safety

### Module Structure

```
lib/
├── arc/          # Journaling, chat, arcform
├── prism/        # Perception, analysis, ATLAS
├── polymeta/     # Memory, MCP, ARCX
├── aurora/       # Orchestration, VEIL
├── echo/         # Safety, privacy, LLM
├── core/         # Shared utilities
└── shared/       # Shared UI components
```

### Adding Features

1. **Identify Module**: Determine which module your feature belongs to
2. **Create Service**: Create service class in appropriate module
3. **Add UI**: Create UI components in shared or module-specific UI folder
4. **Update State**: Use BLoC for state management
5. **Add Tests**: Write unit and widget tests
6. **Update Docs**: Update relevant documentation

### Code Style

- **Dart Style Guide**: Follow official Dart style guide
- **BLoC Pattern**: Use BLoC for state management
- **Repository Pattern**: Use repositories for data access
- **Service Layer**: Use services for business logic

### Testing

```bash
# Run all tests
flutter test

# Run specific test suite
flutter test test/arc/
flutter test test/prism/

# Run with coverage
flutter test --coverage
```

---

## Architecture Guide

### Module Responsibilities

**ARC Module**
- Journal entry capture and editing
- LUMARA chat interface
- ARCForm visualization
- Timeline management

**PRISM Module**
- Content analysis (text, images, audio, video)
- Phase detection (ATLAS)
- Risk assessment (RIVET, SENTINEL)
- Health data integration

**POLYMETA Module**
- Unified memory graph (MIRA)
- MCP-compliant storage
- ARCX encryption
- Vector search and retrieval

**AURORA Module**
- Scheduled job orchestration
- Circadian rhythm awareness
- VEIL restoration cycles
- Background task management

**ECHO Module**
- LLM provider abstraction
- Privacy guardrails
- Content safety filtering
- Dignity-preserving responses
- PRISM data scrubbing (PII scrubbing before cloud API calls)

**LUMARA Memory Attribution**
- Specific excerpt attribution (exact 2-3 sentences from memory entries)
- Weighted context prioritization (current entry → recent responses → other entries)
- Draft entry support (unsaved content can be used as context)
- Journal integration (attributions shown in inline reflections)

### Data Flow

1. **User Input**: ARC captures user input
2. **Processing**: PRISM analyzes content
3. **Storage**: POLYMETA stores in memory graph
4. **Safety**: ECHO applies guardrails
5. **Orchestration**: AURORA schedules maintenance

### Integration Points

- **ARC ↔ PRISM**: Content analysis and phase detection
- **PRISM ↔ POLYMETA**: Memory storage and retrieval
- **POLYMETA ↔ ECHO**: Context retrieval for responses
- **ECHO ↔ AURORA**: Scheduled safety checks
- **ARC ↔ ECHO**: Response generation

---

## Troubleshooting

### Common Issues

**App Won't Start**
- Check Flutter version (3.22.3+)
- Verify dependencies installed (`flutter pub get`)
- Check for initialization errors in logs

**LUMARA Not Responding**
- Verify API key configured (for cloud fallback)
- Check on-device model availability
- Review LUMARA settings

**Photos Not Loading**
- Check photo permissions
- Verify photo library access
- Check file paths and permissions

**Export/Import Issues**
- Verify file format (.zip)
- Check file size limits
- Review MCP bundle structure

### Getting Help

1. **Check Documentation**: Review relevant guides
2. **Check Bug Tracker**: See if issue is known
3. **Review Logs**: Check app logs for errors
4. **Create Issue**: Report new issues with details

---

## Additional Resources

### Documentation
- **Architecture**: `docs/architecture/EPI_MVP_Architecture.md`
- **Status**: `docs/status/status.md`
- **Bug Tracker**: `docs/bugtracker/bug_tracker.md`
- **Features**: `docs/features/`

### Guides
- **Quick Start**: `docs/guides/QUICK_START_GUIDE.md`
- **Installation**: `docs/guides/MVP_Install.md`
- **Integration**: `docs/guides/MULTIMODAL_INTEGRATION_GUIDE.md`

### Reports
- **Overview**: `docs/reports/EPI_MVP_Overview_Report.md`
- **Updates**: `docs/updates/UPDATE_LOG.md`

---

**Guide Status:** ✅ Complete  
**Last Updated:** January 2025  
**Version:** 1.0.0

