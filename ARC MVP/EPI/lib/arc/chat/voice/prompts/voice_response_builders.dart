/// Voice Response Configuration
/// 
/// Voice mode now uses the Master Unified Prompt system with voice-specific adaptations.
/// This file only contains configuration constants for voice response timing.
/// 
/// The actual prompts are built in:
/// - voice_session_service.dart: Uses Master Unified Prompt with voice mode instructions

import '../../../../models/engagement_discipline.dart';

/// Voice Response Mode configuration
/// 
/// Three-tier voice conversation system (matches written mode EngagementMode):
/// - Reflect: Casual conversation, shortest (default) - 100 words (vs 200 in written)
/// - Explore: Pattern analysis, longer (when asked) - 200 words (vs 400 in written)
/// - Integrate: Cross-domain synthesis, longest (when asked) - 300 words (vs 500 in written)
/// 
/// UPDATE (2026-01-22): Reverted to original limits after implementing phase-specific
/// prompts with good/bad examples and seeking classification. The structural improvements
/// should provide quality without needing longer responses.
/// 
/// Written mode limits (for reference):
/// - Reflect: 200 words
/// - Explore: 400 words
/// - Integrate: 500 words
/// 
/// Contains latency targets and word limits for voice mode responses.
/// These are used for performance monitoring and validation.
class VoiceResponseConfig {
  /// Reflect mode configuration (casual conversation, default)
  /// Voice: 100 words (Written: 200 words) - 50% of written mode for brevity
  static const int reflectiveMaxWords = 100;
  static const int reflectiveTargetLatencyMs = 5000;
  
  /// Explore mode configuration (pattern analysis, when asked)
  /// Voice: 200 words (Written: 400 words) - 50% of written mode
  static const int exploreMaxWords = 200;
  static const int exploreTargetLatencyMs = 10000;
  
  /// Integrate mode configuration (synthesis, when asked)
  /// Voice: 300 words (Written: 500 words) - 60% of written mode
  static const int integrateMaxWords = 300;
  static const int integrateTargetLatencyMs = 15000;
  static const int integrateHardLimitMs = 20000; // Hard ceiling for synthesis
  
  /// Get max words for voice engagement mode (matches written mode)
  static int getMaxWords(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflectiveMaxWords;
      case EngagementMode.explore:
        return exploreMaxWords;
      case EngagementMode.integrate:
        return integrateMaxWords;
    }
  }
  
  /// Get target latency for voice engagement mode
  static int getTargetLatencyMs(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflectiveTargetLatencyMs;
      case EngagementMode.explore:
        return exploreTargetLatencyMs;
      case EngagementMode.integrate:
        return integrateTargetLatencyMs;
    }
  }
  
  /// Get hard limit latency for voice engagement mode
  static int getHardLimitMs(EngagementMode mode) {
    switch (mode) {
      case EngagementMode.reflect:
        return reflectiveTargetLatencyMs * 2; // 10s
      case EngagementMode.explore:
        return exploreTargetLatencyMs * 2; // 20s
      case EngagementMode.integrate:
        return integrateHardLimitMs; // 20s
    }
  }
}
