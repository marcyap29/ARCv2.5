// lib/models/temporal_notifications/resonance_prompt.dart
// Model for daily resonance prompts

import 'package:json_annotation/json_annotation.dart';

part 'resonance_prompt.g.dart';

enum ResonancePromptType {
  @JsonValue('themeRecurrence')
  themeRecurrence,    // "You mentioned [theme] 3 times this week"
  @JsonValue('temporalCallback')
  temporalCallback,   // "30 days ago you wrote about [topic]"
  @JsonValue('patternSurface')
  patternSurface,     // "Noticing a pattern around [theme]"
  @JsonValue('phaseRelevant')
  phaseRelevant,      // Prompt specific to current phase
  @JsonValue('openExploration')
  openExploration,    // When no strong signals, gentle open prompt
}

@JsonSerializable()
class ResonancePrompt {
  final ResonancePromptType type;
  final String promptText;
  final String? sourceEntryId;        // Link to relevant past entry
  final DateTime? callbackDate;       // For temporal callbacks
  final List<String> relatedThemes;
  final double relevanceScore;        // SENTINEL-derived

  ResonancePrompt({
    required this.type,
    required this.promptText,
    this.sourceEntryId,
    this.callbackDate,
    required this.relatedThemes,
    required this.relevanceScore,
  });

  factory ResonancePrompt.fromJson(Map<String, dynamic> json) =>
      _$ResonancePromptFromJson(json);

  Map<String, dynamic> toJson() => _$ResonancePromptToJson(this);
}

