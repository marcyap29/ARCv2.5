// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phase_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhaseRegimeAdapter extends TypeAdapter<PhaseRegime> {
  @override
  final int typeId = 200;

  @override
  PhaseRegime read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhaseRegime(
      id: fields[0] as String,
      label: fields[1] as PhaseLabel,
      start: fields[2] as DateTime,
      end: fields[3] as DateTime?,
      source: fields[4] as PhaseSource,
      confidence: fields[5] as double?,
      inferredAt: fields[6] as DateTime?,
      anchors: (fields[7] as List).cast<String>(),
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PhaseRegime obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.start)
      ..writeByte(3)
      ..write(obj.end)
      ..writeByte(4)
      ..write(obj.source)
      ..writeByte(5)
      ..write(obj.confidence)
      ..writeByte(6)
      ..write(obj.inferredAt)
      ..writeByte(7)
      ..write(obj.anchors)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseRegimeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PhaseInfoAdapter extends TypeAdapter<PhaseInfo> {
  @override
  final int typeId = 201;

  @override
  PhaseInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhaseInfo(
      label: fields[0] as PhaseLabel,
      confidence: fields[1] as double?,
      source: fields[2] as PhaseSource,
      inferredAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PhaseInfo obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.confidence)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.inferredAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PhaseWindowAdapter extends TypeAdapter<PhaseWindow> {
  @override
  final int typeId = 202;

  @override
  PhaseWindow read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhaseWindow(
      start: fields[0] as DateTime,
      end: fields[1] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PhaseWindow obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.start)
      ..writeByte(1)
      ..write(obj.end);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseWindowAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PhaseLabelAdapter extends TypeAdapter<PhaseLabel> {
  @override
  final int typeId = 203;

  @override
  PhaseLabel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PhaseLabel.discovery;
      case 1:
        return PhaseLabel.expansion;
      case 2:
        return PhaseLabel.transition;
      case 3:
        return PhaseLabel.consolidation;
      case 4:
        return PhaseLabel.recovery;
      case 5:
        return PhaseLabel.breakthrough;
      default:
        return PhaseLabel.discovery;
    }
  }

  @override
  void write(BinaryWriter writer, PhaseLabel obj) {
    switch (obj) {
      case PhaseLabel.discovery:
        writer.writeByte(0);
        break;
      case PhaseLabel.expansion:
        writer.writeByte(1);
        break;
      case PhaseLabel.transition:
        writer.writeByte(2);
        break;
      case PhaseLabel.consolidation:
        writer.writeByte(3);
        break;
      case PhaseLabel.recovery:
        writer.writeByte(4);
        break;
      case PhaseLabel.breakthrough:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseLabelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PhaseSourceAdapter extends TypeAdapter<PhaseSource> {
  @override
  final int typeId = 204;

  @override
  PhaseSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PhaseSource.user;
      case 1:
        return PhaseSource.rivet;
      default:
        return PhaseSource.user;
    }
  }

  @override
  void write(BinaryWriter writer, PhaseSource obj) {
    switch (obj) {
      case PhaseSource.user:
        writer.writeByte(0);
        break;
      case PhaseSource.rivet:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
