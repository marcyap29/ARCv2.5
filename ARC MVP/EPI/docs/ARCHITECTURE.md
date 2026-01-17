# EPI MVP - Architecture Overview

**Version:** 3.2.3
**Last Updated:** January 10, 2026
**Status:** ✅ Production Ready - MVP Fully Operational with Companion-First LUMARA, Simplified Settings, Health Integration, AssemblyAI v3, Web Access Safety, Correlation-Resistant PII Protection, Bible Reference Retrieval, Google Drive Backup, Temporal Notifications, Enhanced Incremental Backups, Automatic First Export, and Sequential Export Numbering

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
- ✅ **Google Sign-In Configured (iOS)**: OAuth client + URL scheme in place to prevent crashes
- ✅ **Phase System Overhaul (v2.1.48)**: RIVET-based calculations, 10-day rolling windows, chisel effect
- ✅ **LUMARA Persona System (v2.1.51)**: 4 personality modes with auto-detection
- ✅ **Health→LUMARA Integration (v2.1.52)**: Sleep/energy signals influence LUMARA behavior
- ✅ **LUMARA Web Access Safety Layer (v2.1.57)**: Comprehensive 10-rule safety framework for Google Search integration
- ✅ **LUMARA Journal Context Order Fix (v2.1.58)**: Chronological context ordering - LUMARA only sees content above its position
- ✅ **LUMARA Bible Reference Retrieval (v2.1.63)**: Automatic Bible verse and chapter retrieval using HelloAO Bible API with intelligent detection and privacy protection
- ✅ **Google Drive Backup Integration (v2.1.64)**: Automatic cloud backups to Google Drive with OAuth authentication, scheduled backups, and export integration
- ✅ **Stripe Integration Setup (v2.1.76)**: Complete Stripe payment integration with checkout, customer portal, and webhook handlers. Comprehensive documentation and setup guides
- ✅ **Incremental Backup System (v2.1.77)**: Space-efficient incremental backups with export history tracking, media deduplication, and 90%+ size reduction
- ✅ **Temporal Notifications System (v2.1.83)**: Multi-cadence notification system (daily, monthly, 6-month, yearly) with phase-aware insights, deep linking, and comprehensive settings UI
- ✅ **LUMARA Entry Classification System (v2.1.85)**: Intelligent classification prevents over-synthesis on simple questions while preserving sophisticated temporal intelligence for complex entries
- ✅ **Enhanced PRISM Semantic Summarization (v2.1.86)**: Classification-aware privacy system with improved technical content detection and on-device semantic analysis
- ✅ **LUMARA v3.0 User Prompt System (v3.0)**: Fixed user prompt to reinforce master prompt constraints instead of overriding them, ensuring word limits, dated examples, and banned phrases are properly enforced
- ✅ **LUMARA v3.2 Unified Prompt System (v3.2)**: Consolidated master prompt and user prompt into single unified prompt, eliminating duplication and override risk
- ✅ **Adaptive Framework (v3.1)**: User-adaptive calibration system for SENTINEL and RIVET algorithms that automatically adjusts parameters based on journaling cadence (power user, frequent, weekly, sporadic)
- ✅ **Export System Improvements (v3.2.3)**: Automatic first export (full backup of all files), sequential export numbering for clear tracking, and always-available full export option
- ✅ **Export System Improvements (v3.2.3)**: Automatic first export (full backup of all files), sequential export numbering for clear tracking, and always-available full export option

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
8. **Cloud Backup**: Google Drive integration for automatic and manual backups

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

**Architecture:** ARC internally mirrors the 5-module architecture:
- **PRISM (Internal)**: Analysis of text and media
- **MIRA (Internal)**: Memory and security of files
- **AURORA (Internal)**: Handles time when user is active
- **ECHO (Internal)**: Provides PII and security

