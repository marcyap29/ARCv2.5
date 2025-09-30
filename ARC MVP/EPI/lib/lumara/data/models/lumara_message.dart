import 'package:equatable/equatable.dart';
import '../../../mira/memory/enhanced_memory_schema.dart';

/// Role of a LUMARA message
enum LumaraMessageRole {
  user,
  assistant,
  system,
}

/// A message in the LUMARA conversation
class LumaraMessage extends Equatable {
  final String id;
  final LumaraMessageRole role;
  final String content;
  final DateTime timestamp;
  final List<String> sources;
  final Map<String, dynamic> metadata;
  final List<AttributionTrace>? attributionTraces;

  const LumaraMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.sources = const [],
    this.metadata = const {},
    this.attributionTraces,
  });

  factory LumaraMessage.user({
    required String content,
    List<String> sources = const [],
    Map<String, dynamic> metadata = const {},
    List<AttributionTrace>? attributionTraces,
  }) {
    return LumaraMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: LumaraMessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      sources: sources,
      metadata: metadata,
      attributionTraces: attributionTraces,
    );
  }

  factory LumaraMessage.assistant({
    required String content,
    List<String> sources = const [],
    Map<String, dynamic> metadata = const {},
    List<AttributionTrace>? attributionTraces,
  }) {
    return LumaraMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: LumaraMessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
      sources: sources,
      metadata: metadata,
      attributionTraces: attributionTraces,
    );
  }

  factory LumaraMessage.system({
    required String content,
    Map<String, dynamic> metadata = const {},
    List<AttributionTrace>? attributionTraces,
  }) {
    return LumaraMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: LumaraMessageRole.system,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
      attributionTraces: attributionTraces,
    );
  }

  LumaraMessage copyWith({
    String? id,
    LumaraMessageRole? role,
    String? content,
    DateTime? timestamp,
    List<String>? sources,
    Map<String, dynamic>? metadata,
    List<AttributionTrace>? attributionTraces,
  }) {
    return LumaraMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sources: sources ?? this.sources,
      metadata: metadata ?? this.metadata,
      attributionTraces: attributionTraces ?? this.attributionTraces,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'sources': sources,
      'metadata': metadata,
    };
  }

  factory LumaraMessage.fromJson(Map<String, dynamic> json) {
    return LumaraMessage(
      id: json['id'] as String,
      role: LumaraMessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => LumaraMessageRole.user,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sources: List<String>.from(json['sources'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  @override
  List<Object?> get props => [id, role, content, timestamp, sources, metadata, attributionTraces];
}