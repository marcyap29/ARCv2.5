/// Wispr Config Service - API key management for Wispr Flow
/// 
/// Handles:
/// - Loading API key from user preferences (user provides their own key)
/// - Caching key for performance
/// 
/// Note: Wispr Flow API is for personal use only. Users must provide
/// their own API key from wisprflow.ai

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WisprConfigService {
  static final WisprConfigService _instance = WisprConfigService._internal();
  factory WisprConfigService() => _instance;
  WisprConfigService._internal();

  static WisprConfigService get instance => _instance;

  // SharedPreferences key (must match the one in lumara_settings_screen.dart)
  static const String _wisprApiKeyPrefKey = 'wispr_flow_api_key';
  
  // Cached API key
  String? _cachedApiKey;
  bool _hasCheckedPrefs = false;

  /// Check if Wispr is available (has valid API key from user)
  Future<bool> isAvailable() async {
    try {
      final key = await getApiKey();
      return key != null && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Alias for isAvailable (for compatibility)
  Future<bool> isConfigured() async => isAvailable();

  /// Get the user-provided Wispr API key
  /// Returns null if user has not configured their key
  Future<String?> getApiKey() async {
    // Return cached key if available
    if (_hasCheckedPrefs && _cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }
    
    // Load from preferences
    return await _loadApiKey();
  }

  /// True if the stored value looks like instructions instead of an API key
  static bool _looksLikeInstructions(String key) {
    if (key.length < 20) return true;
    final lower = key.toLowerCase();
    if (lower.contains('lumara') && lower.contains('settings')) return true;
    if (lower.contains('tab') && lower.contains('->')) return true;
    if (key.contains('"')) return true;
    return false;
  }

  /// Load API key from SharedPreferences
  Future<String?> _loadApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(_wisprApiKeyPrefKey);
      
      _hasCheckedPrefs = true;
      
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('WisprConfigService: No user API key configured');
        debugPrint('WisprConfigService: Users can add their key in LUMARA Settings → API');
        _cachedApiKey = null;
        return null;
      }
      
      if (_looksLikeInstructions(apiKey)) {
        debugPrint('WisprConfigService: Stored value looks like instructions, not an API key — using On-Device');
        _cachedApiKey = null;
        return null;
      }
      
      _cachedApiKey = apiKey;
      debugPrint('WisprConfigService: User API key loaded successfully');
      return _cachedApiKey;
      
    } catch (e) {
      debugPrint('WisprConfigService: Error loading API key: $e');
      _cachedApiKey = null;
      return null;
    }
  }

  /// Clear cached key (call when user clears their key)
  void clearCache() {
    _cachedApiKey = null;
    _hasCheckedPrefs = false;
    debugPrint('WisprConfigService: Cache cleared');
  }

  /// Force refresh API key from preferences
  Future<String?> refreshApiKey() async {
    _cachedApiKey = null;
    _hasCheckedPrefs = false;
    return await _loadApiKey();
  }

  /// Check if key is cached (without loading)
  bool get hasCachedKey => _cachedApiKey != null && _cachedApiKey!.isNotEmpty;
}
