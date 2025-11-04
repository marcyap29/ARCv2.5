// lib/lumara/memory/mcp_memory_service.dart
// MCP Memory Service - manages conversation persistence and retrieval

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'mcp_memory_models.dart';
import 'pii_redaction_service.dart';
import 'summary_service.dart';
import 'memory_index_service.dart';

/// MCP Memory Service for LUMARA conversational memory
class McpMemoryService {
  static const int _summaryWindowSize = 10; // messages per summary
  static const int _maxContextMessages = 10; // messages in retrieval context
  static const int _maxTopicHits = 5; // topic/entity hits in context

  late final String _userId;
  late final String _basePath;
  String? _currentSessionId;
  McpBundle? _currentBundle;
  MemoryIndexService? _indexService;

  /// Initialize the memory service for a user
  Future<void> initialize(String userId) async {
    _userId = userId;
    final documentsDir = await getApplicationDocumentsDirectory();
    _basePath = path.join(documentsDir.path, 'user_profiles', userId, 'mcp');

    // Ensure directories exist
    await Directory(_basePath).create(recursive: true);
    await Directory(path.join(_basePath, 'sessions')).create(recursive: true);

    // Initialize memory index service
    final indexPath = path.join(_basePath, 'memory.index.json');
    _indexService = MemoryIndexService(userId: userId, indexPath: indexPath);
    await _indexService!.initialize();
  }

  /// Start a new conversation session
  Future<String> startSession({String? title}) async {
    final sessionId = _generateSessionId();
    final sessionTitle = title ?? 'LUMARA Chat ${DateTime.now().day}/${DateTime.now().month}';

    // Create session record
    final sessionRecord = ConversationSession(
      id: 'sess:$sessionId',
      timestamp: DateTime.now(),
      title: sessionTitle,
      tags: ['echo', 'lumara', 'chat'],
      meta: {
        'source': 'ECHO',
        'phase_hint': 'ATLAS:Discovery', // Default phase
      },
    );

    // Create new bundle
    _currentBundle = McpBundle(
      owner: _userId,
      bundleId: sessionId,
      createdAt: DateTime.now(),
      records: [sessionRecord],
    );

    _currentSessionId = sessionId;

    // Save initial bundle
    await _saveBundleToDisk();

    return sessionId;
  }

  /// Resume an existing session
  Future<bool> resumeSession(String sessionId) async {
    try {
      final bundle = await _loadBundleFromDisk(sessionId);
      if (bundle != null) {
        _currentSessionId = sessionId;
        _currentBundle = bundle;
        return true;
      }
      return false;
    } catch (e) {
      print('MCP Memory: Error resuming session $sessionId: $e');
      return false;
    }
  }

  /// Add a message to the current session
  Future<String> addMessage({
    required String role,
    required String content,
  }) async {
    if (_currentBundle == null || _currentSessionId == null) {
      throw Exception('No active session. Call startSession() first.');
    }

    final messageId = _generateMessageId();

    // Redact PII from content
    final redactionResult = PiiRedactionService.redactContent(
      content: content,
      messageId: messageId,
    );

    // Create message record
    final message = ConversationMessage(
      id: messageId,
      timestamp: DateTime.now(),
      role: role,
      content: redactionResult.redactedContent,
      originalHash: ConversationMessage.createHash(content),
      redactionRef: redactionResult.hasRedactions ? redactionResult.redactions.first.id : null,
      parent: 'sess:$_currentSessionId',
    );

    // Add message to bundle
    _currentBundle = _currentBundle!.addRecord(message);

    // Add redaction records if any
    for (final redaction in redactionResult.redactions) {
      _currentBundle = _currentBundle!.addRecord(redaction);
    }

    // Save bundle
    await _saveBundleToDisk();

    // Update memory index
    if (_indexService != null) {
      await _indexService!.updateFromMessage(message);
    }

    // Check if we need to create a summary
    await _checkAndCreateSummary();

    return messageId;
  }

