// lib/lumara/models/reflective_node.dart
// Core data models for LUMARA multimodal reflection

import 'package:hive/hive.dart';

part 'reflective_node.g.dart';

enum NodeType {
  journal,
  draft,
  chat,
  photo,
  audio,
  video,
  phaseRegime,
}

enum PhaseHint {
  discovery,
  expansion,
  transition,
  consolidation,
  recovery,
  breakthrough,
}

@HiveType(typeId: 100)
class MediaRef {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String? mimeType;
  
  @HiveField(2)
  final int? bytes;
  
  @HiveField(3)
  final int? width;
  
  @HiveField(4)
  final int? height;
  
  @HiveField(5)
  final double? durationSec;
  
  @HiveField(6)
  final DateTime? createdAt;
  
  @HiveField(7)
  final String? sha256;
  
  @HiveField(8)
  final Map<String, dynamic>? exif;
  
  @HiveField(9)
  final String? caption;

  const MediaRef({
    required this.id,
    this.mimeType,
    this.bytes,
    this.width,
    this.height,
    this.durationSec,
    this.createdAt,
    this.sha256,
    this.exif,
    this.caption,
  });

  factory MediaRef.fromJson(Map<String, dynamic> json) {
    return MediaRef(
      id: json['id'] as String,
      mimeType: json['mimeType'] as String?,
      bytes: json['bytes'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationSec: json['durationSec'] as double?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      sha256: json['sha256'] as String?,
      exif: json['exif'] as Map<String, dynamic>?,
      caption: json['caption'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mimeType': mimeType,
      'bytes': bytes,
      'width': width,
      'height': height,
      'durationSec': durationSec,
      'createdAt': createdAt?.toIso8601String(),
      'sha256': sha256,
      'exif': exif,
      'caption': caption,
    };
  }
}

@HiveType(typeId: 101)
class ReflectiveNode {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String? mcpId;
  
  @HiveField(2)
  final NodeType type;
  
  @HiveField(3)
  final String? contentText;
  
  @HiveField(4)
  final String? captionText;
  
  @HiveField(5)
  final String? transcription;
  
  @HiveField(6)
  final List<String>? keywords;
  
  @HiveField(7)
  final PhaseHint? phaseHint;
  
  @HiveField(8)
  final List<double>? embeddingText;
  
  @HiveField(9)
  final List<double>? embeddingAffect;
  
  @HiveField(10)
  final List<MediaRef>? mediaRefs;
  
  @HiveField(11)
  final DateTime createdAt;
  
  @HiveField(12)
  final DateTime? importTimestamp;
  
  @HiveField(13)
  final String userId;
  
  @HiveField(14)
  final String? sourceBundleId;
  
  @HiveField(15)
  final DateTime? timelineAt;
  
  @HiveField(16)
  final bool deleted;
  
  @HiveField(17)
  final Map<String, dynamic>? extra;

  const ReflectiveNode({
    required this.id,
    this.mcpId,
    required this.type,
    this.contentText,
    this.captionText,
    this.transcription,
    this.keywords,
    this.phaseHint,
    this.embeddingText,
    this.embeddingAffect,
    this.mediaRefs,
    required this.createdAt,
    this.importTimestamp,
    required this.userId,
    this.sourceBundleId,
    this.timelineAt,
    this.deleted = false,
    this.extra,
  });

  factory ReflectiveNode.fromJson(Map<String, dynamic> json) {
    return ReflectiveNode(
      id: json['id'] as String,
      mcpId: json['mcpId'] as String?,
      type: NodeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NodeType.journal,
      ),
      contentText: json['contentText'] as String?,
      captionText: json['captionText'] as String?,
      transcription: json['transcription'] as String?,
      keywords: (json['keywords'] as List<dynamic>?)?.cast<String>(),
      phaseHint: json['phaseHint'] != null
          ? PhaseHint.values.firstWhere(
              (e) => e.name == json['phaseHint'],
              orElse: () => PhaseHint.discovery,
            )
          : null,
      embeddingText: (json['embeddingText'] as List<dynamic>?)?.cast<double>(),
      embeddingAffect: (json['embeddingAffect'] as List<dynamic>?)?.cast<double>(),
      mediaRefs: (json['mediaRefs'] as List<dynamic>?)
          ?.map((e) => MediaRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      importTimestamp: json['importTimestamp'] != null
          ? DateTime.parse(json['importTimestamp'])
          : null,
      userId: json['userId'] as String,
      sourceBundleId: json['sourceBundleId'] as String?,
      timelineAt: json['timelineAt'] != null
          ? DateTime.parse(json['timelineAt'])
          : null,
      deleted: json['deleted'] as bool? ?? false,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mcpId': mcpId,
      'type': type.name,
      'contentText': contentText,
      'captionText': captionText,
      'transcription': transcription,
      'keywords': keywords,
      'phaseHint': phaseHint?.name,
      'embeddingText': embeddingText,
      'embeddingAffect': embeddingAffect,
      'mediaRefs': mediaRefs?.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'importTimestamp': importTimestamp?.toIso8601String(),
      'userId': userId,
      'sourceBundleId': sourceBundleId,
      'timelineAt': timelineAt?.toIso8601String(),
      'deleted': deleted,
      'extra': extra,
    };
  }

  ReflectiveNode copyWith({
    String? id,
    String? mcpId,
    NodeType? type,
    String? contentText,
    String? captionText,
    String? transcription,
    List<String>? keywords,
    PhaseHint? phaseHint,
    List<double>? embeddingText,
    List<double>? embeddingAffect,
    List<MediaRef>? mediaRefs,
    DateTime? createdAt,
    DateTime? importTimestamp,
    String? userId,
    String? sourceBundleId,
    DateTime? timelineAt,
    bool? deleted,
    Map<String, dynamic>? extra,
  }) {
    return ReflectiveNode(
      id: id ?? this.id,
      mcpId: mcpId ?? this.mcpId,
      type: type ?? this.type,
      contentText: contentText ?? this.contentText,
      captionText: captionText ?? this.captionText,
      transcription: transcription ?? this.transcription,
      keywords: keywords ?? this.keywords,
      phaseHint: phaseHint ?? this.phaseHint,
      embeddingText: embeddingText ?? this.embeddingText,
      embeddingAffect: embeddingAffect ?? this.embeddingAffect,
      mediaRefs: mediaRefs ?? this.mediaRefs,
      createdAt: createdAt ?? this.createdAt,
      importTimestamp: importTimestamp ?? this.importTimestamp,
      userId: userId ?? this.userId,
      sourceBundleId: sourceBundleId ?? this.sourceBundleId,
      timelineAt: timelineAt ?? this.timelineAt,
      deleted: deleted ?? this.deleted,
      extra: extra ?? this.extra,
    );
  }
}

class MatchedNode {
  final String id;
  final NodeType sourceType;
  final String? originalMcpId;
  final DateTime? approxDate;
  final PhaseHint? phaseHint;
  final List<String>? mediaRefs;
  final double similarity;
  final String? excerpt;

  const MatchedNode({
    required this.id,
    required this.sourceType,
    this.originalMcpId,
    this.approxDate,
    this.phaseHint,
    this.mediaRefs,
    required this.similarity,
    this.excerpt,
  });

  factory MatchedNode.fromJson(Map<String, dynamic> json) {
    return MatchedNode(
      id: json['id'] as String,
      sourceType: NodeType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => NodeType.journal,
      ),
      originalMcpId: json['originalMcpId'] as String?,
      approxDate: json['approxDate'] != null
          ? DateTime.parse(json['approxDate'])
          : null,
      phaseHint: json['phaseHint'] != null
          ? PhaseHint.values.firstWhere(
              (e) => e.name == json['phaseHint'],
              orElse: () => PhaseHint.discovery,
            )
          : null,
      mediaRefs: (json['mediaRefs'] as List<dynamic>?)?.cast<String>(),
      similarity: (json['similarity'] as num).toDouble(),
      excerpt: json['excerpt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceType': sourceType.name,
      'originalMcpId': originalMcpId,
      'approxDate': approxDate?.toIso8601String(),
      'phaseHint': phaseHint?.name,
      'mediaRefs': mediaRefs,
      'similarity': similarity,
      'excerpt': excerpt,
    };
  }
}

class ReflectivePromptResponse {
  final String contextSummary;
  final List<MatchedNode> matchedNodes;
  final List<String> reflectivePrompts;
  final List<String>? crossModalPatterns;
  final List<String>? nextStepSuggestions;

  const ReflectivePromptResponse({
    required this.contextSummary,
    required this.matchedNodes,
    required this.reflectivePrompts,
    this.crossModalPatterns,
    this.nextStepSuggestions,
  });

  factory ReflectivePromptResponse.fromJson(Map<String, dynamic> json) {
    return ReflectivePromptResponse(
      contextSummary: json['contextSummary'] as String,
      matchedNodes: (json['matchedNodes'] as List<dynamic>)
          .map((e) => MatchedNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      reflectivePrompts: (json['reflectivePrompts'] as List<dynamic>).cast<String>(),
      crossModalPatterns: (json['crossModalPatterns'] as List<dynamic>?)?.cast<String>(),
      nextStepSuggestions: (json['nextStepSuggestions'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contextSummary': contextSummary,
      'matchedNodes': matchedNodes.map((e) => e.toJson()).toList(),
      'reflectivePrompts': reflectivePrompts,
      'crossModalPatterns': crossModalPatterns,
      'nextStepSuggestions': nextStepSuggestions,
    };
  }
}