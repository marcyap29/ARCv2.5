import 'package:flutter/foundation.dart';
import 'package:my_app/core/analytics/analytics_consent.dart';

/// Analytics service for tracking user interactions with consent-gated events
/// Implements P15 requirements for analytics & QA
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // In-memory analytics tracking (for MVP/demo purposes)
  static final Map<String, int> _eventCounts = {};
  static final List<Map<String, dynamic>> _events = [];
  static bool _isInitialized = false;

  /// Initialize analytics service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize consent manager
    await AnalyticsConsent.initialize();
    _isInitialized = true;
    
    if (kDebugMode) {
      print('📊 Analytics: Service initialized with consent: ${AnalyticsConsent.hasConsent()}');
    }
  }

  /// Check if analytics tracking is enabled (consent given)
  static bool get isEnabled => AnalyticsConsent.hasConsent();

  /// Track event only if consent is given
  static void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    if (!isEnabled) {
      if (kDebugMode) {
        print('📊 Analytics: Event "$eventName" skipped - no consent');
      }
      return;
    }

    final event = {
      'event': eventName,
      'timestamp': DateTime.now().toIso8601String(),
      'properties': properties ?? {},
    };

    _events.add(event);
    _incrementEventCount(eventName);
    
    if (kDebugMode) {
      print('📊 Analytics: Event tracked - $eventName');
    }
  }

  /// Track when user manually overrides geometry (P23 requirement)
  static void trackGeometryOverride({
    required String originalPhase,
    required String originalGeometry,
    required String selectedGeometry,
    required List<String> keywords,
  }) {
    trackEvent('geometry_override', properties: {
      'original_phase': originalPhase,
      'original_geometry': originalGeometry,
      'selected_geometry': selectedGeometry,
      'keyword_count': keywords.length,
      'keywords': keywords,
    });
  }

  /// Track when user accepts auto-detected geometry
  static void trackGeometryAccepted({
    required String phase,
    required String geometry,
    required List<String> keywords,
  }) {
    trackEvent('geometry_accepted', properties: {
      'phase': phase,
      'geometry': geometry,
      'keyword_count': keywords.length,
      'keywords': keywords,
    });
  }

  /// Track journal entry creation
  static void trackJournalEntryCreated({
    required int wordCount,
    required String emotion,
    required int keywordCount,
  }) {
    trackEvent('journal_entry_created', properties: {
      'word_count': wordCount,
      'emotion': emotion,
      'keyword_count': keywordCount,
    });
  }

  /// Track arcform creation
  static void trackArcformCreated({
    required String geometry,
    required String phase,
    required int keywordCount,
  }) {
    trackEvent('arcform_created', properties: {
      'geometry': geometry,
      'phase': phase,
      'keyword_count': keywordCount,
    });
  }

  /// Track app launch
  static void trackAppLaunch() {
    trackEvent('app_launch');
  }

  /// Track tab navigation
  static void trackTabNavigation(String tabName) {
    trackEvent('tab_navigation', properties: {
      'tab': tabName,
    });
  }

  /// Track arcform export/share
  static void trackArcformExport(String phase, String geometry) {
    trackEvent('arcform_export', properties: {
      'phase': phase,
      'geometry': geometry,
    });
  }

  /// Get override frequency percentage (P23 requirement)
  static double getOverrideFrequency() {
    final overrides = _eventCounts['geometry_override'] ?? 0;
    final accepted = _eventCounts['geometry_accepted'] ?? 0;
    final total = overrides + accepted;
    
    if (total == 0) return 0.0;
    return (overrides / total) * 100.0;
  }

  /// Get analytics summary for debugging/admin purposes
  static Map<String, dynamic> getAnalyticsSummary() {
    return {
      'total_events': _events.length,
      'event_counts': Map.from(_eventCounts),
      'override_frequency_percent': getOverrideFrequency(),
      'recent_events': _events.take(10).toList(),
    };
  }

  static void _incrementEventCount(String eventType) {
    _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;
  }

  /// Clear analytics data (for testing/reset purposes)
  static void clearAnalytics() {
    _events.clear();
    _eventCounts.clear();
    print('📊 Analytics: Data cleared');
  }
}