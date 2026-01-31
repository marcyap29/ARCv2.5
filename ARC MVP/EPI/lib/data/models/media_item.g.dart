// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaItemAdapter extends TypeAdapter<MediaItem> {
  @override
  final int typeId = 11;

  @override
  MediaItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaItem(
      id: fields[0] as String,
      uri: fields[1] as String,
      type: fields[2] as MediaType,
      duration: fields[3] as Duration?,
      sizeBytes: fields[4] as int?,
      createdAt: fields[5] as DateTime,
      transcript: fields[6] as String?,
      ocrText: fields[7] as String?,
      analysisData: (fields[8] as Map?)?.cast<String, dynamic>(),
      altText: fields[9] as String?,
      sha256: fields[10] as String?,
      thumbUri: fields[11] as String?,
      fullRef: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaItem obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.uri)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.sizeBytes)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.transcript)
      ..writeByte(7)
      ..write(obj.ocrText)
      ..writeByte(8)
      ..write(obj.analysisData)
      ..writeByte(9)
      ..write(obj.altText)
      ..writeByte(10)
      ..write(obj.sha256)
      ..writeByte(11)
      ..write(obj.thumbUri)
      ..writeByte(12)
      ..write(obj.fullRef);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaTypeAdapter extends TypeAdapter<MediaType> {
  @override
  final int typeId = 10;

  @override
  MediaType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MediaType.audio;
      case 1:
        return MediaType.image;
      case 2:
        return MediaType.video;
      case 3:
        return MediaType.file;
      default:
        return MediaType.audio;
    }
  }

  @override
  void write(BinaryWriter writer, MediaType obj) {
    switch (obj) {
      case MediaType.audio:
        writer.writeByte(0);
        break;
      case MediaType.image:
        writer.writeByte(1);
        break;
      case MediaType.video:
        writer.writeByte(2);
        break;
      case MediaType.file:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
      analysisData: json['analysisData'] as Map<String, dynamic>?,
      altText: json['altText'] as String?,
      sha256: json['sha256'] as String?,
      thumbUri: json['thumbUri'] as String?,
      fullRef: json['fullRef'] as String?,
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
      'analysisData': instance.analysisData,
      'altText': instance.altText,
      'sha256': instance.sha256,
      'thumbUri': instance.thumbUri,
      'fullRef': instance.fullRef,
    };

const _$MediaTypeEnumMap = {
  MediaType.audio: 'audio',
  MediaType.image: 'image',
  MediaType.video: 'video',
  MediaType.file: 'file',
};
