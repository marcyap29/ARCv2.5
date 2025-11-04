/// ARC Module: Core Journaling Interface
///
/// The foundational module of the EPI (Evolving Personal Intelligence) system.
/// ARC provides the primary user experience for journaling, chat, and visualization.
///
/// ## Architecture Context
/// ARC consolidates what were previously separate modules:
/// - LUMARA (conversational AI) → `arc/chat/`
/// - ARCFORM (visualization) → `arc/arcform/`
///
/// This consolidation improves cohesion and reduces module boundaries while
/// maintaining LUMARA branding in the UI.
///
/// ## Key Components
/// - **Journal Capture**: Entry creation, editing, and metadata management
/// - **Chat (LUMARA)**: Conversational AI interface for reflection and guidance
/// - **ARCForm**: 3D visualization of emotional patterns and phase progression
/// - **Privacy**: Real-time PII protection during journaling
///
/// ## Data Flow
/// 1. User creates journal entry → JournalCaptureCubit
/// 2. Entry processed → KeywordExtractionCubit → PRISM extractors
/// 3. Keywords analyzed → ATLAS phase detection → RIVET gating
/// 4. Results visualized → ARCForm renderer
///
/// ## Usage
/// ```dart
/// import 'package:my_app/arc/arc_module.dart';
///
/// // Initialize journal capture
/// final cubit = JournalCaptureCubit(repository);
/// await cubit.createEntry(...);
/// ```

// Core journaling functionality
// State management and UI for journal entry capture and editing
export 'core/journal_capture_cubit.dart';
export 'core/journal_capture_view.dart';
export 'core/journal_repository.dart';
export 'core/keyword_extraction_cubit.dart';
export 'core/sage_echo_panel.dart';
export 'core/start_entry_flow.dart';

// Privacy integration
// Real-time PII detection and masking for journal entries
export 'privacy/privacy_demo_screen.dart';

// Models
// Shared data models for journal entries
export 'package:my_app/models/journal_entry_model.dart';