**Submodules:**
- `internal/` - **ARC Internal Modules** (mirrors EPI 5-module architecture)
  - `prism/` - Text & Media Analysis (PRISM Internal)
    - `theme_analysis_service.dart` - Longitudinal theme tracking
    - `keyword_extraction_service.dart` - Keyword extraction
    - `media/` - Media processing (capture, preview, OCR)
  - `mira/` - Memory & File Security (MIRA Internal)
    - `memory_loader.dart` - Progressive memory loading
    - `reflective_storage.dart` - Reflective node storage
    - `semantic_matching.dart` - Semantic similarity matching
    - `journal_repository.dart` - Secure journal entry storage
    - `version_service.dart` - Version management
    - `memory/` - Memory services (MCP, indexing, PII redaction)
  - `aurora/` - Time & User Activity (AURORA Internal)
    - `active_window_detector.dart` - Active reflection window detection
    - `sleep_protection_service.dart` - Sleep/abstinence window management
    - `notification_service.dart` - Time Echo and Active Window reminders
    - `memory_notification_service.dart` - Memory-based notifications
  - `echo/` - PII & Security (ECHO Internal)
    - `prism_adapter.dart` - PRISM adapter for PII scrubbing
    - `correlation_resistant_transformer.dart` - Correlation-resistant transformation
    - `voice_pipeline.dart` - Secure voice processing pipeline
    - `privacy_redactor.dart` - Privacy redaction for chat
- `chat/` - LUMARA conversational AI
  - `services/reflective_query_service.dart` - EPI-standard reflective queries
  - `services/reflective_query_formatter.dart` - Response formatting
  - `services/bible_api_service.dart` - HelloAO Bible API integration
  - `services/temporal_notification_service.dart` - Multi-cadence notification scheduling
  - `services/notification_content_generator.dart` - Notification content generation
  - `services/google_drive_service.dart` - Google Drive API integration with OAuth
  - `services/backup_upload_service.dart` - Backup creation and upload orchestration
  - `services/scheduled_backup_service.dart` - Periodic backup scheduling
  - `services/google_drive_backup_settings_service.dart` - Persistent settings storage
  - `services/bible_retrieval_helper.dart` - Bible query detection and verse fetching
  - `services/bible_terminology_library.dart` - Comprehensive Bible terminology database
  - `models/reflective_query_models.dart` - Query result models
  - `models/notification_models.dart` - Notification data models
- `arcform/` - 3D visualization and analysis forms
- `core/` - Journal entry processing and state management
- `ui/` - Journaling interface components
- `privacy/` - Privacy demonstration UI

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
- `adaptive/` - User-adaptive calibration system (NEW v3.1)
  - `user_cadence_detector.dart` - Detects user journaling patterns (power user, frequent, weekly, sporadic)
  - `adaptive_config.dart` - Unified adaptive configuration for RIVET and Sentinel
  - `rivet_config.dart` - Adaptive RIVET configuration by user type
  - `adaptive_sentinel_calculator.dart` - Enhanced Sentinel with emotional concentration and explicit emotion detection
  - `adaptive_algorithm_service.dart` - Orchestration service for adaptive algorithms
- `extractors/` - Keyword, emotion, context, metadata extraction
  - `enhanced_keyword_extractor.dart` - Curated keyword library with intensities and RIVET gating
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
- **Adaptive Framework (v3.1)**: Automatic calibration based on user journaling cadence
  - User cadence detection (power user, frequent, weekly, sporadic)
  - Adaptive RIVET configuration (stability windows, confidence thresholds, temporal decay)
  - Adaptive Sentinel configuration (emotional intensity weights, normalization methods, explicit emotion multipliers)
  - Smooth configuration transitions when user patterns change
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
- Google Drive cloud backup integration
- **Two-Stage Memory System (v3.2.4)**: Complementary memory architecture
  - **Stage 1: Context Selection** (Temporal/Phase-Aware Entry Selection)
    - `LumaraContextSelector` selects entries based on Memory Focus, Engagement Mode, semantic relevance, and phase intelligence
    - Determines: "Which parts of the journey?" (horizontal - time/phases)
  - **Stage 2: Polymeta Memory Filtering** (Domain/Confidence-Based)
    - `MemoryModeService` filters memories FROM selected entries
    - Applies domain modes (Always On/Suggestive/High Confidence Only)
    - Applies decay/reinforcement rates
    - Determines: "What to remember from those parts?" (vertical - domain/confidence)
  - **No Conflict**: These systems are complementary, not competing
  - **Integration Pattern**: Context Selector selects entries → Polymeta filters memories from those entries → Both included in prompt

