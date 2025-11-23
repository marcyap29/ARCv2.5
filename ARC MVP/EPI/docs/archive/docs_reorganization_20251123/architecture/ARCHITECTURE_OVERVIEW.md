# EPI Architecture Overview

**Version:** 2.1.2  
**Last Updated:** January 2025  
**Status:** ✅ Production Ready

---

## Executive Summary

EPI (Evolving Personal Intelligence) is a 5-module intelligent journaling system that consolidates perception, memory, orchestration, and safety into a cohesive architecture. The system has been refactored from 8+ separate modules into 5 clean, deployable modules with clear boundaries and responsibilities.

---

## 5-Module Architecture

### 1. ARC - Core Journaling Interface
**Location:** `lib/arc/`  
**Purpose:** Primary user experience for journaling, chat, and visualization

**Submodules:**
- `chat/` - LUMARA conversational AI (formerly separate module)
- `arcform/` - 3D visualization and analysis forms (formerly separate module)
- `core/` - Journal entry processing and state management
- `ui/` - Journaling interface components
- `privacy/` - Real-time PII protection

**Key Features:**
- Journal entry capture and editing
- **Automatic Phase Hashtag System**: Entries automatically receive phase hashtags based on Phase Regimes (date-based), eliminating need for manual tagging
- LUMARA chat interface (maintains LUMARA branding)
  - Favorites system for style adaptation (up to 25 favorites)
  - Style exemplars guide tone, structure, rhythm, and depth
- ARCForm visualization with phase-aware layouts
- Privacy-first data handling
- Dynamic timeline chrome that collapses navigation and resurfaced phase legend only when ARCForm Timeline is expanded, keeping the journal canvas distraction-free while still surfacing phase context on demand.

---

### 2. PRISM - Multimodal Perception & Analysis
**Location:** `lib/prism/`  
**Purpose:** Content analysis, phase detection, and risk assessment

**Submodules:**
- `atlas/` - Phase detection, RIVET, SENTINEL (consolidated from separate modules)
  - `phase/` - Phase detection with EMA smoothing and hysteresis
  - `rivet/` - Risk-Validation Evidence Tracker (ALIGN/TRACE metrics)
  - `sentinel/` - Severity evaluation and negative trend identification
- `extractors/` - Keyword, emotion, context, metadata extraction
- `processors/` - Text, image, audio, video processing
- `privacy/` - Multi-modal PII detection and masking
- `vital/` - Health data integration

**Key Features:**
- Multi-modal content analysis (OCR, object detection, transcription)
- **Phase Regime System**: Time-bounded phase periods with start/end dates that determine phase hashtags for entries
- Phase detection with cooldown and hysteresis to prevent oscillation
- RIVET gating for phase transitions (evidence validation)
- SENTINEL risk monitoring (escalating pattern detection)
- **Phase Hashtag Management**: Automatic hashtag assignment based on entry dates falling within phase regimes

---

### 3. MIRA - Memory Graph & Secure Store
**Location:** `lib/mira/`  
**Purpose:** Memory storage, encryption, and data container management

**Submodules:**
- `store/mcp/` - Memory Container Protocol (formerly separate modules)
- `store/arcx/` - ARCX encryption and export (formerly separate module)
- `core/` - Memory graph core services
- `graph/` - Memory graph construction
- `memory/` - Memory storage and retrieval
- `retrieval/` - Vector search and retrieval

**Key Features:**
- Unified memory graph
- MCP-compliant storage format
- ARCX encryption (AES-256-GCM + Ed25519 signing)
- Vector search and semantic retrieval
- Export/import with format conversion

**Unified API:**
```dart
mira.put(event)                              // Store event
mira.query(vector, k: 10)                    // Vector search
mira.export(format: 'mcp', envelope: 'arcx') // Export
mira.import(file)                            // Import
```

---

### 4. AURORA - Circadian Orchestration
**Location:** `lib/aurora/`  
**Purpose:** Scheduled job orchestration and circadian rhythm management

**Submodules:**
- `regimens/veil/` - VEIL restorative jobs (formerly separate module)
- `services/` - AURORA scheduling services
- `models/` - Circadian context models

**Key Features:**
- Scheduled job orchestration
- Circadian rhythm awareness
- VEIL restoration cycles
- Background task management

**Scheduled Jobs:**
- `prism_batch_refresh` - PRISM batch analysis
- `polymeta_compaction` - Memory graph compaction
- `encryption_key_rotation` - Key rotation
- `context_refresh` - Context update cycles

---

### 5. ECHO - Response Control & Safety
**Location:** `lib/echo/`  
**Purpose:** LLM interface, guardrails, and privacy filtering

**Submodules:**
- `privacy_core/` - Privacy utilities (formerly separate module)
- `providers/` - LLM providers (Rule-based, Llama, Ollama, OpenAI, Mistral)
- `safety/` - Content safety and filtering
- `config/` - ECHO configuration management
- `rhythms/` - VEIL/AURORA scheduler integration

**Key Features:**
- LLM provider abstraction
- Privacy guardrails (PII detection and masking)
- Content safety filtering
- Dignity-preserving responses
- RIVET Lite for chat safety

