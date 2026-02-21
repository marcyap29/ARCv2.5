// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arcform_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArcformSnapshotAdapter extends TypeAdapter<ArcformSnapshot> {
  @override
  final int typeId = 2;

  @override
  ArcformSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArcformSnapshot(
      id: fields[0] as String,
      journalEntryId: fields[1] as String,
      title: fields[2] as String,
      keywords: (fields[3] as List).cast<String>(),
      colorMap: (fields[4] as Map).cast<String, String>(),
      edges: (fields[5] as List)
          .map((dynamic e) => (e as List).cast<dynamic>())
          .toList(),
      createdAt: fields[6] as DateTime,
      phase: fields[7] as String,
      userConsentedPhase: fields[8] as bool,
      isGeometryAuto: fields[9] as bool,
      recommendationRationale: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ArcformSnapshot obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.journalEntryId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.keywords)
      ..writeByte(4)
      ..write(obj.colorMap)
      ..writeByte(5)
      ..write(obj.edges)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.phase)
      ..writeByte(8)
      ..write(obj.userConsentedPhase)
      ..writeByte(9)
      ..write(obj.isGeometryAuto)
      ..writeByte(10)
      ..write(obj.recommendationRationale);
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
