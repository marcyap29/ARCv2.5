// lib/lumara/memory/memory_index_service.dart
// Global memory index management for topics, entities, and open loops

import 'dart:convert';
import 'dart:io';
import 'mcp_memory_models.dart';

/// Service for managing the global memory index
class MemoryIndexService {
  final String userId;
  final String indexPath;
  MemoryIndex? _index;

  MemoryIndexService({
    required this.userId,
    required this.indexPath,
  });

  /// Initialize the memory index
  Future<void> initialize() async {
    await _loadIndex();
  }

  /// Update index with new message content
  Future<void> updateFromMessage(ConversationMessage message) async {
    final topics = _extractTopics(message.content);
    final entities = _extractEntities(message.content);
    final openLoops = _extractOpenLoops(message.content);

    await _updateTopics(topics, message.id, message.timestamp);
    await _updateEntities(entities, message.id, message.timestamp);
    await _updateOpenLoops(openLoops, message.id, message.timestamp);

    await _saveIndex();
  }

  /// Update index with conversation summary
  Future<void> updateFromSummary(ConversationSummary summary) async {
    // Extract additional insights from summary
    final topics = _extractTopicsFromSummary(summary);
    final entities = _extractEntitiesFromSummary(summary);
    final openLoops = summary.openLoops;

    await _updateTopics(topics, summary.id, summary.timestamp);
    await _updateEntities(entities, summary.id, summary.timestamp);
    await _updateOpenLoopsFromList(openLoops, summary.id, summary.timestamp);

    await _saveIndex();
  }