---

### 4. ECHO Module (`lib/echo/`)

**Purpose:** Response control & safety

**Submodules:**
- `response/` - LLM response generation
- `guard/` - Safety and privacy guards
- `prompts/` - Prompt management

**Classification System Files:**
- `lib/services/lumara/entry_classifier.dart` - Core classification logic
- `lib/services/lumara/response_mode.dart` - Response mode configuration
- `lib/services/lumara/classification_logger.dart` - Analytics and monitoring
- `lib/services/lumara/lumara_classifier_integration.dart` - Integration helper
- `test/services/lumara/entry_classifier_test.dart` - Comprehensive test suite

**Key Features:**
- LLM integration (Gemini API, on-device Qwen)
- Response safety checks
- Privacy filtering
- Context management
- Prompt engineering
- **Engagement Discipline System** (v2.1.75): User-controlled engagement modes (Reflect/Explore/Integrate) with synthesis boundaries and response discipline settings

### 5. Subscription & Payment Module (v2.1.76)

**Purpose:** Premium subscription management via Stripe

**Components:**
- `lib/services/subscription_service.dart` - Subscription management with caching
- `lib/ui/subscription/subscription_management_view.dart` - Subscription UI
- `lib/ui/subscription/lumara_subscription_status.dart` - Status display widget
- `functions/index.js` - Stripe Cloud Functions (checkout, portal, webhooks)

**Key Features:**
- Stripe Checkout integration for secure payments
- Monthly ($30) and Annual ($200) subscription options
- Customer Portal for subscription management
- Webhook-based subscription status updates
- Firebase Secret Manager for secure key storage
- Authentication and token refresh for Stripe functions
- Subscription status caching (5-minute TTL)

**Documentation:**
- Setup guides: `docs/stripe/README.md`
- Complete setup: `docs/stripe/STRIPE_SECRETS_SETUP.md`
- Webhook setup: `docs/stripe/STRIPE_WEBHOOK_SETUP_VISUAL.md`

---

### 5. AURORA Module (`lib/aurora/`)

**Purpose:** Circadian orchestration

**Submodules:**
- `regimens/veil/` - VEIL restorative jobs and privacy edge computing
  - `veil_module.dart` - VEIL module placeholder for future implementation
- `services/` - Circadian and scheduling services
  - `circadian_profile_service.dart` - Circadian rhythm awareness
- `models/` - AURORA data models
  - `circadian_context.dart` - Circadian context models

**Key Features:**
- Circadian rhythm awareness
- VEIL restorative job cycles (future implementation)
- Background task management
- Time-based job scheduling

**Note:** VEIL is part of AURORA and accessed via `aurora/regimens/veil/`. Additional VEIL-related components exist in `mira/veil/` (VEIL jobs) and `ui/veil/` (VEIL policy UI).

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
- **Bible API**: HelloAO Bible API (`bible.helloao.org`) for accurate Bible verse retrieval
  - Automatic detection of Bible-related queries using comprehensive terminology library
  - Character-to-book resolution for prophets and biblical figures
  - Privacy-protected (Bible names whitelisted in PRISM)
  - Context-preserving (skips correlation-resistant transformation for Bible questions)
