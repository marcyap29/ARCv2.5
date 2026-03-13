// lib/arc/outputs/outputs_models.dart
//
// Phase 5a: OutputItem and folder taxonomy for the Outputs tab.

/// A single output item (scan, research report, draft reference, etc.).
class OutputItem {
  final String id;
  final String agentKey;
  final String folderKey;
  final String title;
  final DateTime createdAt;
  final String? contentJson;
  final List<String> autoTags;
  final List<String> userTags;
  final String? thumbnailUrl;

  const OutputItem({
    required this.id,
    required this.agentKey,
    required this.folderKey,
    required this.title,
    required this.createdAt,
    this.contentJson,
    this.autoTags = const [],
    this.userTags = const [],
    this.thumbnailUrl,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'agentKey': agentKey,
      'folderKey': folderKey,
      'title': title,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'contentJson': contentJson,
      'autoTags': List<String>.from(autoTags),
      'userTags': List<String>.from(userTags),
      'thumbnailUrl': thumbnailUrl,
    };
  }

  factory OutputItem.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime createdAt = DateTime.now();
    final raw = data['createdAt'];
    if (raw is DateTime) {
      createdAt = raw;
    } else if (raw != null) {
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) createdAt = parsed;
    }
    return OutputItem(
      id: id,
      agentKey: data['agentKey'] as String? ?? '',
      folderKey: data['folderKey'] as String? ?? '',
      title: data['title'] as String? ?? '',
      createdAt: createdAt,
      contentJson: data['contentJson'] as String?,
      autoTags: List<String>.from(data['autoTags'] as List? ?? []),
      userTags: List<String>.from(data['userTags'] as List? ?? []),
      thumbnailUrl: data['thumbnailUrl'] as String?,
    );
  }

  OutputItem copyWith({
    String? id,
    String? agentKey,
    String? folderKey,
    String? title,
    DateTime? createdAt,
    String? contentJson,
    List<String>? autoTags,
    List<String>? userTags,
    String? thumbnailUrl,
  }) {
    return OutputItem(
      id: id ?? this.id,
      agentKey: agentKey ?? this.agentKey,
      folderKey: folderKey ?? this.folderKey,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      contentJson: contentJson ?? this.contentJson,
      autoTags: autoTags ?? List.from(this.autoTags),
      userTags: userTags ?? List.from(this.userTags),
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}

/// Folder definition for the two-level taxonomy: Agent → Category.
class OutputFolder {
  final String agentKey;
  final String folderKey;
  final String label;

  const OutputFolder({
    required this.agentKey,
    required this.folderKey,
    required this.label,
  });

  String get fullKey => '$agentKey/$folderKey';
}

/// Phase 5a folder taxonomy (all folders shown at launch, even if empty).
const List<OutputFolder> kOutputFolders = [
  OutputFolder(agentKey: 'forms', folderKey: 'completed_forms', label: 'Completed Forms'),
  OutputFolder(agentKey: 'research', folderKey: 'research', label: 'Research'),
  OutputFolder(agentKey: 'scanner', folderKey: 'scans', label: 'Scans'),
  OutputFolder(agentKey: 'writer', folderKey: 'articles', label: 'Articles'),
  OutputFolder(agentKey: 'writer', folderKey: 'bluesky', label: 'Bluesky'),
  OutputFolder(agentKey: 'writer', folderKey: 'linkedin', label: 'LinkedIn'),
  OutputFolder(agentKey: 'writer', folderKey: 'substack', label: 'Substack'),
  OutputFolder(agentKey: 'writer', folderKey: 'threads', label: 'Threads'),
];

/// Top-level agent labels for grouping (Forms, Research, Scanner, Writer).
String outputAgentLabel(String agentKey) {
  switch (agentKey) {
    case 'forms':
      return 'Forms';
    case 'research':
      return 'Research';
    case 'scanner':
      return 'Scanner';
    case 'writer':
      return 'Writer';
    default:
      return agentKey;
  }
}
