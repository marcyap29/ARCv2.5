import 'package:equatable/equatable.dart';
import 'incident_template_models.dart';

/// Legacy model for backward compatibility
/// Maps to IncidentTemplate internally
class IncidentReport extends Equatable {
  final String id;
  final IncidentType type;
  final AARData aarData;
  final SAGEData sageData;
  final List<IncidentTag> tags;
  final List<String> customTags;
  final int stressLevel;
  final SeverityLevel severityLevel;
  final String location;
  final Duration duration;
  final List<String> personnelInvolved;
  final List<String> equipmentUsed;
  final String lessonsLearned;
  final String recommendations;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncidentReport({
    required this.id,
    required this.type,
    required this.aarData,
    required this.sageData,
    required this.tags,
    required this.customTags,
    required this.stressLevel,
    required this.severityLevel,
    required this.location,
    required this.duration,
    required this.personnelInvolved,
    required this.equipmentUsed,
    required this.lessonsLearned,
    required this.recommendations,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id, type, aarData, sageData, tags, customTags, stressLevel,
    severityLevel, location, duration, personnelInvolved, equipmentUsed,
    lessonsLearned, recommendations, createdAt, updatedAt,
  ];
}

/// AAR (After Action Review) data
class AARData extends Equatable {
  final String situation;
  final String awareness;
  final List<String> goals;
  final String environment;
  final List<String> actionsCompleted;
  final List<String> challengesFaced;
  final List<String> resourcesUsed;
  final String outcome;

  const AARData({
    this.situation = '',
    this.awareness = '',
    this.goals = const [],
    this.environment = '',
    this.actionsCompleted = const [],
    this.challengesFaced = const [],
    this.resourcesUsed = const [],
    this.outcome = '',
  });

  AARData copyWith({
    String? situation,
    String? awareness,
    List<String>? goals,
    String? environment,
    List<String>? actionsCompleted,
    List<String>? challengesFaced,
    List<String>? resourcesUsed,
    String? outcome,
  }) {
    return AARData(
      situation: situation ?? this.situation,
      awareness: awareness ?? this.awareness,
      goals: goals ?? this.goals,
      environment: environment ?? this.environment,
      actionsCompleted: actionsCompleted ?? this.actionsCompleted,
      challengesFaced: challengesFaced ?? this.challengesFaced,
      resourcesUsed: resourcesUsed ?? this.resourcesUsed,
      outcome: outcome ?? this.outcome,
    );
  }

  @override
  List<Object?> get props => [
    situation, awareness, goals, environment, actionsCompleted,
    challengesFaced, resourcesUsed, outcome,
  ];
}

/// SAGE (Situation, Awareness, Goals, Environment) data
class SAGEData extends Equatable {
  final String situation;
  final String awareness;
  final List<String> goals;
  final String environment;
  final List<String> wentWell;
  final List<String> couldImprove;
  final String keyLearning;
  final String futureConsiderations;

  const SAGEData({
    this.situation = '',
    this.awareness = '',
    this.goals = const [],
    this.environment = '',
    this.wentWell = const [],
    this.couldImprove = const [],
    this.keyLearning = '',
    this.futureConsiderations = '',
  });

  SAGEData copyWith({
    String? situation,
    String? awareness,
    List<String>? goals,
    String? environment,
    List<String>? wentWell,
    List<String>? couldImprove,
    String? keyLearning,
    String? futureConsiderations,
  }) {
    return SAGEData(
      situation: situation ?? this.situation,
      awareness: awareness ?? this.awareness,
      goals: goals ?? this.goals,
      environment: environment ?? this.environment,
      wentWell: wentWell ?? this.wentWell,
      couldImprove: couldImprove ?? this.couldImprove,
      keyLearning: keyLearning ?? this.keyLearning,
      futureConsiderations: futureConsiderations ?? this.futureConsiderations,
    );
  }

  @override
  List<Object?> get props => [
    situation, awareness, goals, environment, wentWell,
    couldImprove, keyLearning, futureConsiderations,
  ];
}

/// Incident tags for categorization
enum IncidentTag {
  training,
  realWorld,
  highStress,
  lowStress,
  successful,
  challenging,
  routine,
  complex,
  multiUnit,
  singleUnit,
  dayShift,
  nightShift,
  weekend,
  holiday,
}

extension IncidentTagExtension on IncidentTag {
  String get displayName {
    switch (this) {
      case IncidentTag.training: return 'Training';
      case IncidentTag.realWorld: return 'Real World';
      case IncidentTag.highStress: return 'High Stress';
      case IncidentTag.lowStress: return 'Low Stress';
      case IncidentTag.successful: return 'Successful';
      case IncidentTag.challenging: return 'Challenging';
      case IncidentTag.routine: return 'Routine';
      case IncidentTag.complex: return 'Complex';
      case IncidentTag.multiUnit: return 'Multi-Unit';
      case IncidentTag.singleUnit: return 'Single Unit';
      case IncidentTag.dayShift: return 'Day Shift';
      case IncidentTag.nightShift: return 'Night Shift';
      case IncidentTag.weekend: return 'Weekend';
      case IncidentTag.holiday: return 'Holiday';
    }
  }
}

/// Severity levels for incidents
enum SeverityLevel {
  low,
  medium,
  high,
  critical,
}

extension SeverityLevelExtension on SeverityLevel {
  String get displayName {
    switch (this) {
      case SeverityLevel.low: return 'Low';
      case SeverityLevel.medium: return 'Medium';
      case SeverityLevel.high: return 'High';
      case SeverityLevel.critical: return 'Critical';
    }
  }
}
