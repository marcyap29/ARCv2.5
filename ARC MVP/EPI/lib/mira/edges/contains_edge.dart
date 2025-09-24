import 'package:my_app/mira/core/schema.dart';

/// MIRA edge representing a "contains" relationship (session contains messages)
class ContainsEdge extends MiraEdge {
  ContainsEdge({
    required String sourceId,
    required String targetId,
    required DateTime timestamp,
    required int order,
  }) : super(
          id: '${sourceId}_contains_${targetId}',
          src: sourceId,
          dst: targetId,
          label: EdgeType.belongsTo, // Using belongsTo as closest match
          schemaVersion: 1,
          data: {
            'order': order,
            'source': 'LUMARA',
            'relation': 'contains',
          },
          createdAt: timestamp,
        );

  // Convenience getters
  String get sourceId => src;
  String get targetId => dst;
  int get order => data['order'] as int;

  /// Create contains edge for session -> message relationship
  factory ContainsEdge.sessionMessage({
    required String sessionId,
    required String messageId,
    required DateTime timestamp,
    required int messageOrder,
  }) {
    return ContainsEdge(
      sourceId: 'session:$sessionId',
      targetId: 'msg:$messageId',
      timestamp: timestamp,
      order: messageOrder,
    );
  }

  /// Get metadata for MCP export
  Map<String, dynamic> getMetadata() {
    return {
      'order': order,
      'source': 'LUMARA',
    };
  }
}