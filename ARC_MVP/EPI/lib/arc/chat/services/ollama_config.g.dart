// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ollama_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OllamaConfigAdapter extends TypeAdapter<OllamaConfig> {
  @override
  final int typeId = 127;

  @override
  OllamaConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OllamaConfig(
      baseUrl: fields[0] as String,
      defaultModel: fields[1] as String?,
      taskModelMapping: (fields[2] as Map).cast<String, String>(),
      enabled: fields[3] as bool,
      strategyIndex: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OllamaConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.baseUrl)
      ..writeByte(1)
      ..write(obj.defaultModel)
      ..writeByte(2)
      ..write(obj.taskModelMapping)
      ..writeByte(3)
      ..write(obj.enabled)
      ..writeByte(4)
      ..write(obj.strategyIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OllamaConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
