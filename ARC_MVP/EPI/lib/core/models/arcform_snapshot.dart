import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'arcform_snapshot.g.dart';

@HiveType(typeId: 2)
class ArcformSnapshot extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String journalEntryId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final List<String> keywords;

  @HiveField(4)
  final Map<String, String> colorMap;

  @HiveField(5)
  final List<List<dynamic>> edges;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final String phase; // Discovery|Expansion|Transition|Consolidation|Recovery|Breakthrough

  @HiveField(8)
  final bool userConsentedPhase; // user explicitly applied/kept this phase

  @HiveField(9)
  final bool isGeometryAuto; // keep current semantics

  @HiveField(10)
  final String? recommendationRationale; // why this phase was recommended

  const ArcformSnapshot({
    required this.id,
    required this.journalEntryId,
    required this.title,
    required this.keywords,
    required this.colorMap,
    required this.edges,
    required this.createdAt,
    required this.phase,
    required this.userConsentedPhase,
    this.isGeometryAuto = true,
    this.recommendationRationale,
  });

  ArcformSnapshot copyWith({
    String? id,
    String? journalEntryId,
    String? title,
    List<String>? keywords,
    Map<String, String>? colorMap,
    List<List<dynamic>>? edges,
    DateTime? createdAt,
    String? phase,
    bool? userConsentedPhase,
    bool? isGeometryAuto,
    String? recommendationRationale,
  }) {
    return ArcformSnapshot(
      id: id ?? this.id,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      title: title ?? this.title,
      keywords: keywords ?? this.keywords,
      colorMap: colorMap ?? this.colorMap,
      edges: edges ?? this.edges,
      createdAt: createdAt ?? this.createdAt,
      phase: phase ?? this.phase,
      userConsentedPhase: userConsentedPhase ?? this.userConsentedPhase,
      isGeometryAuto: isGeometryAuto ?? this.isGeometryAuto,
      recommendationRationale: recommendationRationale ?? this.recommendationRationale,
    );
  }

  @override
  List<Object?> get props => [
        id,
        journalEntryId,
        title,
        keywords,
        colorMap,
        edges,
        createdAt,
        phase,
        userConsentedPhase,
        isGeometryAuto,
        recommendationRationale,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journalEntryId': journalEntryId,
      'title': title,
      'keywords': keywords,
      'colorMap': colorMap,
      'edges': edges,
      'createdAt': createdAt.toIso8601String(),
      'phase': phase,
      'userConsentedPhase': userConsentedPhase,
      'isGeometryAuto': isGeometryAuto,
      'recommendationRationale': recommendationRationale,
    };
  }

  factory ArcformSnapshot.fromJson(Map<String, dynamic> json) {
    return ArcformSnapshot(
      id: json['id'] as String,
      journalEntryId: json['journalEntryId'] as String,
      title: json['title'] as String,
      keywords: List<String>.from(json['keywords'] as List),
      colorMap: Map<String, String>.from(json['colorMap'] as Map),
      edges: List<List<dynamic>>.from(json['edges'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      phase: json['phase'] as String,
      userConsentedPhase: json['userConsentedPhase'] as bool,
      isGeometryAuto: json['isGeometryAuto'] as bool? ?? true,
      recommendationRationale: json['recommendationRationale'] as String?,
    );
  }
}