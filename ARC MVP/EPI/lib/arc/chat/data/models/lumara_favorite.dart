import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

/// A favorite LUMARA reply that the user has marked as a style exemplar
@HiveType(typeId: 80)
class LumaraFavorite extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String? sourceId; // ID of the original message or journal block

  @HiveField(4)
  final String? sourceType; // 'chat' or 'journal'

  @HiveField(5)
  final Map<String, dynamic> metadata; // Additional context (phase, intent, etc.)

  LumaraFavorite({
    required this.id,
    required this.content,
    required this.timestamp,
    this.sourceId,
    this.sourceType,
    this.metadata = const {},
  });

  factory LumaraFavorite.fromMessage({
    required String content,
    String? sourceId,
    String? sourceType,
    Map<String, dynamic> metadata = const {},
  }) {
    return LumaraFavorite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      timestamp: DateTime.now(),
      sourceId: sourceId,
      sourceType: sourceType,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'sourceId': sourceId,
      'sourceType': sourceType,
      'metadata': metadata,
    };
  }

  factory LumaraFavorite.fromJson(Map<String, dynamic> json) {
    return LumaraFavorite(
      id: json['id'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sourceId: json['sourceId'] as String?,
      sourceType: json['sourceType'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  LumaraFavorite copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    String? sourceId,
    String? sourceType,
    Map<String, dynamic>? metadata,
  }) {
    return LumaraFavorite(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sourceId: sourceId ?? this.sourceId,
      sourceType: sourceType ?? this.sourceType,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [id, content, timestamp, sourceId, sourceType, metadata];
}

/// Hive adapter for LumaraFavorite
class LumaraFavoriteAdapter extends TypeAdapter<LumaraFavorite> {
  @override
  final int typeId = 80;

  @override
  LumaraFavorite read(BinaryReader reader) {
    final json = Map<String, dynamic>.from(reader.readMap());
    return LumaraFavorite.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, LumaraFavorite obj) {
    writer.writeMap(obj.toJson());
  }
}

