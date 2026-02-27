/// Voice Service - Main entry point for voice features
/// 
/// This file provides a unified API for voice interactions.
/// Use this instead of the deprecated individual services.
/// 
/// @see UnifiedVoiceService for the implementation
/// @see VoiceMode for available modes (journal, chat)
library;

export 'voice_journal/voice_journal.dart';

// Re-export commonly used types for convenience
export 'voice_journal/voice_journal_state.dart' show VoiceJournalState, VoiceLatencyMetrics;
export 'voice_journal/voice_mode.dart' show VoiceMode;
export 'voice_journal/unified_voice_service.dart' show UnifiedVoiceService, UnifiedVoiceConfig;
export 'voice_journal/unified_voice_panel.dart' show UnifiedVoicePanel;

