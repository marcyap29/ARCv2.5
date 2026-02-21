import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

/// A favorite LUMARA reply that the user has marked as a style exemplar
/// Can be categorized as: 'answer' (LUMARA responses), 'chat' (saved chat sessions), or 'journal_entry' (favorite journal entries)
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
  final String? sourceType; // 'chat' or 'journal' (legacy field, use category instead)

  @HiveField(5)
  final Map<String, dynamic> metadata; // Additional context (phase, intent, etc.)

  @HiveField(6)
  final String category; // 'answer', 'chat', or 'journal_entry' (default: 'answer' for backward compatibility)

  @HiveField(7)
  final String? sessionId; // For saved chats: ID of the chat session

  @HiveField(8)
  final String? entryId; // For favorite journal entries: ID of the journal entry

  LumaraFavorite({
    required this.id,
    required this.content,
    required this.timestamp,
    this.sourceId,
    this.sourceType,
    this.metadata = const {},
    this.category = 'answer', // Default to 'answer' for backward compatibility
    this.sessionId,
    this.entryId,
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
      category: 'answer', // LUMARA answers
    );
  }

  /// Create a favorite from a saved chat session
  factory LumaraFavorite.fromChatSession({
    required String sessionId,
    required String content,
    String? sourceId,
    Map<String, dynamic> metadata = const {},
  }) {
    return LumaraFavorite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      timestamp: DateTime.now(),
      sourceId: sourceId,
      sourceType: 'chat',
      metadata: metadata,
      category: 'chat',
      sessionId: sessionId,
    );
  }

  /// Create a favorite from a journal entry
  factory LumaraFavorite.fromJournalEntry({
    required String entryId,
    required String content,
    String? sourceId,
    Map<String, dynamic> metadata = const {},
  }) {
    return LumaraFavorite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      timestamp: DateTime.now(),
      sourceId: sourceId,
      sourceType: 'journal',
      metadata: metadata,
      category: 'journal_entry',
      entryId: entryId,
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
      'category': category,
      'sessionId': sessionId,
      'entryId': entryId,
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
      category: json['category'] as String? ?? 'answer', // Default to 'answer' for backward compatibility
      sessionId: json['sessionId'] as String?,
      entryId: json['entryId'] as String?,
    );
  }

  LumaraFavorite copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    String? sourceId,
    String? sourceType,
    Map<String, dynamic>? metadata,
    String? category,
    String? sessionId,
    String? entryId,
  }) {
    return LumaraFavorite(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sourceId: sourceId ?? this.sourceId,
      sourceType: sourceType ?? this.sourceType,
      metadata: metadata ?? this.metadata,
      category: category ?? this.category,
      sessionId: sessionId ?? this.sessionId,
      entryId: entryId ?? this.entryId,
    );
  }

  @override
  List<Object?> get props => [id, content, timestamp, sourceId, sourceType, metadata, category, sessionId, entryId];
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

