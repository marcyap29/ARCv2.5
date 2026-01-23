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
/// - Reflect: Casual conversation, shortest (default) - 175 words (vs 200 in written)
/// - Explore: Pattern analysis, longer (when asked) - 350 words (vs 400 in written)
/// - Integrate: Cross-domain synthesis, longest (when asked) - 450 words (vs 500 in written)
/// 
/// UPDATE (2026-01-22): Increased word limits to improve response quality.
/// Previous limits (100/200/300) were too restrictive, leading to generic filler responses.
/// New limits are ~85-90% of written mode to allow substantive answers while still
/// being appropriate for spoken conversation.
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
  /// Voice: 175 words (Written: 200 words) - ~87% of written mode
  static const int reflectiveMaxWords = 175;
  static const int reflectiveTargetLatencyMs = 7000;
  
  /// Explore mode configuration (pattern analysis, when asked)
  /// Voice: 350 words (Written: 400 words) - ~87% of written mode
  static const int exploreMaxWords = 350;
  static const int exploreTargetLatencyMs = 12000;
  
  /// Integrate mode configuration (synthesis, when asked)
  /// Voice: 450 words (Written: 500 words) - 90% of written mode
  static const int integrateMaxWords = 450;
  static const int integrateTargetLatencyMs = 18000;
  static const int integrateHardLimitMs = 25000; // Hard ceiling for synthesis
  
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
        return reflectiveTargetLatencyMs * 2; // 14s
      case EngagementMode.explore:
        return exploreTargetLatencyMs * 2; // 24s
      case EngagementMode.integrate:
        return integrateHardLimitMs; // 25s
    }
  }
}
