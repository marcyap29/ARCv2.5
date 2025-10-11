import 'package:flutter/foundation.dart';
import 'rivet_models.dart';

/// Simple telemetry system for RIVET gate decisions
/// Provides debugging insights and usage analytics
class RivetTelemetry {
  static final RivetTelemetry _instance = RivetTelemetry._internal();
  factory RivetTelemetry() => _instance;
  RivetTelemetry._internal();

  final List<_RivetTelemetryEvent> _events = [];
  static const int _maxEvents = 100; // Keep memory usage bounded

  /// Log a RIVET gate decision for telemetry
  void logGateDecision({
    required String userId,
    required RivetEvent rivetEvent,
    required RivetGateDecision decision,
    required Duration processingTime,
  }) {
    final telemetryEvent = _RivetTelemetryEvent(
      timestamp: DateTime.now(),
      userId: userId,
      rivetEvent: rivetEvent,
      decision: decision,
      processingTime: processingTime,
    );

    // Add to events list
    _events.add(telemetryEvent);

    // Maintain bounded size
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }

    // Debug logging
    if (kDebugMode) {
      final phase = rivetEvent.refPhase;
      final align = (decision.stateAfter.align * 100).round();
      final trace = (decision.stateAfter.trace * 100).round();
      final gateStatus = decision.open ? "OPEN" : "CLOSED";
      
      print('RIVET TELEMETRY: $phase phase | '
            'ALIGN=$align% TRACE=$trace% | '
            'Gate=$gateStatus | '
            '${processingTime.inMilliseconds}ms | '
            'Sustain=${decision.stateAfter.sustainCount} | '
            'Independent=${decision.stateAfter.sawIndependentInWindow}');

      if (!decision.open && decision.whyNot != null) {
        print('RIVET REASON: ${decision.whyNot}');
      }
    }
  }

  /// Log RIVET initialization events
  void logInitialization({
    required String userId,
    required bool success,
    String? errorMessage,
    required Duration initTime,
  }) {
    if (kDebugMode) {
      if (success) {
        print('RIVET TELEMETRY: Initialized for $userId in ${initTime.inMilliseconds}ms');
      } else {
        print('RIVET TELEMETRY: Failed to initialize for $userId: $errorMessage');
      }
    }
  }

  /// Log RIVET recompute operations (delete/edit)
  void logRecompute({
    required String userId,
    required String operation,
    required String eventId,
    required RivetGateDecision decision,
    required Duration processingTime,
  }) {
    if (kDebugMode) {
      final align = (decision.stateAfter.align * 100).round();
      final trace = (decision.stateAfter.trace * 100).round();
      final gateStatus = decision.open ? "OPEN" : "CLOSED";
      
      print('RIVET RECOMPUTE: $operation event $eventId | '
            'ALIGN=$align% TRACE=$trace% | '
            'Gate=$gateStatus | '
            '${processingTime.inMilliseconds}ms | '
            'Sustain=${decision.stateAfter.sustainCount} | '
            'Independent=${decision.stateAfter.sawIndependentInWindow}');

      if (!decision.open && decision.whyNot != null) {
        print('RIVET REASON: ${decision.whyNot}');
      }
    }
  }

  /// Get telemetry summary for debugging
  Map<String, dynamic> getTelemetrySummary() {
    if (_events.isEmpty) {
      return {
        'totalEvents': 0,
        'summary': 'No RIVET events recorded',
      };
    }

    final totalEvents = _events.length;
    final openGates = _events.where((e) => e.decision.open).length;
    final closedGates = totalEvents - openGates;
    final avgProcessingTime = _events
        .map((e) => e.processingTime.inMilliseconds)
        .reduce((a, b) => a + b) / totalEvents;

    // Phase distribution
    final phaseDistribution = <String, int>{};
    for (final event in _events) {
      final phase = event.rivetEvent.refPhase;
      phaseDistribution[phase] = (phaseDistribution[phase] ?? 0) + 1;
    }

    // Recent ALIGN/TRACE values
    final recentEvents = _events.take(10).toList();
    final recentAlign = recentEvents.isNotEmpty 
        ? recentEvents.map((e) => e.decision.stateAfter.align).toList()
        : <double>[];
    final recentTrace = recentEvents.isNotEmpty
        ? recentEvents.map((e) => e.decision.stateAfter.trace).toList()
        : <double>[];

    return {
      'totalEvents': totalEvents,
      'openGates': openGates,
      'closedGates': closedGates,
      'openRate': totalEvents > 0 ? (openGates / totalEvents * 100).round() : 0,
      'avgProcessingTimeMs': avgProcessingTime.round(),
      'phaseDistribution': phaseDistribution,
      'recentAlign': recentAlign,
      'recentTrace': recentTrace,
      'lastEventTime': _events.isNotEmpty ? _events.last.timestamp.toIso8601String() : null,
    };
  }

  /// Get recent events for debugging (last N events)
  List<Map<String, dynamic>> getRecentEvents({int limit = 10}) {
    final events = _events.reversed.take(limit).toList();
    return events.map((e) => {
      'timestamp': e.timestamp.toIso8601String(),
      'userId': e.userId,
      'phase': e.rivetEvent.refPhase,
      'predPhase': e.rivetEvent.predPhase,
      'keywordCount': e.rivetEvent.keywords.length,
      'align': (e.decision.stateAfter.align * 100).round(),
      'trace': (e.decision.stateAfter.trace * 100).round(),
      'gateOpen': e.decision.open,
      'sustainCount': e.decision.stateAfter.sustainCount,
      'sawIndependent': e.decision.stateAfter.sawIndependentInWindow,
      'whyNot': e.decision.whyNot,
      'processingMs': e.processingTime.inMilliseconds,
    }).toList();
  }

  /// Clear all telemetry data
  void clear() {
    _events.clear();
  }
}

/// Internal telemetry event data structure
class _RivetTelemetryEvent {
  final DateTime timestamp;
  final String userId;
  final RivetEvent rivetEvent;
  final RivetGateDecision decision;
  final Duration processingTime;

  _RivetTelemetryEvent({
    required this.timestamp,
    required this.userId,
    required this.rivetEvent,
    required this.decision,
    required this.processingTime,
  });
}