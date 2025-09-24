// lib/mcp/adapters/to_mcp.dart
// Converts MIRA nodes to MCP records (node.v1 and node.v2)

import '../../mira/core/schema.dart';
import '../../mira/nodes/chat_session_node.dart';
import '../../mira/nodes/chat_message_node.dart';
import '../../mira/edges/contains_edge.dart';

class MiraToMcpAdapter {
  /// Convert MiraNode to appropriate MCP node record based on type
  static Map<String, dynamic>? nodeToMcp(MiraNode node) {
    // Route to appropriate converter based on node type
    if (node is ChatSessionNode) {
      return _chatSessionToNodeV2(node);
    } else if (node is ChatMessageNode) {
      return _chatMessageToNodeV2(node);
    } else {
      // Handle legacy journal nodes (entry, keyword, etc.) as node.v1
      return _legacyNodeToV1(node);
    }
  }

  /// Convert ChatSessionNode to node.v2 MCP record
  static Map<String, dynamic> _chatSessionToNodeV2(ChatSessionNode session) {
    return {
      'kind': 'node',
      'type': 'ChatSession',
      'id': session.id,
      'timestamp': session.createdAt.toUtc().toIso8601String(),
      'content': session.getContent(),
      'metadata': session.getMetadata(),
      'schema_version': 'node.v2',
    };
  }

  /// Convert ChatMessageNode to node.v2 MCP record
  static Map<String, dynamic> _chatMessageToNodeV2(ChatMessageNode message) {
    return {
      'kind': 'node',
      'type': 'ChatMessage',
      'id': message.id,
      'timestamp': message.createdAt.toUtc().toIso8601String(),
      'content': message.getContent(),
      'metadata': message.getMetadata(),
      'schema_version': 'node.v2',
    };
  }

  /// Convert legacy MIRA nodes to node.v1 MCP record
  static Map<String, dynamic> _legacyNodeToV1(MiraNode node) {
    final Map<String, dynamic> record = {
      'type': node.type.name,
      'id': node.id,
      'timestamp': node.createdAt.toUtc().toIso8601String(),
      'schema_version': 'node.v1',
    };

    // Add type-specific fields for node.v1
    switch (node.type) {
      case NodeType.entry:
        record['content_summary'] = node.narrative;
        record['keywords'] = node.keywords;
        if (node.data['phase_hint'] != null) {
          record['phase_hint'] = node.data['phase_hint'];
        }
        break;
      case NodeType.keyword:
        record['content_summary'] = 'Keyword node: ${node.data['keyword'] ?? node.id}';
        record['keywords'] = [node.data['keyword'] ?? node.id.split(':').last];
        break;
      default:
        record['content_summary'] = node.narrative;
        record['metadata'] = node.data;
    }

    return record;
  }

  /// Convert MIRA edge to MCP edge record
  static Map<String, dynamic>? edgeToMcp(MiraEdge edge) {
    final Map<String, dynamic> record = {
      'kind': 'edge',
      'id': edge.id,
      'timestamp': edge.createdAt.toUtc().toIso8601String(),
      'source_id': edge.sourceId,
      'target_id': edge.targetId,
      'schema_version': 'edge.v1',
    };

    // Handle different edge types
    if (edge is ContainsEdge) {
      record['type'] = 'contains';
      record['metadata'] = {
        'order': edge.order,
        'source': 'LUMARA',
      };
    } else {
      // Handle legacy edges (mentions, cooccurs, etc.)
      record['type'] = edge.type.name;
      record['metadata'] = edge.data;
    }

    return record;
  }
}
