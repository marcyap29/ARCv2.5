# EPI MVP - Architecture Overview

**Version:** 2.1.46
**Last Updated:** December 9, 2025
**Status:** ✅ Production Ready - MVP Fully Operational with Authentication

---

## Executive Summary

EPI (Evolving Personal Intelligence) is a Flutter-based intelligent journaling application that provides life-aware assistance through journaling, pattern recognition, and contextual AI responses. The MVP is fully operational with a consolidated 5-module architecture that has been refactored from 8+ separate modules into clean, deployable modules with clear boundaries and responsibilities.

### Key Achievements

- ✅ **Complete MVP Implementation**: All core features operational
- ✅ **5-Module Architecture**: Consolidated from 8+ modules for maintainability
- ✅ **LUMARA MCP Memory System**: Persistent conversational memory across sessions
- ✅ **On-Device AI Integration**: Qwen models with llama.cpp and Metal acceleration
- ✅ **MCP Export/Import System**: Standards-compliant data portability
- ✅ **Production Ready**: All critical systems stable and tested
- ✅ **Priority 3 Authentication**: Firebase Auth with per-entry/per-chat rate limiting

### Current Version

- **Application Version**: 1.0.0+1 (from pubspec.yaml)
- **Architecture Version**: 2.2 (Consolidated Architecture)
- **Flutter SDK**: >=3.22.3
- **Dart SDK**: >=3.0.3 <4.0.0

---

## System Overview

### Purpose

EPI provides users with an intelligent journaling companion that:
- Captures multimodal journal entries (text, photos, audio, video)
- Provides contextual AI assistance through LUMARA
- Visualizes life patterns through ARCForm 3D constellations
- Detects life phases and provides insights
- Maintains privacy-first architecture with on-device processing
- Exports/imports data in standardized MCP format

### Core Capabilities

1. **Journaling**: Text, voice, photo, and video journaling with OCR and analysis
2. **AI Assistant (LUMARA)**: Context-aware responses with persistent chat memory
3. **Pattern Recognition**: Keyword extraction, phase detection, and emotional mapping
4. **Visualization**: 3D ARCForm constellations showing journal themes
5. **Memory System**: Semantic memory graph with MCP-compliant storage
6. **Privacy Protection**: On-device processing, PII detection, and encryption
7. **Data Portability**: MCP export/import for AI ecosystem interoperability

---

## 5-Module Architecture

### Module Overview

The EPI system is organized into 5 core modules:

1. **ARC** - Core Journaling Interface
2. **PRISM** - Multimodal Perception & Analysis
3. **MIRA** - Memory Graph & Secure Store
4. **AURORA** - Circadian Orchestration
5. **ECHO** - Response Control & Safety

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         EPI Platform                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐ │
│  │     ARC      │──────▶│    PRISM     │──────▶│  MIRA    │ │
│  │              │      │              │      │              │ │
│  │ • Journaling │      │ • Perception │      │ • Memory     │ │
│  │ • Chat       │      │ • Analysis   │      │ • Encryption │ │
│  │ • Arcform    │      │ • ATLAS      │      │ • Storage    │ │
│  │              │      │   - Phase    │      │ • MCP/ARCX   │ │
│  │              │      │   - RIVET    │      │              │ │
│  │              │      │   - SENTINEL │      │              │ │
│  └──────┬───────┘      └──────┬───────┘      └──────┬───────┘ │
│         │                     │                     │         │
│         │                     │                     │         │
│         └─────────────────────┼─────────────────────┘         │
│                               │                               │
│                         ┌─────▼─────┐                         │
│                         │   ECHO    │                         │
│                         │           │                         │
│                         │ • Guard   │                         │
│                         │ • Privacy │                         │
│                         │ • LLM     │                         │
│                         └─────┬─────┘                         │
│                               │                               │
│                         ┌─────▼─────┐                         │
│                         │  AURORA   │                         │
│                         │           │                         │
│                         │ • Jobs    │                         │
│                         │ • VEIL    │                         │
│                         │ • Schedule│                         │
│                         └───────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Details

### 1. ARC Module (`lib/arc/`)

**Purpose:** Core journaling app & main user experience

**Submodules:**
- `chat/` - LUMARA conversational AI
  - `services/reflective_query_service.dart` - EPI-standard reflective queries
  - `services/reflective_query_formatter.dart` - Response formatting
  - `services/lumara_notification_service.dart` - Time Echo and Active Window reminders
  - `services/active_window_detector.dart` - User reflection pattern detection
  - `services/sleep_protection_service.dart` - Sleep/abstinence window management
  - `services/theme_analysis_service.dart` - Longitudinal theme tracking
  - `models/reflective_query_models.dart` - Query result models
  - `models/notification_models.dart` - Notification data models
