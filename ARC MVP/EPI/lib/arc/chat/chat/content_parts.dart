import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'content_parts.g.dart';

/// Represents a typed content part in a chat message
abstract class ContentPart extends Equatable {
  final String mime;
  
  const ContentPart({required this.mime});
  
  Map<String, dynamic> toJson();
  
  factory ContentPart.fromJson(Map<String, dynamic> json) {
    final mime = json['mime'] as String;
    
    switch (mime) {
      case 'text/plain':
        return TextContentPart.fromJson(json);
      case 'application/x-prism+json':
        return PrismContentPart.fromJson(json);
      default:
        if (mime.startsWith('image/') || mime.startsWith('audio/') || mime.startsWith('video/')) {
          return MediaContentPart.fromJson(json);
        }
        throw ArgumentError('Unknown content part type: $mime');
    }
  }
}

/// Text content part
@HiveType(typeId: 81)
class TextContentPart extends ContentPart {
  @HiveField(1)
  final String text;
  
  const TextContentPart({
    required this.text,
  }) : super(mime: 'text/plain');
  
  @override
  Map<String, dynamic> toJson() => {
    'mime': mime,
    'text': text,
  };
  
  factory TextContentPart.fromJson(Map<String, dynamic> json) {
    return TextContentPart(
      text: json['text'] as String,
    );
  }
  
  @override
  List<Object?> get props => [mime, text];
}

/// Media content part (images, audio, video)
@HiveType(typeId: 82)
class MediaContentPart extends ContentPart {
  @HiveField(0)
  final String mime;
  
  @HiveField(1)
  final MediaPointer pointer;
  
  @HiveField(2)
  final String? alt;
  
  @HiveField(3)
  final int? durationMs;
  
  const MediaContentPart({
    required this.mime,
    required this.pointer,
    this.alt,
    this.durationMs,
  }) : super(mime: mime);
  
  @override
  Map<String, dynamic> toJson() => {
    'mime': mime,
    'pointer': pointer.toJson(),
    if (alt != null) 'alt': alt,
    if (durationMs != null) 'durationMs': durationMs,
  };
  
  factory MediaContentPart.fromJson(Map<String, dynamic> json) {
    return MediaContentPart(
      mime: json['mime'] as String,
      pointer: MediaPointer.fromJson(json['pointer'] as Map<String, dynamic>),
      alt: json['alt'] as String?,
      durationMs: json['durationMs'] as int?,
    );
  }
  
  @override
  List<Object?> get props => [mime, pointer, alt, durationMs];
}

/// PRISM reduction content part
@HiveType(typeId: 83)
class PrismContentPart extends ContentPart {
  @HiveField(1)
  final PrismSummary summary;
  
  const PrismContentPart({
    required this.summary,
  }) : super(mime: 'application/x-prism+json');
  
  @override
  Map<String, dynamic> toJson() => {
    'mime': mime,
    'summary': summary.toJson(),
  };
  
  factory PrismContentPart.fromJson(Map<String, dynamic> json) {
    return PrismContentPart(
      summary: PrismSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
  
  @override
  List<Object?> get props => [mime, summary];
}

/// Media pointer for referencing external media
@HiveType(typeId: 84)
class MediaPointer extends Equatable {
  @HiveField(0)
  final String uri;
  
  @HiveField(1)
  final String? role; // 'primary' | 'aux'
  
  @HiveField(2)
  final Map<String, dynamic> metadata;
  
  const MediaPointer({
    required this.uri,
    this.role,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() => {
    'uri': uri,
    if (role != null) 'role': role,
    'metadata': metadata,
  };
  
  factory MediaPointer.fromJson(Map<String, dynamic> json) {
    return MediaPointer(
      uri: json['uri'] as String,
      role: json['role'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  @override
  List<Object?> get props => [uri, role, metadata];
}

/// PRISM analysis summary
@HiveType(typeId: 85)
class PrismSummary extends Equatable {
  @HiveField(0)
  final List<String>? captions;
  
  @HiveField(1)
  final String? transcript;
  
  @HiveField(2)
  final List<String>? objects;
  
  @HiveField(3)
  final EmotionData? emotion;
  
  @HiveField(4)
  final List<String>? symbols;
  
  @HiveField(5)
  final Map<String, dynamic> metadata;
  
  const PrismSummary({
    this.captions,
    this.transcript,
    this.objects,
    this.emotion,
    this.symbols,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() => {
    if (captions != null) 'captions': captions,
    if (transcript != null) 'transcript': transcript,
    if (objects != null) 'objects': objects,
    if (emotion != null) 'emotion': emotion!.toJson(),
    if (symbols != null) 'symbols': symbols,
    'metadata': metadata,
  };
  
  factory PrismSummary.fromJson(Map<String, dynamic> json) {
    return PrismSummary(
      captions: (json['captions'] as List<dynamic>?)?.cast<String>(),
      transcript: json['transcript'] as String?,
      objects: (json['objects'] as List<dynamic>?)?.cast<String>(),
      emotion: json['emotion'] != null 
          ? EmotionData.fromJson(json['emotion'] as Map<String, dynamic>)
          : null,
      symbols: (json['symbols'] as List<dynamic>?)?.cast<String>(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  @override
  List<Object?> get props => [captions, transcript, objects, emotion, symbols, metadata];
}

/// Emotion data from PRISM analysis
@HiveType(typeId: 86)
class EmotionData extends Equatable {
  @HiveField(0)
  final double valence; // -1.0 to 1.0
  
  @HiveField(1)
  final double arousal; // 0.0 to 1.0
  
  @HiveField(2)
  final String? dominantEmotion;
  
  @HiveField(3)
  final Map<String, dynamic> metadata;
  
  const EmotionData({
    required this.valence,
    required this.arousal,
    this.dominantEmotion,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() => {
    'valence': valence,
    'arousal': arousal,
    if (dominantEmotion != null) 'dominantEmotion': dominantEmotion,
    'metadata': metadata,
  };
  
  factory EmotionData.fromJson(Map<String, dynamic> json) {
    return EmotionData(
      valence: (json['valence'] as num).toDouble(),
      arousal: (json['arousal'] as num).toDouble(),
      dominantEmotion: json['dominantEmotion'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  @override
  List<Object?> get props => [valence, arousal, dominantEmotion, metadata];
}

/// Utility functions for content parts
class ContentPartUtils {
  /// Convert legacy string content to text content part
  static List<ContentPart> fromLegacyContent(String content) {
    if (content.trim().isEmpty) {
      return [];
    }
    return [TextContentPart(text: content)];
  }
  
  /// Extract all text from content parts
  static String extractText(List<ContentPart> parts) {
    return parts
        .whereType<TextContentPart>()
        .map((part) => part.text)
        .join(' ');
  }
  
  /// Check if content parts contain media
  static bool hasMedia(List<ContentPart> parts) {
    return parts.any((part) => part is MediaContentPart);
  }
  
  /// Check if content parts contain PRISM analysis
  static bool hasPrismAnalysis(List<ContentPart> parts) {
    return parts.any((part) => part is PrismContentPart);
  }
  
  /// Get all media pointers from content parts
  static List<MediaPointer> getMediaPointers(List<ContentPart> parts) {
    return parts
        .whereType<MediaContentPart>()
        .map((part) => part.pointer)
        .toList();
  }
  
  /// Get all PRISM summaries from content parts
  static List<PrismSummary> getPrismSummaries(List<ContentPart> parts) {
    return parts
        .whereType<PrismContentPart>()
        .map((part) => part.summary)
        .toList();
  }
}
