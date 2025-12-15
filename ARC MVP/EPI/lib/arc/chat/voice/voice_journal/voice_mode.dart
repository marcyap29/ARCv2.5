/// Voice Mode - Unified voice service for Journal and Chat
/// 
/// This module provides a unified architecture for voice interactions:
/// - JOURNAL mode: Saves to journal only, never to chat
/// - CHAT mode: Saves to chat only, never to journal
/// 
/// Both modes use the same pipeline:
/// 1. AssemblyAI STT (streaming transcription)
/// 2. PRISM (local PII scrubbing)
/// 3. Gemini (LLM response)
/// 4. TTS (text-to-speech)
/// 
/// Security invariants (apply to BOTH modes):
/// - Raw transcript NEVER leaves device
/// - Only scrubbed text goes to Gemini
/// - PRISM reversible map stays local
/// - No raw text in logs

/// Voice mode types
enum VoiceMode {
  /// Journal mode - saves to journal, not chat
  journal,
  
  /// Chat mode - saves to chat history, not journal
  chat,
}

/// Extension for mode-specific behavior
extension VoiceModeExtension on VoiceMode {
  String get displayName {
    switch (this) {
      case VoiceMode.journal:
        return 'Voice Journal';
      case VoiceMode.chat:
        return 'Voice Chat';
    }
  }
  
  String get systemPrompt {
    switch (this) {
      case VoiceMode.journal:
        return '''You are LUMARA, a compassionate and insightful journaling assistant. 
You help users reflect on their thoughts and feelings through their voice journal entries.
Keep responses conversational, warm, and concise (2-3 sentences).
Ask thoughtful follow-up questions to encourage deeper reflection.
Focus on emotions, patterns, and growth opportunities.
Never repeat back what the user said verbatim.''';
      case VoiceMode.chat:
        return '''You are LUMARA, a helpful and friendly AI assistant.
You engage in natural conversation, answer questions, and provide assistance.
Keep responses concise but helpful (2-4 sentences).
Be conversational and engaging.
Ask clarifying questions when needed.''';
    }
  }
  
  String get intentType {
    switch (this) {
      case VoiceMode.journal:
        return 'voice_journal';
      case VoiceMode.chat:
        return 'voice_chat';
    }
  }
}

