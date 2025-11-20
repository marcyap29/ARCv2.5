# EPI Module Reference Guide

**Version:** 1.0.0  
**Last Updated:** January 2025  
**Status:** ✅ Production Ready

---

## Overview

This document provides a comprehensive reference guide to all modules, submodules, and key components in the EPI (Evolving Personal Intelligence) system. Use this as a detailed map when navigating the codebase or understanding system architecture.

---

## Module Directory Structure

```
lib/
├── arc/              # Core Journaling Interface
├── prism/            # Multimodal Perception & Analysis
├── mira/             # Memory Graph & Secure Store
├── aurora/           # Circadian Orchestration
├── echo/             # Response Control & Safety
├── core/             # Shared infrastructure
├── services/         # Cross-module services
├── models/           # Shared data models
├── ui/               # UI components
├── data/             # Data layer
├── insights/         # Analytics and insights
├── mode/             # Application modes (Coach, First Responder)
├── shared/           # Shared UI components
└── utils/           # Utility functions
```

---

## 1. ARC Module (`lib/arc/`)

### Purpose
Primary user experience for journaling, chat, and visualization.

### Directory Structure

```
arc/
├── arc_module.dart           # Module entry point
├── chat/                     # LUMARA conversational AI
│   ├── bloc/                 # State management (Cubits)
│   ├── chat/                 # Chat core functionality
│   │   ├── chat_repo.dart    # Repository interface
│   │   ├── chat_models.dart  # Chat data models
│   │   ├── chat_pruner.dart  # Chat cleanup
│   │   └── ui/               # Chat UI components
│   ├── llm/                  # LLM integration
│   │   ├── llm_adapter.dart  # LLM adapter interface
│   │   ├── qwen_adapter.dart # Qwen model adapter
│   │   ├── providers/        # LLM provider implementations
│   │   └── prompt_templates.dart
│   ├── memory/               # Memory integration
│   │   ├── mcp_memory_service.dart
│   │   ├── memory_index_service.dart
│   │   └── summary_service.dart
│   ├── services/            # Chat services
│   ├── ui/                   # Chat UI
│   ├── voice/                # Voice chat
│   │   ├── voice_chat_service.dart
│   │   ├── push_to_talk_controller.dart
│   │   └── voice_orchestrator.dart
│   └── veil_edge/            # Privacy edge
├── arcform/                  # 3D visualization
│   ├── layouts/              # Layout definitions
│   ├── render/               # Rendering engine
│   │   ├── arcform_renderer_3d.dart
│   │   ├── nebula.dart
│   │   └── color_map.dart
│   ├── services/             # ARCForm services
│   └── share/                # Sharing functionality
├── core/                     # Journal core
│   ├── journal_capture_cubit.dart
│   ├── journal_repository.dart
│   ├── keyword_extraction_cubit.dart
│   └── sage_echo_panel.dart
├── ui/                       # ARC UI components
│   ├── journal_capture_view.dart
│   ├── timeline/             # Timeline views
│   └── arcforms/             # ARCForm UI
└── privacy/                  # Privacy protection
```

### Key Components

**Chat (LUMARA)**
- `main_chat_manager.dart` - Main chat orchestration
- `lumara_core.dart` - Core LUMARA functionality
- LLM providers: Qwen, Ollama, Rule-based, Native
- Voice chat with push-to-talk
- Memory integration via MCP
- **Favorites System**: Three-category favorites (Answers, Saved Chats, Favorite Entries)
  - Answers: Style examples for LUMARA responses (25 limit)
  - Saved Chats: Entire chat sessions saved for reference (20 limit)
  - Favorite Entries: Journal entries marked for quick access (20 limit)
  - Integrated into PRISM activity and control state for modulation
  - ARCX export/import support with category tracking

**ARCForm**
- 3D visualization with nebula effects
- Phase-aware layouts
- Constellation service for pattern visualization
- Share/export functionality

