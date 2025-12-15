/// Unified Voice Module
/// 
/// A complete voice solution for LUMARA supporting both Journal and Chat modes.
/// 
/// ## Features
/// 
/// - Streaming STT via AssemblyAI (with on-device fallback)
/// - Local PII scrubbing via PRISM
/// - Gemini-powered LUMARA responses
/// - TTS playback
/// - Mode-specific storage:
///   - Journal mode: Saves to journal only
///   - Chat mode: Saves to chat history only
/// 
/// ## Security
/// 
/// - Raw transcript NEVER leaves device
/// - Only scrubbed text sent to Gemini
/// - PRISM reversible map stays local
/// - No raw text in logs
/// 
/// ## Usage
/// 
/// ```dart
/// import 'package:my_app/arc/chat/voice/voice_journal/voice_journal.dart';
/// 
/// // Create unified voice service
/// final service = UnifiedVoiceService(
///   assemblyAIService: assemblyAIService,
///   lumaraApi: lumaraApi,
///   journalCubit: journalCubit,  // For journal mode
///   chatCubit: chatCubit,        // For chat mode
///   initialMode: VoiceMode.journal,
/// );
/// 
/// await service.initialize();
/// await service.startSession();
/// await service.startListening();
/// 
/// // User speaks... partial transcripts arrive via callback
/// 
/// // When user taps stop button:
/// await service.endTurnAndProcess();
/// 
/// // LUMARA responds via TTS, then auto-continues listening
/// // Repeat until user ends session:
/// 
/// await service.saveAndEndSession();
/// 
/// // To switch modes:
/// service.switchMode(VoiceMode.chat);
/// ```

// Core state management
export 'voice_journal_state.dart';
export 'voice_mode.dart';

// Pipeline components
export 'prism_adapter.dart';
export 'assemblyai_stt.dart';
export 'gemini_client.dart';
export 'tts_client.dart';

// Storage
export 'journal_store.dart';
export 'chat_store.dart';

// Services
export 'voice_journal_pipeline.dart';
export 'unified_voice_service.dart';

// UI
export 'voice_journal_panel.dart';
export 'unified_voice_panel.dart';

