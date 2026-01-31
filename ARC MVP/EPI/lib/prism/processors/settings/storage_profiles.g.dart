// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_profiles.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StorageProfile _$StorageProfileFromJson(Map<String, dynamic> json) =>
    StorageProfile(
      policy: $enumDecode(_$StoragePolicyEnumMap, json['policy']),
      displayName: json['displayName'] as String,
      description: json['description'] as String,
      keepThumbnails: json['keepThumbnails'] as bool,
      keepTranscripts: json['keepTranscripts'] as bool,
      keepAnalysisVariant: json['keepAnalysisVariant'] as bool,
      keepFullResolution: json['keepFullResolution'] as bool,
      enableEncryption: json['enableEncryption'] as bool,
      maxFileSizeMB: (json['maxFileSizeMB'] as num).toInt(),
      retentionDays: (json['retentionDays'] as num).toInt(),
    );

Map<String, dynamic> _$StorageProfileToJson(StorageProfile instance) =>
    <String, dynamic>{
      'policy': _$StoragePolicyEnumMap[instance.policy]!,
      'displayName': instance.displayName,
      'description': instance.description,
      'keepThumbnails': instance.keepThumbnails,
      'keepTranscripts': instance.keepTranscripts,
      'keepAnalysisVariant': instance.keepAnalysisVariant,
      'keepFullResolution': instance.keepFullResolution,
      'enableEncryption': instance.enableEncryption,
      'maxFileSizeMB': instance.maxFileSizeMB,
      'retentionDays': instance.retentionDays,
    };

const _$StoragePolicyEnumMap = {
  StoragePolicy.minimal: 'minimal',
  StoragePolicy.balanced: 'balanced',
  StoragePolicy.hiFidelity: 'hiFidelity',
};

StorageSettings _$StorageSettingsFromJson(Map<String, dynamic> json) =>
    StorageSettings(
      globalDefault: $enumDecode(_$StoragePolicyEnumMap, json['globalDefault']),
      modeOverrides: (json['modeOverrides'] as Map<String, dynamic>).map(
        (k, e) => MapEntry($enumDecode(_$AppModeEnumMap, k),
            $enumDecode(_$StoragePolicyEnumMap, e)),
      ),
      enableAutoOffload: json['enableAutoOffload'] as bool,
      autoOffloadDays: (json['autoOffloadDays'] as num).toInt(),
      enableRetentionPruner: json['enableRetentionPruner'] as bool,
    );

Map<String, dynamic> _$StorageSettingsToJson(StorageSettings instance) =>
    <String, dynamic>{
      'globalDefault': _$StoragePolicyEnumMap[instance.globalDefault]!,
      'modeOverrides': instance.modeOverrides.map(
          (k, e) => MapEntry(_$AppModeEnumMap[k]!, _$StoragePolicyEnumMap[e]!)),
      'enableAutoOffload': instance.enableAutoOffload,
      'autoOffloadDays': instance.autoOffloadDays,
      'enableRetentionPruner': instance.enableRetentionPruner,
    };

const _$AppModeEnumMap = {
  AppMode.personal: 'personal',
};
