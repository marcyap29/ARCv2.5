// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflection_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReflectionSessionAdapter extends TypeAdapter<ReflectionSession> {
  @override
  final int typeId = 125;

  @override
  ReflectionSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReflectionSession(
      id: fields[0] as String,
      userId: fields[1] as String,
      entryId: fields[2] as String,
      startTime: fields[3] as DateTime,
      exchanges: (fields[4] as List?)?.cast<ReflectionExchange>(),
      pausedUntil: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ReflectionSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.entryId)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.exchanges)
      ..writeByte(5)
      ..write(obj.pausedUntil);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReflectionSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReflectionExchangeAdapter extends TypeAdapter<ReflectionExchange> {
  @override
  final int typeId = 126;

  @override
  ReflectionExchange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReflectionExchange(
      timestamp: fields[0] as DateTime,
      userQuery: fields[1] as String,
      lumaraResponse: fields[2] as String,
      citedChronicle: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReflectionExchange obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.userQuery)
      ..writeByte(2)
      ..write(obj.lumaraResponse)
      ..writeByte(3)
      ..write(obj.citedChronicle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReflectionExchangeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
