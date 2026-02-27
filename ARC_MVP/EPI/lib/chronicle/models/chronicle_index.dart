import 'package:flutter/foundation.dart';
import 'dominant_theme.dart';
import 'theme_cluster.dart';

@immutable
class ChronicleIndex {
  final Map<String, ThemeCluster> themeClusters;
  final Map<String, String> labelToClusterId;
  final Map<String, PendingEcho> pendingEchoes;
  final Map<String, UnresolvedArc> arcs;
  final DateTime lastUpdated;

  const ChronicleIndex({
    required this.themeClusters,
    required this.labelToClusterId,
    required this.pendingEchoes,
    required this.arcs,
    required this.lastUpdated,
  });

  factory ChronicleIndex.empty() => ChronicleIndex(
        themeClusters: const {},
        labelToClusterId: const {},
        pendingEchoes: const {},
        arcs: const {},
        lastUpdated: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'theme_clusters':
            themeClusters.map((k, v) => MapEntry(k, v.toJson())),
        'label_to_cluster_id': labelToClusterId,
        'pending_echoes': pendingEchoes.map((k, v) => MapEntry(k, v.toJson())),
        'arcs': arcs.map((k, v) => MapEntry(k, v.toJson())),
        'last_updated': lastUpdated.toIso8601String(),
      };

  factory ChronicleIndex.fromJson(Map<String, dynamic> json) => ChronicleIndex(
        themeClusters: (json['theme_clusters'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, ThemeCluster.fromJson(v as Map<String, dynamic>)),
        ),
        labelToClusterId:
            (json['label_to_cluster_id'] as Map<String, dynamic>).cast<String, String>(),
        pendingEchoes: (json['pending_echoes'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, PendingEcho.fromJson(v as Map<String, dynamic>)),
        ),
        arcs: (json['arcs'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, UnresolvedArc.fromJson(v as Map<String, dynamic>)),
        ),
        lastUpdated: DateTime.parse(json['last_updated'] as String),
      );

  ChronicleIndex copyWith({
    Map<String, ThemeCluster>? themeClusters,
    Map<String, String>? labelToClusterId,
    Map<String, PendingEcho>? pendingEchoes,
    Map<String, UnresolvedArc>? arcs,
    DateTime? lastUpdated,
  }) =>
      ChronicleIndex(
        themeClusters: themeClusters ?? this.themeClusters,
        labelToClusterId: labelToClusterId ?? this.labelToClusterId,
        pendingEchoes: pendingEchoes ?? this.pendingEchoes,
        arcs: arcs ?? this.arcs,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  /// Returns a copy of this index with theme clusters whose [canonicalLabel]
  /// is in [ignoredCanonicalLabels] removed. Used to hide user-ignored themes
  /// from pattern queries and related-entry resolution.
  ChronicleIndex withoutIgnoredThemes(Set<String> ignoredCanonicalLabels) {
    if (ignoredCanonicalLabels.isEmpty) return this;
    final keepIds = <String>{};
    final filteredClusters = <String, ThemeCluster>{};
    for (final e in themeClusters.entries) {
      if (!ignoredCanonicalLabels.contains(e.value.canonicalLabel)) {
        keepIds.add(e.key);
        filteredClusters[e.key] = e.value;
      }
    }
    if (filteredClusters.length == themeClusters.length) return this;

    final filteredLabelToClusterId = Map<String, String>.fromEntries(
      labelToClusterId.entries.where(
        (e) => keepIds.contains(e.value),
      ),
    );
    final filteredEchoes = Map<String, PendingEcho>.fromEntries(
      pendingEchoes.entries.where(
        (e) => keepIds.contains(e.value.candidateCluster.clusterId),
      ),
    );
    final filteredArcs = Map<String, UnresolvedArc>.fromEntries(
      arcs.entries.where((e) => keepIds.contains(e.value.clusterId)),
    );

    return ChronicleIndex(
      themeClusters: filteredClusters,
      labelToClusterId: filteredLabelToClusterId,
      pendingEchoes: filteredEchoes,
      arcs: filteredArcs,
      lastUpdated: lastUpdated,
    );
  }
}

@immutable
class PendingEcho {
  final String id;
  final DominantTheme newTheme;
  final ThemeCluster candidateCluster;
  final double similarity;
  final DateTime flaggedDate;

  const PendingEcho({
    required this.id,
    required this.newTheme,
    required this.candidateCluster,
    required this.similarity,
    required this.flaggedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'new_theme': newTheme.toJson(),
        'candidate_cluster': candidateCluster.toJson(),
        'similarity': similarity,
        'flagged_date': flaggedDate.toIso8601String(),
      };

  factory PendingEcho.fromJson(Map<String, dynamic> json) => PendingEcho(
        id: json['id'] as String,
        newTheme: DominantTheme.fromJson(json['new_theme'] as Map<String, dynamic>),
        candidateCluster: ThemeCluster.fromJson(
          json['candidate_cluster'] as Map<String, dynamic>,
        ),
        similarity: (json['similarity'] as num).toDouble(),
        flaggedDate: DateTime.parse(json['flagged_date'] as String),
      );
}

@immutable
class UnresolvedArc {
  final String clusterId;
  final DateTime firstSeen;
  final int totalAppearances;
  final List<double> intensityOverTime;
  final List<AttemptedResolution> attemptedResolutions;
  final String currentStatus;
  final String? recommendation;

  const UnresolvedArc({
    required this.clusterId,
    required this.firstSeen,
    required this.totalAppearances,
    required this.intensityOverTime,
    required this.attemptedResolutions,
    required this.currentStatus,
    this.recommendation,
  });

  bool get isEscalating =>
      intensityOverTime.length >= 3 &&
      intensityOverTime.last >
          intensityOverTime[intensityOverTime.length - 3];

  Map<String, dynamic> toJson() => {
        'cluster_id': clusterId,
        'first_seen': firstSeen.toIso8601String(),
        'total_appearances': totalAppearances,
        'intensity_over_time': intensityOverTime,
        'attempted_resolutions':
            attemptedResolutions.map((r) => r.toJson()).toList(),
        'current_status': currentStatus,
        'recommendation': recommendation,
      };

  factory UnresolvedArc.fromJson(Map<String, dynamic> json) => UnresolvedArc(
        clusterId: json['cluster_id'] as String,
        firstSeen: DateTime.parse(json['first_seen'] as String),
        totalAppearances: json['total_appearances'] as int,
        intensityOverTime:
            (json['intensity_over_time'] as List).cast<double>(),
        attemptedResolutions: (json['attempted_resolutions'] as List)
            .map((r) => AttemptedResolution.fromJson(r as Map<String, dynamic>))
            .toList(),
        currentStatus: json['current_status'] as String,
        recommendation: json['recommendation'] as String?,
      );
}

@immutable
class AttemptedResolution {
  final String period;
  final String approach;
  final bool success;
  final String? outcome;

  const AttemptedResolution({
    required this.period,
    required this.approach,
    required this.success,
    this.outcome,
  });

  Map<String, dynamic> toJson() => {
        'period': period,
        'approach': approach,
        'success': success,
        'outcome': outcome,
      };

  factory AttemptedResolution.fromJson(Map<String, dynamic> json) =>
      AttemptedResolution(
        period: json['period'] as String,
        approach: json['approach'] as String,
        success: json['success'] as bool,
        outcome: json['outcome'] as String?,
      );
}
