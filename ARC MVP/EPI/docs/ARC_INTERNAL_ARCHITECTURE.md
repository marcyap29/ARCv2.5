# ARC Internal Architecture

**Version:** 2.1.61  
**Last Updated:** December 19, 2025

---

## Overview

ARC (the core journaling program) internally mirrors the same 5-module architecture as EPI at a high level. While ARC uses the external PRISM, MIRA, AURORA, and ECHO modules, it also has its own internal components that correspond to these architectural patterns.

---

## ARC's Internal 5-Module Architecture

### Internal Module Mapping

```
ARC (Program)
  ├── PRISM (Internal) - Analysis of text and media
  ├── MIRA (Internal) - Memory and security of files
  ├── AURORA (Internal) - Handles time when user is active
  └── ECHO (Internal) - Provides PII and security
```

---

## 1. PRISM (Internal) - Text & Media Analysis

**Location**: `lib/arc/internal/prism/`

**Purpose**: Analysis of text and media within ARC

**Components**:
- `theme_analysis_service.dart` - Longitudinal theme tracking and analysis
- `keyword_extraction_service.dart` - Keyword extraction from journal entries (copied from core)
- `media/media_capture_sheet.dart` - Media processing and analysis
- `media/media_preview_dialog.dart` - Media preview functionality
- `media/media_strip.dart` - Media strip display
- `media/ocr_service.dart` - OCR text extraction from images

**Responsibilities**:
- Analyze journal entry text for themes, keywords, and patterns
- Process media (photos, videos) for OCR and content extraction
- Extract metadata from media items
- Build semantic context from entries for LUMARA
- Track longitudinal themes across entries

**Integration**:
- Uses external `lib/prism/` for phase detection and RIVET calculations
- Uses external `lib/prism/atlas/` for ATLAS analysis
- Provides ARC-specific analysis services on top of PRISM foundation

---

## 2. MIRA (Internal) - Memory & File Security

**Location**: `lib/arc/internal/mira/`

**Purpose**: Memory management and file security within ARC

**Components**:
- `memory_loader.dart` - Progressive memory loading for LUMARA (moved from `chat/services/progressive_memory_loader.dart`)
- `reflective_storage.dart` - Storage of reflective nodes (moved from `chat/services/reflective_node_storage.dart`)
- `semantic_matching.dart` - Semantic memory matching (moved from `chat/services/semantic_similarity_service.dart`)
- `journal_repository.dart` - Secure journal entry storage (moved from `core/journal_repository.dart`)
- `version_service.dart` - Version management for entries (moved from `core/services/journal_version_service.dart`)
- `memory/` - Memory-related services (moved from `chat/memory/`)
  - `mcp_memory_service.dart` - MCP memory service
  - `memory_index_service.dart` - Memory indexing
  - `pii_redaction_service.dart` - PII redaction for memory
  - `summary_service.dart` - Memory summarization

**Responsibilities**:
- Manage LUMARA's conversational memory across sessions
- Store and retrieve reflective nodes for context
- Handle semantic similarity matching for memory retrieval
- Secure storage of journal entries and media
- Version control for journal entries
- Memory attribution and tracing

**Integration**:
- Uses external `lib/mira/` for core memory graph structure
- Uses external `lib/mira/store/` for ARCX and MCP storage
- Provides ARC-specific memory services for LUMARA chat

---

## 3. AURORA (Internal) - Time & User Activity

**Location**: `lib/arc/internal/aurora/`

**Purpose**: Handles time-based user activity patterns

**Components**:
- `active_window_detector.dart` - Detects user's active reflection windows (moved from `chat/services/`)
- `sleep_protection_service.dart` - Manages sleep/abstinence windows (moved from `chat/services/`)
- `notification_service.dart` - Time Echo and Active Window reminders (moved from `chat/services/lumara_notification_service.dart`)
- `memory_notification_service.dart` - Memory-based notifications (moved from `chat/services/memory_notification_service.dart`)

**Responsibilities**:
- Detect when user is most active (active window detection)
- Manage sleep/abstinence windows to avoid notifications
- Schedule Time Echo reminders based on user patterns
- Track circadian patterns for optimal engagement
- Coordinate with external AURORA for circadian context

**Integration**:
- Uses external `lib/aurora/` for circadian profile service
- Uses external `lib/aurora/services/circadian_profile_service.dart` for rhythm analysis
- Provides ARC-specific time-based services for notifications and engagement

---

## 4. ECHO (Internal) - PII & Security

**Location**: `lib/arc/internal/echo/`

**Purpose**: Provides PII protection and security within ARC

**Components**:
- `prism_adapter.dart` - PRISM adapter for voice journal (moved from `chat/voice/voice_journal/`)
- `correlation_resistant_transformer.dart` - Correlation-resistant PII protection (moved from `chat/voice/voice_journal/`)
- `voice_pipeline.dart` - Secure voice processing pipeline (moved from `chat/voice/voice_journal/voice_journal_pipeline.dart`)
- `privacy_redactor.dart` - Privacy redaction for chat (moved from `chat/chat/privacy_redactor.dart`)

**Responsibilities**:
- Real-time PII detection and masking in journal entries
- Correlation-resistant transformation for voice journal
- Secure voice processing pipeline
- Privacy redaction in chat messages
- Local-only PII mapping (never transmitted)
- Security validation before external API calls

**Integration**:
- Uses external `lib/echo/privacy_core/` for PII detection and masking
- Uses external `lib/services/lumara/pii_scrub.dart` for PRISM scrubbing
- Provides ARC-specific privacy services for journaling and chat

---

## Data Flow Within ARC

```
User Input (Journal Entry/Media)
  ↓
ECHO (Internal) - PII Detection & Masking
  ↓
PRISM (Internal) - Text/Media Analysis
  ↓
MIRA (Internal) - Memory Storage & Retrieval
  ↓
AURORA (Internal) - Time-Based Processing
  ↓
LUMARA Response / Visualization
```

---

## Integration with External Modules

ARC's internal architecture mirrors the external EPI modules but provides ARC-specific implementations:

| Internal Module | External Module | Relationship |
|----------------|-----------------|--------------|
| PRISM (Internal) | `lib/prism/` | Uses external for phase/RIVET, provides ARC-specific analysis |
| MIRA (Internal) | `lib/mira/` | Uses external for memory graph, provides ARC-specific memory services |
| AURORA (Internal) | `lib/aurora/` | Uses external for circadian profiles, provides ARC-specific time services |
| ECHO (Internal) | `lib/echo/` | Uses external for PII detection, provides ARC-specific privacy services |

---

## Key Design Principles

1. **Separation of Concerns**: Each internal module has clear responsibilities
2. **Layered Architecture**: Internal modules build on external module foundations
3. **Privacy First**: ECHO (Internal) ensures all data is protected before processing
4. **Time Awareness**: AURORA (Internal) optimizes engagement based on user patterns
5. **Memory Continuity**: MIRA (Internal) maintains context across sessions

---

## Implementation Notes

- Internal modules are located within `lib/arc/internal/` directory structure
- They provide ARC-specific services while leveraging external module capabilities
- The architecture allows ARC to be self-contained while benefiting from shared EPI infrastructure
- Internal modules can evolve independently while maintaining compatibility with external modules
- **Backward Compatibility**: Re-exports in old locations ensure existing imports continue to work
- **Barrel Exports**: Each module has a barrel export file (`*_internal.dart`) for convenient importing
- **Gradual Migration**: Files can be updated to use new paths incrementally without breaking existing code
