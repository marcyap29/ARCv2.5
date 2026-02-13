// Crossroads: Decision capture and outcome prompt models.

import 'package:my_app/models/phase_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';

/// A single captured decision (four-prompt flow + optional outcome).
class DecisionCapture {
  final String id;
  final DateTime capturedAt;
  final PhaseLabel phaseAtCapture;
  final double sentinelScoreAtCapture;

  final String decisionStatement;
  final String lifeContext;
  final String optionsConsidered;
  final String successMarker;

  final String? outcomeLog;
  final DateTime? outcomeLoggedAt;
  final PhaseLabel? phaseAtOutcome;

  final String? linkedJournalEntryId;
  final bool includedInAggregation;

  final double triggerConfidence;
  final DecisionPhraseCategory triggerPhrase;
  final bool userInitiated;

  const DecisionCapture({
    required this.id,
    required this.capturedAt,
    required this.phaseAtCapture,
    required this.sentinelScoreAtCapture,
    required this.decisionStatement,
    required this.lifeContext,
    required this.optionsConsidered,
    required this.successMarker,
    this.outcomeLog,
    this.outcomeLoggedAt,
    this.phaseAtOutcome,
    this.linkedJournalEntryId,
    this.includedInAggregation = false,
    required this.triggerConfidence,
    required this.triggerPhrase,
    required this.userInitiated,
  });

  DecisionCapture copyWith({
    String? id,
    DateTime? capturedAt,
    PhaseLabel? phaseAtCapture,
    double? sentinelScoreAtCapture,
    String? decisionStatement,
    String? lifeContext,
    String? optionsConsidered,
    String? successMarker,
    String? outcomeLog,
    DateTime? outcomeLoggedAt,
    PhaseLabel? phaseAtOutcome,
    String? linkedJournalEntryId,
    bool? includedInAggregation,
    double? triggerConfidence,
    DecisionPhraseCategory? triggerPhrase,
    bool? userInitiated,
  }) {
    return DecisionCapture(
      id: id ?? this.id,
      capturedAt: capturedAt ?? this.capturedAt,
      phaseAtCapture: phaseAtCapture ?? this.phaseAtCapture,
      sentinelScoreAtCapture: sentinelScoreAtCapture ?? this.sentinelScoreAtCapture,
      decisionStatement: decisionStatement ?? this.decisionStatement,
      lifeContext: lifeContext ?? this.lifeContext,
      optionsConsidered: optionsConsidered ?? this.optionsConsidered,
      successMarker: successMarker ?? this.successMarker,
      outcomeLog: outcomeLog ?? this.outcomeLog,
      outcomeLoggedAt: outcomeLoggedAt ?? this.outcomeLoggedAt,
      phaseAtOutcome: phaseAtOutcome ?? this.phaseAtOutcome,
      linkedJournalEntryId: linkedJournalEntryId ?? this.linkedJournalEntryId,
      includedInAggregation: includedInAggregation ?? this.includedInAggregation,
      triggerConfidence: triggerConfidence ?? this.triggerConfidence,
      triggerPhrase: triggerPhrase ?? this.triggerPhrase,
      userInitiated: userInitiated ?? this.userInitiated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'captured_at': capturedAt.toIso8601String(),
      'phase_at_capture': phaseAtCapture.name,
      'sentinel_score_at_capture': sentinelScoreAtCapture,
      'decision_statement': decisionStatement,
      'life_context': lifeContext,
      'options_considered': optionsConsidered,
      'success_marker': successMarker,
      'outcome_log': outcomeLog,
      'outcome_logged_at': outcomeLoggedAt?.toIso8601String(),
      'phase_at_outcome': phaseAtOutcome?.name,
      'linked_journal_entry_id': linkedJournalEntryId,
      'included_in_aggregation': includedInAggregation,
      'trigger_confidence': triggerConfidence,
      'trigger_phrase': triggerPhrase.name,
      'user_initiated': userInitiated,
    };
  }

  factory DecisionCapture.fromJson(Map<String, dynamic> json) {
    return DecisionCapture(
      id: json['id'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      phaseAtCapture: PhaseLabel.values.firstWhere(
        (p) => p.name == json['phase_at_capture'],
        orElse: () => PhaseLabel.discovery,
      ),
      sentinelScoreAtCapture: (json['sentinel_score_at_capture'] as num).toDouble(),
      decisionStatement: json['decision_statement'] as String? ?? '',
      lifeContext: json['life_context'] as String? ?? '',
      optionsConsidered: json['options_considered'] as String? ?? '',
      successMarker: json['success_marker'] as String? ?? '',
      outcomeLog: json['outcome_log'] as String?,
      outcomeLoggedAt: json['outcome_logged_at'] != null
          ? DateTime.parse(json['outcome_logged_at'] as String)
          : null,
      phaseAtOutcome: json['phase_at_outcome'] != null
          ? PhaseLabel.values.firstWhere(
              (p) => p.name == json['phase_at_outcome'],
              orElse: () => PhaseLabel.discovery,
            )
          : null,
      linkedJournalEntryId: json['linked_journal_entry_id'] as String?,
      includedInAggregation: json['included_in_aggregation'] as bool? ?? false,
      triggerConfidence: (json['trigger_confidence'] as num?)?.toDouble() ?? 0.0,
      triggerPhrase: DecisionPhraseCategory.values.firstWhere(
        (p) => p.name == json['trigger_phrase'],
        orElse: () => DecisionPhraseCategory.consideration,
      ),
      userInitiated: json['user_initiated'] as bool? ?? false,
    );
  }
}

/// Scheduled prompt to revisit a decision and log outcome
class DecisionOutcomePrompt {
  final String decisionCaptureId;
  final DateTime scheduledFor;
  final bool hasBeenSurfaced;
  final DateTime? surfacedAt;
  final bool completed;

  const DecisionOutcomePrompt({
    required this.decisionCaptureId,
    required this.scheduledFor,
    this.hasBeenSurfaced = false,
    this.surfacedAt,
    this.completed = false,
  });

  DecisionOutcomePrompt copyWith({
    String? decisionCaptureId,
    DateTime? scheduledFor,
    bool? hasBeenSurfaced,
    DateTime? surfacedAt,
    bool? completed,
  }) {
    return DecisionOutcomePrompt(
      decisionCaptureId: decisionCaptureId ?? this.decisionCaptureId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      hasBeenSurfaced: hasBeenSurfaced ?? this.hasBeenSurfaced,
      surfacedAt: surfacedAt ?? this.surfacedAt,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'decision_capture_id': decisionCaptureId,
      'scheduled_for': scheduledFor.toIso8601String(),
      'has_been_surfaced': hasBeenSurfaced,
      'surfaced_at': surfacedAt?.toIso8601String(),
      'completed': completed,
    };
  }

  factory DecisionOutcomePrompt.fromJson(Map<String, dynamic> json) {
    return DecisionOutcomePrompt(
      decisionCaptureId: json['decision_capture_id'] as String,
      scheduledFor: DateTime.parse(json['scheduled_for'] as String),
      hasBeenSurfaced: json['has_been_surfaced'] as bool? ?? false,
      surfacedAt: json['surfaced_at'] != null
          ? DateTime.parse(json['surfaced_at'] as String)
          : null,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
