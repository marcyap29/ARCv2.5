import 'package:my_app/core/mira/mira_edge.dart';

/// MIRA edge representing a "contains" relationship (session contains messages)
class ContainsEdge extends MiraEdge {
  final int order;

  ContainsEdge({
    required String sourceId,
    required String targetId,
    required DateTime timestamp,
    required this.order,
  }) : super(
          id: '${sourceId}_contains_${targetId}',
          sourceId: sourceId,
          targetId: targetId,
          relation: 'contains',
          timestamp: timestamp,
        );

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

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceId': sourceId,
      'targetId': targetId,
      'relation': relation,
      'timestamp': timestamp.toIso8601String(),
      'order': order,
      'metadata': {
        'order': order,
        'source': 'LUMARA',
      },
    };
  }

  @override
  Map<String, dynamic> getMetadata() {
    return {
      'order': order,
      'source': 'LUMARA',
    };
  }

  @override
  List<Object?> get props => [
        id,
        sourceId,
        targetId,
        relation,
        timestamp,
        order,
      ];
}