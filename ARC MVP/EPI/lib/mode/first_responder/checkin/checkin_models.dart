import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'checkin_models.g.dart';

/// P31: Quick Check-in Models
/// Simple wellness datapoints for first responders

@HiveType(typeId: 50)
class CheckIn extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final int stressLevel; // 0-10
  
  @HiveField(2)
  final int sleepHours; // Hours of sleep last night
  
  @HiveField(3)
  final bool hasIntrusiveThoughts; // Yes/No
  
  @HiveField(4)
  final bool usedSupport; // Did you use support resources?
  
  @HiveField(5)
  final String? notes; // Optional notes
  
  @HiveField(6)
  final DateTime timestamp;
  
  @HiveField(7)
  final String? shiftId; // Optional shift identifier
  
  @HiveField(8)
  final List<String> triggers; // What triggered this check-in

  const CheckIn({
    required this.id,
    required this.stressLevel,
    required this.sleepHours,
    required this.hasIntrusiveThoughts,
    required this.usedSupport,
    this.notes,
    required this.timestamp,
    this.shiftId,
    this.triggers = const [],
  });

  factory CheckIn.create({
    required int stressLevel,
    required int sleepHours,
    required bool hasIntrusiveThoughts,
    required bool usedSupport,
    String? notes,
    String? shiftId,
    List<String> triggers = const [],
  }) {
    return CheckIn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      stressLevel: stressLevel,
      sleepHours: sleepHours,
      hasIntrusiveThoughts: hasIntrusiveThoughts,
      usedSupport: usedSupport,
      notes: notes,
      timestamp: DateTime.now(),
      shiftId: shiftId,
      triggers: triggers,
    );
  }

  CheckIn copyWith({
    String? id,
    int? stressLevel,
    int? sleepHours,
    bool? hasIntrusiveThoughts,
    bool? usedSupport,
    String? notes,
    DateTime? timestamp,
    String? shiftId,
    List<String>? triggers,
  }) {
    return CheckIn(
      id: id ?? this.id,
      stressLevel: stressLevel ?? this.stressLevel,
      sleepHours: sleepHours ?? this.sleepHours,
      hasIntrusiveThoughts: hasIntrusiveThoughts ?? this.hasIntrusiveThoughts,
      usedSupport: usedSupport ?? this.usedSupport,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      shiftId: shiftId ?? this.shiftId,
      triggers: triggers ?? this.triggers,
    );
  }

  /// Get stress level description
  String get stressDescription {
    if (stressLevel <= 2) return 'Very Low';
    if (stressLevel <= 4) return 'Low';
    if (stressLevel <= 6) return 'Moderate';
    if (stressLevel <= 8) return 'High';
    return 'Very High';
  }

  /// Get stress level color
  String get stressColor {
    if (stressLevel <= 2) return 'green';
    if (stressLevel <= 4) return 'yellow';
    if (stressLevel <= 6) return 'orange';
    if (stressLevel <= 8) return 'red';
    return 'dark_red';
  }

  /// Check if grounding is recommended
  bool get needsGrounding => stressLevel >= 7 || hasIntrusiveThoughts;

  /// Get sleep quality description
  String get sleepDescription {
    if (sleepHours >= 8) return 'Excellent';
    if (sleepHours >= 7) return 'Good';
    if (sleepHours >= 6) return 'Fair';
    if (sleepHours >= 4) return 'Poor';
    return 'Very Poor';
  }

  @override
  List<Object?> get props => [
        id,
        stressLevel,
        sleepHours,
        hasIntrusiveThoughts,
        usedSupport,
        notes,
        timestamp,
        shiftId,
        triggers,
      ];
}

