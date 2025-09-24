import 'package:my_app/mira/core/schema.dart';
import 'package:my_app/lumara/chat/chat_models.dart';

/// MIRA node representing a chat message
class ChatMessageNode extends MiraNode {
  ChatMessageNode({
    required String messageId,
    required String sessionId,
    required String role,
    required String content,
    required DateTime createdAt,
    String? originalTextHash,
  }) : super(
          id: 'msg:$messageId',
          type: NodeType.entry, // Using entry type for compatibility
          schemaVersion: 2,
          data: {
            'messageId': messageId,
            'sessionId': sessionId,
            'role': role,
            'content': content,
            'originalTextHash': originalTextHash,
            'source': 'LUMARA',
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        );

  // Convenience getters
  String get messageId => data['messageId'] as String;
  String get sessionId => data['sessionId'] as String;
  String get role => data['role'] as String;
  String get content => data['content'] as String;
  String? get originalTextHash => data['originalTextHash'] as String?;

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


  /// Get content for MCP export
  Map<String, dynamic> getContent() {
    return {
      'mime': 'text/plain',
      'text': content,
    };
  }

  /// Get metadata for MCP export
  Map<String, dynamic> getMetadata() {
    return {
      'role': role,
      'sessionId': sessionId,
      'source': 'LUMARA',
      'originalTextHash': originalTextHash,
    };
  }
}