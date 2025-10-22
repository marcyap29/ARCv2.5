// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = 0;

  @override
  JournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JournalEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      tags: (fields[5] as List).cast<String>(),
      mood: fields[6] as String,
      audioUri: fields[7] as String?,
      media: (fields[12] as List).cast<MediaItem>(),
      sageAnnotation: fields[8] as SAGEAnnotation?,
      keywords: (fields[9] as List).cast<String>(),
      emotion: fields[10] as String?,
      emotionReason: fields[11] as String?,
      metadata: (fields[13] as Map?)?.cast<String, dynamic>(),
      location: fields[14] as String?,
      phase: fields[15] as String?,
      phaseAtTime: fields[18] as DateTime?,
      isEdited: fields[16] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.mood)
      ..writeByte(7)
      ..write(obj.audioUri)
      ..writeByte(12)
      ..write(obj.media)
      ..writeByte(8)
      ..write(obj.sageAnnotation)
      ..writeByte(9)
      ..write(obj.keywords)
      ..writeByte(10)
      ..write(obj.emotion)
      ..writeByte(11)
      ..write(obj.emotionReason)
      ..writeByte(13)
      ..write(obj.metadata)
      ..writeByte(14)
      ..write(obj.location)
      ..writeByte(15)
      ..write(obj.phase)
      ..writeByte(18)
      ..write(obj.phaseAtTime)
      ..writeByte(16)
      ..write(obj.isEdited);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