- `arcform/` - 3D visualization and analysis forms
- `core/` - Journal entry processing and state management
- `ui/` - Journaling interface components
- `privacy/` - Real-time PII protection
- `repository/` - Journal data access layer
- `services/` - ARC-specific services

**Key Features:**
- Journal entry capture and editing
- **LUMARA Reflective Queries**: Three EPI-standard anti-harm queries
  - "Show me three times I handled something hard"
  - "What was I struggling with around this time last year?"
  - "Which themes have softened in the last six months?"
- **Notification System**: Time Echo reminders and Active Window detection
- LUMARA chat interface with persistent memory
- ARCForm visualization with phase-aware layouts
- Privacy-first data handling
- Timeline management with accurate date navigation
- Draft management with auto-save
- **Original Creation Time Preservation**: `createdAt` never changes on updates

---

### 2. PRISM Module (`lib/prism/`)

**Purpose:** Multimodal perception & analysis

**Submodules:**
- `atlas/` - Phase detection, RIVET, SENTINEL
  - `phase/` - Versioned phase inference pipeline with Phase Regimes integration
    - `phase_inference_service.dart` - Pure inference ignoring hashtags and legacy tags
    - `phase_regime_tracker.dart` - Bridges PhaseTracker and PhaseRegimeService
    - `phase_migration_service.dart` - On-demand phase recomputation for eligible entries
    - `phase_scoring.dart` - Expanded keyword sets (60-120 keywords per phase)
    - `phase_tracker.dart` - EMA smoothing and hysteresis for stable phase detection
  - `rivet/` - Risk-Validation Evidence Tracker
  - `sentinel/` - Severity evaluation and negative trend identification
- `extractors/` - Keyword, emotion, context, metadata extraction
- `processors/` - Text, image, audio, video processing
- `privacy/` - Multi-modal PII detection and masking
- `vital/` - Health data integration

**Key Features:**
- Multi-modal content analysis (OCR, object detection, transcription)
- Versioned phase detection with traceability (phaseInferenceVersion tracking)
- Phase Regimes integration for stable phase changes (prevents erratic day-to-day changes)
- Expanded keyword detection (60-120 keywords per phase for improved accuracy)
- User phase overrides with lock mechanism
- Automatic migration of legacy phase data
- RIVET gating for phase transitions
- SENTINEL risk monitoring
- Health data integration
- Privacy-aware processing

---

### 3. MIRA Module (`lib/mira/`)

**Purpose:** Memory graph & secure storage

**Submodules:**
- `store/` - Secure storage with encryption
  - `mcp/` - MCP format export/import
  - `arcx/` - ARCX encrypted archive format
- `graph/` - Semantic memory graph
- `services/` - Memory services

**Key Features:**
- MCP-compliant memory storage
- ARCX encrypted archives
- Semantic graph construction
- Export/import with extended data support
- Secure key management

---

### 4. ECHO Module (`lib/echo/`)

**Purpose:** Response control & safety

**Submodules:**
- `response/` - LLM response generation
- `guard/` - Safety and privacy guards
- `prompts/` - Prompt management

**Key Features:**
- LLM integration (Gemini API, on-device Qwen)
- Response safety checks
- Privacy filtering
- Context management
- Prompt engineering

---

### 5. AURORA Module (`lib/aurora/`)

**Purpose:** Circadian orchestration

**Submodules:**
- `jobs/` - Scheduled background jobs
- `veil/` - Privacy edge computing
- `schedule/` - Task scheduling

**Key Features:**
- Background job scheduling
- Privacy-preserving edge computing
- Task orchestration
- Circadian rhythm awareness

---

## Technical Stack

### Frontend
- **Framework**: Flutter 3.22.3+
- **Language**: Dart 3.0.3+
- **UI**: Material Design 3
- **State Management**: Provider, Cubit

### Backend Services
- **Storage**: Hive (local NoSQL database)
  - JournalEntry model with `lumaraBlocks` field (HiveField 27)
  - InlineBlock type (HiveType 103) for LUMARA reflection blocks
  - Automatic migration from legacy `metadata.inlineBlocks` format
- **File System**: path_provider, file_picker
- **Networking**: http, dio
- **Crypto**: crypto, pointycastle

