// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaItem _$MediaItemFromJson(Map<String, dynamic> json) => MediaItem(
      id: json['id'] as String,
      uri: json['uri'] as String,
      type: $enumDecode(_$MediaTypeEnumMap, json['type']),
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      transcript: json['transcript'] as String?,
      ocrText: json['ocrText'] as String?,
    );

Map<String, dynamic> _$MediaItemToJson(MediaItem instance) => <String, dynamic>{
      'id': instance.id,
      'uri': instance.uri,
      'type': _$MediaTypeEnumMap[instance.type]!,
      'duration': instance.duration?.inMicroseconds,
      'sizeBytes': instance.sizeBytes,
      'createdAt': instance.createdAt.toIso8601String(),
      'transcript': instance.transcript,
      'ocrText': instance.ocrText,
    };

const _$MediaTypeEnumMap = {
  MediaType.audio: 'audio',
  MediaType.image: 'image',
  MediaType.video: 'video',
  MediaType.file: 'file',
};
