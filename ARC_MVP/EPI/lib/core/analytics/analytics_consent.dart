import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages analytics consent for P15 requirements
/// Provides consent-gated analytics tracking
class AnalyticsConsent {
  static const String _consentKey = 'analytics_consent';
  static bool? _hasConsent;
  static SharedPreferences? _prefs;

  /// Initialize consent manager
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _hasConsent = _prefs?.getBool(_consentKey);
    
    if (kDebugMode) {
      print('📊 Analytics Consent: Initialized - hasConsent: $_hasConsent');
    }
  }

  /// Check if user has given consent for analytics
  static bool hasConsent() {
    return _hasConsent ?? false;
  }

  /// Grant analytics consent
  static Future<void> grantConsent() async {
    _hasConsent = true;
    await _prefs?.setBool(_consentKey, true);
    
    if (kDebugMode) {
      print('📊 Analytics Consent: Granted');
    }
  }

  /// Revoke analytics consent
  static Future<void> revokeConsent() async {
    _hasConsent = false;
    await _prefs?.setBool(_consentKey, false);
    
    if (kDebugMode) {
      print('📊 Analytics Consent: Revoked');
    }
  }

  /// Reset consent (for testing)
  static Future<void> resetConsent() async {
    _hasConsent = null;
    await _prefs?.remove(_consentKey);
    
    if (kDebugMode) {
      print('📊 Analytics Consent: Reset');
    }
  }
}
