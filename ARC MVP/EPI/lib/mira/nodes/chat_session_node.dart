import 'package:my_app/core/mira/mira_node.dart';
import 'package:my_app/lumara/chat/chat_models.dart';

/// MIRA node representing a chat session
class ChatSessionNode extends MiraNode {
  final String sessionId;
  final String subject;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final DateTime? archivedAt;
  final List<String> tags;
  final int messageCount;

  ChatSessionNode({
    required this.sessionId,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.isArchived,
    this.archivedAt,
    required this.tags,
    required this.messageCount,
  }) : super(
          id: 'session:$sessionId',
          type: 'ChatSession',
          timestamp: createdAt,
        );

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

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'subject': subject,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
      'tags': tags,
      'messageCount': messageCount,
      'metadata': {
        'retention': 'auto-archive-30d',
        'source': 'LUMARA',
      },
    };
  }

  @override
  Map<String, dynamic> getContent() {
    return {
      'title': subject,
      'messageCount': messageCount,
    };
  }

  @override
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

  @override
  List<Object?> get props => [
        id,
        type,
        sessionId,
        subject,
        createdAt,
        updatedAt,
        isPinned,
        isArchived,
        archivedAt,
        tags,
        messageCount,
      ];
}