/// Voice Response Configuration
/// 
/// Voice mode now uses the Master Unified Prompt system with voice-specific adaptations.
/// This file only contains configuration constants for voice response timing.
/// 
/// The actual prompts are built in:
/// - voice_session_service.dart: Uses Master Unified Prompt with voice mode instructions
library;

import '../../../../models/engagement_discipline.dart';

/// Voice Response Mode configuration
///
/// Two modes (matches written EngagementMode: Default, Deeper):
/// - Reflect: Casual conversation (default) - 100 words, 5s target
/// - Deeper: Patterns, connections, synthesis - 300 words, 15s target
///
/// Contains latency targets, word limits, and system-prompt character caps for voice mode.
class VoiceResponseConfig {
  /// Default (reflect) mode
  static const int reflectiveMaxWords = 100;
  static const int reflectiveTargetLatencyMs = 5000;
  static const int reflectiveMaxPromptChars = 6000;

  /// Deeper mode (connections, synthesis)
  static const int deeperMaxWords = 300;
  static const int deeperTargetLatencyMs = 15000;
  static const int deeperHardLimitMs = 20000;
  static const int deeperMaxPromptChars = 13000;

  /// Get max words for voice engagement mode
  static int getMaxWords(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflectiveMaxWords;
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return deeperMaxWords;
    }
  }

  /// Get target latency for voice engagement mode
  static int getTargetLatencyMs(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflectiveTargetLatencyMs;
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return deeperTargetLatencyMs;
    }
  }

  /// Get hard limit latency for voice engagement mode
  static int getHardLimitMs(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflectiveTargetLatencyMs * 2; // 10s
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return deeperHardLimitMs;
    }
  }

  /// Get hard cap (chars) for voice system+context prompt
  static int getVoicePromptMaxChars(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflectiveMaxPromptChars;
      case EngagementMode.deeper:
      case EngagementMode.explore:
      case EngagementMode.integrate:
        return deeperMaxPromptChars;
    }
  }
}