  /// Get topics matching query
  List<TopicEntry> searchTopics(String query, {int limit = 10}) {
    if (_index == null) return [];

    final queryLower = query.toLowerCase();
    final matches = _index!.topics
        .where((topic) => topic.topic.toLowerCase().contains(queryLower))
        .toList()
      ..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));

    return matches.take(limit).toList();
  }

  /// Get entities matching query
  List<EntityEntry> searchEntities(String query, {int limit = 10}) {
    if (_index == null) return [];

    final queryLower = query.toLowerCase();
    final matches = _index!.entities
        .where((entity) => entity.name.toLowerCase().contains(queryLower))
        .toList()
      ..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));

    return matches.take(limit).toList();
  }

  /// Get all open loops
  List<OpenLoopEntry> getOpenLoops() {
    if (_index == null) return [];

    return _index!.openLoops
        .where((loop) => loop.status == 'open')
        .toList()
      ..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
  }

  /// Close an open loop
  Future<void> closeOpenLoop(String title) async {
    if (_index == null) return;

    final loops = List<OpenLoopEntry>.from(_index!.openLoops);
    final index = loops.indexWhere((loop) => loop.title == title);

    if (index != -1) {
      loops[index] = OpenLoopEntry(
        title: loops[index].title,
        refs: loops[index].refs,
        status: 'closed',
        lastTimestamp: DateTime.now(),
      );

      _index = MemoryIndex(
        owner: _index!.owner,
        updatedAt: DateTime.now(),
        topics: _index!.topics,
        entities: _index!.entities,
        openLoops: loops,
      );

      await _saveIndex();
    }
  }

  /// Get relevant context for a query
  Future<Map<String, dynamic>> getRelevantContext(String query, {int limit = 5}) async {
    final topics = searchTopics(query, limit: limit);
    final entities = searchEntities(query, limit: limit);
    final openLoops = getOpenLoops().take(limit).toList();

    return {
      'topics': topics.map((t) => {
        'topic': t.topic,
        'refs': t.refs,
        'last_ts': t.lastTimestamp.toIso8601String(),
      }).toList(),
      'entities': entities.map((e) => {
        'name': e.name,
        'refs': e.refs,
        'last_ts': e.lastTimestamp.toIso8601String(),
      }).toList(),
      'open_loops': openLoops.map((o) => {
        'title': o.title,
        'refs': o.refs,
        'status': o.status,
        'last_ts': o.lastTimestamp.toIso8601String(),
      }).toList(),
    };
  }

  /// Remove references to a deleted session
  Future<void> removeSessionReferences(String sessionId) async {
    if (_index == null) return;

    final sessionPrefix = 'sess:$sessionId';

    // Remove refs from topics
    final updatedTopics = _index!.topics
        .map((topic) => TopicEntry(
              topic: topic.topic,
              refs: topic.refs.where((ref) => !ref.startsWith(sessionPrefix)).toList(),
              lastTimestamp: topic.lastTimestamp,
            ))
        .where((topic) => topic.refs.isNotEmpty)
        .toList();

    // Remove refs from entities
    final updatedEntities = _index!.entities
        .map((entity) => EntityEntry(
              name: entity.name,
              refs: entity.refs.where((ref) => !ref.startsWith(sessionPrefix)).toList(),
              lastTimestamp: entity.lastTimestamp,
            ))
        .where((entity) => entity.refs.isNotEmpty)
        .toList();

    // Remove refs from open loops
    final updatedOpenLoops = _index!.openLoops
        .map((loop) => OpenLoopEntry(
              title: loop.title,
              refs: loop.refs.where((ref) => !ref.startsWith(sessionPrefix)).toList(),
              status: loop.status,
              lastTimestamp: loop.lastTimestamp,
            ))
        .where((loop) => loop.refs.isNotEmpty)
        .toList();

    _index = MemoryIndex(
      owner: _index!.owner,
      updatedAt: DateTime.now(),
      topics: updatedTopics,
      entities: updatedEntities,
      openLoops: updatedOpenLoops,
    );

    await _saveIndex();
  }

  /// Get index statistics
  Map<String, int> getStatistics() {
    if (_index == null) {
      return {
        'topics': 0,
        'entities': 0,
        'open_loops': 0,
        'closed_loops': 0,
      };
    }

    final openLoopsCount = _index!.openLoops.where((l) => l.status == 'open').length;
    final closedLoopsCount = _index!.openLoops.where((l) => l.status == 'closed').length;

    return {
      'topics': _index!.topics.length,
      'entities': _index!.entities.length,
      'open_loops': openLoopsCount,
      'closed_loops': closedLoopsCount,
    };
  }

  // Private methods

  Future<void> _loadIndex() async {
    final indexFile = File(indexPath);

    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _index = MemoryIndex.fromJson(json);
      } catch (e) {
        print('Memory Index: Error loading index: $e');
        _index = _createEmptyIndex();
      }
    } else {
      _index = _createEmptyIndex();
    }
  }

  MemoryIndex _createEmptyIndex() {
    return MemoryIndex(
      owner: userId,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _saveIndex() async {
    if (_index == null) return;

    _index = MemoryIndex(
      owner: _index!.owner,
      updatedAt: DateTime.now(),
      topics: _index!.topics,
      entities: _index!.entities,
      openLoops: _index!.openLoops,
    );

    final indexFile = File(indexPath);
    await indexFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_index!.toJson()),
    );
  }

  Future<void> _updateTopics(List<String> topics, String refId, DateTime timestamp) async {
    if (_index == null) return;

    final existingTopics = Map<String, TopicEntry>.fromEntries(
      _index!.topics.map((t) => MapEntry(t.topic, t)),
    );

    for (final topic in topics) {
      if (existingTopics.containsKey(topic)) {
        final existing = existingTopics[topic]!;
        final updatedRefs = Set<String>.from(existing.refs)..add(refId);
        existingTopics[topic] = TopicEntry(
          topic: topic,
          refs: updatedRefs.toList(),
          lastTimestamp: timestamp,
        );
      } else {
        existingTopics[topic] = TopicEntry(
          topic: topic,
          refs: [refId],
          lastTimestamp: timestamp,
        );
      }
    }

    _index = MemoryIndex(
      owner: _index!.owner,
      updatedAt: _index!.updatedAt,
      topics: existingTopics.values.toList(),
      entities: _index!.entities,
      openLoops: _index!.openLoops,
    );
  }

  Future<void> _updateEntities(List<String> entities, String refId, DateTime timestamp) async {
    if (_index == null) return;

    final existingEntities = Map<String, EntityEntry>.fromEntries(
      _index!.entities.map((e) => MapEntry(e.name, e)),
    );

    for (final entity in entities) {
      if (existingEntities.containsKey(entity)) {
        final existing = existingEntities[entity]!;
        final updatedRefs = Set<String>.from(existing.refs)..add(refId);
        existingEntities[entity] = EntityEntry(
          name: entity,
          refs: updatedRefs.toList(),
          lastTimestamp: timestamp,
        );
      } else {
        existingEntities[entity] = EntityEntry(
          name: entity,
          refs: [refId],
          lastTimestamp: timestamp,
        );
      }
    }

    _index = MemoryIndex(
      owner: _index!.owner,
      updatedAt: _index!.updatedAt,
      topics: _index!.topics,
      entities: existingEntities.values.toList(),
      openLoops: _index!.openLoops,
    );
  }

  Future<void> _updateOpenLoops(List<String> loops, String refId, DateTime timestamp) async {
    if (_index == null) return;

    final existingLoops = Map<String, OpenLoopEntry>.fromEntries(
      _index!.openLoops.map((l) => MapEntry(l.title, l)),
    );

    for (final loop in loops) {
      if (existingLoops.containsKey(loop)) {
        final existing = existingLoops[loop]!;
        final updatedRefs = Set<String>.from(existing.refs)..add(refId);
        existingLoops[loop] = OpenLoopEntry(
          title: loop,
          refs: updatedRefs.toList(),
          status: 'open',
          lastTimestamp: timestamp,
        );
      } else {
        existingLoops[loop] = OpenLoopEntry(
          title: loop,
          refs: [refId],
          status: 'open',
          lastTimestamp: timestamp,
        );
      }
    }

    _index = MemoryIndex(
      owner: _index!.owner,
      updatedAt: _index!.updatedAt,
      topics: _index!.topics,
      entities: _index!.entities,
      openLoops: existingLoops.values.toList(),
    );
  }

  Future<void> _updateOpenLoopsFromList(List<String> loops, String refId, DateTime timestamp) async {
    await _updateOpenLoops(loops, refId, timestamp);
  }

  List<String> _extractTopics(String content) {
    final topics = <String>[];
    final contentLower = content.toLowerCase();

    // Technical topics
    final techPatterns = {
      'api_development': RegExp(r'\b(api|endpoint|rest|graphql|webhook)\b'),
      'database': RegExp(r'\b(database|sql|query|table|schema)\b'),
      'frontend': RegExp(r'\b(ui|ux|frontend|react|flutter|component)\b'),
      'backend': RegExp(r'\b(backend|server|service|microservice)\b'),
      'deployment': RegExp(r'\b(deploy|deployment|ci|cd|pipeline)\b'),
      'testing': RegExp(r'\b(test|testing|unit|integration|qa)\b'),
      'security': RegExp(r'\b(security|auth|authentication|encryption)\b'),
      'performance': RegExp(r'\b(performance|optimization|speed|latency)\b'),
    };

    // Business topics
    final businessPatterns = {
      'project_management': RegExp(r'\b(project|milestone|deadline|sprint)\b'),
      'planning': RegExp(r'\b(plan|planning|strategy|roadmap)\b'),
      'meeting': RegExp(r'\b(meeting|call|discussion|standup)\b'),
      'client_communication': RegExp(r'\b(client|customer|stakeholder|feedback)\b'),
      'documentation': RegExp(r'\b(document|documentation|spec|requirement)\b'),
    };

    // Personal topics
    final personalPatterns = {
      'learning': RegExp(r'\b(learn|study|tutorial|course|skill)\b'),
      'problem_solving': RegExp(r'\b(problem|issue|bug|fix|solve)\b'),
      'collaboration': RegExp(r'\b(team|collaborate|pair|review)\b'),
      'career': RegExp(r'\b(career|job|promotion|interview)\b'),
      'wellbeing': RegExp(r'\b(stress|burnout|break|health|balance)\b'),
    };

    final allPatterns = {
      ...techPatterns,
      ...businessPatterns,
      ...personalPatterns,
    };

    for (final entry in allPatterns.entries) {
      if (entry.value.hasMatch(contentLower)) {
        topics.add(entry.key);
      }
    }

    return topics;
  }

  List<String> _extractEntities(String content) {
    final entities = <String>[];

    // Extract potential names (capitalized words)
    final namePattern = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b');
    final matches = namePattern.allMatches(content);

    for (final match in matches) {
      final name = match.group(0)!;
      if (!_isCommonWord(name) && name.length > 2) {
        entities.add(name);
      }
    }

    // Extract organizations
    final orgPattern = RegExp(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+(?:Inc|Corp|LLC|Ltd|Company|Co)\b');
    final orgMatches = orgPattern.allMatches(content);

    for (final match in orgMatches) {
      entities.add(match.group(0)!);
    }

    return entities.toSet().toList();
  }

  List<String> _extractOpenLoops(String content) {
    final loops = <String>[];

    // Extract questions
    final questionPattern = RegExp(r'[^.!?]*\?');
    final questionMatches = questionPattern.allMatches(content);

    for (final match in questionMatches) {
      final question = match.group(0)!.trim();
      if (question.length > 10) {
        loops.add(question);
      }
    }

    // Extract todos and action items
    final todoPatterns = [
      RegExp(r'\b(?:need to|should|must|have to|todo|task)\s+[^.!?]*[.!?]'),
      RegExp(r'\b(?:remind|remember|follow up)\s+[^.!?]*[.!?]'),
      RegExp(r'\b(?:action item|ai|todo):\s*[^.!?]*[.!?]'),
    ];

    for (final pattern in todoPatterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        final todo = match.group(0)!.trim();
        if (todo.length > 10) {
          loops.add(todo);
        }
      }
    }

    return loops;
  }

  List<String> _extractTopicsFromSummary(ConversationSummary summary) {
    final topics = <String>[];

    // Extract from key facts
    for (final fact in summary.keyFacts) {
      topics.addAll(_extractTopics(fact));
    }

    // Extract from content
    topics.addAll(_extractTopics(summary.content));

    return topics.toSet().toList();
  }

  List<String> _extractEntitiesFromSummary(ConversationSummary summary) {
    final entities = <String>[];

    // Extract from key facts
    for (final fact in summary.keyFacts) {
      entities.addAll(_extractEntities(fact));
    }

    // Extract from content
    entities.addAll(_extractEntities(summary.content));

    return entities.toSet().toList();
  }

  bool _isCommonWord(String word) {
    const commonWords = {
      'The', 'This', 'That', 'And', 'But', 'Or', 'So', 'If', 'When', 'Where',
      'Who', 'What', 'How', 'Why', 'Can', 'Will', 'Should', 'Could', 'Would',
      'Have', 'Has', 'Had', 'Do', 'Does', 'Did', 'Get', 'Got', 'Make', 'Made',
      'Also', 'Just', 'Now', 'Then', 'Here', 'There', 'Very', 'Much', 'More',
      'Some', 'Any', 'All', 'Each', 'Every', 'Other', 'Another', 'Same', 'Different',
    };

    return commonWords.contains(word);
  }
}