**Journal Core**
- `JournalCaptureCubit` - State management for journal entries
- `JournalRepository` - Data access layer
- `KeywordExtractionCubit` - Keyword processing
- SAGE Echo panel for AI annotations

---

## 2. PRISM Module (`lib/prism/`)

### Purpose
Content analysis, phase detection, and risk assessment.

### Directory Structure

```
prism/
├── prism_module.dart
├── atlas/                    # Phase detection & risk systems
│   ├── phase/                # Phase tracking
│   │   ├── phase_tracker.dart
│   │   ├── phase_scoring.dart
│   │   ├── phase_history_repository.dart
│   │   └── pattern_analysis_service.dart
│   ├── rivet/                # Risk-Validation Evidence Tracker
│   │   ├── rivet_service.dart
│   │   ├── rivet_models.dart
│   │   └── rivet_reducer.dart
│   └── sentinel/             # Risk monitoring
│       └── sentinel_risk_detector.dart
├── extractors/               # Content extraction
│   ├── enhanced_keyword_extractor.dart
│   ├── emotion_extractor.dart
│   ├── context_extractor.dart
│   └── metadata_extractor.dart
├── processors/               # Multimodal processing
│   ├── text_processor.dart
│   ├── image_processor.dart
│   ├── audio_processor.dart
│   ├── video_processor.dart
│   ├── analysis/             # Analysis services
│   │   ├── vision_analysis_service.dart
│   │   ├── audio_transcribe_service.dart
│   │   └── video_keyframe_service.dart
│   └── storage/              # Storage services
│       └── enhanced_cas_store.dart
├── privacy/                  # Privacy protection
│   ├── audio_content_scrubber.dart
│   ├── visual_content_masker.dart
│   └── media_pii_detector.dart
├── vital/                    # Health data
│   ├── healthkit_bridge_ios.dart
│   ├── healthconnect_bridge_android.dart
│   └── prism_vital.dart
└── engines/                  # Processing engines
    └── atlas_engine.dart
```

### Key Components

**ATLAS Phase System**
- `PhaseTracker` - Core phase detection with EMA smoothing
- `PhaseScoring` - Phase scoring algorithms
- `PhaseHistoryRepository` - Phase history storage
- Hysteresis and cooldown to prevent oscillation

**RIVET (Risk-Validation Evidence Tracker)**
- `RivetService` - Evidence validation
- ALIGN/TRACE metrics
- Gating for phase transitions

**SENTINEL**
- `SentinelRiskDetector` - Risk pattern detection
- Severity evaluation
- Negative trend identification

**Extractors**
- Keyword extraction with co-occurrence analysis
- Emotion detection
- Context extraction
- Metadata extraction

**Processors**
- Text processing
- Image processing (iOS Vision Framework)
- Audio transcription
- Video keyframe extraction

---

## 3. MIRA Module (`lib/mira/`)

### Purpose
Memory storage, encryption, and data container management.

### Directory Structure

