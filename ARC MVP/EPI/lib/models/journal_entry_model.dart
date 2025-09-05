import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:my_app/features/journal/sage_annotation_model.dart';
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
    );
  }
}
