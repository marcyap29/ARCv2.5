import 'package:json_annotation/json_annotation.dart';
import 'package:hive/hive.dart';

part 'media_item.g.dart';

@HiveType(typeId: 10)
enum MediaType {
  @HiveField(0)
  @JsonValue('audio')
  audio,
  @HiveField(1)
  @JsonValue('image')
  image,
  @HiveField(2)
  @JsonValue('video')
  video,
  @HiveField(3)
  @JsonValue('file')
  file,
}

@HiveType(typeId: 11)
@JsonSerializable()
class MediaItem {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String uri;
  
  @HiveField(2)
  final MediaType type;
  
  @HiveField(3)
  final Duration? duration;
  
  @HiveField(4)
  final int? sizeBytes;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final String? transcript;
  
  @HiveField(7)
  final String? ocrText;
  
  @HiveField(8)
  final Map<String, dynamic>? analysisData; // Full analysis JSON from iOS Vision
  
  @HiveField(9)
  final String? altText; // Descriptive text for accessibility and fallback (like HTML alt attribute)

  const MediaItem({
    required this.id,
    required this.uri,
    required this.type,
    this.duration,
    this.sizeBytes,
    required this.createdAt,
    this.transcript,
    this.ocrText,
    this.analysisData,
    this.altText,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => _$MediaItemFromJson(json);
  Map<String, dynamic> toJson() => _$MediaItemToJson(this);

  MediaItem copyWith({
    String? id,
    String? uri,
    MediaType? type,
    Duration? duration,
    int? sizeBytes,
    DateTime? createdAt,
    String? transcript,
    String? ocrText,
    Map<String, dynamic>? analysisData,
    String? altText,
  }) {
    return MediaItem(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      transcript: transcript ?? this.transcript,
      ocrText: ocrText ?? this.ocrText,
      analysisData: analysisData ?? this.analysisData,
      altText: altText ?? this.altText,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MediaItem(id: $id, type: $type, uri: $uri, duration: $duration)';
  }
}
