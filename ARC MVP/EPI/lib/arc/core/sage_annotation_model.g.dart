// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sage_annotation_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SAGEAnnotationAdapter extends TypeAdapter<SAGEAnnotation> {
  @override
  final int typeId = 3;

  @override
  SAGEAnnotation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SAGEAnnotation(
      situation: fields[0] as String,
      action: fields[1] as String,
      growth: fields[2] as String,
      essence: fields[3] as String,
      confidence: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SAGEAnnotation obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.situation)
      ..writeByte(1)
      ..write(obj.action)
      ..writeByte(2)
      ..write(obj.growth)
      ..writeByte(3)
      ..write(obj.essence)
      ..writeByte(4)
      ..write(obj.confidence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SAGEAnnotationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
