import 'package:flutter/foundation.dart';

/// Structured theme object produced by monthly synthesis.
/// This is what gets vectorized, NOT raw journal entries.
@immutable
class DominantTheme {
  final String themeLabel;
  final String themeSummary;
  final List<double> embedding;
  final double confidence;
  final List<String> evidenceRefs;
  final double? intensity;
  final String? phase;
  final Map<String, dynamic> metadata;

  const DominantTheme({
    required this.themeLabel,
    required this.themeSummary,
    required this.embedding,
    required this.confidence,
    required this.evidenceRefs,
    this.intensity,
    this.phase,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'theme_label': themeLabel,
        'theme_summary': themeSummary,
        'embedding': embedding,
        'confidence': confidence,
        'evidence_refs': evidenceRefs,
        'intensity': intensity,
        'phase': phase,
        'metadata': metadata,
      };

  factory DominantTheme.fromJson(Map<String, dynamic> json) => DominantTheme(
        themeLabel: json['theme_label'] as String,
        themeSummary: json['theme_summary'] as String,
        embedding: (json['embedding'] as List).cast<double>(),
        confidence: (json['confidence'] as num).toDouble(),
        evidenceRefs: (json['evidence_refs'] as List).cast<String>(),
        intensity: (json['intensity'] as num?)?.toDouble(),
        phase: json['phase'] as String?,
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );
}
