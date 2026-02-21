import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'insight_card.g.dart';

@HiveType(typeId: 20)
class InsightCard extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final List<String> badges;

  @HiveField(4)
  final DateTime periodStart;

  @HiveField(5)
  final DateTime periodEnd;

  @HiveField(6)
  final Map<String, dynamic> sources;

  @HiveField(7)
  final String? deeplink;

  @HiveField(8)
  final String ruleId;

  @HiveField(9)
  final DateTime createdAt;

  const InsightCard({
    required this.id,
    required this.title,
    required this.body,
    required this.badges,
    required this.periodStart,
    required this.periodEnd,
    required this.sources,
    this.deeplink,
    required this.ruleId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        badges,
        periodStart,
        periodEnd,
        sources,
        deeplink,
        ruleId,
        createdAt,
      ];

  InsightCard copyWith({
    String? id,
    String? title,
    String? body,
    List<String>? badges,
    DateTime? periodStart,
    DateTime? periodEnd,
    Map<String, dynamic>? sources,
    String? deeplink,
    String? ruleId,
    DateTime? createdAt,
  }) {
    return InsightCard(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      badges: badges ?? this.badges,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      sources: sources ?? this.sources,
      deeplink: deeplink ?? this.deeplink,
      ruleId: ruleId ?? this.ruleId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'badges': badges,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'sources': sources,
      'deeplink': deeplink,
      'ruleId': ruleId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InsightCard.fromJson(Map<String, dynamic> json) {
    return InsightCard(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      badges: List<String>.from(json['badges'] as List),
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      sources: Map<String, dynamic>.from(json['sources'] as Map),
      deeplink: json['deeplink'] as String?,
      ruleId: json['ruleId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
