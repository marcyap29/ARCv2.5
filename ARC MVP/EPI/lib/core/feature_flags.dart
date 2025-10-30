/// Feature Flags for EPI
/// 
/// Centralized feature flag system for managing placeholder implementations
/// and experimental features. All flags should be documented in PLACEHOLDER_IMPLEMENTATIONS.md
class FeatureFlags {
  // ============================================================
  // PLACEHOLDER IMPLEMENTATION FLAGS
  // ============================================================
  
  /// Apple Vision OCR integration
  /// Status: Partially implemented - verify Apple Vision integration is complete
  static const bool ENABLE_APPLE_VISION_OCR = true;
  
  /// Audio transcription service
  /// Status: Placeholder - implement native bridge or use cloud service
  static const bool ENABLE_AUDIO_TRANSCRIPTION = false;
  
  /// SQLite-based MIRA repository
  /// Status: Stub implementation - implement or remove if Hive is sufficient
  static const bool ENABLE_SQLITE_MIRA_REPO = false;
  
  /// MCP UI components (thumbnails, popups, gallery)
  /// Status: Placeholder UI - implement MCP UI components
  static const bool ENABLE_MCP_UI_COMPONENTS = false;
  
  /// On-device LLM integration (llama.cpp/MLC)
  /// Status: Stub implementation - complete llama.cpp integration or remove
  static const bool ENABLE_ON_DEVICE_LLM = false;
  
  // ============================================================
  // EXPERIMENTAL FEATURES
  // ============================================================
  
  /// Enhanced encryption with key rotation
  /// Status: Implemented - AES-256-GCM with DEK/KEK architecture
  static const bool ENABLE_ENHANCED_ENCRYPTION = true;
  
  /// Parallel service initialization
  /// Status: Implemented - bootstrap.dart uses Future.wait
  static const bool ENABLE_PARALLEL_STARTUP = true;
  
  /// Lazy loading for LUMARA quick answers
  /// Status: Implemented - quick answers load on first use
  static const bool ENABLE_LAZY_LOADING = true;
  
  /// Optimized widget rebuilds with ValueNotifier
  /// Status: Implemented - network graph uses ValueNotifier
  static const bool ENABLE_OPTIMIZED_REBUILDS = true;
  
  // ============================================================
  // RUNTIME FEATURE FLAG CHECKING
  // ============================================================
  
  /// Check if a feature flag is enabled
  /// 
  /// Usage:
  /// ```dart
  /// if (FeatureFlags.isEnabled('APPLE_VISION_OCR')) {
  ///   return await _appleVisionService.processImage(image);
  /// } else {
  ///   return "OCR not available";
  /// }
  /// ```
  static bool isEnabled(String flag) {
    switch (flag.toUpperCase()) {
      // Placeholder implementation flags
      case 'APPLE_VISION_OCR': return ENABLE_APPLE_VISION_OCR;
      case 'AUDIO_TRANSCRIPTION': return ENABLE_AUDIO_TRANSCRIPTION;
      case 'SQLITE_MIRA_REPO': return ENABLE_SQLITE_MIRA_REPO;
      case 'MCP_UI_COMPONENTS': return ENABLE_MCP_UI_COMPONENTS;
      case 'ON_DEVICE_LLM': return ENABLE_ON_DEVICE_LLM;
      
      // Experimental features
      case 'ENHANCED_ENCRYPTION': return ENABLE_ENHANCED_ENCRYPTION;
      case 'PARALLEL_STARTUP': return ENABLE_PARALLEL_STARTUP;
      case 'LAZY_LOADING': return ENABLE_LAZY_LOADING;
      case 'OPTIMIZED_REBUILDS': return ENABLE_OPTIMIZED_REBUILDS;
      
      default: 
        // Log unknown flag for debugging
        print('Warning: Unknown feature flag "$flag"');
        return false;
    }
  }
  
  /// Get all enabled feature flags
  /// Useful for debugging and feature status reporting
  static Map<String, bool> getAllFlags() {
    return {
      'APPLE_VISION_OCR': ENABLE_APPLE_VISION_OCR,
      'AUDIO_TRANSCRIPTION': ENABLE_AUDIO_TRANSCRIPTION,
      'SQLITE_MIRA_REPO': ENABLE_SQLITE_MIRA_REPO,
      'MCP_UI_COMPONENTS': ENABLE_MCP_UI_COMPONENTS,
      'ON_DEVICE_LLM': ENABLE_ON_DEVICE_LLM,
      'ENHANCED_ENCRYPTION': ENABLE_ENHANCED_ENCRYPTION,
      'PARALLEL_STARTUP': ENABLE_PARALLEL_STARTUP,
      'LAZY_LOADING': ENABLE_LAZY_LOADING,
      'OPTIMIZED_REBUILDS': ENABLE_OPTIMIZED_REBUILDS,
    };
  }
  
  /// Get enabled feature flags only
  static List<String> getEnabledFlags() {
    return getAllFlags()
        .entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Get disabled feature flags only
  static List<String> getDisabledFlags() {
    return getAllFlags()
        .entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Print feature flag status (useful for debugging)
  static void printStatus() {
    print('=== FEATURE FLAGS STATUS ===');
    print('Enabled: ${getEnabledFlags().join(', ')}');
    print('Disabled: ${getDisabledFlags().join(', ')}');
    print('============================');
  }
}




