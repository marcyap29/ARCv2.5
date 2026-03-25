import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'agents_data.dart';

/// CHRONICLE bundle sent to the workflow Worker when [useChronicle] is true.
class ChronicleBundle {
  final String profile;
  final String tags;
  final String recent;
  final String topical;

  const ChronicleBundle({
    required this.profile,
    required this.tags,
    required this.recent,
    required this.topical,
  });

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'tags': tags
            .split(', ')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'recent': recent,
        'topical': topical,
      };
}

class WritingPlatform {
  final String id;
  final String label;
  final String emoji;
  final bool defaultSelected;

  const WritingPlatform({
    required this.id,
    required this.label,
    required this.emoji,
    required this.defaultSelected,
  });
}

class WritingPlatforms {
  static const List<WritingPlatform> all = [
    WritingPlatform(
      id: 'linkedin',
      label: 'LinkedIn',
      emoji: '💼',
      defaultSelected: true,
    ),
    WritingPlatform(
      id: 'orbital_ai',
      label: 'Orbital AI (Substack)',
      emoji: '🚀',
      defaultSelected: true,
    ),
    WritingPlatform(
      id: 'mechanical_musings',
      label: 'Mechanical Musings',
      emoji: '⚙️',
      defaultSelected: true,
    ),
    WritingPlatform(
      id: 'twitter',
      label: 'Twitter / X',
      emoji: '𝕏',
      defaultSelected: false,
    ),
    WritingPlatform(
      id: 'bluesky',
      label: 'Bluesky',
      emoji: '🦋',
      defaultSelected: false,
    ),
    WritingPlatform(
      id: 'reddit',
      label: 'Reddit',
      emoji: '🤖',
      defaultSelected: false,
    ),
    WritingPlatform(
      id: 'devto',
      label: 'Dev.to',
      emoji: '👩‍💻',
      defaultSelected: false,
    ),
    WritingPlatform(
      id: 'hacker_news',
      label: 'Hacker News',
      emoji: '🔶',
      defaultSelected: false,
    ),
  ];

  static List<String> defaultSelectedIds() =>
      all.where((p) => p.defaultSelected).map((p) => p.id).toList();
}

class WorkerService {
  WorkerService._();

  static const String _base = 'https://lumara-workflows.orbitalai.workers.dev';

  /// Picks the Worker route for this [chain] (single POST covers the whole run).
  static String resolveEndpoint(WorkflowChain chain) {
    final steps = chain.steps.map((s) => s.toLowerCase()).toList();

    if (steps.contains('competitor intel')) {
      return '$_base/workflows/competitor';
    }
    if (steps.contains('plugin discovery')) {
      return '$_base/workflows/plugins';
    }
    if (steps.length > 1 && steps.contains('writing')) {
      return '$_base/workflows/writing';
    }
    if (steps.contains('research')) {
      return '$_base/workflows/research';
    }
    if (steps.contains('writing')) {
      return '$_base/workflows/writing';
    }

    return '$_base/workflows/research';
  }

  /// POST [endpoint] and parse Server-Sent Events (`data: {...}`) lines.
  static Stream<Map<String, dynamic>> streamWorkflow({
    required String endpoint,
    required String input,
    required bool useChronicle,
    ChronicleBundle? chronicle,
    List<String>? platforms,
  }) async* {
    final client = http.Client();
    try {
      final body = <String, dynamic>{
        'input': input,
        'use_chronicle': useChronicle,
      };
      if (useChronicle && chronicle != null) {
        body['chronicle_context'] = chronicle.toJson();
      }
      if (platforms != null && platforms.isNotEmpty) {
        body['platforms'] = platforms;
      }

      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final response = await client.send(request);
      if (response.statusCode != 200) {
        yield {
          'type': 'error',
          'message': 'HTTP ${response.statusCode}',
        };
        return;
      }

      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final parts = buffer.split('\n');
        buffer = parts.isNotEmpty ? parts.removeLast() : '';
        for (final raw in parts) {
          final line = raw.trimRight();
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isNotEmpty) {
              try {
                final event = jsonDecode(jsonStr) as Map<String, dynamic>;
                yield event;
              } catch (_) {
                /* skip malformed line */
              }
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