- **Entry Classification System**: Intelligent classification of user entries to optimize LUMARA responses
  - **5 Entry Types**: Factual, Reflective, Analytical, Conversational, Meta-Analysis
  - **Pre-Processing Classification**: Classification happens before LUMARA processing to prevent over-synthesis
  - **Response Mode Optimization**: Different response modes with appropriate word limits and context scoping
  - **Pattern Detection**: Emotional density, first-person density, technical indicators, and meta-analysis patterns
  - **Classification Logging**: Firebase-based analytics for monitoring and improving classification accuracy
- **Companion-First LUMARA System (v2.1.87)**: Complete architectural overhaul implementing Companion-first persona selection
  - **Persona Distribution Target**: 50-60% Companion, 25-35% Strategist, 10-15% Therapist, <5% Challenger
  - **Backend-Only Personas**: No manual persona selection - all decisions made by system based on entry classification and user state
  - **Strict Anti-Over-Referencing**: Maximum 1 past reference for personal Companion responses, maximum 3 for project content
  - **Personal vs. Project Detection**: Intelligent content analysis distinguishing personal reflections from project discussions
  - **User Intent Detection**: Button interactions mapped to 6 intent types (reflect, suggestIdeas, thinkThrough, differentPerspective, suggestSteps, reflectDeeply)
  - **Safety Escalation Hierarchy**: Sentinel alerts → High distress → User intent → Entry type → Default Companion
  - **Validation System**: Comprehensive response validation with Firebase logging for violations and persona distribution monitoring
  - **Simplified Settings**: Removed overwhelming options (manual persona, therapeutic depth, response length) while preserving essential controls
- **Enhanced PRISM Privacy System**: Classification-aware privacy protection with improved semantic analysis
  - **Dual Privacy Strategy**: Classification-aware PRISM preserves semantic content for factual entries while using full abstraction for personal/emotional content
  - **Technical Content Detection**: On-device recognition of mathematics, physics, computer science, engineering topics with subject-specific summarization
  - **Enhanced Semantic Summarization**: Improved on-device analysis creates descriptive summaries instead of generic abstractions
  - **Privacy Guarantee**: Personal/emotional entries still receive full correlation-resistant transformation with rotating aliases and non-verbatim abstraction
  - **On-Device Processing**: All classification and semantic analysis happens locally before any cloud transmission

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

### Incremental Backup System (v2.1.77)

**Purpose:** Space-efficient backups that only export new/changed data since last backup, reducing backup size by 90%+.

**Components:**
- **ExportHistoryService**: Tracks export history using SharedPreferences
  - Stores exported entry IDs, chat IDs, and media hashes (SHA-256)
  - Maintains last export date and last full backup date
  - Provides export statistics and preview data
- **ARCXExportServiceV2**: Enhanced with incremental export methods
  - `exportIncremental()`: Exports only new/modified entries since last export
  - `exportFullBackup()`: Exports all data and records as full backup
  - `getIncrementalExportPreview()`: Provides summary of new data for UI
- **LocalBackupSettingsView**: UI for backup management
  - Incremental Backup: Incremental backup with preview
  - Full Backup: Complete backup option
  - Backup History: Statistics and history management

**Backup Flow:**
```
User initiates backup
    ↓
ExportHistoryService checks last export date
    ↓
Filter entries/chats modified since last export
    ↓
If text-only mode: Skip all media
If full mode: Filter media by SHA-256 hash (skip already exported)
    ↓
Create ARCX archive with only new/changed data
    ↓
Record export in ExportHistoryService
    ↓
Update last export date and tracked IDs/hashes
```

**Backup Modes:**
- **Text-Only Incremental**: Excludes all media for space-efficient backups
  - Typical size: < 1 MB
  - Ideal for frequent daily backups
  - 90%+ size reduction vs full incremental
- **Full Incremental**: Includes entries, chats, and new media
  - Media deduplication by SHA-256 hash
  - Typical size: ~30-50MB (reduced from ~500MB)

