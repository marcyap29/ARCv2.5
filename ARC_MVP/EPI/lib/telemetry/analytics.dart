import 'dart:convert';
import '../state/feature_flags.dart';

/// Analytics service for tracking user interactions and app events
class Analytics {
  static final Analytics _instance = Analytics._internal();
  factory Analytics() => _instance;
  Analytics._internal();

  /// Log an event with optional parameters
  void log(String eventName, Map<String, dynamic>? parameters) {
    if (!FeatureFlags.analytics) return;
    
    final event = {
      'event': eventName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'parameters': parameters ?? {},
    };
    
    // In a real implementation, this would send to your analytics provider
    print('ANALYTICS: ${jsonEncode(event)}');
  }

  /// Log journal-specific events
  void logJournalEvent(String action, {Map<String, dynamic>? data}) {
    log('journal_$action', data);
  }

  /// Log LUMARA-specific events
  void logLumaraEvent(String action, {Map<String, dynamic>? data}) {
    log('lumara_$action', data);
  }

  /// Log OCR/scanning events
  void logScanEvent(String action, {Map<String, dynamic>? data}) {
    log('scan_$action', data);
  }
}
