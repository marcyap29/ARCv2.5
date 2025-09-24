import 'package:my_app/core/mira/mira_node.dart';
import 'package:my_app/lumara/chat/chat_models.dart';

/// MIRA node representing a chat message
class ChatMessageNode extends MiraNode {
  final String messageId;
  final String sessionId;
  final String role;
  final String content;
  final String? originalTextHash;

  ChatMessageNode({
    required this.messageId,
    required this.sessionId,
    required this.role,
    required this.content,
    required DateTime createdAt,
    this.originalTextHash,
  }) : super(
          id: 'msg:$messageId',
          type: 'ChatMessage',
          timestamp: createdAt,
        );

  /// Create from ChatMessage model
  factory ChatMessageNode.fromModel(ChatMessage message) {
    return ChatMessageNode(
      messageId: message.id,
      sessionId: message.sessionId,
      role: message.role,
      content: message.content,
      createdAt: message.createdAt,
      originalTextHash: message.originalTextHash,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'messageId': messageId,
      'sessionId': sessionId,
      'role': role,
      'content': content,
      'originalTextHash': originalTextHash,
      'metadata': {
        'source': 'LUMARA',
        'sessionId': sessionId,
      },
    };
  }

  @override
  Map<String, dynamic> getContent() {
    return {
      'mime': 'text/plain',
      'text': content,
    };
  }

  @override
  Map<String, dynamic> getMetadata() {
    return {
      'role': role,
      'sessionId': sessionId,
      'source': 'LUMARA',
      'originalTextHash': originalTextHash,
    };
  }

  @override
  List<Object?> get props => [
        id,
        type,
        messageId,
        sessionId,
        role,
        content,
        originalTextHash,
        timestamp,
      ];
}