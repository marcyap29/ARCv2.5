import 'package:collection/collection.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';

import '../nodes/chat_session_node.dart';
import '../nodes/chat_message_node.dart';
import '../edges/contains_edge.dart';

/// Helpers to convert chat models into MIRA nodes and edges.
class ChatIngest {
  const ChatIngest._();

  static ChatSessionNode toSessionNode(ChatSession session) {
    return ChatSessionNode.fromModel(session);
  }

  static ChatMessageNode toMessageNode(ChatMessage message) {
    return ChatMessageNode.fromModel(message);
  }

  static ContainsEdge toContainsEdge({
    required ChatSession session,
    required ChatMessage message,
    required int order,
  }) {
    return ContainsEdge.sessionMessage(
      sessionId: session.id,
      messageId: message.id,
      timestamp: message.createdAt,
      messageOrder: order,
    );
  }

  static Iterable<ContainsEdge> toContainsEdges(
    ChatSession session,
    List<ChatMessage> messages,
  ) {
    return messages.mapIndexed((index, message) => toContainsEdge(
          session: session,
          message: message,
          order: index,
        ));
  }
}
