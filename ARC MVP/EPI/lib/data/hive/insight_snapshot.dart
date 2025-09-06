import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'insight_snapshot.g.dart';

@HiveType(typeId: 21)
class InsightSnapshot extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime periodStart;

  @HiveField(2)
  final DateTime periodEnd;

  @HiveField(3)
  final List<String> topWords;

  @HiveField(4)
  final Map<String, int> wordFrequencies;

  @HiveField(5)
  final Map<String, double> emotionScores;

  @HiveField(6)
  final Map<String, int> phaseCounts;

  @HiveField(7)
  final Map<String, double> sageCoverage;

  @HiveField(8)
  final double emotionVariance;

  @HiveField(9)
  final List<String> journalIds;

  @HiveField(10)
  final DateTime createdAt;

  const InsightSnapshot({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.topWords,
    required this.wordFrequencies,
    required this.emotionScores,
    required this.phaseCounts,
    required this.sageCoverage,
    required this.emotionVariance,
    required this.journalIds,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        periodStart,
        periodEnd,
        topWords,
        wordFrequencies,
        emotionScores,
        phaseCounts,
        sageCoverage,
        emotionVariance,
        journalIds,
        createdAt,
      ];

  InsightSnapshot copyWith({
    String? id,
    DateTime? periodStart,
    DateTime? periodEnd,
    List<String>? topWords,
    Map<String, int>? wordFrequencies,
    Map<String, double>? emotionScores,
    Map<String, int>? phaseCounts,
    Map<String, double>? sageCoverage,
    double? emotionVariance,
    List<String>? journalIds,
    DateTime? createdAt,
  }) {
    return InsightSnapshot(
      id: id ?? this.id,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      topWords: topWords ?? this.topWords,
      wordFrequencies: wordFrequencies ?? this.wordFrequencies,
      emotionScores: emotionScores ?? this.emotionScores,
      phaseCounts: phaseCounts ?? this.phaseCounts,
      sageCoverage: sageCoverage ?? this.sageCoverage,
      emotionVariance: emotionVariance ?? this.emotionVariance,
      journalIds: journalIds ?? this.journalIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
