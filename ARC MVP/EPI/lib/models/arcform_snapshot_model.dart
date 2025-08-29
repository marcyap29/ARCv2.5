import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'arcform_snapshot_model.g.dart';

@HiveType(typeId: 1)
class ArcformSnapshot extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String arcformId;

  @HiveField(2)
  final Map<String, dynamic> data;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String notes;

  const ArcformSnapshot({
    required this.id,
    required this.arcformId,
    required this.data,
    required this.timestamp,
    required this.notes,
  });

  ArcformSnapshot copyWith({
    String? id,
    String? arcformId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    String? notes,
  }) {
    return ArcformSnapshot(
      id: id ?? this.id,
      arcformId: arcformId ?? this.arcformId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        arcformId,
        data,
        timestamp,
        notes,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'arcformId': arcformId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }

  factory ArcformSnapshot.fromJson(Map<String, dynamic> json) {
    return ArcformSnapshot(
      id: json['id'] as String,
      arcformId: json['arcformId'] as String,
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String,
    );
  }
}