### AI Integration
- **Cloud LLM**: Gemini API (Google)
- **On-Device**: llama.cpp with Qwen models
- **Embeddings**: Qwen3-Embedding-0.6B
- **Vision**: Qwen2.5-VL-3B

### Platform-Specific
- **iOS**: Swift, Metal acceleration
- **Android**: Kotlin, NDK
- **Native Bridges**: Platform channels

---

## Data Flow & Integration

### Entry Creation Flow

```
User Input → ARC UI → Journal Repository → PRISM Analysis → MIRA Storage
                                                              ↓
                                                         ECHO Response
                                                              ↓
                                                         LUMARA Chat
```

### Export/Import Flow

```
MIRA Store → MCP Export Service → ZIP/ARCX Archive
                                    ↓
                              Extended Data:
                              - Phase Regimes
                              - RIVET State
                              - Sentinel State
                              - ArcForm Timeline
                              - LUMARA Favorites
                              - Media Packs (/Media/packs/pack-XXX/)
                                    ↓
                              media_index.json (pack tracking)
```

---

## Security & Privacy

### Privacy Features
- **On-Device Processing**: Primary AI processing on-device
- **PII Detection**: Automatic detection and flagging
- **Encryption**: AES-256-GCM for ARCX archives
- **Digital Signatures**: Ed25519 for archive verification
- **No Cloud Storage**: User data never stored in cloud

### Security Measures
- **Encrypted Archives**: Optional encryption for exports
- **Secure Key Storage**: Platform keychain/keyring
- **Privacy Guards**: ECHO module filters sensitive data
- **Access Control**: Platform-level permissions

---

## Performance & Scalability

### Optimization Strategies
- **Lazy Loading**: On-demand data loading
- **Caching**: In-memory caching for frequently accessed data
- **Background Processing**: AURORA handles heavy tasks
- **Metal Acceleration**: iOS GPU acceleration for AI

### Scalability
- **Modular Design**: Easy to extend and modify
- **Memory Management**: Efficient memory usage
- **Storage Optimization**: Compressed storage formats

---

## Deployment Architecture

### Build Targets
- **iOS**: Xcode project with Swift bridges
- **Android**: Gradle build with Kotlin
- **macOS**: Desktop support (planned)
- **Linux**: Desktop support (planned)

### Distribution
- **App Store**: iOS distribution
- **Play Store**: Android distribution
- **Direct**: APK/IPA distribution

---

## API Specifications

### Internal APIs
- **Journal Repository**: Entry CRUD operations
- **MIRA Store**: Memory graph operations
- **PRISM Analysis**: Content analysis services
- **ECHO Response**: LLM integration

### External APIs
- **Gemini API**: Cloud LLM provider
- **HealthKit**: iOS health data (planned)
- **Google Fit**: Android health data (planned)

---

## Testing Strategy

### Test Coverage
- **Unit Tests**: Core logic and services
- **Integration Tests**: Module interactions
- **Widget Tests**: UI components
- **Golden Tests**: Visual regression

### Test Structure
- `test/arc/` - ARC module tests
- `test/prism/` - PRISM module tests
- `test/mira/` - MIRA module tests
- `test/integration/` - Integration tests

---

## Related Documentation

For detailed information on specific modules and features, see:
- [Features Guide](FEATURES.md)
- [Changelog](CHANGELOG.md)
- [Bug Tracker](BUGTRACKER.md)

---

---

## Authentication & Security Architecture (Priority 3)

### Authentication Flow

```
User Launch → Anonymous Auth (Auto) → 5 Free Requests → Sign-In Prompt
                                                              ↓
                                            Google/Email Sign-In → Account Linked
                                                              ↓
                                            Per-Entry/Per-Chat Rate Limiting
```

### Rate Limiting System

| Tier | In-Journal LUMARA | In-Chat LUMARA |
|------|-------------------|----------------|
| **Free** | 5 per entry | 20 per chat |
| **Admin** | Unlimited | Unlimited |
| **Premium** | Unlimited | Unlimited |

### Security Components

- **Firebase Auth**: Anonymous, Google, Email/Password authentication
- **Account Linking**: Anonymous sessions linked to real accounts on sign-in
- **AuthGuard**: Centralized authentication enforcement in Cloud Functions
- **Admin Privileges**: Email-based admin detection with automatic pro upgrade
- **Firestore Rules**: Per-user data isolation and field-level protection

---

**Status**: ✅ Production Ready
**Last Updated**: December 9, 2025
**Version**: 2.1.46

