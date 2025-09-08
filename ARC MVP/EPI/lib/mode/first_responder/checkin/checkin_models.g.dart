// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkin_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CheckInAdapter extends TypeAdapter<CheckIn> {
  @override
  final int typeId = 50;

  @override
  CheckIn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CheckIn(
      id: fields[0] as String,
      stressLevel: fields[1] as int,
      sleepHours: fields[2] as int,
      hasIntrusiveThoughts: fields[3] as bool,
      usedSupport: fields[4] as bool,
      notes: fields[5] as String?,
      timestamp: fields[6] as DateTime,
      shiftId: fields[7] as String?,
      triggers: (fields[8] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, CheckIn obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.stressLevel)
      ..writeByte(2)
      ..write(obj.sleepHours)
      ..writeByte(3)
      ..write(obj.hasIntrusiveThoughts)
      ..writeByte(4)
      ..write(obj.usedSupport)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.shiftId)
      ..writeByte(8)
      ..write(obj.triggers);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CheckInPatternAdapter extends TypeAdapter<CheckInPattern> {
  @override
  final int typeId = 51;

  @override
  CheckInPattern read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CheckInPattern(
      id: fields[0] as String,
      startDate: fields[1] as DateTime,
      endDate: fields[2] as DateTime,
      averageStress: fields[3] as double,
      averageSleep: fields[4] as double,
      totalCheckIns: fields[5] as int,
      highStressDays: fields[6] as int,
      intrusiveThoughtDays: fields[7] as int,
      supportUsedDays: fields[8] as int,
      commonTriggers: (fields[9] as List).cast<String>(),
      insights: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CheckInPattern obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.averageStress)
      ..writeByte(4)
      ..write(obj.averageSleep)
      ..writeByte(5)
      ..write(obj.totalCheckIns)
      ..writeByte(6)
      ..write(obj.highStressDays)
      ..writeByte(7)
      ..write(obj.intrusiveThoughtDays)
      ..writeByte(8)
      ..write(obj.supportUsedDays)
      ..writeByte(9)
      ..write(obj.commonTriggers)
      ..writeByte(10)
      ..write(obj.insights);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInPatternAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