  /// Get conversation context for AI response generation
  Future<Map<String, dynamic>> getConversationContext() async {
    if (_currentBundle == null) {
      return {'messages': [], 'summary': null, 'topics': [], 'entities': []};
    }

    // Get recent messages
    final messages = _getRecentMessages(_maxContextMessages);

    // Get latest summary
    final summary = _getLatestSummary();

    // Get relevant topics and entities from memory index
    final topicHits = _indexService?.searchTopics(
      messages.isNotEmpty ? messages.last.content : '',
      limit: _maxTopicHits,
    ) ?? [];
    final entityHits = _indexService?.searchEntities(
      messages.isNotEmpty ? messages.last.content : '',
      limit: _maxTopicHits,
    ) ?? [];
    final openLoops = _indexService?.getOpenLoops() ?? [];

    return {
      'messages': messages.map((m) => {
        'role': m.role,
        'content': m.content,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList(),
      'summary': summary?.toJson(),
      'topics': topicHits.map((t) => {
        'topic': t.topic,
        'refs': t.refs,
        'last_ts': t.lastTimestamp.toIso8601String(),
      }).toList(),
      'entities': entityHits.map((e) => {
        'name': e.name,
        'refs': e.refs,
        'last_ts': e.lastTimestamp.toIso8601String(),
      }).toList(),
      'open_loops': openLoops.take(_maxTopicHits).map((o) => {
        'title': o.title,
        'refs': o.refs,
        'status': o.status,
        'last_ts': o.lastTimestamp.toIso8601String(),
      }).toList(),
      'session_id': _currentSessionId,
      'total_messages': _getMessageCount(),
    };
  }

  /// List all conversation sessions
  Future<List<Map<String, dynamic>>> listSessions() async {
    final sessionsDir = Directory(path.join(_basePath, 'sessions'));
    if (!await sessionsDir.exists()) return [];

    List<Map<String, dynamic>> sessions = [];

    await for (final entity in sessionsDir.list()) {
      if (entity is Directory) {
        final sessionId = path.basename(entity.path);
        final bundle = await _loadBundleFromDisk(sessionId);

        if (bundle != null) {
          final sessionRecord = bundle.records
              .whereType<ConversationSession>()
              .firstOrNull;

          if (sessionRecord != null) {
            final messageCount = bundle.records
                .whereType<ConversationMessage>()
                .length;

            sessions.add({
              'session_id': sessionId,
              'title': sessionRecord.title,
              'created_at': sessionRecord.timestamp.toIso8601String(),
              'message_count': messageCount,
              'tags': sessionRecord.tags,
              'meta': sessionRecord.meta,
            });
          }
        }
      }
    }

    // Sort by creation date, newest first
    sessions.sort((a, b) =>
        DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

    return sessions;
  }

  /// Get messages for a specific session
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    final bundle = await _loadBundleFromDisk(sessionId);
    if (bundle == null) return [];

    final messages = bundle.records
        .whereType<ConversationMessage>()
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return messages.map((m) => {
      'id': m.id,
      'role': m.role,
      'content': m.content,
      'timestamp': m.timestamp.toIso8601String(),
      'has_redactions': m.redactionRef != null,
    }).toList();
  }

  /// Delete a conversation session
  Future<void> deleteSession(String sessionId) async {
    final sessionDir = Directory(path.join(_basePath, 'sessions', sessionId));
    if (await sessionDir.exists()) {
      await sessionDir.delete(recursive: true);
    }

    // Remove from memory index
    if (_indexService != null) {
      await _indexService!.removeSessionReferences(sessionId);
    }

    // If this was the current session, clear it
    if (_currentSessionId == sessionId) {
      _currentSessionId = null;
      _currentBundle = null;
    }
  }

  /// Export conversations to MCP bundle zip
  Future<String> exportConversations() async {
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    final exportPath = path.join(_basePath, '..', 'exports', 'mcp_chat_$timestamp.zip');

    // TODO: Implement zip creation with all MCP bundles
    // For now, return the MCP directory path
    return _basePath;
  }

  /// Handle memory commands
  Future<String> handleMemoryCommand(String command) async {
    final parts = command.toLowerCase().split(' ');

    switch (parts[0]) {
      case '/memory':
        if (parts.length < 2) return _getMemoryHelp();

        switch (parts[1]) {
          case 'show':
            return await _showMemoryStatus();
          case 'forget':
            if (parts.length < 3) return 'Usage: /memory forget <session_id>';
            return await _forgetMemory(parts[2]);
          case 'export':
            final exportPath = await exportConversations();
            return 'Memory exported to: $exportPath';
          default:
            return _getMemoryHelp();
        }
      default:
        return 'Unknown command: $command';
    }
  }

  // Private helper methods

  String _generateSessionId() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('-', '').replaceAll('.', '');
    final random = Random().nextInt(99999).toString().padLeft(5, '0');
    return '${timestamp}_$random';
  }

  String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'msg:${timestamp}_$random';
  }

