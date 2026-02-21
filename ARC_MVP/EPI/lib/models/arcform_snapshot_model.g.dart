// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arcform_snapshot_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArcformSnapshotAdapter extends TypeAdapter<ArcformSnapshot> {
  @override
  final int typeId = 1;

  @override
  ArcformSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArcformSnapshot(
      id: fields[0] as String,
      arcformId: fields[1] as String,
      data: (fields[2] as Map).cast<String, dynamic>(),
      timestamp: fields[3] as DateTime,
      notes: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ArcformSnapshot obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.arcformId)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArcformSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
