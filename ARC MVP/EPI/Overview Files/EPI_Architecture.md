  Current MVP → EPI Module Mapping

  **EPI System consists of 8 Core Modules:**
  - ARC: Core Journaling Interface
  - PRISM: Multi-Modal Processing
  - ECHO: Expressive Response Layer
  - ATLAS: Phase Detection & Analysis
  - MIRA: Narrative Intelligence
  - AURORA: Circadian Intelligence
  - VEIL: Self-Pruning & Coherence
  - RIVET: Risk-Validation Evidence Tracker

  ## 🤖 **On-Device LLM Architecture** (Updated Oct 2, 2025)

  **MLX Integration Pipeline with Async Progress**:
  ```
  Flutter (LLMAdapter) → Pigeon Bridge → Swift (LLMBridge) → ModelStore → ModelLifecycle → MLX Inference
                      ← Progress API ← Swift Callbacks ← Model Loading Progress
  ```

  **Key Components**:
  - `lib/lumara/llm/llm_adapter.dart` - Flutter adapter using Pigeon bridge with progress waiting
  - `lib/lumara/llm/model_progress_service.dart` - Progress callback handler with stream broadcasting
  - `ios/Runner/LLMBridge.swift` - Swift implementation of Pigeon protocol with progress emission
  - `ios/Runner/SafetensorsLoader.swift` - Safetensors format parser with memory-mapped I/O
  - `ios/Runner/ModelStore.swift` - Model registry and bundle path management
  - `ios/Runner/ModelLifecycle.swift` - Async model loading lifecycle with completion handlers
  - `ios/Runner/AppDelegate.swift` - Progress API wiring for native→Flutter callbacks

  **Async Model Loading**:
  - **Non-Blocking Init**: `initModel()` returns immediately, loading happens in background
  - **Progress Streaming**: Real-time updates (0%, 10%, 30%, 60%, 90%, 100%) via Pigeon callbacks
  - **Bundle Loading**: Models loaded directly from `flutter_assets/assets/models/MLX/`
  - **Memory Mapping**: Large model files (872MB) loaded with memory-mapped I/O
  - **Background Queue**: `DispatchQueue(label: "com.epi.model.load", qos: .userInitiated)`

  **Model Management**:
  - **Registry**: JSON-based model tracking at `~/Library/Application Support/Models/models.json`
  - **Auto-Creation**: Registry auto-created on first launch with bundled model entry
  -   **Bundle Resolution**: `resolveBundlePath()` maps model IDs to flutter_assets paths (debugging in progress)
  - **Formats**: Supports MLX (iOS) and GGUF (Android) model formats
  - **Loading**: Real-time safetensors parsing to MLXArrays with progress reporting
  - **Debug Status**: Enhanced logging with multiple fallback paths for bundle resolution

  **Privacy Architecture**:
  - **On-Device Processing**: All inference happens locally on device
  - **No External Calls**: No data sent to external servers when using on-device model
  - **Fallback System**: On-Device → Cloud API → Rule-Based response hierarchy
  - **Model Verification**: File integrity checks before loading
  - **Progress Transparency**: User can see model loading progress in UI

  ## 📱 Navigation & User Interface Architecture (Updated Sept 28, 2025)

  **Primary Navigation Structure**:
  ```
  Phase → Timeline → Write (Elevated) → LUMARA → Insights → Settings
   [0]     [1]       [2]               [3]       [4]       [5]
  ```

  **Elevated Actions**:
  - **Write Button**: Elevated circular button above navigation tabs, launches complete journal flow
  - **Flow**: Emotion Picker → Reason Picker → Advanced Writing → Keyword Analysis → Save

  **Key Components**:
  - `lib/features/home/home_view.dart` - Main navigation controller with elevated tab design
  - `lib/shared/tab_bar.dart` - Custom tab bar with elevated tab functionality
  - `lib/arc/core/start_entry_flow.dart` - Complete journal creation flow
  - `lib/ui/journal/journal_screen.dart` - Advanced writing interface

  **UI/UX Design Evolution (Sept 27, 2025)**:
  - ✅ **Elevated Write Button**: Replaced floating action button with elegant elevated tab design
  - ✅ **Thicker Navigation**: Increased bottom navigation height to 100px for elevated button
  - ✅ **No Content Blocking**: Eliminated FAB interference with content across all tabs
  - ✅ **Perfect Integration**: Seamless integration with existing CustomTabBar elevated functionality
  - ✅ **Action vs Navigation**: Write triggers action (journal flow) rather than navigation to page

  1. ARC Module: Core Journaling Interface

  lib/arc/
  ├── core/
  │   ├── journal_entry_service.dart     # Current journal functionality
  │   ├── entry_processor.dart           # Text input processing
  │   └── arc_state_manager.dart         # UI state management
  ├── privacy/                           # **MIGRATED FROM CURRENT MVP**
  │   ├── pii_detection_service.dart     # Move from lib/services/privacy/
  │   ├── pii_masking_service.dart       # Move from lib/services/privacy/
  │   └── privacy_settings_service.dart  # Move from lib/services/privacy/
  ├── ui/
  │   ├── journal_entry_view.dart        # Main journaling interface
  │   ├── privacy_controls.dart          # Integrated privacy UI
  │   └── writing_assistance.dart        # Writing prompts/tools
  └── models/
      ├── journal_entry.dart
      └── privacy_protected_entry.dart

  2. PRISM Module: Multi-Modal Processing

  lib/prism/
  ├── processors/
  │   ├── text_processor.dart            # Keyword extraction from journal
  │   ├── image_processor.dart           # Image analysis and tagging
  │   ├── audio_processor.dart           # Voice note transcription
  │   └── video_processor.dart           # Video content analysis
  ├── extractors/
  │   ├── keyword_extractor.dart         # NLP keyword extraction
  │   ├── emotion_extractor.dart         # Sentiment analysis
  │   ├── context_extractor.dart         # Context understanding
  │   └── metadata_extractor.dart        # EXIF, timestamps, location
  ├── privacy/                           # **ENHANCED FROM MVP**
  │   ├── media_pii_detector.dart        # PII in images/audio
  │   ├── visual_content_masker.dart     # Blur faces, license plates
  │   └── audio_content_scrubber.dart    # Remove voice PII
  └── mcp/
      ├── mcp_formatter.dart             # Format for MCP export
      └── structured_data_builder.dart   # Build semantic structures

  3. ECHO Module: Expressive Response Layer (Enhanced with MCP Memory & Batch Management - Oct 1, 2025)

  lib/echo/
  ├── response/
  │   ├── dignity_rules.dart             # Maintain narrative dignity
  │   ├── phase_aware_voice.dart         # Context-appropriate responses
  │   ├── provider_abstraction.dart      # Model-agnostic interface
  │   └── lumara_voice.dart              # LUMARA personality layer
  ├── safeguards/
  │   ├── output_validation.dart         # Validate response appropriateness
  │   ├── privacy_compliance.dart        # Ensure privacy in responses
  │   ├── tone_regulation.dart           # Maintain consistent tone
  │   └── context_verification.dart      # Verify contextual accuracy
  ├── providers/
  │   ├── local_model_adapter.dart       # Local model integration
  │   ├── cloud_api_adapter.dart         # Cloud API integration
  │   ├── fallback_handler.dart          # Handle provider failures
  │   └── response_orchestrator.dart     # Coordinate multiple providers
  ├── memory/                            # **MCP Memory System**
  │   ├── mcp_memory_models.dart         # MCP data models and JSON serialization
  │   ├── mcp_memory_service.dart        # Core conversation persistence and session management
  │   ├── memory_index_service.dart      # Global indexing for topics, entities, open loops
  │   ├── pii_redaction_service.dart     # Privacy protection with PII detection/redaction
  │   └── summary_service.dart           # Map-reduce summarization and context extraction
  ├── chat/                              # **NEW: Chat History Management**
  │   ├── chat_repo.dart                 # Repository interface with batch operations
  │   ├── chat_repo_impl.dart            # Hive-based implementation with batch delete
  │   ├── chat_models.dart               # ChatSession and ChatMessage data models
  │   └── ui/
  │       ├── chats_screen.dart          # Main chat history with batch selection
  │       ├── archive_screen.dart        # Archive with identical batch functionality
  │       └── session_view.dart          # Individual chat session view
  └── models/
      ├── response_context.dart
      ├── dignity_metrics.dart
      └── voice_configuration.dart

  4. ATLAS Module: Phase Detection & Analysis

  lib/atlas/
  ├── phase_detection/
  │   ├── life_stage_analyzer.dart       # Detect developmental phases
  │   ├── transition_detector.dart       # Major life changes
  │   ├── pattern_recognition.dart       # Behavioral pattern analysis
  │   └── phase_classifier.dart          # ML-based phase classification
  ├── analysis/
  │   ├── readiness_signals.dart         # System adaptation signals
  │   ├── coherence_analyzer.dart        # Analyze entry coherence
  │   ├── development_tracker.dart       # Track developmental progress
  │   └── insight_generator.dart         # Generate phase-based insights
  ├── privacy/                           # **INTEGRATED FROM MVP**
  │   ├── phase_aware_privacy.dart       # Adjust privacy by life phase
  │   ├── context_based_masking.dart     # Mask based on phase context
  │   └── adaptive_guardrails.dart       # Smart guardrail adjustment
  └── models/
      ├── life_phase.dart
      ├── phase_transition.dart
      └── development_metrics.dart

  5. MIRA Module: Narrative Intelligence

  lib/mira/
  ├── graph/                             # **EXISTING - KEEP AS IS**
  │   ├── memory_graph_builder.dart
  │   ├── semantic_clustering.dart
  │   ├── theme_evolution_tracker.dart
  │   └── narrative_coherence.dart
  ├── ingest/                            # **EXISTING - KEEP AS IS**
  │   ├── journal_ingestion.dart
  │   ├── experience_parser.dart
  │   └── significance_detector.dart
  ├── privacy/                           # **NEW - ENHANCE WITH MVP**
  │   ├── graph_anonymization.dart       # Anonymize memory graphs
  │   ├── narrative_pii_detection.dart   # Detect PII in stories
  │   ├── semantic_masking.dart          # Preserve meaning, mask PII
  │   └── memory_privacy_layers.dart     # Layered privacy for memories
  ├── intelligence/
  │   ├── emotional_tonality.dart        # Emotion analysis
  │   ├── developmental_tracking.dart    # Growth pattern analysis
  │   ├── self_authorship.dart           # User significance weighting
  │   └── narrative_synthesis.dart       # Story building
  └── adapters/
      └── to_mcp.dart                    # **EXISTING - KEEP AS IS**

  6. AURORA Module: Circadian Intelligence (Future)

  lib/aurora/
  ├── scheduling/
  │   ├── circadian_scheduler.dart       # Time-based task distribution
  │   ├── energy_optimizer.dart          # Resource allocation by energy
  │   ├── compute_orchestrator.dart      # Distribute heavy processing
  │   └── rhythm_detector.dart           # Learn user patterns
  ├── monitoring/
  │   ├── cognitive_drift_pruner.dart    # Reset system entropy
  │   ├── wellness_monitor.dart          # Track ethical/narrative load
  │   ├── overload_detector.dart         # Detect saturation signals
  │   └── restorative_mode.dart          # Trigger rest/reflection
  ├── privacy/                           # **FUTURE INTEGRATION**
  │   ├── temporal_privacy.dart          # Time-based privacy levels
  │   ├── energy_aware_masking.dart      # Adjust masking by energy
  │   └── circadian_guardrails.dart      # Time-sensitive guardrails
  └── intelligence/
      ├── reflective_mode.dart           # Deep reflection triggers
      ├── silence_orchestrator.dart      # Strategic system silence
      └── restoration_engine.dart        # System healing processes

  7. VEIL Module: Self-Pruning & Coherence (Future)

  lib/veil/
  ├── pruning/
  │   ├── memory_pruner.dart             # Remove outdated memories
  │   ├── model_weight_adjuster.dart     # LoRA-style adjustments
  │   ├── coherence_maintainer.dart      # Preserve system coherence
  │   └── entropy_reducer.dart           # Reduce system complexity
  ├── restoration/
  │   ├── nightly_processor.dart         # Sleep-cycle operations
  │   ├── duplication_manager.dart       # Safe state duplication
  │   ├── reintegration_engine.dart      # Merge pruned updates
  │   └── healing_algorithms.dart        # Self-repair mechanisms
  ├── privacy/                           # **FUTURE PRIVACY EVOLUTION**
  │   ├── privacy_weight_adjustment.dart # Adjust privacy models
  │   ├── forgotten_data_pruner.dart     # Right to be forgotten
  │   └── coherent_anonymization.dart    # Maintain utility while anonymizing
  └── models/
      ├── pruning_strategy.dart
      ├── restoration_state.dart
      └── coherence_metrics.dart


  8. RIVET Module: Risk-Validation Evidence Tracker

  lib/rivet/
  ├── alignment/
  │   ├── align_calculator.dart          # ALIGN score computation
  │   ├── prediction_validator.dart      # Model vs empirical comparison
  │   ├── normalization_engine.dart      # Normalize agreement measures
  │   └── confidence_estimator.dart      # Statistical confidence metrics
  ├── trace/
  │   ├── trace_calculator.dart          # TRACE score computation
  │   ├── evidence_accumulator.dart      # Accumulate test results
  │   ├── independence_scorer.dart       # Weight independent events
  │   └── novelty_detector.dart          # Detect novel vs repeat tests
  ├── validation/
  │   ├── threshold_manager.dart         # Manage ALIGN/TRACE thresholds
  │   ├── sustainment_tracker.dart       # Track sustainment windows
  │   ├── test_reduction_authorizer.dart # Authorize test reductions
  │   └── risk_assessor.dart             # Assess reduction risks
  ├── privacy/
  │   ├── evidence_anonymization.dart    # Anonymize test evidence
  │   ├── validation_privacy.dart        # Privacy-aware validation
  │   └── secure_aggregation.dart        # Secure evidence aggregation
  └── models/
      ├── align_metrics.dart
      ├── trace_metrics.dart
      ├── validation_evidence.dart
      └── risk_profile.dart

  Core Privacy Integration Strategy

  Shared Privacy Foundation

  lib/privacy_core/
  ├── interfaces/                        # **FROM CURRENT MVP**
  │   ├── pii_detector_interface.dart
  │   ├── masking_strategy_interface.dart
  │   └── guardrail_interface.dart
  ├── models/                            # **FROM CURRENT MVP**
  │   ├── pii_types.dart
  │   ├── detection_result.dart
  │   └── masking_result.dart
  ├── utils/                             # **FROM CURRENT MVP**
  │   ├── privacy_patterns.dart
  │   ├── confidence_calculators.dart
  │   └── validation_utils.dart
  └── config/
      ├── module_privacy_configs.dart    # Per-module privacy settings
      └── cross_module_policies.dart     # Global privacy policies

  Module-Specific Privacy Adaptations

  ARC Privacy: Real-time input protection

  - Current MVP functionality with real-time masking as user types
  - Integration with writing assistance to suggest privacy-safe alternatives

  PRISM Privacy: Multi-modal PII detection

  - Enhanced MVP detection for images (face recognition, license plates)
  - Audio PII detection (voices, spoken names, phone numbers)
  - Video content analysis with temporal PII tracking

  ECHO Privacy: Response-layer protection

  - Output validation to prevent PII leakage in responses
  - Provider-agnostic privacy compliance regardless of model source
  - Dignity-preserving response filtering with contextual awareness

  ATLAS Privacy: Context-adaptive protection

  - Phase-aware privacy adjustment based on developmental context
  - Dynamic privacy levels based on life phase and analysis
  - Context-sensitive guardrail adjustment

  MIRA Privacy: Narrative-aware anonymization

  - MVP masking enhanced to preserve narrative coherence
  - Graph-level anonymization that maintains semantic relationships
  - Story-aware PII detection that understands context

  RIVET Privacy: Evidence protection

  - Anonymization of validation evidence and test results
  - Privacy-aware evidence aggregation and scoring
  - Secure handling of empirical data and model predictions

  Migration Strategy

  ✅ **Phase 1: Foundation (COMPLETED - December 2025)**

  1. ✅ Extracted RIVET validation system to lib/rivet/ module
  2. ✅ Migrated ECHO expressive response layer to lib/echo/ module
  3. ✅ Created modular export interfaces (rivet_module.dart, echo_module.dart)
  4. ✅ Updated app.dart to use new module imports
  5. ✅ Fixed internal import paths for module isolation

  Phase 2: Enhancement (Next - PRISM/ATLAS modules)

  1. Migrate multimodal perception capabilities to lib/prism/
  2. Migrate phase detection system to lib/atlas/
  3. Update remaining import dependencies
  4. Integrate phase-aware privacy levels

  Phase 3: Memory & Storage (MIRA/AURORA modules)

  1. Migrate semantic memory system to lib/mira/
  2. Migrate temporal orchestration to lib/aurora/
  3. Update storage and retrieval interfaces

  Phase 4: Privacy & Security (VEIL completion)

  1. Complete Universal Privacy Guardrail migration to lib/veil/
  2. Implement self-improving privacy models
  3. Add coherence-preserving anonymization