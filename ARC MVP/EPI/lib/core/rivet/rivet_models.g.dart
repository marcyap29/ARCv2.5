// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rivet_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EvidenceSourceAdapter extends TypeAdapter<EvidenceSource> {
  @override
  final int typeId = 10;

  @override
  EvidenceSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EvidenceSource.text;
      case 1:
        return EvidenceSource.voice;
      case 2:
        return EvidenceSource.therapistTag;
      case 3:
        return EvidenceSource.other;
      default:
        return EvidenceSource.other;
    }
  }

  @override
  void write(BinaryWriter writer, EvidenceSource obj) {
    switch (obj) {
      case EvidenceSource.text:
        writer.writeByte(0);
        break;
      case EvidenceSource.voice:
        writer.writeByte(1);
        break;
      case EvidenceSource.therapistTag:
        writer.writeByte(2);
        break;
      case EvidenceSource.other:
        writer.writeByte(3);
        break;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}

class RivetEventAdapter extends TypeAdapter<RivetEvent> {
  @override
  final int typeId = 11;

  @override
  RivetEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RivetEvent(
      eventId: fields[0] as String,
      date: fields[1] as DateTime,
      source: fields[2] as EvidenceSource,
      keywords: (fields[3] as List).cast<String>().toSet(),
      predPhase: fields[4] as String,
      refPhase: fields[5] as String,
      tolerance: (fields[6] as Map).cast<String, double>(),
      version: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RivetEvent obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.eventId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.keywords.toList())
      ..writeByte(4)
      ..write(obj.predPhase)
      ..writeByte(5)
      ..write(obj.refPhase)
      ..writeByte(6)
      ..write(obj.tolerance)
      ..writeByte(7)
      ..write(obj.version);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RivetEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}

class RivetStateAdapter extends TypeAdapter<RivetState> {
  @override
  final int typeId = 12;

  @override
  RivetState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RivetState(
      align: fields[0] as double,
      trace: fields[1] as double,
      sustainCount: fields[2] as int,
      sawIndependentInWindow: fields[3] as bool,
      eventId: fields[4] as String?,
      date: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RivetState obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.align)
      ..writeByte(1)
      ..write(obj.trace)
      ..writeByte(2)
      ..write(obj.sustainCount)
      ..writeByte(3)
      ..write(obj.sawIndependentInWindow)
      ..writeByte(4)
      ..write(obj.eventId)
      ..writeByte(5)
      ..write(obj.date);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RivetStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}

class RivetSnapshotAdapter extends TypeAdapter<RivetSnapshot> {
  @override
  final int typeId = 13;

  @override
  RivetSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RivetSnapshot(
      eventId: fields[0] as String,
      date: fields[1] as DateTime,
      align: fields[2] as double,
      trace: fields[3] as double,
      sumEvidenceSoFar: fields[4] as double,
      eventCount: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RivetSnapshot obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.eventId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.align)
      ..writeByte(3)
      ..write(obj.trace)
      ..writeByte(4)
      ..write(obj.sumEvidenceSoFar)
      ..writeByte(5)
      ..write(obj.eventCount);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RivetSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}