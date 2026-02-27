/// Transition Policy Integration Service
/// 
/// This service wires the unified transition policy into the journal capture flow,
/// providing seamless integration with ATLAS, RIVET, and SENTINEL systems.
/// 
/// Key responsibilities:
/// - Orchestrate policy evaluation during journal entry processing
/// - Handle policy decision outcomes (hold/promote)
/// - Provide telemetry and debugging information
/// - Manage phase transitions and notifications
/// - Integrate with existing journal capture cubit
library;

import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:my_app/policy/transition_policy.dart';
import 'package:my_app/core/models/reflective_entry_data.dart';
import 'package:my_app/prism/atlas/phase/phase_tracker.dart';
import 'package:my_app/prism/atlas/rivet/rivet_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/extractors/sentinel_risk_detector.dart';
import 'package:my_app/models/user_profile_model.dart';
// import 'package:my_app/core/services/analytics_service.dart';
// import 'package:my_app/core/services/notification_service.dart';

/// Service for integrating transition policy with journal capture flow
class TransitionIntegrationService {
  final TransitionPolicy _policy;
  final PhaseTracker _phaseTracker;
  final RivetService _rivetService;
  // final SentinelRiskDetector _sentinelDetector;
  // final AnalyticsService _analytics;
  // final NotificationService _notifications;
  final UserProfile _userProfile;

  // State tracking
  final Map<String, RivetEvent> _recentEvents = {};
  final Map<String, JournalEntryData> _recentJournalEntries = {};
  final Set<String> _independenceSet = {};

  TransitionIntegrationService({
    required TransitionPolicy policy,
    required PhaseTracker phaseTracker,
    required RivetService rivetService,
    // required SentinelRiskDetector sentinelDetector,
    // required AnalyticsService analytics,
    // required NotificationService notifications,
    required UserProfile userProfile,
  }) : _policy = policy,
       _phaseTracker = phaseTracker,
       _rivetService = rivetService,
       // _sentinelDetector = sentinelDetector,
       // _analytics = analytics,
       // _notifications = notifications,
       _userProfile = userProfile;

  /// Process a journal entry through the complete transition pipeline
  Future<TransitionProcessingResult> processJournalEntry({
    required String journalEntryId,
    required String emotion,
    required String reason,
    required String text,
    required List<String> selectedKeywords,
    required String predictedPhase,
    required String confirmedPhase,
  }) async {
    final startTime = DateTime.now();
    final telemetry = <String, dynamic>{};

    try {
      // 1. Calculate phase scores using ATLAS
      final phaseScores = await _calculatePhaseScores(
        emotion: emotion,
        reason: reason,
        text: text,
        selectedKeywords: selectedKeywords,
      );

      // 2. Update phase tracking
      final phaseResult = await _phaseTracker.updatePhaseScores(
        phaseScores: phaseScores,
        journalEntryId: journalEntryId,
        emotion: emotion,
        reason: reason,
        text: text,
      );

      // 3. Create RIVET event
      final rivetEvent = RivetEvent(
        eventId: const Uuid().v4(),
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: selectedKeywords.toSet(),
        predPhase: predictedPhase,
        refPhase: confirmedPhase,
        tolerance: _getPhaseTolerance(),
      );

      // 4. Process through RIVET
      final lastEvent = _getLastRivetEvent();
      final rivetDecision = _rivetService.ingest(rivetEvent, lastEvent: lastEvent);
      _recentEvents[journalEntryId] = rivetEvent;

      // 5. Update independence tracking
      _updateIndependenceTracking(rivetEvent, lastEvent);

      // 6. Calculate novelty score
      final noveltyScore = _calculateNoveltyScore(rivetEvent, lastEvent);

      // 7. Analyze risk with SENTINEL
      final journalEntryData = JournalEntryData(
        timestamp: DateTime.now(),
        keywords: selectedKeywords,
        phase: confirmedPhase,
        mood: emotion,
      );
      _recentJournalEntries[journalEntryId] = journalEntryData;

      final sentinelAnalysis = await _analyzeRiskWithSentinel();

      // 8. Create snapshots for policy evaluation
      final atlasSnapshot = AtlasSnapshot.fromPhaseResult(
        phaseResult,
        _userProfile.currentPhase,
        _userProfile.lastPhaseChangeAt ?? DateTime.now(),
      );

      final rivetSnapshot = RivetSnapshot.fromRivetState(
        rivetDecision.stateAfter,
        rivetDecision,
        independenceSet: _independenceSet,
        noveltyScore: noveltyScore,
      );

      final sentinelSnapshot = SentinelSnapshot.fromAnalysis(sentinelAnalysis);

      // 9. Evaluate transition policy
      final transitionOutcome = await _policy.decide(
        atlas: atlasSnapshot,
        rivet: rivetSnapshot,
        sentinel: sentinelSnapshot,
        cooldownActive: phaseResult.cooldownActive,
      );

      // 10. Handle policy decision
      final processingResult = await _handleTransitionDecision(
        transitionOutcome,
        phaseResult,
        rivetDecision,
        sentinelAnalysis,
      );

      // 11. Record telemetry
      telemetry['processing_time_ms'] = DateTime.now().difference(startTime).inMilliseconds;
      telemetry['transition_outcome'] = transitionOutcome.toJson();
      telemetry['phase_result'] = _phaseResultToJson(phaseResult);
      telemetry['rivet_decision'] = rivetDecision.toJson();
      telemetry['sentinel_analysis'] = sentinelAnalysis.toJson();

      // await _analytics.trackEvent('transition_policy_evaluation', telemetry);

      return processingResult;

    } catch (e, stackTrace) {
      // Error handling
      telemetry['error'] = e.toString();
      telemetry['stack_trace'] = stackTrace.toString();
      telemetry['processing_time_ms'] = DateTime.now().difference(startTime).inMilliseconds;

      // await _analytics.trackEvent('transition_policy_error', telemetry);

      return TransitionProcessingResult(
        success: false,
        phaseChanged: false,
        newPhase: null,
        reason: 'Error in transition processing: $e',
        telemetry: telemetry,
      );
    }
  }

