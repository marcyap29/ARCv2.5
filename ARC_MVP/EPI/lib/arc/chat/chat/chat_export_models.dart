import 'package:equatable/equatable.dart';
import 'chat_models.dart';

/// Chat export format for saving/importing chats (sessions + messages only).
class ChatExportData extends Equatable {
  final String version;
  final DateTime exportedAt;
  final String exportedBy;
  final List<ChatSession> sessions;
  final List<ChatMessage> messages;

  const ChatExportData({
    required this.version,
    required this.exportedAt,
    required this.exportedBy,
    required this.sessions,
    required this.messages,
  });

  factory ChatExportData.create({
    required List<ChatSession> sessions,
    required List<ChatMessage> messages,
  }) {
    return ChatExportData(
      version: '1.0',
      exportedAt: DateTime.now(),
      exportedBy: 'LUMARA EPI v1.0',
      sessions: sessions,
      messages: messages,
    );
  }

  @override
  List<Object?> get props => [version, exportedAt, exportedBy, sessions, messages];

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'exportedBy': exportedBy,
      'sessions': sessions.map((s) => {
        'id': s.id,
        'subject': s.subject,
        'createdAt': s.createdAt.toIso8601String(),
        'updatedAt': s.updatedAt.toIso8601String(),
        'isPinned': s.isPinned,
        'isArchived': s.isArchived,
        'archivedAt': s.archivedAt?.toIso8601String(),
        'tags': s.tags,
        'messageCount': s.messageCount,
        'retention': s.retention,
        if (s.metadata != null) 'metadata': s.metadata,
      }).toList(),
      'messages': messages.map((m) => {
        'id': m.id,
        'sessionId': m.sessionId,
        'role': m.role,
        'content': m.textContent,
        'createdAt': m.createdAt.toIso8601String(),
        'originalTextHash': m.originalTextHash,
        'provenance': m.provenance,
      }).toList(),
      'categories': [],
      'sessionCategories': [],
    };
  }

  factory ChatExportData.fromJson(Map<String, dynamic> json) {
    return ChatExportData(
      version: json['version'] as String,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      exportedBy: json['exportedBy'] as String,
      sessions: (json['sessions'] as List)
          .map((s) => ChatSession(
                id: s['id'] as String,
                subject: s['subject'] as String,
                createdAt: DateTime.parse(s['createdAt'] as String),
                updatedAt: DateTime.parse(s['updatedAt'] as String),
                isPinned: s['isPinned'] as bool? ?? false,
                isArchived: s['isArchived'] as bool? ?? false,
                archivedAt: s['archivedAt'] != null ? DateTime.parse(s['archivedAt'] as String) : null,
                tags: (s['tags'] as List?)?.cast<String>() ?? [],
                messageCount: s['messageCount'] as int? ?? 0,
                retention: s['retention'] as String? ?? 'auto-archive-30d',
                metadata: s['metadata'] as Map<String, dynamic>?,
              ))
          .toList(),
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.createText(
                sessionId: m['sessionId'] as String,
                role: m['role'] as String,
                content: m['content'] as String,
                provenance: m['provenance'] as String?,
                id: m['id'] as String?,
                createdAt: m['createdAt'] != null ? DateTime.parse(m['createdAt'] as String) : null,
              ))
          .toList(),
    );
  }
}
