import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'aurora_lite_models.g.dart';

/// P33: AURORA-Lite Shift Rhythm Models
/// Manages shift-aware prompts and recovery recommendations

@HiveType(typeId: 60)
class ShiftSchedule extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final List<Shift> shifts;
  
  @HiveField(3)
  final bool isActive;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final DateTime? updatedAt;

  const ShiftSchedule({
    required this.id,
    required this.name,
    required this.shifts,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ShiftSchedule.create({
    required String name,
    required List<Shift> shifts,
  }) {
    return ShiftSchedule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      shifts: shifts,
      createdAt: DateTime.now(),
    );
  }

  ShiftSchedule copyWith({
    String? id,
    String? name,
    List<Shift>? shifts,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShiftSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      shifts: shifts ?? this.shifts,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, shifts, isActive, createdAt, updatedAt];
}

@HiveType(typeId: 61)
class Shift extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday
  
  @HiveField(3)
  final int startHour;
  
  @HiveField(4)
  final int startMinute;
  
  @HiveField(5)
  final int endHour;
  
  @HiveField(6)
  final int endMinute;
  
  @HiveField(7)
  final String? notes;

  const Shift({
    required this.id,
    required this.name,
    required this.daysOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.notes,
  });

  factory Shift.create({
    required String name,
    required List<int> daysOfWeek,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? notes,
  }) {
    return Shift(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      daysOfWeek: daysOfWeek,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      notes: notes,
    );
  }

  /// Get formatted time range
  String get timeRange {
    final startTime = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final endTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    return '$startTime - $endTime';
  }

  /// Get formatted days of week
  String get daysDisplay {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return daysOfWeek.map((day) => dayNames[day - 1]).join(', ');
  }

  @override
  List<Object?> get props => [id, name, daysOfWeek, startHour, startMinute, endHour, endMinute, notes];
}

/// Shift status information
class ShiftStatus extends Equatable {
  final bool isOnShift;
  final Duration? timeUntilNextShift;
  final Duration? timeSinceLastShift;
  final ShiftPhase currentPhase;
  final List<ShiftAction> recommendedActions;

  const ShiftStatus({
    required this.isOnShift,
    this.timeUntilNextShift,
    this.timeSinceLastShift,
    required this.currentPhase,
    required this.recommendedActions,
  });

  @override
  List<Object?> get props => [isOnShift, timeUntilNextShift, timeSinceLastShift, currentPhase, recommendedActions];
}

/// Shift phases
@HiveType(typeId: 62)
enum ShiftPhase {
  @HiveField(0)
  onDuty,
  @HiveField(1)
  immediateRecovery, // 0-12 hours after shift
  @HiveField(2)
  shortTermRecovery, // 12-48 hours after shift
  @HiveField(3)
  longTermRecovery, // 2+ days after shift
  @HiveField(4)
  offDuty, // No recent shifts
}

extension ShiftPhaseExtension on ShiftPhase {
  String get displayName {
    switch (this) {
      case ShiftPhase.onDuty:
        return 'On Duty';
      case ShiftPhase.immediateRecovery:
        return 'Immediate Recovery';
      case ShiftPhase.shortTermRecovery:
        return 'Short-term Recovery';
      case ShiftPhase.longTermRecovery:
        return 'Long-term Recovery';
      case ShiftPhase.offDuty:
        return 'Off Duty';
    }
  }

  String get description {
    switch (this) {
      case ShiftPhase.onDuty:
        return 'Currently on shift';
      case ShiftPhase.immediateRecovery:
        return 'Just finished shift - focus on immediate recovery';
      case ShiftPhase.shortTermRecovery:
        return 'Early recovery phase - monitor stress levels';
      case ShiftPhase.longTermRecovery:
        return 'Extended recovery phase - maintain wellness';
      case ShiftPhase.offDuty:
        return 'No recent shifts - maintain general wellness';
    }
  }
}

/// Shift actions
class ShiftAction extends Equatable {
  final String id;
  final String title;
  final String description;
  final ActionType type;
  final int priority; // 1-10, higher = more important
  final int estimatedMinutes;

  const ShiftAction({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.estimatedMinutes,
  });

  @override
  List<Object?> get props => [id, title, description, type, priority, estimatedMinutes];
}

/// Action types
@HiveType(typeId: 63)
enum ActionType {
  @HiveField(0)
  checkIn,
  @HiveField(1)
  debrief,
  @HiveField(2)
  grounding,
  @HiveField(3)
  wellness,
  @HiveField(4)
  reflection,
  @HiveField(5)
  support,
}

extension ActionTypeExtension on ActionType {
  String get displayName {
    switch (this) {
      case ActionType.checkIn:
        return 'Check-in';
      case ActionType.debrief:
        return 'Debrief';
      case ActionType.grounding:
        return 'Grounding';
      case ActionType.wellness:
        return 'Wellness';
      case ActionType.reflection:
        return 'Reflection';
      case ActionType.support:
        return 'Support';
    }
  }

  String get icon {
    switch (this) {
      case ActionType.checkIn:
        return '📊';
      case ActionType.debrief:
        return '💭';
      case ActionType.grounding:
        return '🧘';
      case ActionType.wellness:
        return '💚';
      case ActionType.reflection:
        return '🤔';
      case ActionType.support:
        return '🤝';
    }
  }
}

/// Shift prompts
class ShiftPrompt extends Equatable {
  final String id;
  final String title;
  final String message;
  final PromptType type;
  final int priority;
  final int estimatedMinutes;
  final DateTime? scheduledFor;
  final bool isCompleted;

