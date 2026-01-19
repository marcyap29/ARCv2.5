/// Environment Configuration
/// 
/// Loads Wispr API key from environment variables (development only)
/// For production, use WisprConfigService with Firebase Remote Config

import 'package:flutter/foundation.dart';

class EnvConfig {
  // IMPORTANT: Never commit real API keys to source control
  // This is for local development only
  // Use Firebase Remote Config for production
  
  static const String _wisprApiKeyEnv = String.fromEnvironment(
    'WISPR_FLOW_API_KEY',
    defaultValue: '',
  );
  
  /// Get Wispr API key from environment
  static String? get wisprApiKey {
    if (_wisprApiKeyEnv.isEmpty) {
      debugPrint('EnvConfig: WISPR_FLOW_API_KEY not set in environment');
      return null;
    }
    return _wisprApiKeyEnv;
  }
  
  /// Check if running in development mode with env vars
  static bool get isDevelopmentMode {
    return _wisprApiKeyEnv.isNotEmpty;
  }
}

/// Usage:
/// 
/// Run with: flutter run --dart-define=WISPR_FLOW_API_KEY=your_key_here