**Unified Privacy API:**
```dart
echo.guard(output)              // Apply guardrails
echo.privacy.mask(input)        // Mask PII
echo.privacy.detect(input)      // Detect PII
```

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EPI Platform                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐         │
│  │   ARC    │──────▶│  PRISM   │──────▶│   MIRA   │         │
│  │          │      │          │      │          │         │
│  │ Journal  │      │ Analysis │      │ Memory   │         │
│  │ Chat     │      │ ATLAS    │      │ Store    │         │
│  │ Arcform  │      │          │      │ MCP/ARCX │         │
│  └────┬─────┘      └────┬─────┘      └────┬─────┘         │
│       │                 │                 │               │
│       └─────────────────┼─────────────────┘               │
│                         │                                 │
│                   ┌─────▼─────┐                           │
│                   │   ECHO    │                           │
│                   │           │                           │
│                   │ Guard     │                           │
│                   │ Privacy   │                           │
│                   │ LLM      │                           │
│                   └─────┬─────┘                           │
│                         │                                 │
│                   ┌─────▼─────┐                           │
│                   │  AURORA   │                           │
│                   │           │                           │
│                   │ Jobs      │                           │
│                   │ VEIL      │                           │
│                   │ Schedule  │                           │
│                   └───────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Module Relationships

```
ARC  ─►  PRISM.atlas  ─►  MIRA.store
 ↑           │                │
 │           └── ECHO.guard   │
 └─────── AURORA.regimens ────┘
```

**Data Flow:**
1. User creates journal entry in **ARC**
2. **PRISM** processes and analyzes content (ATLAS detects phases)
3. **MIRA** stores encrypted memories (MCP/ARCX format)
4. **ECHO** provides guardrails and privacy filtering
5. **AURORA** orchestrates scheduled jobs (VEIL restoration cycles)

---

## Key Architectural Decisions

### Consolidation Rationale
- **Reduced Complexity:** From 8+ modules to 5 clear modules
- **Improved Cohesion:** Related functionality grouped together
- **Clear Boundaries:** Each module has distinct responsibilities
- **Maintained Functionality:** All features preserved during consolidation

### Module Independence
- Each module can be developed and tested independently
- Clear interfaces between modules
- Minimal inter-module dependencies
- Shared infrastructure in `lib/core/`

### Privacy & Security
- Privacy-first design throughout
- AES-256-GCM encryption for sensitive data
- Ed25519 signing for data integrity
- PII detection and masking at multiple layers

### January 2025 UI/UX & Timeline Linkage
- **Unified Navigation Surface**: The floating journal action was migrated into the bottom tab bar, centering the + button above Journal | LUMARA | Insights so core actions sit within the navigation chrome instead of floating.
- **Action Button Consistency**: Both in-journal and in-chat LUMARA bubbles now expose the same toolbar (Regenerate, Soften tone, More depth, Continue thought, Explore conversation), aligning the experience between interfaces and simplifying the architecture.
- **Timeline-Date Connection**: The calendar week timeline synchronizes directly with the visible entries (scroll to entry highlights the matching week and scrolling updates the week tiles), ensuring the timeline and journal data layers are tightly coupled within the ARC module while still respecting the layered architecture.

---

## Migration History

### Completed (November 4, 2025)
- ✅ PRISM.ATLAS migration (phase, RIVET, SENTINEL unified)
- ✅ ARC consolidation (LUMARA + ARCFORM merged)
- ✅ MIRA unification (MCP + ARCX merged)
- ✅ VEIL regimen (moved to AURORA)
- ✅ Privacy merge (moved to ECHO)
- ✅ Import path updates across codebase
- ✅ Comprehensive documentation and code comments

### Deprecated Modules
The following modules have been consolidated and are deprecated:
- ❌ ATLAS → Now `prism/atlas/`
- ❌ LUMARA → Now `arc/chat/`
- ❌ ARCFORM → Now `arc/arcform/`
- ❌ MIRA → Now `mira/` (renamed to MIRA)
- ❌ MCP → Now `mira/store/mcp/`
- ❌ ARCX → Now `mira/store/arcx/`
- ❌ VEIL → Now `aurora/regimens/veil/`
- ❌ Privacy Core → Now `echo/privacy_core/`

---

## Documentation Structure

- **Architecture Files:**
  - `EPI_Consolidated_Architecture.md` - Complete architecture specification
  - `ARCHITECTURE_OVERVIEW.md` - This file (high-level overview)
  - `MODULE_REFERENCE.md` - Detailed module and component reference guide
  - `Migration_Status.md` - Migration completion status

- **Module Documentation:**
  - Each module has inline documentation in key files
  - Algorithm explanations in PhaseTracker and RivetService
  - Data flow diagrams in service classes
  - Usage examples in module entry points

---

## Next Steps

1. **Testing:** Comprehensive test suite for all modules
2. **Performance:** Optimize memory usage and processing speed
3. **Features:** Continue feature development within new structure
4. **Cleanup:** Remove deprecated directories after verification period

---

**For detailed module specifications, see:**
- [EPI_Consolidated_Architecture.md](./EPI_Consolidated_Architecture.md) - Complete architecture specification
- [MODULE_REFERENCE.md](./MODULE_REFERENCE.md) - Detailed module and component reference guide

