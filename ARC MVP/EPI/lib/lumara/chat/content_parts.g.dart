// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_parts.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TextContentPartAdapter extends TypeAdapter<TextContentPart> {
  @override
  final int typeId = 81;

  @override
  TextContentPart read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TextContentPart(
      text: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TextContentPart obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.mime)
      ..writeByte(1)
      ..write(obj.text);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextContentPartAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaContentPartAdapter extends TypeAdapter<MediaContentPart> {
  @override
  final int typeId = 82;

  @override
  MediaContentPart read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaContentPart(
      mime: fields[0] as String,
      pointer: fields[1] as MediaPointer,
      alt: fields[2] as String?,
      durationMs: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaContentPart obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.mime)
      ..writeByte(1)
      ..write(obj.pointer)
      ..writeByte(2)
      ..write(obj.alt)
      ..writeByte(3)
      ..write(obj.durationMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaContentPartAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrismContentPartAdapter extends TypeAdapter<PrismContentPart> {
  @override
  final int typeId = 83;

  @override
  PrismContentPart read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrismContentPart(
      summary: fields[1] as PrismSummary,
    );
  }

  @override
  void write(BinaryWriter writer, PrismContentPart obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.mime)
      ..writeByte(1)
      ..write(obj.summary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismContentPartAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaPointerAdapter extends TypeAdapter<MediaPointer> {
  @override
  final int typeId = 84;

  @override
  MediaPointer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaPointer(
      uri: fields[0] as String,
      role: fields[1] as String?,
      metadata: Map<String, dynamic>.from(fields[2] as Map),
    );
  }

  @override
  void write(BinaryWriter writer, MediaPointer obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.uri)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaPointerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrismSummaryAdapter extends TypeAdapter<PrismSummary> {
  @override
  final int typeId = 85;

  @override
  PrismSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrismSummary(
      captions: (fields[0] as List?)?.cast<String>(),
      transcript: fields[1] as String?,
      objects: (fields[2] as List?)?.cast<String>(),
      emotion: fields[3] as EmotionData?,
      symbols: (fields[4] as List?)?.cast<String>(),
      metadata: Map<String, dynamic>.from(fields[5] as Map),
    );
  }

  @override
  void write(BinaryWriter writer, PrismSummary obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.captions)
      ..writeByte(1)
      ..write(obj.transcript)
      ..writeByte(2)
      ..write(obj.objects)
      ..writeByte(3)
      ..write(obj.emotion)
      ..writeByte(4)
      ..write(obj.symbols)
      ..writeByte(5)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EmotionDataAdapter extends TypeAdapter<EmotionData> {
  @override
  final int typeId = 86;

  @override
  EmotionData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmotionData(
      valence: fields[0] as double,
      arousal: fields[1] as double,
      dominantEmotion: fields[2] as String?,
      metadata: Map<String, dynamic>.from(fields[3] as Map),
    );
  }

  @override
  void write(BinaryWriter writer, EmotionData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.valence)
      ..writeByte(1)
      ..write(obj.arousal)
      ..writeByte(2)
      ..write(obj.dominantEmotion)
      ..writeByte(3)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmotionDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}