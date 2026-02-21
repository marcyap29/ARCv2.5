// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflective_node.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaRefAdapter extends TypeAdapter<MediaRef> {
  @override
  final int typeId = 100;

  @override
  MediaRef read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaRef(
      id: fields[0] as String,
      mimeType: fields[1] as String?,
      bytes: fields[2] as int?,
      width: fields[3] as int?,
      height: fields[4] as int?,
      durationSec: fields[5] as double?,
      createdAt: fields[6] as DateTime?,
      sha256: fields[7] as String?,
      exif: (fields[8] as Map?)?.cast<String, dynamic>(),
      caption: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaRef obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mimeType)
      ..writeByte(2)
      ..write(obj.bytes)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.height)
      ..writeByte(5)
      ..write(obj.durationSec)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.sha256)
      ..writeByte(8)
      ..write(obj.exif)
      ..writeByte(9)
      ..write(obj.caption);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaRefAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReflectiveNodeAdapter extends TypeAdapter<ReflectiveNode> {
  @override
  final int typeId = 101;

  @override
  ReflectiveNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReflectiveNode(
      id: fields[0] as String,
      mcpId: fields[1] as String?,
      type: fields[2] as NodeType,
      contentText: fields[3] as String?,
      captionText: fields[4] as String?,
      transcription: fields[5] as String?,
      keywords: (fields[6] as List?)?.cast<String>(),
      phaseHint: fields[7] as PhaseHint?,
      embeddingText: (fields[8] as List?)?.cast<double>(),
      embeddingAffect: (fields[9] as List?)?.cast<double>(),
      mediaRefs: (fields[10] as List?)?.cast<MediaRef>(),
      createdAt: fields[11] as DateTime,
      importTimestamp: fields[12] as DateTime?,
      userId: fields[13] as String,
      sourceBundleId: fields[14] as String?,
      timelineAt: fields[15] as DateTime?,
      deleted: fields[16] as bool,
      extra: (fields[17] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReflectiveNode obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mcpId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.contentText)
      ..writeByte(4)
      ..write(obj.captionText)
      ..writeByte(5)
      ..write(obj.transcription)
      ..writeByte(6)
      ..write(obj.keywords)
      ..writeByte(7)
      ..write(obj.phaseHint)
      ..writeByte(8)
      ..write(obj.embeddingText)
      ..writeByte(9)
      ..write(obj.embeddingAffect)
      ..writeByte(10)
      ..write(obj.mediaRefs)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.importTimestamp)
      ..writeByte(13)
      ..write(obj.userId)
      ..writeByte(14)
      ..write(obj.sourceBundleId)
      ..writeByte(15)
      ..write(obj.timelineAt)
      ..writeByte(16)
      ..write(obj.deleted)
      ..writeByte(17)
      ..write(obj.extra);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReflectiveNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
