// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aurora_lite_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShiftScheduleAdapter extends TypeAdapter<ShiftSchedule> {
  @override
  final int typeId = 60;

  @override
  ShiftSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShiftSchedule(
      id: fields[0] as String,
      name: fields[1] as String,
      shifts: (fields[2] as List).cast<Shift>(),
      isActive: fields[3] as bool,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ShiftSchedule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.shifts)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShiftAdapter extends TypeAdapter<Shift> {
  @override
  final int typeId = 61;

  @override
  Shift read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Shift(
      id: fields[0] as String,
      name: fields[1] as String,
      daysOfWeek: (fields[2] as List).cast<int>(),
      startHour: fields[3] as int,
      startMinute: fields[4] as int,
      endHour: fields[5] as int,
      endMinute: fields[6] as int,
      notes: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Shift obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.daysOfWeek)
      ..writeByte(3)
      ..write(obj.startHour)
      ..writeByte(4)
      ..write(obj.startMinute)
      ..writeByte(5)
      ..write(obj.endHour)
      ..writeByte(6)
      ..write(obj.endMinute)
      ..writeByte(7)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShiftPhaseAdapter extends TypeAdapter<ShiftPhase> {
  @override
  final int typeId = 62;

  @override
  ShiftPhase read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ShiftPhase.onDuty;
      case 1:
        return ShiftPhase.immediateRecovery;
      case 2:
        return ShiftPhase.shortTermRecovery;
      case 3:
        return ShiftPhase.longTermRecovery;
      case 4:
        return ShiftPhase.offDuty;
      default:
        return ShiftPhase.onDuty;
    }
  }

  @override
  void write(BinaryWriter writer, ShiftPhase obj) {
    switch (obj) {
      case ShiftPhase.onDuty:
        writer.writeByte(0);
        break;
      case ShiftPhase.immediateRecovery:
        writer.writeByte(1);
        break;
      case ShiftPhase.shortTermRecovery:
        writer.writeByte(2);
        break;
      case ShiftPhase.longTermRecovery:
        writer.writeByte(3);
        break;
      case ShiftPhase.offDuty:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftPhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ActionTypeAdapter extends TypeAdapter<ActionType> {
  @override
  final int typeId = 63;

  @override
  ActionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActionType.checkIn;
      case 1:
        return ActionType.debrief;
      case 2:
        return ActionType.grounding;
      case 3:
        return ActionType.wellness;
      case 4:
        return ActionType.reflection;
      case 5:
        return ActionType.support;
      default:
        return ActionType.checkIn;
    }
  }

  @override
  void write(BinaryWriter writer, ActionType obj) {
    switch (obj) {
      case ActionType.checkIn:
        writer.writeByte(0);
        break;
      case ActionType.debrief:
        writer.writeByte(1);
        break;
      case ActionType.grounding:
        writer.writeByte(2);
        break;
      case ActionType.wellness:
        writer.writeByte(3);
        break;
      case ActionType.reflection:
        writer.writeByte(4);
        break;
      case ActionType.support:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PromptTypeAdapter extends TypeAdapter<PromptType> {
  @override
  final int typeId = 64;

  @override
  PromptType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PromptType.checkIn;
      case 1:
        return PromptType.debrief;
      case 2:
        return PromptType.recovery;
      case 3:
        return PromptType.wellness;
      case 4:
        return PromptType.reminder;
      default:
        return PromptType.checkIn;
    }
  }

  @override
  void write(BinaryWriter writer, PromptType obj) {
    switch (obj) {
      case PromptType.checkIn:
        writer.writeByte(0);
        break;
      case PromptType.debrief:
        writer.writeByte(1);
        break;
      case PromptType.recovery:
        writer.writeByte(2);
        break;
      case PromptType.wellness:
        writer.writeByte(3);
        break;
      case PromptType.reminder:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UrgencyLevelAdapter extends TypeAdapter<UrgencyLevel> {
  @override
  final int typeId = 65;

  @override
  UrgencyLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UrgencyLevel.low;
      case 1:
        return UrgencyLevel.medium;
      case 2:
        return UrgencyLevel.high;
      default:
        return UrgencyLevel.low;
    }
  }

  @override
  void write(BinaryWriter writer, UrgencyLevel obj) {
    switch (obj) {
      case UrgencyLevel.low:
        writer.writeByte(0);
        break;
      case UrgencyLevel.medium:
        writer.writeByte(1);
        break;
      case UrgencyLevel.high:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrgencyLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrendDirectionAdapter extends TypeAdapter<TrendDirection> {
  @override
  final int typeId = 66;

  @override
  TrendDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TrendDirection.increasing;
      case 1:
        return TrendDirection.decreasing;
      case 2:
        return TrendDirection.stable;
      default:
        return TrendDirection.increasing;
    }
  }

  @override
  void write(BinaryWriter writer, TrendDirection obj) {
    switch (obj) {
      case TrendDirection.increasing:
        writer.writeByte(0);
        break;
      case TrendDirection.decreasing:
        writer.writeByte(1);
        break;
      case TrendDirection.stable:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