  Future<void> _saveBundleToDisk() async {
    if (_currentBundle == null || _currentSessionId == null) return;

    final sessionDir = Directory(path.join(_basePath, 'sessions', _currentSessionId!));
    await sessionDir.create(recursive: true);

    final bundleFile = File(path.join(sessionDir.path, 'bundle.json'));
    await bundleFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_currentBundle!.toJson()),
    );
  }

  Future<McpBundle?> _loadBundleFromDisk(String sessionId) async {
    final bundleFile = File(path.join(_basePath, 'sessions', sessionId, 'bundle.json'));

    if (!await bundleFile.exists()) return null;

    try {
      final content = await bundleFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return McpBundle.fromJson(json);
    } catch (e) {
      print('MCP Memory: Error loading bundle $sessionId: $e');
      return null;
    }
  }

  // Note: Memory index methods removed - now handled by MemoryIndexService

  // Note: _updateMemoryIndex method removed - now handled by MemoryIndexService

  List<ConversationMessage> _getRecentMessages(int count) {
    if (_currentBundle == null) return [];

    final messages = _currentBundle!.records
        .whereType<ConversationMessage>()
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return messages.length > count ? messages.sublist(messages.length - count) : messages;
  }

  ConversationSummary? _getLatestSummary() {
    if (_currentBundle == null) return null;

    final summaries = _currentBundle!.records
        .whereType<ConversationSummary>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return summaries.isNotEmpty ? summaries.first : null;
  }

  // Note: _getRelevantTopics and _getRelevantEntities methods removed - now handled by MemoryIndexService

  int _getMessageCount() {
    if (_currentBundle == null) return 0;
    return _currentBundle!.records.whereType<ConversationMessage>().length;
  }

  Future<void> _checkAndCreateSummary() async {
    final messageCount = _getMessageCount();

    if (messageCount > 0 && messageCount % _summaryWindowSize == 0) {
      await _createSummary();
    }
  }

  Future<void> _createSummary() async {
    final messages = _getRecentMessages(_summaryWindowSize);
    if (messages.isEmpty) return;

    try {
      // Generate summary using SummaryService
      final windowIndex = (_getMessageCount() / _summaryWindowSize).floor();
      final summary = await SummaryService.generateSummary(
        messages: messages,
        sessionId: _currentSessionId!,
        windowIndex: windowIndex,
      );

      // Add summary to bundle
      _currentBundle = _currentBundle!.addRecord(summary);

      // Update memory index with summary
      if (_indexService != null) {
        await _indexService!.updateFromSummary(summary);
      }

      await _saveBundleToDisk();
      print('LUMARA Memory: Created summary for ${messages.length} messages');
    } catch (e) {
      print('LUMARA Memory: Error creating summary: $e');
    }
  }

  // Note: _removeSessionFromIndex method removed - now handled by MemoryIndexService

  String _getMemoryHelp() {
    return '''
Memory Commands:
/memory show - Show memory status and open loops
/memory forget <session_id> - Delete a conversation session
/memory export - Export conversations to MCP bundle
''';
  }

  Future<String> _showMemoryStatus() async {
    final sessions = await listSessions();
    final context = await getConversationContext();
    final stats = _indexService?.getStatistics() ?? {};

    return '''
Memory Status:
- Total sessions: ${sessions.length}
- Current session: ${_currentSessionId ?? 'None'}
- Messages in session: ${context['total_messages'] ?? 0}
- Topics tracked: ${stats['topics'] ?? 0}
- Entities tracked: ${stats['entities'] ?? 0}
- Open loops: ${stats['open_loops'] ?? 0}
- Closed loops: ${stats['closed_loops'] ?? 0}
''';
  }

  Future<String> _forgetMemory(String sessionId) async {
    try {
      await deleteSession(sessionId);
      return 'Session $sessionId has been deleted from memory.';
    } catch (e) {
      return 'Error deleting session $sessionId: $e';
    }
  }
}