/// Check-in patterns and trends
@HiveType(typeId: 51)
class CheckInPattern extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime startDate;
  
  @HiveField(2)
  final DateTime endDate;
  
  @HiveField(3)
  final double averageStress;
  
  @HiveField(4)
  final double averageSleep;
  
  @HiveField(5)
  final int totalCheckIns;
  
  @HiveField(6)
  final int highStressDays; // Days with stress >= 7
  
  @HiveField(7)
  final int intrusiveThoughtDays; // Days with intrusive thoughts
  
  @HiveField(8)
  final int supportUsedDays; // Days when support was used
  
  @HiveField(9)
  final List<String> commonTriggers;
  
  @HiveField(10)
  final String insights; // AI-generated insights

  const CheckInPattern({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.averageStress,
    required this.averageSleep,
    required this.totalCheckIns,
    required this.highStressDays,
    required this.intrusiveThoughtDays,
    required this.supportUsedDays,
    required this.commonTriggers,
    required this.insights,
  });

  /// Get pattern duration in days
  int get durationDays => endDate.difference(startDate).inDays + 1;

  /// Get high stress percentage
  double get highStressPercentage => (highStressDays / durationDays) * 100;

  /// Get intrusive thoughts percentage
  double get intrusiveThoughtsPercentage => (intrusiveThoughtDays / durationDays) * 100;

  /// Get support usage percentage
  double get supportUsagePercentage => (supportUsedDays / durationDays) * 100;

  /// Check if pattern shows concerning trends
  bool get hasConcerningTrends => 
      highStressPercentage > 30 || 
      intrusiveThoughtsPercentage > 20 ||
      averageSleep < 6;

  @override
  List<Object?> get props => [
        id,
        startDate,
        endDate,
        averageStress,
        averageSleep,
        totalCheckIns,
        highStressDays,
        intrusiveThoughtDays,
        supportUsedDays,
        commonTriggers,
        insights,
      ];
}

/// Predefined check-in triggers
enum CheckInTrigger {
  endOfShift,
  afterCall,
  beforeShift,
  duringBreak,
  afterIncident,
  personal,
  scheduled,
  other,
}

extension CheckInTriggerExtension on CheckInTrigger {
  String get label {
    switch (this) {
      case CheckInTrigger.endOfShift:
        return 'End of Shift';
      case CheckInTrigger.afterCall:
        return 'After Call';
      case CheckInTrigger.beforeShift:
        return 'Before Shift';
      case CheckInTrigger.duringBreak:
        return 'During Break';
      case CheckInTrigger.afterIncident:
        return 'After Incident';
      case CheckInTrigger.personal:
        return 'Personal';
      case CheckInTrigger.scheduled:
        return 'Scheduled';
      case CheckInTrigger.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case CheckInTrigger.endOfShift:
        return '🏁';
      case CheckInTrigger.afterCall:
        return '📞';
      case CheckInTrigger.beforeShift:
        return '🌅';
      case CheckInTrigger.duringBreak:
        return '☕';
      case CheckInTrigger.afterIncident:
        return '🚨';
      case CheckInTrigger.personal:
        return '👤';
      case CheckInTrigger.scheduled:
        return '⏰';
      case CheckInTrigger.other:
        return '❓';
    }
  }
}

/// Check-in statistics
class CheckInStatistics {
  final int totalCheckIns;
  final double averageStress;
  final double averageSleep;
  final int highStressDays;
  final int intrusiveThoughtDays;
  final int supportUsedDays;
  final List<String> topTriggers;
  final String trendInsights;

  const CheckInStatistics({
    required this.totalCheckIns,
    required this.averageStress,
    required this.averageSleep,
    required this.highStressDays,
    required this.intrusiveThoughtDays,
    required this.supportUsedDays,
    required this.topTriggers,
    required this.trendInsights,
  });

  /// Get high stress percentage
  double get highStressPercentage => totalCheckIns > 0 ? (highStressDays / totalCheckIns) * 100 : 0;

  /// Get intrusive thoughts percentage
  double get intrusiveThoughtsPercentage => totalCheckIns > 0 ? (intrusiveThoughtDays / totalCheckIns) * 100 : 0;

  /// Get support usage percentage
  double get supportUsagePercentage => totalCheckIns > 0 ? (supportUsedDays / totalCheckIns) * 100 : 0;

  /// Check if statistics show concerning patterns
  bool get hasConcerningPatterns => 
      highStressPercentage > 30 || 
      intrusiveThoughtsPercentage > 20 ||
      averageSleep < 6;
}
