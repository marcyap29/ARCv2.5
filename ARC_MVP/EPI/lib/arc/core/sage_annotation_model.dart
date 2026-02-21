import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'sage_annotation_model.g.dart';

@HiveType(typeId: 3)
class SAGEAnnotation extends Equatable {
  @HiveField(0)
  final String situation;

  @HiveField(1)
  final String action;

  @HiveField(2)
  final String growth;

  @HiveField(3)
  final String essence;

  @HiveField(4)
  final double confidence;

  const SAGEAnnotation({
    required this.situation,
    required this.action,
    required this.growth,
    required this.essence,
    required this.confidence,
  });

  SAGEAnnotation copyWith({
    String? situation,
    String? action,
    String? growth,
    String? essence,
    double? confidence,
  }) {
    return SAGEAnnotation(
      situation: situation ?? this.situation,
      action: action ?? this.action,
      growth: growth ?? this.growth,
      essence: essence ?? this.essence,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  List<Object?> get props => [
        situation,
        action,
        growth,
        essence,
        confidence,
      ];

  Map<String, dynamic> toJson() {
    return {
      'situation': situation,
      'action': action,
      'growth': growth,
      'essence': essence,
      'confidence': confidence,
    };
  }

  factory SAGEAnnotation.fromJson(Map<String, dynamic> json) {
    return SAGEAnnotation(
      situation: json['situation'] as String,
      action: json['action'] as String,
      growth: json['growth'] as String,
      essence: json['essence'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}
