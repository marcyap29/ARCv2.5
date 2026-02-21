// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phase_history_repository.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhaseHistoryEntryAdapter extends TypeAdapter<PhaseHistoryEntry> {
  @override
  final int typeId = 3;

  @override
  PhaseHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhaseHistoryEntry(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      phaseScores: (fields[2] as Map).cast<String, double>(),
      journalEntryId: fields[3] as String,
      emotion: fields[4] as String,
      reason: fields[5] as String,
      text: fields[6] as String,
      operationalReadinessScore: fields[7] as int?,
      healthData: (fields[8] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, PhaseHistoryEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.phaseScores)
      ..writeByte(3)
      ..write(obj.journalEntryId)
      ..writeByte(4)
      ..write(obj.emotion)
      ..writeByte(5)
      ..write(obj.reason)
      ..writeByte(6)
      ..write(obj.text)
      ..writeByte(7)
      ..write(obj.operationalReadinessScore)
      ..writeByte(8)
      ..write(obj.healthData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
