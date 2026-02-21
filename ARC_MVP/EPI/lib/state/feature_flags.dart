/// Feature flags for controlling experimental features
class FeatureFlags {
  /// Enable inline LUMARA reflections within the journal
  static const bool inlineLumara = true;
  
  /// Enable page scanning with OCR functionality
  static const bool scanPage = true;
  
  /// Enable phase-aware LUMARA responses
  static const bool phaseAwareLumara = true;
  
  /// Enable PII scrubbing for external API calls
  static const bool piiScrubbing = true;
  
  /// Enable analytics and telemetry
  static const bool analytics = true;
  
  /// Enable reduced motion for accessibility
  static bool get reducedMotion => false; // This should check MediaQuery.disableAnimations

  /// Use LUMARA Orchestrator for context (CHRONICLE via subsystem); when false, uses legacy query router + context builder.
  static const bool useOrchestrator = false;
}
