import 'dart:math' as math;
import 'package:my_app/models/journal_entry_model.dart';

/// User cadence metrics
class UserCadenceMetrics {
  final double avgDaysBetween;
  final double stdDev;
  final int totalEntries;
  final int windowDays;
  final bool isSporadic;
  final bool hasInsufficientData;

  UserCadenceMetrics({
    required this.avgDaysBetween,
    required this.stdDev,
    required this.totalEntries,
    required this.windowDays,
    this.isSporadic = false,
    this.hasInsufficientData = false,
  });

  factory UserCadenceMetrics.insufficient_data() {
    return UserCadenceMetrics(
      avgDaysBetween: 0.0,
      stdDev: 0.0,
      totalEntries: 0,
      windowDays: 30,
      hasInsufficientData: true,
    );
  }

  factory UserCadenceMetrics.sporadic() {
    return UserCadenceMetrics(
      avgDaysBetween: 30.0,
      stdDev: 0.0,
      totalEntries: 0,
      windowDays: 30,
      isSporadic: true,
    );
  }
}

/// User type classification
enum UserType {
  powerUser,      // Daily/near-daily journaling (≤ 2 days)
  frequent,       // 2-3 times per week (2-4 days)
  weekly,         // Once per week (4-9 days)
  sporadic,       // Less than weekly (> 9 days)
  insufficientData, // < 5 entries
}

/// User cadence detector
class UserCadenceDetector {
  static const int DEFAULT_WINDOW_DAYS = 30;
  static const int MIN_ENTRIES_FOR_DETECTION = 5;
  static const int MAX_GAP_DAYS = 30; // Gaps > 30 days = breaks, not pattern

  /// Calculate user cadence from journal entries
  static UserCadenceMetrics calculateCadence(List<JournalEntry> entries) {
    if (entries.length < MIN_ENTRIES_FOR_DETECTION) {
      return UserCadenceMetrics.insufficient_data();
    }

    // Sort entries by createdAt
    final sortedEntries = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Calculate days between consecutive entries
    final List<int> daysBetweenEntries = [];
    for (int i = 1; i < sortedEntries.length; i++) {
      final daysDiff = sortedEntries[i].createdAt
          .difference(sortedEntries[i - 1].createdAt)
          .inDays;
      daysBetweenEntries.add(daysDiff);
    }

    // Filter outliers (gaps > 30 days = breaks, not pattern)
    final filteredGaps = daysBetweenEntries
        .where((days) => days <= MAX_GAP_DAYS)
        .toList();

    if (filteredGaps.isEmpty) {
      return UserCadenceMetrics.sporadic();
    }

    // Calculate average
    final avgDaysBetween = filteredGaps.reduce((a, b) => a + b) /
        filteredGaps.length;

    // Calculate standard deviation
    final stdDev = _calculateStdDev(filteredGaps, avgDaysBetween);

    return UserCadenceMetrics(
      avgDaysBetween: avgDaysBetween,
      stdDev: stdDev,
      totalEntries: entries.length,
      windowDays: DEFAULT_WINDOW_DAYS,
    );
  }

  /// Calculate standard deviation
  static double _calculateStdDev(List<int> values, double mean) {
    if (values.isEmpty) return 0.0;

    final sumSquaredDiff = values
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b);

    return math.sqrt(sumSquaredDiff / values.length);
  }
}

/// User type classifier
class UserTypeClassifier {
  static const int RECALCULATION_THRESHOLD = 10;

  /// Classify user type from cadence metrics
  static UserType classifyUser(UserCadenceMetrics metrics) {
    if (metrics.hasInsufficientData) {
      return UserType.insufficientData;
    }

    if (metrics.isSporadic) {
      return UserType.sporadic;
    }

    final avg = metrics.avgDaysBetween;

    if (avg <= 2.0) {
      return UserType.powerUser;
    } else if (avg <= 4.0) {
      return UserType.frequent;
    } else if (avg <= 9.0) {
      return UserType.weekly;
    } else {
      return UserType.sporadic;
    }
  }

  /// Check if cadence should be recalculated
  static bool shouldRecalculate(int entriesSinceLastCalc) {
    return entriesSinceLastCalc >= RECALCULATION_THRESHOLD;
  }
}

/// User cadence profile
class UserCadenceProfile {
  final UserType currentType;
  final UserCadenceMetrics metrics;
  final DateTime lastCalculated;
  final int entriesAtLastCalculation;
  final List<UserTypeTransition> typeHistory;

  UserCadenceProfile({
    required this.currentType,
    required this.metrics,
    required this.lastCalculated,
    required this.entriesAtLastCalculation,
    this.typeHistory = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'currentType': currentType.name,
      'metrics': {
        'avgDaysBetween': metrics.avgDaysBetween,
        'stdDev': metrics.stdDev,
        'totalEntries': metrics.totalEntries,
        'windowDays': metrics.windowDays,
      },
      'lastCalculated': lastCalculated.toIso8601String(),
      'entriesAtLastCalculation': entriesAtLastCalculation,
      'typeHistory': typeHistory.map((t) => t.toJson()).toList(),
    };
  }

  factory UserCadenceProfile.fromJson(Map<String, dynamic> json) {
    return UserCadenceProfile(
      currentType: UserType.values.firstWhere(
        (e) => e.name == json['currentType'],
        orElse: () => UserType.insufficientData,
      ),
      metrics: UserCadenceMetrics(
        avgDaysBetween: (json['metrics'] as Map)['avgDaysBetween'] as double,
        stdDev: (json['metrics'] as Map)['stdDev'] as double,
        totalEntries: (json['metrics'] as Map)['totalEntries'] as int,
        windowDays: (json['metrics'] as Map)['windowDays'] as int,
      ),
      lastCalculated: DateTime.parse(json['lastCalculated'] as String),
      entriesAtLastCalculation: json['entriesAtLastCalculation'] as int,
      typeHistory: (json['typeHistory'] as List)
          .map((t) => UserTypeTransition.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// User type transition record
class UserTypeTransition {
  final UserType fromType;
  final UserType toType;
  final DateTime transitionDate;
  final int totalEntriesAtTransition;

  UserTypeTransition({
    required this.fromType,
    required this.toType,
    required this.transitionDate,
    required this.totalEntriesAtTransition,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromType': fromType.name,
      'toType': toType.name,
      'transitionDate': transitionDate.toIso8601String(),
      'totalEntriesAtTransition': totalEntriesAtTransition,
    };
  }

  factory UserTypeTransition.fromJson(Map<String, dynamic> json) {
    return UserTypeTransition(
      fromType: UserType.values.firstWhere(
        (e) => e.name == json['fromType'],
        orElse: () => UserType.insufficientData,
      ),
      toType: UserType.values.firstWhere(
        (e) => e.name == json['toType'],
        orElse: () => UserType.insufficientData,
      ),
      transitionDate: DateTime.parse(json['transitionDate'] as String),
      totalEntriesAtTransition: json['totalEntriesAtTransition'] as int,
    );
  }
}

