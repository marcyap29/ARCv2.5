import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/data/models/media_item.dart';

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
  final String? phase; // Current phase of the entry

  @HiveField(16)
  final bool isEdited; // Whether this entry has been edited from original

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
    this.isEdited = false,
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
    bool? isEdited,
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
      isEdited: isEdited ?? this.isEdited,
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
        isEdited,
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
      'isEdited': isEdited,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tags: List<String>.from(json['tags'] as List),
      mood: json['mood'] as String,
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
      isEdited: json['isEdited'] as bool? ?? false,
    );
  }
}
