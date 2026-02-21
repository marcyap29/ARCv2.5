// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insight_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InsightSnapshotAdapter extends TypeAdapter<InsightSnapshot> {
  @override
  final int typeId = 21;

  @override
  InsightSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InsightSnapshot(
      id: fields[0] as String,
      periodStart: fields[1] as DateTime,
      periodEnd: fields[2] as DateTime,
      topWords: (fields[3] as List).cast<String>(),
      wordFrequencies: (fields[4] as Map).cast<String, int>(),
      emotionScores: (fields[5] as Map).cast<String, double>(),
      phaseCounts: (fields[6] as Map).cast<String, int>(),
      sageCoverage: (fields[7] as Map).cast<String, double>(),
      emotionVariance: fields[8] as double,
      journalIds: (fields[9] as List).cast<String>(),
      createdAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InsightSnapshot obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.periodStart)
      ..writeByte(2)
      ..write(obj.periodEnd)
      ..writeByte(3)
      ..write(obj.topWords)
      ..writeByte(4)
      ..write(obj.wordFrequencies)
      ..writeByte(5)
      ..write(obj.emotionScores)
      ..writeByte(6)
      ..write(obj.phaseCounts)
      ..writeByte(7)
      ..write(obj.sageCoverage)
      ..writeByte(8)
      ..write(obj.emotionVariance)
      ..writeByte(9)
      ..write(obj.journalIds)
      ..writeByte(10)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
