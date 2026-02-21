// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_category_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatCategoryAdapter extends TypeAdapter<ChatCategory> {
  @override
  final int typeId = 72;

  @override
  ChatCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      color: fields[3] as String,
      icon: fields[4] as String,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      sessionCount: fields[7] as int,
      isDefault: fields[8] as bool,
      sortOrder: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ChatCategory obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.icon)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.sessionCount)
      ..writeByte(8)
      ..write(obj.isDefault)
      ..writeByte(9)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatSessionCategoryAdapter extends TypeAdapter<ChatSessionCategory> {
  @override
  final int typeId = 73;

  @override
  ChatSessionCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSessionCategory(
      sessionId: fields[0] as String,
      categoryId: fields[1] as String,
      assignedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatSessionCategory obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.assignedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatExportDataAdapter extends TypeAdapter<ChatExportData> {
  @override
  final int typeId = 74;

  @override
  ChatExportData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatExportData(
      version: fields[0] as String,
      exportedAt: fields[1] as DateTime,
      exportedBy: fields[2] as String,
      sessions: (fields[3] as List).cast<ChatSession>(),
      messages: (fields[4] as List).cast<ChatMessage>(),
      categories: (fields[5] as List).cast<ChatCategory>(),
      sessionCategories: (fields[6] as List).cast<ChatSessionCategory>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatExportData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.version)
      ..writeByte(1)
      ..write(obj.exportedAt)
      ..writeByte(2)
      ..write(obj.exportedBy)
      ..writeByte(3)
      ..write(obj.sessions)
      ..writeByte(4)
      ..write(obj.messages)
      ..writeByte(5)
      ..write(obj.categories)
      ..writeByte(6)
      ..write(obj.sessionCategories);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatExportDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