**Benefits:**
- **90%+ Size Reduction**: Text-only backups are < 1 MB, full incremental ~30-50MB (vs ~500MB full)
- **Faster Backups**: Less data to process and encrypt
- **Storage Efficiency**: Prevents redundant data in backup files
- **Smart Deduplication**: Media files tracked by hash to prevent duplicates
- **Flexible Options**: Choose text-only for frequent backups, full for periodic backups
- **Enhanced Error Handling**: Clear detection and reporting of disk space vs permission errors

---

## Security & Privacy

### Privacy Features
- **On-Device Processing**: Primary AI processing on-device
- **PII Detection**: Automatic detection and flagging
- **PRISM Scrubbing**: Two-layer PII protection system
  - Layer 1: PRISM scrubbing (tokens like `[EMAIL_1]`, `[NAME_1]`)
  - Layer 2: Correlation-resistant transformation (rotating aliases like `PERSON(H:7c91f2, S:⟡K3)`)
- **Structured Payloads**: JSON abstractions instead of verbatim text
- **Session Rotation**: Identifiers rotate per session to prevent linkage
- **Encryption**: AES-256-GCM for ARCX archives
- **Digital Signatures**: Ed25519 for archive verification
- **No Cloud Storage**: User data never stored in cloud

### Security Measures
- **Encrypted Archives**: Optional encryption for exports
- **Secure Key Storage**: Platform keychain/keyring
- **Privacy Guards**: ECHO module filters sensitive data
- **Correlation Resistance**: Rotating aliases prevent re-identification
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

## Adaptive Framework (v3.1)

### Overview

The Adaptive Framework automatically calibrates RIVET and Sentinel algorithms based on user journaling patterns. The core principle: **Psychological time ≠ Calendar time**. A phase transition takes the same number of journal entries whether written daily or weekly, but spans different calendar periods.

### User Cadence Detection

The system automatically detects user journaling cadence and classifies users into one of five types:

- **Power User**: ≤ 2 days between entries (daily/near-daily journaling)
- **Frequent**: 2-4 days between entries (2-3 times per week)
- **Weekly**: 4-9 days between entries (once per week)
- **Sporadic**: > 9 days between entries (less than weekly)
- **Insufficient Data**: < 5 entries total

### Adaptive RIVET Configuration

RIVET parameters automatically adjust based on user type:

- **Stability Windows**: Power users (7-14 days) vs. Sporadic users (42-84 days)
- **Confidence Thresholds**: Lower thresholds for sparse journalers
- **Temporal Decay**: Slower decay for less frequent entries
- **Phase Intensity**: Adjusted thresholds for emerging vs. established phases

### Adaptive Sentinel Configuration

Sentinel emotional density calculation adapts to user patterns:

- **Component Weights**: Higher emotional intensity weight for sparse journalers
- **Emotional Concentration**: Detects when multiple emotional terms cluster in same semantic family
- **Explicit Emotion Detection**: Multipliers for explicit emotion statements ("I feel...", "I'm so...")
- **Word Count Normalization**: Linear for power users, sqrt/log for sparse journalers
- **Temporal Decay**: Slower decay for less frequent entries

### Configuration Transitions

When user cadence changes (e.g., power user → weekly), the system smoothly transitions configurations over 5 entries to prevent sudden algorithmic shifts.

### Implementation

- **Location**: `lib/services/adaptive/`
- **Storage**: Firebase Firestore (`users/{userId}/adaptive_state/cadence_profile`)
- **Recalculation**: Every 10 new entries or on demand
- **Documentation**: See [RIVET Architecture](RIVET_ARCHITECTURE.md) and [Sentinel Architecture](SENTINEL_ARCHITECTURE.md) for detailed pseudocode

---

## Related Documentation

For detailed information on specific modules and features, see:
- [Features Guide](FEATURES.md)
- [Changelog](CHANGELOG.md)
- [Bug Tracker](BUGTRACKER.md)
- [RIVET Architecture](RIVET_ARCHITECTURE.md) - Phase detection and validation
- [Sentinel Architecture](SENTINEL_ARCHITECTURE.md) - Crisis detection system

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
**Last Updated**: January 1, 2026
**Version**: 2.1.76

