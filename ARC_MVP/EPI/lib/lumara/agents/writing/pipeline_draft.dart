// lib/lumara/agents/writing/pipeline_draft.dart
//
// Phase 5b: Draft produced by the writing pipeline (gemini-flash).
// Used by DraftEditorScreen and Save to Outputs.

/// Format for generated content; maps to Writing subfolders.
enum WritingFormat {
  article,
  linkedin,
  substack,
  bluesky,
  threads,
}

/// Tone for the draft.
enum WritingTone {
  informative,
  conversational,
  persuasive,
  reflective,
}

/// Draft produced by the Phase 5b writing pipeline.
/// Serialises to JSON for OutputItem.contentJson.
class PipelineDraft {
  final String id;
  final String topic;
  final WritingFormat format;
  final WritingTone tone;
  final String body;
  final String? briefId;
  final DateTime createdAt;
  final List<String> versions;

  const PipelineDraft({
    required this.id,
    required this.topic,
    required this.format,
    required this.tone,
    required this.body,
    this.briefId,
    required this.createdAt,
    this.versions = const [],
  });

  PipelineDraft copyWith({
    String? id,
    String? topic,
    WritingFormat? format,
    WritingTone? tone,
    String? body,
    String? briefId,
    DateTime? createdAt,
    List<String>? versions,
  }) {
    return PipelineDraft(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      format: format ?? this.format,
      tone: tone ?? this.tone,
      body: body ?? this.body,
      briefId: briefId ?? this.briefId,
      createdAt: createdAt ?? this.createdAt,
      versions: versions ?? List.from(this.versions),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'format': format.name,
        'tone': tone.name,
        'body': body,
        'briefId': briefId,
        'createdAt': createdAt.toIso8601String(),
        'versions': List<String>.from(versions),
      };

  factory PipelineDraft.fromJson(Map<String, dynamic> json) {
    final vers = json['versions'] as List<dynamic>? ?? [];
    return PipelineDraft(
      id: json['id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      format: _parseFormat(json['format'] as String?),
      tone: _parseTone(json['tone'] as String?),
      body: json['body'] as String? ?? '',
      briefId: json['briefId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      versions: vers.map((e) => e.toString()).toList(),
    );
  }

  static WritingFormat _parseFormat(String? v) {
    if (v == null) return WritingFormat.article;
    return WritingFormat.values.firstWhere(
      (e) => e.name == v.toLowerCase(),
      orElse: () => WritingFormat.article,
    );
  }

  static WritingTone _parseTone(String? v) {
    if (v == null) return WritingTone.informative;
    return WritingTone.values.firstWhere(
      (e) => e.name == v.toLowerCase(),
      orElse: () => WritingTone.informative,
    );
  }

  /// Writing folderKey for Outputs (article → articles, etc.).
  String get folderKey {
    switch (format) {
      case WritingFormat.article:
        return 'articles';
      case WritingFormat.linkedin:
        return 'linkedin';
      case WritingFormat.substack:
        return 'substack';
      case WritingFormat.bluesky:
        return 'bluesky';
      case WritingFormat.threads:
        return 'threads';
    }
  }
}
