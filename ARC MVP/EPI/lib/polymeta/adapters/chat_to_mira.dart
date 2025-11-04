import 'package:my_app/polymeta/mira_service.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import '../core/schema.dart';
import '../nodes/chat_session_node.dart';
import '../nodes/chat_message_node.dart';
import '../edges/contains_edge.dart';

/// Adapter for converting chat data to MIRA graph nodes and edges
class ChatToMiraAdapter {
  final ChatRepo _chatRepo;
  final MiraService _miraService;

  ChatToMiraAdapter({
    required ChatRepo chatRepo,
    required MiraService miraService,
  }) : _chatRepo = chatRepo,
       _miraService = miraService;

  /// Sync all chat sessions and messages to MIRA graph
  Future<ChatSyncResult> syncAllChats({
    bool includeArchived = true,
  }) async {
    final result = ChatSyncResult();

    try {
      // Get all sessions
      final sessions = await _chatRepo.listAll(includeArchived: includeArchived);
      result.totalSessions = sessions.length;

      for (final session in sessions) {
        await _syncSession(session, result);
      }

      result.success = true;
      print('ChatToMira: Synced ${result.syncedSessions} sessions, ${result.syncedMessages} messages, ${result.syncedEdges} edges');
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      print('ChatToMira: Sync failed: $e');
    }

    return result;
  }

  /// Sync a single session and its messages
  Future<void> syncSession(String sessionId) async {
    final session = await _chatRepo.getSession(sessionId);
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final result = ChatSyncResult();
    await _syncSession(session, result);
  }

  /// Internal method to sync a session
  Future<void> _syncSession(ChatSession session, ChatSyncResult result) async {
    try {
      // Create session node
      final sessionNode = ChatSessionNode.fromModel(session);
      await _miraService.addNode(sessionNode);
      result.syncedSessions++;

      // Get messages for this session
      final messages = await _chatRepo.getMessages(session.id, lazy: false);

      // Create message nodes and edges
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];

        // Create message node
        final messageNode = ChatMessageNode.fromModel(message);
        await _miraService.addNode(messageNode);
        result.syncedMessages++;

        // Create contains edge (session contains message)
        final containsEdge = ContainsEdge.sessionMessage(
          sessionId: session.id,
          messageId: message.id,
          timestamp: message.createdAt,
          messageOrder: i,
        );
        await _miraService.addEdge(containsEdge);
        result.syncedEdges++;
      }

      // Create tag edges if needed (future enhancement)
      for (final tag in session.tags) {
        // TODO: Create taggedAs edges when tag nodes are implemented
      }
    } catch (e) {
      result.errors.add('Session ${session.id}: $e');
      rethrow;
    }
  }

  /// Remove chat data from MIRA graph
  Future<void> removeFromMira(String sessionId) async {
    try {
      // Get session and messages to remove all nodes/edges
      final session = await _chatRepo.getSession(sessionId);
      if (session == null) return;

      final messages = await _chatRepo.getMessages(sessionId, lazy: false);

      // Remove message nodes and edges
      for (final message in messages) {
        await _miraService.removeNode('msg:${message.id}');
        await _miraService.removeEdge('session:${sessionId}_contains_msg:${message.id}');
      }

      // Remove session node
      await _miraService.removeNode('session:$sessionId');

      print('ChatToMira: Removed session $sessionId from MIRA');
    } catch (e) {
      print('ChatToMira: Failed to remove session $sessionId from MIRA: $e');
      rethrow;
    }
  }

  /// Get chat-related nodes from MIRA
  Future<List<ChatSessionNode>> getChatSessionsFromMira() async {
    try {
      final nodes = await _miraService.getNodesByType(NodeType.entry);
      return nodes
          .map(ChatSessionNode.fromMiraNode)
          .whereType<ChatSessionNode>()
          .toList();
    } catch (e) {
      print('ChatToMira: Failed to get sessions from MIRA: $e');
      return [];
    }
  }

  /// Get message nodes for a session from MIRA
  Future<List<ChatMessageNode>> getSessionMessagesFromMira(String sessionId) async {
    try {
      final edges = await _miraService.getEdgesBySource(
        'session:$sessionId',
        label: EdgeType.belongsTo,
      );

      // Sort edges by recorded order before resolving nodes
      final orderedEdges = edges
          .where((edge) => (edge.data['relation'] as String?) == 'contains')
          .toList()
        ..sort((a, b) {
          final orderA = (a.data['order'] as num?)?.toInt() ?? 0;
          final orderB = (b.data['order'] as num?)?.toInt() ?? 0;
          return orderA.compareTo(orderB);
        });

      final messages = <ChatMessageNode>[];
      for (final edge in orderedEdges) {
        final rawNode = await _miraService.getNode(edge.dst);
        if (rawNode == null) {
          continue;
        }
        final messageNode = ChatMessageNode.fromMiraNode(rawNode);
        if (messageNode != null) {
          messages.add(messageNode);
        }
      }

      return messages;
    } catch (e) {
      print('ChatToMira: Failed to get messages for session $sessionId from MIRA: $e');
      return [];
    }
  }
}

/// Result of chat synchronization to MIRA
class ChatSyncResult {
  bool success = false;
  String? error;
  int totalSessions = 0;
  int syncedSessions = 0;
  int syncedMessages = 0;
  int syncedEdges = 0;
  List<String> errors = [];

  @override
  String toString() {
    if (!success) {
      return 'ChatSyncResult(failed: $error, errors: ${errors.length})';
    }
    return 'ChatSyncResult(sessions: $syncedSessions/$totalSessions, messages: $syncedMessages, edges: $syncedEdges)';
  }
}