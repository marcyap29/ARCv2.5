// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_note.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VoiceNoteAdapter extends TypeAdapter<VoiceNote> {
  @override
  final int typeId = 120;

  @override
  VoiceNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VoiceNote(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      transcription: fields[2] as String,
      tags: (fields[3] as List).cast<String>(),
      archived: fields[4] as bool,
      convertedToJournal: fields[5] as bool,
      convertedEntryId: fields[6] as String?,
      durationMs: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, VoiceNote obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.transcription)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.archived)
      ..writeByte(5)
      ..write(obj.convertedToJournal)
      ..writeByte(6)
      ..write(obj.convertedEntryId)
      ..writeByte(7)
      ..write(obj.durationMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceNoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
