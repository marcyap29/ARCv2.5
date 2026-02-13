import 'package:flutter/foundation.dart';
import 'theme_appearance.dart';
import 'pattern_insights.dart';

/// Cluster of semantically similar themes across time.
/// Preserves all variations of how user describes a pattern.
@immutable
class ThemeCluster {
  final String clusterId;
  final String canonicalLabel;
  final List<String> aliases;
  final List<ThemeAppearance> appearances;
  final PatternInsights insights;
  final List<double> canonicalEmbedding;
  final DateTime firstSeen;
  final DateTime lastUpdated;

  const ThemeCluster({
    required this.clusterId,
    required this.canonicalLabel,
    required this.aliases,
    required this.appearances,
    required this.insights,
    required this.canonicalEmbedding,
    required this.firstSeen,
    required this.lastUpdated,
  });

  int get totalAppearances => appearances.length;

  bool get isActive =>
      appearances.isEmpty ||
      (appearances.last.resolution?.resolved != true);

  ThemeCluster addAlias(String newLabel) {
    if (aliases.contains(newLabel)) return this;

    return ThemeCluster(
      clusterId: clusterId,
      canonicalLabel: canonicalLabel,
      aliases: [...aliases, newLabel],
      appearances: appearances,
      insights: insights,
      canonicalEmbedding: canonicalEmbedding,
      firstSeen: firstSeen,
      lastUpdated: DateTime.now(),
    );
  }

  ThemeCluster addAppearance(ThemeAppearance appearance) {
    return ThemeCluster(
      clusterId: clusterId,
      canonicalLabel: canonicalLabel,
      aliases: aliases,
      appearances: [...appearances, appearance],
      insights: insights,
      canonicalEmbedding: canonicalEmbedding,
      firstSeen: firstSeen,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cluster_id': clusterId,
        'canonical_label': canonicalLabel,
        'aliases': aliases,
        'appearances': appearances.map((a) => a.toJson()).toList(),
        'insights': insights.toJson(),
        'canonical_embedding': canonicalEmbedding,
        'first_seen': firstSeen.toIso8601String(),
        'last_updated': lastUpdated.toIso8601String(),
      };

  factory ThemeCluster.fromJson(Map<String, dynamic> json) => ThemeCluster(
        clusterId: json['cluster_id'] as String,
        canonicalLabel: json['canonical_label'] as String,
        aliases: (json['aliases'] as List).cast<String>(),
        appearances: (json['appearances'] as List)
            .map((a) => ThemeAppearance.fromJson(a as Map<String, dynamic>))
            .toList(),
        insights: PatternInsights.fromJson(
          json['insights'] as Map<String, dynamic>,
        ),
        canonicalEmbedding:
            (json['canonical_embedding'] as List).cast<double>(),
        firstSeen: DateTime.parse(json['first_seen'] as String),
        lastUpdated: DateTime.parse(json['last_updated'] as String),
      );
}
