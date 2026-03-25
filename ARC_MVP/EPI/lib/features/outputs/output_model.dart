import 'package:collection/collection.dart';

class WorkflowOutput {
  final String id; // UUID generated at save time
  final String type; // 'research' | 'competitor' | 'writing' | 'image'
  final String title; // derived from input (first 60 chars)
  final String input; // original user input
  final DateTime createdAt;
  final Map<String, dynamic> data; // raw result from Worker
  final List<String> steps; // chain steps that ran

  const WorkflowOutput({
    required this.id,
    required this.type,
    required this.title,
    required this.input,
    required this.createdAt,
    required this.data,
    required this.steps,
  });

  // Derive display type from steps
  static String typeFromSteps(List<String> steps) {
    final lower = steps.map((s) => s.toLowerCase()).toList();
    if (lower.contains('competitor intel')) return 'competitor';
    if (lower.contains('plugin discovery')) return 'plugins';
    if (lower.contains('writing') && !lower.contains('research')) return 'writing';
    if (lower.contains('writing')) return 'research'; // research + writing = research report
    return 'research';
  }

  String get typeLabel {
    switch (type) {
      case 'competitor':
        return 'Competitive Brief';
      case 'writing':
        return 'Content Pack';
      case 'plugins':
        return 'Plugin Discovery';
      default:
        return 'Research Report';
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'competitor':
        return '🗺️';
      case 'writing':
        return '✍️';
      case 'plugins':
        return '🔌';
      default:
        return '🔍';
    }
  }

  String get preview {
    // First 120 chars of the most relevant content field
    if (type == 'writing') {
      final platforms = data['platforms'] as Map<String, dynamic>?;
      final first = platforms?.values.firstOrNull as String?;
      return first != null
          ? first.substring(0, first.length.clamp(0, 120))
          : input;
    }
    if (type == 'competitor') {
      final brief = data['brief'] as String?;
      return brief != null
          ? brief.substring(0, brief.length.clamp(0, 120))
          : input;
    }
    final report = data['report'] as String?;
    return report != null
        ? report.substring(0, report.length.clamp(0, 120))
        : input;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'input': input,
        'createdAt': createdAt.toIso8601String(),
        'data': data,
        'steps': steps,
      };

  factory WorkflowOutput.fromJson(Map<String, dynamic> json) => WorkflowOutput(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        input: json['input'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        data: Map<String, dynamic>.from(json['data'] as Map),
        steps: List<String>.from(json['steps'] as List),
      );
}

