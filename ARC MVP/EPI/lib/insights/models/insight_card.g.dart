// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insight_card.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InsightCardAdapter extends TypeAdapter<InsightCard> {
  @override
  final int typeId = 20;

  @override
  InsightCard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InsightCard(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      badges: (fields[3] as List).cast<String>(),
      periodStart: fields[4] as DateTime,
      periodEnd: fields[5] as DateTime,
      sources: (fields[6] as Map).cast<String, dynamic>(),
      deeplink: fields[7] as String?,
      ruleId: fields[8] as String,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InsightCard obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.badges)
      ..writeByte(4)
      ..write(obj.periodStart)
      ..writeByte(5)
      ..write(obj.periodEnd)
      ..writeByte(6)
      ..write(obj.sources)
      ..writeByte(7)
      ..write(obj.deeplink)
      ..writeByte(8)
      ..write(obj.ruleId)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightCardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