  const ShiftPrompt({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.estimatedMinutes,
    this.scheduledFor,
    this.isCompleted = false,
  });

  @override
  List<Object?> get props => [id, title, message, type, priority, estimatedMinutes, scheduledFor, isCompleted];
}

/// Prompt types
@HiveType(typeId: 64)
enum PromptType {
  @HiveField(0)
  checkIn,
  @HiveField(1)
  debrief,
  @HiveField(2)
  recovery,
  @HiveField(3)
  wellness,
  @HiveField(4)
  reminder,
}

extension PromptTypeExtension on PromptType {
  String get displayName {
    switch (this) {
      case PromptType.checkIn:
        return 'Check-in';
      case PromptType.debrief:
        return 'Debrief';
      case PromptType.recovery:
        return 'Recovery';
      case PromptType.wellness:
        return 'Wellness';
      case PromptType.reminder:
        return 'Reminder';
    }
  }
}

/// Recovery recommendations
class RecoveryRecommendation extends Equatable {
  final double stressLevel;
  final double sleepQuality;
  final int incidentCount;
  final int debriefCount;
  final List<String> recommendations;
  final UrgencyLevel urgencyLevel;

  const RecoveryRecommendation({
    required this.stressLevel,
    required this.sleepQuality,
    required this.incidentCount,
    required this.debriefCount,
    required this.recommendations,
    required this.urgencyLevel,
  });

  @override
  List<Object?> get props => [stressLevel, sleepQuality, incidentCount, debriefCount, recommendations, urgencyLevel];
}

/// Urgency levels
@HiveType(typeId: 65)
enum UrgencyLevel {
  @HiveField(0)
  low,
  @HiveField(1)
  medium,
  @HiveField(2)
  high,
}

extension UrgencyLevelExtension on UrgencyLevel {
  String get displayName {
    switch (this) {
      case UrgencyLevel.low:
        return 'Low';
      case UrgencyLevel.medium:
        return 'Medium';
      case UrgencyLevel.high:
        return 'High';
    }
  }

  String get color {
    switch (this) {
      case UrgencyLevel.low:
        return 'green';
      case UrgencyLevel.medium:
        return 'orange';
      case UrgencyLevel.high:
        return 'red';
    }
  }
}

/// Recent activity analysis
class RecentActivity extends Equatable {
  final double averageStress;
  final double averageSleep;
  final int recentDebriefs;
  final int recentIncidents;
  final int highStressDays;

  const RecentActivity({
    required this.averageStress,
    required this.averageSleep,
    required this.recentDebriefs,
    required this.recentIncidents,
    required this.highStressDays,
  });

  @override
  List<Object?> get props => [averageStress, averageSleep, recentDebriefs, recentIncidents, highStressDays];
}

/// Shift statistics
class ShiftStatistics extends Equatable {
  final int periodDays;
  final int totalCheckIns;
  final int totalDebriefs;
  final int totalIncidents;
  final double averageStress;
  final double averageSleep;
  final int highStressDays;
  final int recoveryDays;
  final TrendAnalysis trendAnalysis;

  const ShiftStatistics({
    required this.periodDays,
    required this.totalCheckIns,
    required this.totalDebriefs,
    required this.totalIncidents,
    required this.averageStress,
    required this.averageSleep,
    required this.highStressDays,
    required this.recoveryDays,
    required this.trendAnalysis,
  });

  /// Get stress level description
  String get stressDescription {
    if (averageStress <= 3) return 'Low';
    if (averageStress <= 5) return 'Moderate';
    if (averageStress <= 7) return 'High';
    return 'Very High';
  }

  /// Get sleep quality description
  String get sleepDescription {
    if (averageSleep >= 8) return 'Excellent';
    if (averageSleep >= 7) return 'Good';
    if (averageSleep >= 6) return 'Fair';
    return 'Poor';
  }

  /// Get recovery percentage
  double get recoveryPercentage {
    if (periodDays == 0) return 0.0;
    return (recoveryDays / periodDays) * 100;
  }

  @override
  List<Object?> get props => [
        periodDays,
        totalCheckIns,
        totalDebriefs,
        totalIncidents,
        averageStress,
        averageSleep,
        highStressDays,
        recoveryDays,
        trendAnalysis,
      ];
}

/// Trend analysis
class TrendAnalysis extends Equatable {
  final TrendDirection stressTrend;
  final TrendDirection sleepTrend;
  final double debriefFrequency;
  final double incidentFrequency;

  const TrendAnalysis({
    required this.stressTrend,
    required this.sleepTrend,
    required this.debriefFrequency,
    required this.incidentFrequency,
  });

  @override
  List<Object?> get props => [stressTrend, sleepTrend, debriefFrequency, incidentFrequency];
}

/// Trend directions
@HiveType(typeId: 66)
enum TrendDirection {
  @HiveField(0)
  increasing,
  @HiveField(1)
  decreasing,
  @HiveField(2)
  stable,
}

extension TrendDirectionExtension on TrendDirection {
  String get displayName {
    switch (this) {
      case TrendDirection.increasing:
        return 'Increasing';
      case TrendDirection.decreasing:
        return 'Decreasing';
      case TrendDirection.stable:
        return 'Stable';
    }
  }

  String get icon {
    switch (this) {
      case TrendDirection.increasing:
        return '📈';
      case TrendDirection.decreasing:
        return '📉';
      case TrendDirection.stable:
        return '➡️';
    }
  }
}