  /// Calculate phase scores using ATLAS scoring system
  Future<Map<String, double>> _calculatePhaseScores({
    required String emotion,
    required String reason,
    required String text,
    required List<String> selectedKeywords,
  }) async {
    // This would integrate with the existing PhaseScoring system
    // For now, return a mock implementation
    return {
      'Discovery': 0.3,
      'Expansion': 0.4,
      'Transition': 0.2,
      'Consolidation': 0.1,
      'Recovery': 0.0,
      'Breakthrough': 0.0,
    };
  }

  /// Get phase tolerance configuration
  Map<String, double> _getPhaseTolerance() {
    return {
      'Discovery': 0.1,
      'Expansion': 0.1,
      'Transition': 0.15,
      'Consolidation': 0.1,
      'Recovery': 0.2,
      'Breakthrough': 0.1,
    };
  }

  /// Get the most recent RIVET event
  RivetEvent? _getLastRivetEvent() {
    if (_recentEvents.isEmpty) return null;
    
    final sortedEvents = _recentEvents.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    return sortedEvents.first;
  }

  /// Update independence tracking
  void _updateIndependenceTracking(RivetEvent currentEvent, RivetEvent? lastEvent) {
    if (lastEvent == null) {
      _independenceSet.add('${currentEvent.date.day}-${currentEvent.source.name}');
      return;
    }

    final differentDay = currentEvent.date.difference(lastEvent.date).inDays >= 1;
    final differentSource = currentEvent.source != lastEvent.source;

    if (differentDay || differentSource) {
      _independenceSet.add('${currentEvent.date.day}-${currentEvent.source.name}');
    }
  }

  /// Calculate novelty score based on keyword drift
  double _calculateNoveltyScore(RivetEvent currentEvent, RivetEvent? lastEvent) {
    if (lastEvent == null) return 0.0;

    final currentKeywords = currentEvent.keywords;
    final lastKeywords = lastEvent.keywords;

    if (currentKeywords.isEmpty && lastKeywords.isEmpty) return 0.0;

    final intersection = currentKeywords.intersection(lastKeywords).length.toDouble();
    final union = currentKeywords.union(lastKeywords).length.toDouble();

    if (union == 0) return 0.0;

    final jaccard = intersection / union;
    return 1.0 - jaccard; // Higher drift = higher novelty
  }

  /// Analyze risk with SENTINEL
  Future<SentinelAnalysis> _analyzeRiskWithSentinel() async {
    final entries = _recentJournalEntries.values.toList();
    
    // Convert JournalEntryData to ReflectiveEntryData for SentinelRiskDetector
    final reflectiveEntries = entries.map((entry) => ReflectiveEntryData.fromJournalEntry(
      timestamp: entry.timestamp,
      keywords: entry.keywords,
      phase: entry.phase,
      mood: entry.mood,
    )).toList();
    
    return SentinelRiskDetector.analyzeRisk(
      entries: reflectiveEntries,
      timeWindow: TimeWindow.twoWeek,
    );
  }

