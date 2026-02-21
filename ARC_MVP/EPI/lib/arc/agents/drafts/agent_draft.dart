// lib/arc/agents/drafts/agent_draft.dart
// Model for agent-generated drafts (Writing/Research) with versioning and publish target.

/// Which agent produced the draft.
enum AgentType {
  writing,
  research;

  String get displayName => switch (this) {
        AgentType.writing => 'Writing',
        AgentType.research => 'Research',
      };
}

/// Draft lifecycle status.
enum DraftStatus {
  draft,
  edited,
  readyToPublish,
  published,
}

/// Where the draft was or will be published.
enum PublishTarget {
  substack,
  linkedin,
  twitter,
  clipboard,
  export,
}

/// A single draft produced by the Writing or Research agent.
class AgentDraft {
  final String id;
  final AgentType agentType;
  final String title;
  final String content;
  final String originalPrompt;
  final String? sourceMaterial;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final DraftStatus status;
  final Map<String, dynamic> metadata;
  final List<String> versions;
  final PublishTarget? publishTarget;
  final bool archived;
  final DateTime? archivedAt;

  const AgentDraft({
    required this.id,
    required this.agentType,
    required this.title,
    required this.content,
    required this.originalPrompt,
    this.sourceMaterial,
    required this.createdAt,
    this.lastEditedAt,
    this.status = DraftStatus.draft,
    this.metadata = const {},
    this.versions = const [],
    this.publishTarget,
    this.archived = false,
    this.archivedAt,
  });

  AgentDraft copyWith({
    String? id,
    AgentType? agentType,
    String? title,
    String? content,
    String? originalPrompt,
    String? sourceMaterial,
    DateTime? createdAt,
    DateTime? lastEditedAt,
    DraftStatus? status,
    Map<String, dynamic>? metadata,
    List<String>? versions,
    PublishTarget? publishTarget,
    bool? archived,
    DateTime? archivedAt,
  }) {
    return AgentDraft(
      id: id ?? this.id,
      agentType: agentType ?? this.agentType,
      title: title ?? this.title,
      content: content ?? this.content,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      sourceMaterial: sourceMaterial ?? this.sourceMaterial,
      createdAt: createdAt ?? this.createdAt,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      versions: versions ?? this.versions,
      publishTarget: publishTarget ?? this.publishTarget,
      archived: archived ?? this.archived,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'agentType': agentType.name,
        'title': title,
        'content': content,
        'originalPrompt': originalPrompt,
        'sourceMaterial': sourceMaterial,
        'createdAt': createdAt.toIso8601String(),
        'lastEditedAt': lastEditedAt?.toIso8601String(),
        'status': status.name,
        'metadata': metadata,
        'versions': versions,
        'publishTarget': publishTarget?.name,
        'archived': archived,
        'archivedAt': archivedAt?.toIso8601String(),
      };

  static PublishTarget? _parsePublishTarget(String? name) {
    if (name == null || name.isEmpty) return null;
    try {
      return PublishTarget.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  factory AgentDraft.fromJson(Map<String, dynamic> json) {
    return AgentDraft(
      id: json['id'] as String,
      agentType: AgentType.values.firstWhere(
        (e) => e.name == json['agentType'],
        orElse: () => AgentType.writing,
      ),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      originalPrompt: json['originalPrompt'] as String? ?? '',
      sourceMaterial: json['sourceMaterial'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastEditedAt: json['lastEditedAt'] != null
          ? DateTime.tryParse(json['lastEditedAt'] as String)
          : null,
      status: DraftStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DraftStatus.draft,
      ),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      versions: List<String>.from(json['versions'] as List? ?? []),
      publishTarget: _parsePublishTarget(json['publishTarget'] as String?),
      archived: json['archived'] as bool? ?? false,
      archivedAt: json['archivedAt'] != null
          ? DateTime.tryParse(json['archivedAt'] as String)
          : null,
    );
  }
}
