# EPI Consolidated Architecture

**Version:** 2.0  
**Last Updated:** January 2025  
**Status:** Target Architecture (Migration In Progress)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Module Specifications](#module-specifications)
4. [Migration Plan](#migration-plan)
5. [Data Flow & Integration](#data-flow--integration)
6. [API Specifications](#api-specifications)
7. [Testing & Verification](#testing--verification)
8. [Deprecation Timeline](#deprecation-timeline)

---

## Executive Summary

### Objective

Unify the EPI codebase by merging redundant modules, correcting directory mismatches, and aligning implementation reality with architectural intent. Reduce 8+ core modules to 5 clean deployables with clear submodule hierarchies.

### Current State (January 2025 - Migration In Progress)

**Status:** The migration is **partially complete**. New module structures have been created in target locations, but old modules remain and `epi_module.dart` still exports deprecated paths. The codebase is in a **transitional state**.

**New Structures Created:**
- ✅ `lib/prism/atlas/` - ATLAS unified under PRISM
- ✅ `lib/arc/chat/` - LUMARA moved to ARC
- ✅ `lib/arc/arcform/` - ARCFORM moved to ARC
- ✅ `lib/polymeta/store/mcp/` - MCP moved to POLYMETA
- ✅ `lib/polymeta/store/arcx/` - ARCX moved to POLYMETA
- ✅ `lib/aurora/regimens/veil/` - VEIL moved to AURORA
- ✅ `lib/echo/privacy_core/` - Privacy Core moved to ECHO

**Old Structures Still Present:**
- ⚠️ `lib/atlas/` - Still exists (deprecated, has shim)
- ⚠️ `lib/lumara/` - Still exists (duplicate)
- ⚠️ `lib/arcform/` - Still exists (duplicate)
- ⚠️ `lib/mira/` - Still exists (may be duplicate of polymeta)
- ⚠️ `lib/mcp/` - Still exists (should be in polymeta/store/mcp/)
- ⚠️ `lib/arcx/` - Still exists (should be in polymeta/store/arcx/)
- ⚠️ `lib/veil/` - Still exists (duplicate)
- ⚠️ `lib/privacy_core/` - Still exists (duplicate)

**Module Export Status:**
- `lib/epi_module.dart` still exports old paths (atlas, mira, veil, privacy_core)
- Needs update to reflect consolidated architecture

**See [Migration_Status.md](./Migration_Status.md) for detailed migration progress.**

### Target State (Post-Migration)

**Five consolidated modules:**
1. **ARC** - Journaling app & main UX (includes LUMARA + ARCFORM)
2. **PRISM** - Multimodal perception & analysis (includes ATLAS)
3. **POLYMETA** - Memory graph, recall, encryption, data container (includes MIRA + MCP + ARCX)
4. **AURORA** - Circadian orchestration & job scheduling (includes VEIL)
5. **ECHO** - Response control, LLM interface, safety & privacy (includes Privacy Core)

---

## Architecture Overview

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         EPI Platform                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐ │
│  │     ARC      │──────▶│    PRISM     │──────▶│  POLYMETA    │ │
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

### Module Relationships

```
ARC  ─►  PRISM.atlas  ─►  POLYMETA.store
 ↑           │                │
 │           └── ECHO.guard   │
 └─────── AURORA.regimens ────┘
```

**Data Flow:**
1. User creates journal entry in **ARC**
2. **PRISM** processes and analyzes content (ATLAS detects phases)
3. **POLYMETA** stores encrypted memories (MCP/ARCX format)
4. **ECHO** provides guardrails and privacy filtering
5. **AURORA** orchestrates scheduled jobs (VEIL restoration cycles)

---

## Module Specifications

### 1. ARC Module (`lib/arc/`)

**Purpose:** Core journaling app & main user experience

**Submodules:**
- `chat/` - LUMARA conversational AI (moved from `lib/lumara/`)
- `arcform/` - Visualization and analysis forms (moved from `lib/arcform/`)
- `privacy/` - Real-time PII protection for journaling
- `core/` - Journal entry processing and state management
- `ui/` - Journaling interface components
- `repository/` - Journal data access layer
- `services/` - ARC-specific services

**Key Features:**
- Journal entry capture and editing
- LUMARA chat interface (retains LUMARA branding)
- ARCForm visualization and timeline
- Privacy-first data handling

**Migration Notes:**
- `lib/lumara/` → `lib/arc/chat/`
- `lib/arcform/` → `lib/arc/arcform/`
- Update imports: `package:lumara/...` → `package:arc/chat/...`
- Update imports: `package:arcform/...` → `package:arc/arcform/...`

**Directory Structure:**
```
lib/arc/
├── arc_module.dart
├── chat/                    # LUMARA (formerly lib/lumara/)
│   ├── chat/
│   ├── llm/
│   ├── memory/
│   ├── services/
│   └── ui/
├── arcform/                 # ARCFORM (formerly lib/arcform/)
│   ├── layouts/
│   ├── render/
│   ├── services/
│   └── models/
├── privacy/
├── core/
├── ui/
├── repository/
└── services/
```

---

### 2. PRISM Module (`lib/prism/`)

**Purpose:** Multimodal perception & analysis

**Submodules:**
- `atlas/` - Phase detection, RIVET, SENTINEL (moved from `lib/atlas/`)
  - `phase/` - Phase detection and readiness scoring
  - `rivet/` - Risk-Validation Evidence Tracker
  - `sentinel/` - Risk detection and monitoring
- `extractors/` - Keyword, emotion, context, metadata extraction
- `processors/` - Text, image, audio, video processing
- `privacy/` - Multi-modal PII detection and masking
- `vital/` - Health data integration
- `models/` - PRISM data models
- `services/` - PRISM services

**Key Features:**
- Multi-modal content analysis
- Phase detection and lifecycle tracking
- Risk assessment (RIVET + SENTINEL)
- Health data integration
- Privacy-aware processing

**Migration Notes:**
- `lib/atlas/` → `lib/prism/atlas/`
- `lib/prism/extractors/sentinel_risk_detector.dart` → `lib/prism/atlas/sentinel/sentinel_risk_detector.dart`
- Update imports: `package:atlas/...` → `package:prism/atlas/index.dart`
- Create unified API export: `lib/prism/atlas/index.dart`

**Directory Structure:**
```
lib/prism/
├── prism_module.dart
├── atlas/                   # ATLAS (formerly lib/atlas/)
│   ├── phase/
│   │   ├── phase_detector.dart
│   │   ├── readiness_scorer.dart
│   │   └── models.dart
│   ├── rivet/
│   │   ├── rivet_service.dart
│   │   ├── rivet_provider.dart
│   │   ├── rivet_storage.dart
│   │   ├── rivet_telemetry.dart
│   │   ├── rivet_reducer.dart
│   │   └── models.dart
│   ├── sentinel/
│   │   ├── sentinel_risk_detector.dart
│   │   └── models.dart
│   └── index.dart          # Unified API export
├── extractors/
├── processors/
│   ├── crypto/
│   ├── analysis/
│   ├── import/
│   └── settings/
├── privacy/
├── vital/
├── models/
└── services/
```

**Unified Atlas API (`lib/prism/atlas/index.dart`):**
```dart
// Unified export for all ATLAS functionality
export 'phase/phase_detector.dart';
export 'phase/readiness_scorer.dart';
export 'phase/models.dart';
export 'rivet/rivet_service.dart';
export 'rivet/rivet_provider.dart';
export 'rivet/rivet_storage.dart';
export 'rivet/rivet_telemetry.dart';
export 'rivet/rivet_reducer.dart';
export 'rivet/models.dart';
export 'sentinel/sentinel_risk_detector.dart';
export 'sentinel/models.dart';
```

---

### 3. POLYMETA Module (`lib/polymeta/`)

**Purpose:** Memory graph, recall, encryption, and data container

**Submodules:**
- `store/mcp/` - Memory Container Protocol (moved from `lib/mcp/` and `lib/core/mcp/`)
- `store/arcx/` - ARCX encryption and export (moved from `lib/arcx/`)
- `core/` - Core MIRA services (moved from `lib/mira/core/`)
- `graph/` - Memory graph construction (moved from `lib/mira/graph/`)
- `memory/` - Memory storage and retrieval (moved from `lib/mira/memory/`)
- `retrieval/` - Memory search and retrieval (moved from `lib/mira/retrieval/`)
- `adapters/` - Integration adapters (moved from `lib/mira/adapters/`)
- `nodes/` - Memory node types (moved from `lib/mira/nodes/`)
- `edges/` - Memory edge types (moved from `lib/mira/edges/`)

**Key Features:**
- Unified memory graph (MIRA)
- MCP-compliant storage
- ARCX encryption (AES-256-GCM + Ed25519)
- Vector search and retrieval
- Export/import with format conversion

**Migration Notes:**
- `lib/mira/` → `lib/polymeta/` (rename)
- `lib/mcp/` → `lib/polymeta/store/mcp/`
- `lib/core/mcp/` → `lib/polymeta/store/mcp/` (merge)
- `lib/arcx/` → `lib/polymeta/store/arcx/`
- Update imports: `package:mira/...` → `package:polymeta/...`
- Update imports: `package:mcp/...` → `package:polymeta/store/mcp/...`
- Update imports: `package:arcx/...` → `package:polymeta/store/arcx/...`

**Unified API:**
```dart
// Unified POLYMETA API
polymeta.put(event)                    // Store event
polymeta.query(vector, k)              // Vector search
polymeta.export(format:'mcp', envelope:'arcx')  // Export
polymeta.import(file)                  // Import
polymeta.convert(input:'mcp:zip', output:'mcp+arcx')  // Convert
```

**Directory Structure:**
```
lib/polymeta/
├── polymeta_module.dart
├── store/
│   ├── mcp/                # MCP (formerly lib/mcp/ and lib/core/mcp/)
│   │   ├── schema/
│   │   └── mcp_fs.dart
│   └── arcx/               # ARCX (formerly lib/arcx/)
│       ├── models/
│       ├── services/
│       └── ui/
├── core/                   # MIRA core (formerly lib/mira/core/)
│   ├── events.dart
│   ├── schema.dart
│   ├── schema_v2.dart
│   └── mira_repo.dart
├── graph/                  # MIRA graph (formerly lib/mira/graph/)
├── memory/                 # MIRA memory (formerly lib/mira/memory/)
├── retrieval/              # MIRA retrieval (formerly lib/mira/retrieval/)
├── adapters/               # MIRA adapters (formerly lib/mira/adapters/)
├── nodes/                  # MIRA nodes (formerly lib/mira/nodes/)
└── edges/                  # MIRA edges (formerly lib/mira/edges/)
```

---

### 4. AURORA Module (`lib/aurora/`)

**Purpose:** Circadian orchestration & job scheduling

**Submodules:**
- `regimens/veil/` - VEIL restorative jobs (moved from `lib/veil/`)
- `services/` - AURORA scheduling services
- `models/` - AURORA data models

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

**Migration Notes:**
- `lib/veil/` → `lib/aurora/regimens/veil/`
- Update imports: `package:veil/...` → `package:aurora/regimens/veil/...`
- Define YAML/JSON regimen definitions for scheduled jobs

**Directory Structure:**
```
lib/aurora/
├── aurora_module.dart
├── regimens/
│   └── veil/               # VEIL (formerly lib/veil/)
│       ├── models/
│       └── services/
├── services/
└── models/
```

---

### 5. ECHO Module (`lib/echo/`)

**Purpose:** Response control, LLM interface, safety & privacy

**Submodules:**
- `privacy_core/` - Privacy utilities (moved from `lib/privacy_core/`)
- `providers/` - LLM providers and safety
- `safety/` - Content safety and filtering
- `voice/` - Voice processing safety
- `prompts/` - Safe prompt templates
- `response/` - Response formatting and control
- `core/` - ECHO core services

**Key Features:**
- LLM provider abstraction
- Privacy guardrails
- Content safety filtering
- Dignity-preserving responses

**Unified Privacy API:**
```dart
echo.guard(output)              // Apply guardrails
echo.privacy.mask(input)        // Mask PII
echo.privacy.detect(input)      // Detect PII
```

**Migration Notes:**
- `lib/privacy_core/` → `lib/echo/privacy_core/`
- Update imports: `package:privacy_core/...` → `package:echo/privacy_core/...`
- Expose privacy helpers through ECHO API

**Directory Structure:**
```
lib/echo/
├── echo_module.dart
├── privacy_core/              # Privacy Core (formerly lib/privacy_core/)
│   ├── interfaces/
│   ├── models/
│   ├── pii_detection_service.dart
│   ├── pii_masking_service.dart
│   └── privacy_settings_service.dart
├── providers/
├── safety/
├── voice/
├── prompts/
├── response/
└── core/
```

---

## Migration Plan

**⚠️ IMPORTANT:** The migration is partially complete. See [Migration_Status.md](./Migration_Status.md) for current state.

### Phase 1: PRISM.ATLAS Migration - **PARTIALLY COMPLETE**

**Scope:** Move ATLAS → PRISM; integrate RIVET + SENTINEL

**Status:** ✅ New structure created, deprecation shim in place

**Completed:**
- ✅ `lib/prism/atlas/` directory created
- ✅ `lib/prism/atlas/index.dart` unified export created
- ✅ Phase, RIVET, and SENTINEL moved to new location
- ✅ `lib/atlas/atlas_module.dart` deprecated with re-export shim

**Remaining Tasks:**
1. Verify all imports use `package:prism/atlas/index.dart`
2. Update `lib/epi_module.dart` to remove `atlas/atlas_module.dart` export
3. Delete `lib/atlas/` directory (after confirming no imports)
4. Run tests and verify functionality

**Verification:**
- Golden output tests: Capture ATLAS+RIVET+SENTINEL outputs pre-merge → ensure byte-identical results post-merge
- All phase detection tests pass
- RIVET sweep tests pass
- SENTINEL risk detection tests pass

---

### Phase 2: ARC Consolidation - **PARTIALLY COMPLETE**

**Scope:** Merge LUMARA + ARCFORM into ARC

**Status:** ✅ New structures created, but old modules remain

**Completed:**
- ✅ `lib/arc/chat/` directory created with LUMARA functionality
- ✅ `lib/arc/arcform/` directory created with ARCFORM functionality
- ✅ Code appears to be using new paths

**Remaining Tasks:**
1. Verify all imports use new paths:
   - `package:lumara/...` → `package:arc/chat/...`
   - `package:arcform/...` → `package:arc/arcform/...`
2. Delete `lib/lumara/` directory (after confirming no imports)
3. Delete `lib/arcform/` directory (after confirming no imports)
4. Maintain LUMARA branding in UI components
5. Run tests and verify functionality

**Verification:**
- Chat interface functional
- ARCFORM visualization works
- Journal entries integrate properly
- UI maintains LUMARA branding

---

### Phase 3: POLYMETA Unification - **PARTIALLY COMPLETE**

**Scope:** Merge MIRA + MCP + ARCX

**Status:** ✅ New structure created with store/mcp and store/arcx, but old modules remain

**Completed:**
- ✅ `lib/polymeta/` directory created
- ✅ `lib/polymeta/store/mcp/` - MCP functionality moved
- ✅ `lib/polymeta/store/arcx/` - ARCX functionality moved
- ✅ MIRA core, graph, memory, retrieval moved to polymeta

**Remaining Tasks:**
1. Verify `lib/mira/` and `lib/polymeta/` are identical (check for divergence)
2. Merge any differences between mira and polymeta
3. Update all imports:
   - `package:mira/...` → `package:polymeta/...`
   - `package:mcp/...` → `package:polymeta/store/mcp/...`
   - `package:arcx/...` → `package:polymeta/store/arcx/...`
   - `package:core/mcp/...` → `package:polymeta/store/mcp/...`
4. Update `lib/epi_module.dart` to use `polymeta` instead of `mira`
5. Delete old directories:
   - `lib/mira/` (if identical to polymeta)
   - `lib/mcp/`
   - `lib/arcx/`
   - Merge `lib/core/mcp/` into `polymeta/store/mcp/`
6. Implement unified API (`polymeta.put`, `polymeta.query`, etc.)
7. Run tests and verify functionality

**Verification:**
- Round-trip crypto tests: Validate `POLYMETA.store` can export/import ARCX archives with AES-256-GCM and Ed25519 signature verification
- Memory graph tests pass
- MCP compliance tests pass
- Vector search tests pass

---

### Phase 4: VEIL Regimen - **PARTIALLY COMPLETE**

**Scope:** Move VEIL into AURORA/regimens

**Status:** ✅ New structure created, but old module remains

**Completed:**
- ✅ `lib/aurora/regimens/veil/` directory created
- ✅ `lib/aurora/regimens/veil/veil_module.dart` exists

**Remaining Tasks:**
1. Verify all imports use `package:aurora/regimens/veil/...`
2. Define YAML/JSON regimen definitions for scheduled jobs:
   - `prism_batch_refresh`
   - `polymeta_compaction`
   - `encryption_key_rotation`
   - `context_refresh`
3. Update `lib/epi_module.dart` to remove `veil/veil_module.dart` export
4. Delete `lib/veil/` directory (after confirming no imports)
5. Integrate with AURORA scheduling system
6. Run tests and verify functionality

**Verification:**
- AURORA nightly regimen triggers `veil` cleanup job successfully
- Scheduled jobs execute correctly
- Regimen definitions parse correctly

---

### Phase 5: Privacy Merge - **PARTIALLY COMPLETE**

**Scope:** Fold Privacy Core into ECHO

**Status:** ✅ New structure created, but old module remains

**Completed:**
- ✅ `lib/echo/privacy_core/` directory created
- ✅ All privacy core files moved to new location
- ✅ `lib/echo/privacy_core/privacy_core_module.dart` exists

**Remaining Tasks:**
1. Verify all imports use `package:echo/privacy_core/...`
2. Expose privacy helpers through ECHO API:
   - `echo.guard(output)`
   - `echo.privacy.mask(input)`
3. Update `lib/epi_module.dart` to remove `privacy_core/privacy_core_module.dart` export
4. Update PRISM and ARC to use ECHO privacy functions
5. Delete `lib/privacy_core/` directory (after confirming no imports)
6. Run tests and verify functionality

**Verification:**
- Privacy masking works correctly
- Guardrails function properly
- PII detection accurate
- Integration with PRISM and ARC functional

---

### Phase 6: Import + Doc Cleanup

**Scope:** Replace imports, update architecture docs, delete deprecated modules

**Tasks:**
1. Global search & replace all import statements:
   - `package:atlas/` → `package:prism/atlas/`
   - `package:lumara/` → `package:arc/chat/`
   - `package:arcform/` → `package:arc/arcform/`
   - `package:mira/` → `package:polymeta/`
   - `package:mcp/` → `package:polymeta/store/mcp/`
   - `package:arcx/` → `package:polymeta/store/arcx/`
   - `package:veil/` → `package:aurora/regimens/veil/`
   - `package:privacy_core/` → `package:echo/privacy_core/`
2. Run linter to detect any residual imports to old module paths
3. Update all README files and architecture diagrams
4. Remove references to ATLAS, VEIL, LUMARA, MIRA, MCP, ARCX as separate modules
5. Delete deprecated module directories (after deprecation period)
6. Update `pubspec.yaml` if needed
7. Final test suite run

**Verification:**
- No linter errors
- All imports resolve correctly
- Documentation updated
- All tests pass

---

## Data Flow & Integration

### User Journal Entry Flow

```
1. User creates journal entry
   └─> ARC (lib/arc/ui/journal/)
   
2. ARC processes entry
   └─> PRISM (lib/prism/processors/)
       ├─> Text processing
       ├─> Image analysis (if media attached)
       └─> ATLAS phase detection (lib/prism/atlas/phase/)
       
3. PRISM extracts insights
   └─> POLYMETA (lib/polymeta/core/)
       ├─> Store in memory graph
       ├─> Encrypt with ARCX (lib/polymeta/store/arcx/)
       └─> Export to MCP format (lib/polymeta/store/mcp/)
       
4. ECHO applies guardrails
   └─> ECHO (lib/echo/privacy_core/)
       ├─> PII detection
       ├─> Content safety check
       └─> Privacy masking
       
5. AURORA schedules maintenance
   └─> AURORA (lib/aurora/regimens/veil/)
       └─> Scheduled restoration cycles
```

### Chat Interaction Flow

```
1. User sends chat message
   └─> ARC Chat (lib/arc/chat/)
   
2. ECHO formats request
   └─> ECHO (lib/echo/providers/)
       └─> LLM provider selection
       
3. POLYMETA retrieves context
   └─> POLYMETA (lib/polymeta/retrieval/)
       └─> Vector search for relevant memories
       
4. PRISM analyzes context
   └─> PRISM (lib/prism/atlas/)
       └─> Phase-aware context weighting
       
5. ECHO generates response
   └─> ECHO (lib/echo/response/)
       ├─> Apply guardrails
       └─> Privacy masking
       
6. ARC displays response
   └─> ARC Chat (lib/arc/chat/ui/)
```

### Phase Detection Flow

```
1. PRISM processes journal entries
   └─> PRISM (lib/prism/extractors/)
       └─> Extract keywords, emotions, context
       
2. ATLAS detects phase changes
   └─> PRISM ATLAS (lib/prism/atlas/phase/)
       ├─> Change point detection
       ├─> Phase inference
       └─> Regime creation
       
3. RIVET validates transitions
   └─> PRISM ATLAS (lib/prism/atlas/rivet/)
       ├─> Risk assessment
       └─> Evidence tracking
       
4. SENTINEL monitors risks
   └─> PRISM ATLAS (lib/prism/atlas/sentinel/)
       └─> Risk detection and alerts
       
5. POLYMETA stores phase data
   └─> POLYMETA (lib/polymeta/core/)
       └─> Store phase regimes in memory graph
```

---

## API Specifications

### ARC Module API

```dart
// ARC Module
import 'package:arc/arc_module.dart';

// Initialize ARC
ARCModule.initialize();

// Access chat (LUMARA)
import 'package:arc/chat/multimodal_chat_service.dart';
final chatService = MultimodalChatService();

// Access arcform
import 'package:arc/arcform/services/arcform_service.dart';
final arcformService = ArcformService();
```

### PRISM Module API

```dart
// PRISM Module
import 'package:prism/prism_module.dart';

// Initialize PRISM
PrismModule.initialize();

// Access ATLAS (unified API)
import 'package:prism/atlas/index.dart' as atlas;

// Phase detection
final phaseDetector = atlas.PhaseDetector();
final readiness = atlas.ReadinessScorer();

// RIVET
final rivetService = atlas.RivetService();
final rivetProvider = atlas.RivetProvider();

// SENTINEL
final sentinel = atlas.SentinelRiskDetector();
```

### POLYMETA Module API

```dart
// POLYMETA Module
import 'package:polymeta/polymeta_module.dart';

// Initialize POLYMETA
PolymetaModule.initialize();

// Unified API
final polymeta = PolymetaService();

// Store event
await polymeta.put(event);

// Query memories
final results = await polymeta.query(vector, k: 10);

// Export
await polymeta.export(format: 'mcp', envelope: 'arcx');

// Import
await polymeta.import(file);

// Convert
await polymeta.convert(input: 'mcp:zip', output: 'mcp+arcx');
```

### AURORA Module API

```dart
// AURORA Module
import 'package:aurora/aurora_module.dart';

// Initialize AURORA
AuroraModule.initialize();

// Access VEIL regimens
import 'package:aurora/regimens/veil/veil_service.dart';
final veilService = VeilService();

// Schedule jobs
await AuroraModule.scheduleJob(
  name: 'prism_batch_refresh',
  schedule: CronExpression('0 2 * * *'), // 2 AM daily
);
```

### ECHO Module API

```dart
// ECHO Module
import 'package:echo/echo_module.dart';

// Initialize ECHO
EchoModule.initialize();

// Apply guardrails
final guardedOutput = await echo.guard(output);

// Privacy masking
final maskedInput = await echo.privacy.mask(input);

// PII detection
final piiDetected = await echo.privacy.detect(input);

// Access privacy core
import 'package:echo/privacy_core/pii_detection_service.dart';
final piiService = PIIDetectionService();
```

---

## Testing & Verification

### Test Categories

1. **Golden Output Tests**
   - Capture ATLAS+RIVET+SENTINEL outputs pre-merge
   - Ensure byte-identical results post-merge
   - Verify phase detection accuracy
   - Validate RIVET sweep consistency

2. **Round-Trip Crypto Tests**
   - Validate POLYMETA.store can export/import ARCX archives
   - Verify AES-256-GCM encryption
   - Confirm Ed25519 signature verification
   - Test MCP compliance

3. **Regression Tests**
   - Journal → PRISM → POLYMETA → ECHO response → ARC UI
   - AURORA nightly regimen triggers `veil` cleanup job
   - Chat interactions with memory retrieval
   - Phase detection and regime creation

4. **Import Coverage Tests**
   - Run linter to detect residual imports to old module paths
   - Verify all imports resolve correctly
   - Check for circular dependencies

### Test Execution Plan

```bash
# Phase 1: PRISM.ATLAS Migration
flutter test test/atlas/ test/rivet/ test/prism/

# Phase 2: ARC Consolidation
flutter test test/arc/ test/lumara/ test/arcform/

# Phase 3: POLYMETA Unification
flutter test test/mira/ test/mcp/ test/arcx/

# Phase 4: VEIL Regimen
flutter test test/aurora/ test/veil/

# Phase 5: Privacy Merge
flutter test test/echo/ test/privacy_core/

# Phase 6: Full Integration
flutter test test/integration/
```

---

## Deprecation Timeline

### Deprecation Shim Strategy

Create deprecation shims for 2-week transition period:

```dart
// lib/atlas/atlas_module.dart
@Deprecated('Use package:prism/atlas/index.dart')
library atlas;

export 'package:prism/atlas/index.dart';
```

```dart
// lib/lumara/lumara_module.dart
@Deprecated('Use package:arc/chat/...')
library lumara;

export 'package:arc/chat/...';
```

### Timeline

- **Week 1-2:** Deprecation shims active, emit warnings
- **Week 3:** Remove deprecation shims
- **Week 4:** Delete deprecated module directories

---

## Post-Migration Deliverables

✅ `lib/arc/` → complete app with chat + arcform  
✅ `lib/prism/atlas/` → phase, rivet, sentinel unified  
✅ `lib/polymeta/` → memory + store + crypto  
✅ `lib/aurora/regimens/veil/` → restorative jobs  
✅ `lib/echo/privacy_core/` → safety + PII  
✅ All tests green and old imports deprecated cleanly  
✅ Documentation updated  
✅ Architecture diagrams reflect new structure  

---

## Module Naming Conventions

### Updated Core Module List

1. **ARC** — Journaling & Chat (LUMARA), Arcform visualization
2. **PRISM** — Perception layer (Atlas, Rivet, Sentinel included)
3. **POLYMETA** — Memory graph and secure store (MCP + ARCX)
4. **AURORA** — Circadian orchestration (includes VEIL regimen)
5. **ECHO** — Guardrails, LLMs, and privacy filter

### Removed References

- ❌ ATLAS (now `prism/atlas/`)
- ❌ VEIL (now `aurora/regimens/veil/`)
- ❌ LUMARA (now `arc/chat/`)
- ❌ MIRA (now `polymeta/`)
- ❌ MCP (now `polymeta/store/mcp/`)
- ❌ ARCX (now `polymeta/store/arcx/`)
- ❌ Privacy Core (now `echo/privacy_core/`)
- ❌ ARCFORM (now `arc/arcform/`)

---

## Conclusion

This consolidated architecture reduces complexity from 8+ modules to 5 clean deployables while maintaining all functionality. The migration should be executed phase by phase with thorough testing at each step. After completion, the codebase will have:

- Clearer module boundaries
- Reduced duplication
- Improved maintainability
- Better alignment with architectural intent
- Simplified dependency management

---

**Document Status:** Migration In Progress  
**Current State:** See [Migration_Status.md](./Migration_Status.md) for detailed status

**Next Steps:**
1. Complete remaining migration tasks for each phase
2. Update `lib/epi_module.dart` exports
3. Remove old directories after import verification
4. Run comprehensive test suite
5. Update documentation and diagrams

