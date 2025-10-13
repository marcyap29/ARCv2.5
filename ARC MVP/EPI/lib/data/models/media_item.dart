import 'package:json_annotation/json_annotation.dart';

part 'media_item.g.dart';

enum MediaType {
  @JsonValue('audio')
  audio,
  @JsonValue('image')
  image,
  @JsonValue('video')
  video,
  @JsonValue('file')
  file,
}

@JsonSerializable()
class MediaItem {
  final String id;
  final String uri;
  final MediaType type;
  final Duration? duration;
  final int? sizeBytes;
  final DateTime createdAt;
  final String? transcript;
  final String? ocrText;
  final Map<String, dynamic>? analysisData; // Full analysis JSON from iOS Vision
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
