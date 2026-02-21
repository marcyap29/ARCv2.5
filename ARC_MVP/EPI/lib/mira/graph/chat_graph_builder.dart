import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/mira/core/schema.dart';

import '../ingest/chat_ingest.dart';

/// Builds chat-specific graph fragments for MIRA ingestion.
class ChatGraphBuilder {
  const ChatGraphBuilder._();

  static GraphFragment fromSessions(
    List<ChatSession> sessions,
    Map<String, List<ChatMessage>> messagesBySession,
  ) {
    final nodes = <MiraNode>[];
    final edges = <MiraEdge>[];

    for (final session in sessions) {
      nodes.add(ChatIngest.toSessionNode(session));
      final messages = messagesBySession[session.id] ?? const [];
      nodes.addAll(messages.map(ChatIngest.toMessageNode));
      edges.addAll(ChatIngest.toContainsEdges(session, messages));
    }

    return GraphFragment(nodes: nodes, edges: edges);
  }
}

/// Simple container for nodes/edges produced by builders.
class GraphFragment {
  final List<MiraNode> nodes;
  final List<MiraEdge> edges;

  const GraphFragment({required this.nodes, required this.edges});

  GraphFragment merge(GraphFragment other) {
    return GraphFragment(
      nodes: [...nodes, ...other.nodes],
      edges: [...edges, ...other.edges],
    );
  }
}