  /// Handle transition decision outcome
  Future<TransitionProcessingResult> _handleTransitionDecision(
    TransitionOutcome outcome,
    PhaseTrackingResult phaseResult,
    RivetGateDecision rivetDecision,
    SentinelAnalysis sentinelAnalysis,
  ) async {
    if (outcome.decision == TransitionDecision.promote) {
      // Phase change approved
      await _executePhaseChange(phaseResult);
      
      // Send notification
      // await _notifications.showPhaseChangeNotification(
      //   newPhase: phaseResult.newPhase!,
      //   previousPhase: phaseResult.previousPhase!,
      //   reason: outcome.reason,
      // );

      return TransitionProcessingResult(
        success: true,
        phaseChanged: true,
        newPhase: phaseResult.newPhase,
        reason: outcome.reason,
        telemetry: outcome.telemetry,
      );
    } else {
      // Phase change blocked
      await _handlePhaseChangeBlocked(outcome, phaseResult, rivetDecision, sentinelAnalysis);

      return TransitionProcessingResult(
        success: true,
        phaseChanged: false,
        newPhase: null,
        reason: outcome.reason,
        telemetry: outcome.telemetry,
      );
    }
  }

  /// Execute phase change
  Future<void> _executePhaseChange(PhaseTrackingResult phaseResult) async {
    // Update user profile
    // _userProfile.currentPhase = phaseResult.newPhase!;
    // _userProfile.lastPhaseChangeAt = DateTime.now();
    
    // Save to persistent storage
    // await _userProfile.save();

    // Track analytics
    // await _analytics.trackEvent('phase_change_executed', {
    //   'new_phase': phaseResult.newPhase,
    //   'previous_phase': phaseResult.previousPhase,
    //   'reason': phaseResult.reason,
    // });
  }

  /// Handle blocked phase change
  Future<void> _handlePhaseChangeBlocked(
    TransitionOutcome outcome,
    PhaseTrackingResult phaseResult,
    RivetGateDecision rivetDecision,
    SentinelAnalysis sentinelAnalysis,
  ) async {
    // Log the blocking reason
    // await _analytics.trackEvent('phase_change_blocked', {
    //   'reason': outcome.reason,
    //   'atlas_margin': phaseResult.smoothedScores.values.fold(0.0, (a, b) => a > b ? a : b),
    //   'rivet_align': rivetDecision.stateAfter.align,
    //   'rivet_trace': rivetDecision.stateAfter.trace,
    //   'sentinel_risk': sentinelAnalysis.riskScore,
    // });

    // Send user feedback if risk is high
    // if (sentinelAnalysis.riskLevel.index > RiskLevel.moderate.index) {
    //   await _notifications.showRiskAlert(
    //     riskLevel: sentinelAnalysis.riskLevel,
    //     recommendations: sentinelAnalysis.recommendations,
    //   );
    // }
  }

  /// Convert phase result to JSON
  Map<String, dynamic> _phaseResultToJson(PhaseTrackingResult result) => {
    'phase_changed': result.phaseChanged,
    'new_phase': result.newPhase,
    'previous_phase': result.previousPhase,
    'smoothed_scores': result.smoothedScores,
    'reason': result.reason,
    'cooldown_active': result.cooldownActive,
    'hysteresis_blocked': result.hysteresisBlocked,
  };
}

/// Result of transition processing
class TransitionProcessingResult {
  final bool success;
  final bool phaseChanged;
  final String? newPhase;
  final String reason;
  final Map<String, dynamic> telemetry;

  const TransitionProcessingResult({
    required this.success,
    required this.phaseChanged,
    this.newPhase,
    required this.reason,
    required this.telemetry,
  });

  @override
  String toString() => 'TransitionProcessingResult(success: $success, phaseChanged: $phaseChanged, newPhase: $newPhase)';
}

/// Factory for creating transition integration service
class TransitionIntegrationServiceFactory {
  /// Create service with production configuration
  static Future<TransitionIntegrationService> createProduction({
    required UserProfile userProfile,
    // required AnalyticsService analytics,
    // required NotificationService notifications,
  }) async {
    final policy = TransitionPolicyFactory.createProduction();
    final phaseTracker = PhaseTracker(userProfile: userProfile);
    final rivetService = RivetService();
    // final sentinelDetector = SentinelRiskDetector();

    return TransitionIntegrationService(
      policy: policy,
      phaseTracker: phaseTracker,
      rivetService: rivetService,
      // sentinelDetector: sentinelDetector,
      // analytics: analytics,
      // notifications: notifications,
      userProfile: userProfile,
    );
  }

  /// Create service with custom configuration
  static Future<TransitionIntegrationService> createCustom({
    required TransitionPolicyConfig config,
    required UserProfile userProfile,
    // required AnalyticsService analytics,
    // required NotificationService notifications,
  }) async {
    final policy = TransitionPolicyFactory.createCustom(config);
    final phaseTracker = PhaseTracker(userProfile: userProfile);
    final rivetService = RivetService();
    // final sentinelDetector = SentinelRiskDetector();

    return TransitionIntegrationService(
      policy: policy,
      phaseTracker: phaseTracker,
      rivetService: rivetService,
      // sentinelDetector: sentinelDetector,
      // analytics: analytics,
      // notifications: notifications,
      userProfile: userProfile,
    );
  }
}
