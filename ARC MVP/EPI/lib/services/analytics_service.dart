/// Simple analytics service for tracking user interactions
/// This is a stub implementation for P23 requirements
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // In-memory analytics tracking (for MVP/demo purposes)
  static final Map<String, int> _eventCounts = {};
  static final List<Map<String, dynamic>> _events = [];

  /// Track when user manually overrides geometry (P23 requirement)
  static void trackGeometryOverride({
    required String originalPhase,
    required String originalGeometry,
    required String selectedGeometry,
    required List<String> keywords,
  }) {
    final event = {
      'event': 'geometry_override',
      'timestamp': DateTime.now().toIso8601String(),
      'original_phase': originalPhase,
      'original_geometry': originalGeometry,
      'selected_geometry': selectedGeometry,
      'keyword_count': keywords.length,
      'keywords': keywords,
    };

    _events.add(event);
    _incrementEventCount('geometry_override');
    
    print('📊 Analytics: Geometry override tracked - $originalGeometry → $selectedGeometry');
  }

  /// Track when user accepts auto-detected geometry
  static void trackGeometryAccepted({
    required String phase,
    required String geometry,
    required List<String> keywords,
  }) {
    final event = {
      'event': 'geometry_accepted',
      'timestamp': DateTime.now().toIso8601String(),
      'phase': phase,
      'geometry': geometry,
      'keyword_count': keywords.length,
      'keywords': keywords,
    };

    _events.add(event);
    _incrementEventCount('geometry_accepted');
    
    print('📊 Analytics: Auto-geometry accepted - $geometry for $phase');
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