// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phase_check_in_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhaseCheckInAdapter extends TypeAdapter<PhaseCheckIn> {
  @override
  final int typeId = 115;

  @override
  PhaseCheckIn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhaseCheckIn(
      id: fields[0] as String,
      userId: fields[1] as String,
      checkInDate: fields[2] as DateTime,
      previousPhase: fields[3] as String,
      confirmedPhase: fields[4] as String,
      wasConfirmed: fields[5] as bool,
      wasRecalibrated: fields[6] as bool,
      diagnosticAnswers: (fields[7] as Map?)?.cast<String, dynamic>(),
      wasManualOverride: fields[8] as bool,
      manualOverrideReason: fields[9] as String?,
      nextCheckInDue: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PhaseCheckIn obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.checkInDate)
      ..writeByte(3)
      ..write(obj.previousPhase)
      ..writeByte(4)
      ..write(obj.confirmedPhase)
      ..writeByte(5)
      ..write(obj.wasConfirmed)
      ..writeByte(6)
      ..write(obj.wasRecalibrated)
      ..writeByte(7)
      ..write(obj.diagnosticAnswers)
      ..writeByte(8)
      ..write(obj.wasManualOverride)
      ..writeByte(9)
      ..write(obj.manualOverrideReason)
      ..writeByte(10)
      ..write(obj.nextCheckInDue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseCheckInAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
