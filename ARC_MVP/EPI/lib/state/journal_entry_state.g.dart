// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InlineBlockAdapter extends TypeAdapter<InlineBlock> {
  @override
  final int typeId = 103;

  @override
  InlineBlock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InlineBlock(
      type: fields[0] as String,
      intent: fields[1] as String,
      content: fields[2] as String,
      timestamp: fields[3] as int,
      phase: fields[4] as String?,
      userComment: fields[5] as String?,
      attributionTracesJson: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InlineBlock obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.intent)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.phase)
      ..writeByte(5)
      ..write(obj.userComment)
      ..writeByte(6)
      ..write(obj.attributionTracesJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineBlockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
