// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_storage_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveStorageSettingsAdapter extends TypeAdapter<HiveStorageSettings> {
  @override
  final int typeId = 41;

  @override
  HiveStorageSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveStorageSettings(
      global: fields[0] as StorageProfile,
      perMode: (fields[1] as Map?)?.cast<String, StorageProfile>(),
      retentionDays: fields[2] as int,
      enableAutoOffload: fields[3] as bool,
      autoOffloadDays: fields[4] as int,
      enableRetentionPruner: fields[5] as bool,
      retentionStrategy: fields[6] as String,
      privacySettings: (fields[7] as Map?)?.cast<String, dynamic>(),
      lastUpdated: fields[8] as DateTime?,
      version: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HiveStorageSettings obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.global)
      ..writeByte(1)
      ..write(obj.perMode)
      ..writeByte(2)
      ..write(obj.retentionDays)
      ..writeByte(3)
      ..write(obj.enableAutoOffload)
      ..writeByte(4)
      ..write(obj.autoOffloadDays)
      ..writeByte(5)
      ..write(obj.enableRetentionPruner)
      ..writeByte(6)
      ..write(obj.retentionStrategy)
      ..writeByte(7)
      ..write(obj.privacySettings)
      ..writeByte(8)
      ..write(obj.lastUpdated)
      ..writeByte(9)
      ..write(obj.version);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveStorageSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConsentRecordAdapter extends TypeAdapter<ConsentRecord> {
  @override
  final int typeId = 42;

  @override
  ConsentRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConsentRecord(
      entryId: fields[0] as String,
      userId: fields[1] as String,
      deviceId: fields[2] as String,
      selectedProfile: fields[3] as StorageProfile,
      perImportOverride: fields[4] as StorageProfile?,
      timestamp: fields[5] as DateTime,
      appMode: fields[6] as String,
      privacyChoices: (fields[7] as Map).cast<String, dynamic>(),
      consentVersion: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ConsentRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.entryId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.deviceId)
      ..writeByte(3)
      ..write(obj.selectedProfile)
      ..writeByte(4)
      ..write(obj.perImportOverride)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.appMode)
      ..writeByte(7)
      ..write(obj.privacyChoices)
      ..writeByte(8)
      ..write(obj.consentVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StorageProfileAdapter extends TypeAdapter<StorageProfile> {
  @override
  final int typeId = 40;

  @override
  StorageProfile read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StorageProfile.minimal;
      case 1:
        return StorageProfile.balanced;
      case 2:
        return StorageProfile.hifi;
      default:
        return StorageProfile.minimal;
    }
  }

  @override
  void write(BinaryWriter writer, StorageProfile obj) {
    switch (obj) {
      case StorageProfile.minimal:
        writer.writeByte(0);
        break;
      case StorageProfile.balanced:
        writer.writeByte(1);
        break;
      case StorageProfile.hifi:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HiveStorageSettings _$HiveStorageSettingsFromJson(Map<String, dynamic> json) =>
    HiveStorageSettings(
      global: $enumDecodeNullable(_$StorageProfileEnumMap, json['global']) ??
          StorageProfile.minimal,
      perMode: (json['perMode'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, $enumDecode(_$StorageProfileEnumMap, e)),
      ),
      retentionDays: (json['retentionDays'] as num?)?.toInt() ?? 30,
      enableAutoOffload: json['enableAutoOffload'] as bool? ?? true,
      autoOffloadDays: (json['autoOffloadDays'] as num?)?.toInt() ?? 30,
      enableRetentionPruner: json['enableRetentionPruner'] as bool? ?? true,
      retentionStrategy: json['retentionStrategy'] as String? ?? 'lru',
      privacySettings: json['privacySettings'] as Map<String, dynamic>?,
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$HiveStorageSettingsToJson(
        HiveStorageSettings instance) =>
    <String, dynamic>{
      'global': _$StorageProfileEnumMap[instance.global]!,
      'perMode': instance.perMode
          .map((k, e) => MapEntry(k, _$StorageProfileEnumMap[e]!)),
      'retentionDays': instance.retentionDays,
      'enableAutoOffload': instance.enableAutoOffload,
      'autoOffloadDays': instance.autoOffloadDays,
      'enableRetentionPruner': instance.enableRetentionPruner,
      'retentionStrategy': instance.retentionStrategy,
      'privacySettings': instance.privacySettings,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'version': instance.version,
    };

const _$StorageProfileEnumMap = {
  StorageProfile.minimal: 'minimal',
  StorageProfile.balanced: 'balanced',
  StorageProfile.hifi: 'hifi',
};

ConsentRecord _$ConsentRecordFromJson(Map<String, dynamic> json) =>
    ConsentRecord(
      entryId: json['entryId'] as String,
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String,
      selectedProfile:
          $enumDecode(_$StorageProfileEnumMap, json['selectedProfile']),
      perImportOverride: $enumDecodeNullable(
          _$StorageProfileEnumMap, json['perImportOverride']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      appMode: json['appMode'] as String,
      privacyChoices: json['privacyChoices'] as Map<String, dynamic>,
      consentVersion: json['consentVersion'] as String,
    );

Map<String, dynamic> _$ConsentRecordToJson(ConsentRecord instance) =>
    <String, dynamic>{
      'entryId': instance.entryId,
      'userId': instance.userId,
      'deviceId': instance.deviceId,
      'selectedProfile': _$StorageProfileEnumMap[instance.selectedProfile]!,
      'perImportOverride': _$StorageProfileEnumMap[instance.perImportOverride],
      'timestamp': instance.timestamp.toIso8601String(),
      'appMode': instance.appMode,
      'privacyChoices': instance.privacyChoices,
      'consentVersion': instance.consentVersion,
    };
