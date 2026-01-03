import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/state/journal_entry_state.dart';

part 'journal_entry_model.g.dart';

@HiveType(typeId: 0)
class JournalEntry extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final List<String> tags;

  @HiveField(6)
  final String mood;

  @HiveField(7)
  final String? audioUri; // Legacy field - kept for migration compatibility

  @HiveField(12)
  final List<MediaItem> media; // New multi-modal media list

  @HiveField(8)
  final SAGEAnnotation? sageAnnotation;

  @HiveField(9)
  final List<String> keywords;

  @HiveField(10)
  final String? emotion;

  @HiveField(11)
  final String? emotionReason;

  @HiveField(13)
  final Map<String, dynamic>? metadata;

  @HiveField(14)
  final String? location; // Location where entry was created/edited

  @HiveField(15)
  final String? phase; // Current phase of the entry (deprecated - use phaseAtTime)
  
  @HiveField(18)
  final DateTime? phaseAtTime; // Reference to phase regime start time

  @HiveField(16)
  final bool isEdited; // Whether this entry has been edited from original

  // New phase detection fields (versioned inference pipeline)
  @HiveField(19)
  final String? autoPhase; // Model-detected phase, authoritative
  
  @HiveField(20)
  final double? autoPhaseConfidence; // Confidence score 0.0-1.0
  
  @HiveField(21)
  final String? userPhaseOverride; // Manual override via dropdown
  
  @HiveField(22)
  final bool isPhaseLocked; // If true, don't auto-overwrite
  
  @HiveField(23)
  final String? legacyPhaseTag; // From old phase field or imports (reference only)
  
  @HiveField(24)
  final String? importSource; // "NATIVE", "ARCHX", "ZIP", "OTHER"
  
  @HiveField(25)
  final int? phaseInferenceVersion; // Version of inference pipeline used
  
  @HiveField(26)
  final String? phaseMigrationStatus; // "PENDING", "DONE", "SKIPPED"

  @HiveField(27)
  final List<InlineBlock> lumaraBlocks; // LUMARA inline reflection blocks

  @HiveField(28)
  final String? overview; // 3-5 sentence overview of the entire entry (user content + LUMARA comments)

  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.mood,
    this.audioUri, // Legacy field
    this.media = const [], // New multi-modal media list
    this.sageAnnotation,
    this.keywords = const [],
    this.emotion,
    this.emotionReason,
    this.metadata,
    this.location,
    this.phase,
    this.phaseAtTime,
    this.isEdited = false,
    this.autoPhase,
    this.autoPhaseConfidence,
    this.userPhaseOverride,
    this.isPhaseLocked = false,
    this.legacyPhaseTag,
    this.importSource,
    this.phaseInferenceVersion,
    this.phaseMigrationStatus,
    this.lumaraBlocks = const [], // LUMARA inline reflection blocks
    this.overview, // 3-5 sentence overview of the entire entry
  });

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? mood,
    String? audioUri, // Legacy field
    List<MediaItem>? media, // New multi-modal media list
    SAGEAnnotation? sageAnnotation,
    List<String>? keywords,
    String? emotion,
    String? emotionReason,
    Map<String, dynamic>? metadata,
    String? location,
    String? phase,
    DateTime? phaseAtTime,
    bool? isEdited,
    String? autoPhase,
    double? autoPhaseConfidence,
    String? userPhaseOverride,
    bool? isPhaseLocked,
    String? legacyPhaseTag,
    String? importSource,
    int? phaseInferenceVersion,
    String? phaseMigrationStatus,
    List<InlineBlock>? lumaraBlocks,
    String? overview,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      mood: mood ?? this.mood,
      audioUri: audioUri ?? this.audioUri, // Legacy field
      media: media ?? this.media, // New multi-modal media list
      sageAnnotation: sageAnnotation ?? this.sageAnnotation,
      keywords: keywords ?? this.keywords,
      emotion: emotion ?? this.emotion,
      emotionReason: emotionReason ?? this.emotionReason,
      metadata: metadata ?? this.metadata,
      location: location ?? this.location,
      phase: phase ?? this.phase,
      phaseAtTime: phaseAtTime ?? this.phaseAtTime,
      isEdited: isEdited ?? this.isEdited,
      autoPhase: autoPhase ?? this.autoPhase,
      autoPhaseConfidence: autoPhaseConfidence ?? this.autoPhaseConfidence,
      userPhaseOverride: userPhaseOverride ?? this.userPhaseOverride,
      isPhaseLocked: isPhaseLocked ?? this.isPhaseLocked,
      legacyPhaseTag: legacyPhaseTag ?? this.legacyPhaseTag,
      importSource: importSource ?? this.importSource,
      phaseInferenceVersion: phaseInferenceVersion ?? this.phaseInferenceVersion,
      phaseMigrationStatus: phaseMigrationStatus ?? this.phaseMigrationStatus,
      lumaraBlocks: lumaraBlocks ?? this.lumaraBlocks,
      overview: overview ?? this.overview,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        createdAt,
        updatedAt,
        tags,
        mood,
        audioUri, // Legacy field
        media, // New multi-modal media list
        sageAnnotation,
        keywords,
        emotion,
        emotionReason,
        metadata,
        location,
        phase,
        phaseAtTime,
        isEdited,
        autoPhase,
        autoPhaseConfidence,
        userPhaseOverride,
        isPhaseLocked,
        legacyPhaseTag,
        importSource,
        phaseInferenceVersion,
        phaseMigrationStatus,
        lumaraBlocks,
        overview,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'mood': mood,
      'audioUri': audioUri, // Legacy field - kept for backward compatibility
      'media': media.map((item) => item.toJson()).toList(), // New multi-modal media list
      'sageAnnotation': sageAnnotation?.toJson(),
      'keywords': keywords,
      'emotion': emotion,
      'emotionReason': emotionReason,
      'metadata': metadata,
      'location': location,
      'phase': phase,
      'phaseAtTime': phaseAtTime?.toIso8601String(),
      'isEdited': isEdited,
      'autoPhase': autoPhase,
      'autoPhaseConfidence': autoPhaseConfidence,
      'userPhaseOverride': userPhaseOverride,
      'isPhaseLocked': isPhaseLocked,
      'legacyPhaseTag': legacyPhaseTag,
      'importSource': importSource,
      'phaseInferenceVersion': phaseInferenceVersion,
      'phaseMigrationStatus': phaseMigrationStatus,
      'lumaraBlocks': lumaraBlocks.map((b) => b.toJson()).toList(),
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Untitled',
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tags: List<String>.from(json['tags'] as List? ?? []),
      mood: (json['mood'] as String?) ?? '',
      audioUri: json['audioUri'] as String?, // Legacy field
      media: (json['media'] as List?)
          ?.map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [], // New multi-modal media list
      sageAnnotation: json['sageAnnotation'] != null
          ? SAGEAnnotation.fromJson(
              json['sageAnnotation'] as Map<String, dynamic>)
          : null,
      keywords: List<String>.from(json['keywords'] as List? ?? []),
      emotion: json['emotion'] as String?,
      emotionReason: json['emotionReason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      location: json['location'] as String?,
      phase: json['phase'] as String?,
      phaseAtTime: json['phaseAtTime'] != null ? DateTime.parse(json['phaseAtTime']) : null,
      isEdited: json['isEdited'] as bool? ?? false,
      autoPhase: json['autoPhase'] as String?,
      autoPhaseConfidence: (json['autoPhaseConfidence'] as num?)?.toDouble(),
      userPhaseOverride: json['userPhaseOverride'] as String?,
      isPhaseLocked: json['isPhaseLocked'] as bool? ?? false,
      // Populate legacyPhaseTag from phase if autoPhase is null (for older entries)
      legacyPhaseTag: json['legacyPhaseTag'] as String? ?? 
          (json['autoPhase'] == null && json['phase'] != null ? json['phase'] as String? : null),
      importSource: json['importSource'] as String?,
      phaseInferenceVersion: json['phaseInferenceVersion'] as int?,
      phaseMigrationStatus: json['phaseMigrationStatus'] as String?,
      lumaraBlocks: (json['lumaraBlocks'] as List?)
          ?.map((b) => InlineBlock.fromJson(b as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// Get the computed phase for display (user override > auto phase > legacy phase)
  /// Note: phase (old field) is only used as last resort for backward compatibility
  String? get computedPhase {
    // Priority: user override > auto phase > legacy tag > old phase field
    // If legacyPhaseTag is null but phase exists and autoPhase is null, use phase
    final effectiveLegacyTag = legacyPhaseTag ?? (autoPhase == null && phase != null ? phase : null);
    return userPhaseOverride ?? autoPhase ?? effectiveLegacyTag;
  }

  /// Check if phase is manually overridden
  bool get isPhaseManuallyOverridden => userPhaseOverride != null;
  
  /// Ensure legacyPhaseTag is populated from phase if needed (for older entries)
  /// Returns a new entry with legacyPhaseTag populated if it was null but phase exists
  JournalEntry ensureLegacyPhaseTag() {
    if (legacyPhaseTag == null && phase != null && autoPhase == null) {
      return copyWith(legacyPhaseTag: phase);
    }
    return this;
  }

  /// Get the original creation time (from metadata if available, otherwise createdAt)
  /// This ensures Time Echo reminders use the true original creation time
  DateTime get originalCreatedAt {
    if (metadata != null && metadata!.containsKey('originalCreatedAt')) {
      try {
        return DateTime.parse(metadata!['originalCreatedAt'] as String);
      } catch (e) {
        // Fall back to createdAt if parsing fails
        return createdAt;
      }
    }
    return createdAt;
  }
}