```
mira/
├── mira_service.dart          # Main service entry point
├── mira_integration.dart      # Integration layer
├── core/                      # Core memory graph
│   ├── schema.dart            # Schema definitions
│   ├── schema_v2.dart         # V2 schema
│   ├── mira_repo.dart         # Repository interface
│   ├── hive_repo.dart         # Hive implementation
│   ├── sqlite_repo.dart       # SQLite implementation
│   └── migrations.dart        # Migration service
├── store/
│   ├── mcp/                   # Memory Container Protocol
│   │   ├── bundle/            # Bundle creation/reading
│   │   │   ├── writer.dart
│   │   │   ├── reader.dart
│   │   │   └── manifest.dart
│   │   ├── export/            # Export services
│   │   │   ├── mcp_export_service.dart
│   │   │   └── enhanced_mcp_export_service.dart
│   │   ├── import/            # Import services
│   │   │   ├── mcp_import_service.dart
│   │   │   └── enhanced_mcp_import_service.dart
│   │   ├── orchestrator/      # Complex operations
│   │   ├── adapters/          # Format adapters
│   │   └── models/            # MCP models
│   └── arcx/                  # ARCX encryption
│       ├── services/
│       │   ├── arcx_crypto_service.dart
│       │   ├── arcx_export_service.dart
│       │   └── arcx_import_service.dart
│       └── models/
│           └── arcx_manifest.dart
├── memory/                    # Memory services
│   ├── enhanced_mira_memory_service.dart
│   ├── attribution_service.dart
│   ├── conflict_resolution_service.dart
│   ├── conversation_context_service.dart
│   └── lifecycle_management_service.dart
├── retrieval/                 # Vector search
│   └── retrieval_engine.dart
├── graph/                     # Graph construction
│   └── chat_graph_builder.dart
├── nodes/                     # Node types
│   ├── chat_message_node.dart
│   └── chat_session_node.dart
└── edges/                     # Edge types
    └── contains_edge.dart
```

### Key Components

**MIRA Service**
- Main entry point for memory operations
- Unified API for storage, retrieval, export/import
- Supports Hive and SQLite backends

**MCP (Memory Container Protocol)**
- Bundle creation and reading
- Export/import services
- Manifest management
- Media pack handling
- Orchestrator for complex operations

**ARCX Encryption**
- AES-256-GCM encryption
- Ed25519 signing
- Export/import with migration
- Crypto service for key management

**Memory Services**
- Enhanced memory service with semantic search
- Attribution service for memory sources
- Conflict resolution
- Conversation context management
- Lifecycle management

---

## 4. AURORA Module (`lib/aurora/`)

### Purpose
Scheduled job orchestration and circadian rhythm management.

### Directory Structure

```
aurora/
├── aurora_module.dart
├── regimens/
│   └── veil/                  # VEIL restorative jobs
│       └── veil_module.dart
├── services/
│   └── circadian_profile_service.dart
└── models/
    └── circadian_context.dart
```

### Key Components

**Circadian Profile Service**
- Circadian rhythm awareness
- Time-based job scheduling
- Context-aware task management

**VEIL Regimens**
- Restorative job cycles
- Background task management
- Scheduled maintenance

**Scheduled Jobs**
- `prism_batch_refresh` - PRISM batch analysis
- `polymeta_compaction` - Memory graph compaction
- `encryption_key_rotation` - Key rotation
- `context_refresh` - Context update cycles

---

## 5. ECHO Module (`lib/echo/`)

### Purpose
LLM interface, guardrails, and privacy filtering.

### Directory Structure

```
echo/
├── echo_module.dart
├── echo_service.dart
├── providers/                 # LLM providers
│   ├── llm/
│   │   ├── qwen_adapter.dart
│   │   ├── ollama_adapter.dart
│   │   ├── llama_adapter.dart
│   │   ├── rule_based_adapter.dart
│   │   └── lumara_native.dart
│   └── llm_client.dart
├── privacy_core/              # Privacy utilities
│   ├── pii_detection_service.dart
│   ├── pii_masking_service.dart
│   ├── privacy_guardrail_interceptor.dart
│   └── privacy_settings_service.dart
├── safety/                    # Content safety
│   ├── chat_rivet_lite.dart
│   └── rivet_lite_validator.dart
├── response/                   # Response management
│   ├── lumara_assistant_cubit.dart
│   └── prompts/
│       ├── lumara_system_prompt.dart
│       └── prompt_library.dart
├── core/                      # Core integrations
│   ├── atlas_phase_integration.dart
│   └── mira_memory_grounding.dart
├── config/
│   └── echo_config.dart
└── rhythms/
    └── veil_aurora_scheduler.dart
```

### Key Components

**LLM Providers**
- Qwen adapter (on-device)
- Ollama adapter
- Llama adapter
- Rule-based adapter (fallback)
- Native Lumara integration

