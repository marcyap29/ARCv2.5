import 'package:flutter/foundation.dart';
import 'rivet_models.dart';

/// Enhanced telemetry system for RIVET gate decisions with recompute metrics
/// Provides debugging insights, usage analytics, and clear gate explanations
class RivetTelemetry {
  static final RivetTelemetry _instance = RivetTelemetry._internal();
  factory RivetTelemetry() => _instance;
  RivetTelemetry._internal();

  final List<_RivetTelemetryEvent> _events = [];
  final List<_RivetRecomputeEvent> _recomputeEvents = [];
  static const int _maxEvents = 100; // Keep memory usage bounded
  static const int _maxRecomputeEvents = 50; // Keep memory usage bounded

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

    // Enhanced debug logging with clear explanations
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

  /// Log a RIVET recompute operation for telemetry
  void logRecompute({
    required String userId,
    required String operation, // 'apply', 'delete', 'edit'
    required int eventCount,
    required Duration recomputeTime,
    required RivetGateDecision? finalDecision,
    String? eventId,
  }) {
    final recomputeEvent = _RivetRecomputeEvent(
      timestamp: DateTime.now(),
      userId: userId,
      operation: operation,
      eventCount: eventCount,
      recomputeTime: recomputeTime,
      finalDecision: finalDecision,
      eventId: eventId,
    );

    // Add to recompute events list
    _recomputeEvents.add(recomputeEvent);

    // Maintain bounded size
    if (_recomputeEvents.length > _maxRecomputeEvents) {
      _recomputeEvents.removeAt(0);
    }

    // Debug logging
    if (kDebugMode) {
      final gateStatus = finalDecision?.open == true ? "OPEN" : "CLOSED";
      print('RIVET RECOMPUTE: $operation | '
            'Events=$eventCount | '
            'Time=${recomputeTime.inMilliseconds}ms | '
            'Gate=$gateStatus${eventId != null ? ' | EventId=$eventId' : ''}');
      
      if (finalDecision != null && !finalDecision.open && finalDecision.whyNot != null) {
        print('RIVET RECOMPUTE REASON: ${finalDecision.whyNot}');
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

  /// Get telemetry summary for debugging
  Map<String, dynamic> getTelemetrySummary() {
    if (_events.isEmpty && _recomputeEvents.isEmpty) {
      return {
        'totalEvents': 0,
        'totalRecomputes': 0,
        'summary': 'No RIVET events recorded',
      };
    }

    final totalEvents = _events.length;
    final openGates = _events.where((e) => e.decision.open).length;
    final closedGates = totalEvents - openGates;
    final avgProcessingTime = _events.isNotEmpty
        ? _events.map((e) => e.processingTime.inMilliseconds).reduce((a, b) => a + b) / totalEvents
        : 0.0;

    // Recompute metrics
    final totalRecomputes = _recomputeEvents.length;
    final avgRecomputeTime = _recomputeEvents.isNotEmpty
        ? _recomputeEvents.map((e) => e.recomputeTime.inMilliseconds).reduce((a, b) => a + b) / totalRecomputes
        : 0.0;
    
    // Operation distribution
    final operationDistribution = <String, int>{};
    for (final event in _recomputeEvents) {
      operationDistribution[event.operation] = (operationDistribution[event.operation] ?? 0) + 1;
    }

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

    // Gate closure reasons
    final gateClosureReasons = <String, int>{};
    for (final event in _events) {
      if (!event.decision.open && event.decision.whyNot != null) {
        final reason = event.decision.whyNot!;
        gateClosureReasons[reason] = (gateClosureReasons[reason] ?? 0) + 1;
      }
    }

    return {
      'totalEvents': totalEvents,
      'openGates': openGates,
      'closedGates': closedGates,
      'openRate': totalEvents > 0 ? (openGates / totalEvents * 100).round() : 0,
      'avgProcessingTimeMs': avgProcessingTime.round(),
      'totalRecomputes': totalRecomputes,
      'avgRecomputeTimeMs': avgRecomputeTime.round(),
      'operationDistribution': operationDistribution,
      'phaseDistribution': phaseDistribution,
      'gateClosureReasons': gateClosureReasons,
      'recentAlign': recentAlign,
      'recentTrace': recentTrace,
      'lastEventTime': _events.isNotEmpty ? _events.last.timestamp.toIso8601String() : null,
      'lastRecomputeTime': _recomputeEvents.isNotEmpty ? _recomputeEvents.last.timestamp.toIso8601String() : null,
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

  /// Get recent recompute events for debugging
  List<Map<String, dynamic>> getRecentRecomputeEvents({int limit = 10}) {
    final events = _recomputeEvents.reversed.take(limit).toList();
    return events.map((e) => {
      'timestamp': e.timestamp.toIso8601String(),
      'userId': e.userId,
      'operation': e.operation,
      'eventCount': e.eventCount,
      'recomputeTimeMs': e.recomputeTime.inMilliseconds,
      'gateOpen': e.finalDecision?.open ?? false,
      'eventId': e.eventId,
      'whyNot': e.finalDecision?.whyNot,
    }).toList();
  }

  /// Clear all telemetry data
  void clear() {
    _events.clear();
    _recomputeEvents.clear();
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

/// Internal recompute event data structure
class _RivetRecomputeEvent {
  final DateTime timestamp;
  final String userId;
  final String operation;
  final int eventCount;
  final Duration recomputeTime;
  final RivetGateDecision? finalDecision;
  final String? eventId;

  _RivetRecomputeEvent({
    required this.timestamp,
    required this.userId,
    required this.operation,
    required this.eventCount,
    required this.recomputeTime,
    required this.finalDecision,
    this.eventId,
  });
}