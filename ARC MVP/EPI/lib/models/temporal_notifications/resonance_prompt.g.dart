// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resonance_prompt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResonancePrompt _$ResonancePromptFromJson(Map<String, dynamic> json) =>
    ResonancePrompt(
      type: $enumDecode(_$ResonancePromptTypeEnumMap, json['type']),
      promptText: json['promptText'] as String,
      sourceEntryId: json['sourceEntryId'] as String?,
      callbackDate: json['callbackDate'] == null
          ? null
          : DateTime.parse(json['callbackDate'] as String),
      relatedThemes: (json['relatedThemes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
    );

Map<String, dynamic> _$ResonancePromptToJson(ResonancePrompt instance) =>
    <String, dynamic>{
      'type': _$ResonancePromptTypeEnumMap[instance.type]!,
      'promptText': instance.promptText,
      'sourceEntryId': instance.sourceEntryId,
      'callbackDate': instance.callbackDate?.toIso8601String(),
      'relatedThemes': instance.relatedThemes,
      'relevanceScore': instance.relevanceScore,
    };

const _$ResonancePromptTypeEnumMap = {
  ResonancePromptType.themeRecurrence: 'themeRecurrence',
  ResonancePromptType.temporalCallback: 'temporalCallback',
  ResonancePromptType.patternSurface: 'patternSurface',
  ResonancePromptType.phaseRelevant: 'phaseRelevant',
  ResonancePromptType.openExploration: 'openExploration',
};