**Privacy Core**
- PII detection service
- PII masking service
- Privacy guardrail interceptor
- Privacy settings management

**Safety**
- RIVET Lite for chat safety
- Content validation
- Dignity-preserving responses

**Response Management**
- Lumara assistant (Cubit-based state)
- Prompt library
- System prompt templates

---

## Supporting Infrastructure

### Core (`lib/core/`)

```
core/
├── app_flags.dart             # Application flags
├── feature_flags.dart         # Feature flags
├── prompts_arc.dart           # ARC prompts
├── arc_llm.dart              # LLM bridge
├── bridges/                  # Platform bridges
├── llm/                      # LLM utilities
├── mira/                     # MIRA integration
├── services/                 # Core services
│   ├── analytics_service.dart
│   ├── sync_service.dart
│   └── ...
└── utils/                    # Utilities
```

### Services (`lib/services/`)

Key services:
- `phase_detector_service.dart` - Phase detection
- `phase_regime_service.dart` - Phase regime management
- `phase_aware_analysis_service.dart` - Phase-aware analysis
- `arcform_service.dart` - ARCForm processing
- `rivet_sweep_service.dart` - RIVET operations
- `llm_bridge_adapter.dart` - LLM bridge adapter
- `media_resolver_service.dart` - Media resolution
- `keyword_analysis_service.dart` - Keyword analysis

### Models (`lib/models/`)

- `journal_entry_model.dart` - Journal entry data model
- `arcform_snapshot_model.dart` - ARCForm snapshot model
- `phase_models.dart` - Phase data models
- `user_profile_model.dart` - User profile model

### UI (`lib/ui/`)

- `journal/` - Journal screens and widgets
- `phase/` - Phase analysis views
- `export_import/` - Export/import screens
- `settings/` - Settings screens
- `widgets/` - Shared widgets

### Data (`lib/data/`)

- `hive/` - Hive storage adapters
- `migrations/` - Data migrations
- `models/` - Data layer models

---

## Module Dependencies

```
ARC
  ├── depends on: PRISM (for analysis)
  ├── depends on: MIRA (for storage)
  ├── depends on: ECHO (for LLM)
  └── depends on: AURORA (for scheduling)

PRISM
  ├── depends on: MIRA (for storage)
  └── depends on: ECHO (for safety)

MIRA
  └── (standalone, no dependencies)

AURORA
  ├── depends on: PRISM (for batch jobs)
  └── depends on: MIRA (for compaction)

ECHO
  ├── depends on: MIRA (for memory grounding)
  └── depends on: PRISM (for phase integration)
```

---

## Key Design Patterns

1. **Repository Pattern** - Used throughout for data access
2. **Cubit/Bloc Pattern** - State management (flutter_bloc)
3. **Adapter Pattern** - LLM providers, storage backends
4. **Service Pattern** - Business logic encapsulation
5. **Module Pattern** - Clear module boundaries with exports

---

## Technology Stack

- **Framework:** Flutter (Dart 3.0.3+)
- **State Management:** flutter_bloc
- **Storage:** Hive, SQLite
- **LLM:** On-device (Qwen via llama.cpp/MLC LLM)
- **Encryption:** AES-256-GCM, Ed25519
- **Health:** HealthKit (iOS), Health Connect (Android)
- **Vision:** iOS Vision Framework (native)

---

## Navigation Tips

1. **Module Entry Points:** Each module has a `*_module.dart` file
2. **Service Entry Points:** Look for `*_service.dart` files
3. **State Management:** Cubits in `*_cubit.dart` files
4. **Models:** Data models in `models/` subdirectories
5. **UI:** UI components in `ui/` subdirectories

---

**For high-level architecture overview, see [ARCHITECTURE_OVERVIEW.md](./ARCHITECTURE_OVERVIEW.md)**

