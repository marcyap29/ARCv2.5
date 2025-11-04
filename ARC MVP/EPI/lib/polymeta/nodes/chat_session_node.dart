import 'package:my_app/polymeta/core/schema.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';

/// MIRA node representing a chat session
class ChatSessionNode extends MiraNode {
  ChatSessionNode({
    required String sessionId,
    required String subject,
    required super.createdAt,
    required super.updatedAt,
    required bool isPinned,
    required bool isArchived,
    DateTime? archivedAt,
    required List<String> tags,
    required int messageCount,
  }) : super(
          id: 'session:$sessionId',
          type: NodeType.entry, // Using entry type for compatibility
          schemaVersion: 2,
          data: {
            'sessionId': sessionId,
            'subject': subject,
            'isPinned': isPinned,
            'isArchived': isArchived,
            'archivedAt': archivedAt?.toIso8601String(),
            'tags': tags,
            'messageCount': messageCount,
            'retention': 'auto-archive-30d',
            'source': 'LUMARA',
            'content': subject,
          },
        );

  // Convenience getters
  String get sessionId => data['sessionId'] as String;
  String get subject => data['subject'] as String;
  bool get isPinned => data['isPinned'] as bool;
  bool get isArchived => data['isArchived'] as bool;
  DateTime? get archivedAt => data['archivedAt'] != null ? DateTime.parse(data['archivedAt'] as String) : null;
  List<String> get tags => List<String>.from(data['tags'] as List);
  int get messageCount => data['messageCount'] as int;

  /// Create from ChatSession model
  factory ChatSessionNode.fromModel(ChatSession session) {
    return ChatSessionNode(
      sessionId: session.id,
      subject: session.subject,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      isPinned: session.isPinned,
      isArchived: session.isArchived,
      archivedAt: session.archivedAt,
      tags: List.from(session.tags),
      messageCount: session.messageCount,
    );
  }

  /// Create from a generic MIRA node
  static ChatSessionNode? fromMiraNode(MiraNode node) {
    if (node.type != NodeType.entry) {
      return null;
    }

    final data = node.data;
    if (!data.containsKey('sessionId') || !data.containsKey('subject')) {
      return null;
    }

    return ChatSessionNode(
      sessionId: data['sessionId'] as String,
      subject: data['subject'] as String? ?? '',
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
      isPinned: data['isPinned'] as bool? ?? false,
      isArchived: data['isArchived'] as bool? ?? false,
      archivedAt: (data['archivedAt'] as String?) != null
          ? DateTime.tryParse(data['archivedAt'] as String)
          : null,
      tags: List<String>.from(data['tags'] as List? ?? const []),
      messageCount: data['messageCount'] as int? ?? 0,
    );
  }


  /// Get content for MCP export
  Map<String, dynamic> getContent() {
    return {
      'title': subject,
      'messageCount': messageCount,
    };
  }

  /// Get metadata for MCP export
  Map<String, dynamic> getMetadata() {
    return {
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
      'isPinned': isPinned,
      'tags': tags,
      'messageCount': messageCount,
      'retention': 'auto-archive-30d',
      'source': 'LUMARA',
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}