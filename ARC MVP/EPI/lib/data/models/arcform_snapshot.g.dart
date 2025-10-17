// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arcform_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArcformSnapshotAdapter extends TypeAdapter<ArcformSnapshot> {
  @override
  final int typeId = 17;

  @override
  ArcformSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArcformSnapshot(
      phase: fields[0] as String,
      geometryJson: fields[1] as String,
      timestamp: fields[2] as DateTime,
      description: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ArcformSnapshot obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.phase)
      ..writeByte(1)
      ..write(obj.geometryJson)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.description);
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