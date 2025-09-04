import 'dart:math' as math;

/// Node types in the MIRA semantic memory graph
enum MiraNodeType {
  entry,
  keyword,
  phase,
  emotion,
  periodDay,
  periodWeek,
}

/// Edge types connecting nodes in the MIRA graph
enum MiraEdgeKind {
  mentions,    // Entry -> Keyword
  cooccurs,    // Keyword <-> Keyword (undirected)
  expresses,   // Entry -> Emotion
  taggedAs,    // Entry -> Phase
  inPeriod,    // Entry -> PeriodDay/PeriodWeek
}

/// A node in the MIRA semantic memory graph
class MiraNode {
  final String id;
  final MiraNodeType type;
  final String label;
  final DateTime createdAt;
  final DateTime updatedAt;

  MiraNode({
    required this.id,
    required this.type,
    required this.label,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a keyword node with normalized ID
  factory MiraNode.keyword(String keyword) {
    final normalizedId = _normalizeKeywordId(keyword);
    final now = DateTime.now();
    return MiraNode(
      id: normalizedId,
      type: MiraNodeType.keyword,
      label: keyword,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a phase node
  factory MiraNode.phase(String phase) {
    final now = DateTime.now();
    return MiraNode(
      id: 'phase:$phase',
      type: MiraNodeType.phase,
      label: phase,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create an emotion node
  factory MiraNode.emotion(String emotion) {
    final now = DateTime.now();
    return MiraNode(
      id: 'emotion:$emotion',
      type: MiraNodeType.emotion,
      label: emotion,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a day period node
  factory MiraNode.dayPeriod(DateTime date) {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    return MiraNode(
      id: 'day:$dateStr',
      type: MiraNodeType.periodDay,
      label: dateStr,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a week period node (ISO week)
  factory MiraNode.weekPeriod(DateTime date) {
    final weekStr = _getIsoWeekString(date);
    final now = DateTime.now();
    return MiraNode(
      id: 'week:$weekStr',
      type: MiraNodeType.periodWeek,
      label: weekStr,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Normalize keyword to ID format (lowercase, spaces to underscores)
  static String _normalizeKeywordId(String keyword) {
    return keyword.toLowerCase().replaceAll(' ', '_');
  }

  /// Get ISO week string for a date
  static String _getIsoWeekString(DateTime date) {
    // Simple ISO week calculation (week starts on Monday)
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  MiraNode copyWith({
    String? id,
    MiraNodeType? type,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MiraNode(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;

  @override
  String toString() => 'MiraNode(id: $id, type: $type, label: $label)';
}

/// An edge connecting two nodes in the MIRA graph
class MiraEdge {
  final String srcId;
  final String dstId;
  final MiraEdgeKind kind;
  final double wFreq;        // running frequency weight
  final double wRecency;     // recency emphasis (1.0 on update)
  final double wConfidence;  // confidence from RIVET (0.0-1.0)
  final DateTime updatedAt;

  MiraEdge({
    required this.srcId,
    required this.dstId,
    required this.kind,
    required this.wFreq,
    required this.wRecency,
    required this.wConfidence,
    required this.updatedAt,
  });

  /// Create a new edge with default values
  factory MiraEdge.create({
    required String srcId,
    required String dstId,
    required MiraEdgeKind kind,
    double wConfidence = 1.0,
  }) {
    return MiraEdge(
      srcId: srcId,
      dstId: dstId,
      kind: kind,
      wFreq: 1.0,
      wRecency: 1.0,
      wConfidence: wConfidence,
      updatedAt: DateTime.now(),
    );
  }

  /// Bump the frequency weight of this edge
  MiraEdge bump({double wConfidence = 1.0}) {
    return MiraEdge(
      srcId: srcId,
      dstId: dstId,
      kind: kind,
      wFreq: wFreq + 1.0,
      wRecency: 1.0,
      wConfidence: wConfidence,
      updatedAt: DateTime.now(),
    );
  }

  /// Get a stable key for this edge (for cooccurs, use ordered pair)
  String get key {
    if (kind == MiraEdgeKind.cooccurs) {
      // For cooccurs, always use ordered pair for undirected edges
      final ordered = [srcId, dstId]..sort();
      return '${ordered[0]}|${ordered[1]}|${kind.name}';
    }
    return '$srcId|$dstId|${kind.name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraEdge &&
          runtimeType == other.runtimeType &&
          srcId == other.srcId &&
          dstId == other.dstId &&
          kind == other.kind;

  @override
  int get hashCode => srcId.hashCode ^ dstId.hashCode ^ kind.hashCode;

  @override
  String toString() => 'MiraEdge($srcId -> $dstId, $kind, wFreq: $wFreq)';
}

/// Data transfer objects for query results

/// Keyword statistics for insights
class MiraKeywordStat {
  final String keyword;
  final double score;
  final int count;

  MiraKeywordStat({
    required this.keyword,
    required this.score,
    required this.count,
  });

  @override
  String toString() => 'MiraKeywordStat(keyword: $keyword, score: $score, count: $count)';
}

/// Keyword pair statistics for co-occurrence analysis
class MiraPairStat {
  final String k1;
  final String k2;
  final double lift;
  final int count;

  MiraPairStat({
    required this.k1,
    required this.k2,
    required this.lift,
    required this.count,
  });

  @override
  String toString() => 'MiraPairStat($k1 + $k2, lift: $lift, count: $count)';
}

/// Phase trajectory point for time series analysis
class MiraPhasePoint {
  final DateTime timestamp;
  final Map<String, int> countsByPhase;

  MiraPhasePoint({
    required this.timestamp,
    required this.countsByPhase,
  });

  @override
  String toString() => 'MiraPhasePoint($timestamp, phases: $countsByPhase)';
}

/// Configuration for MIRA algorithms
class MiraConfig {
  final double halfLifeDays;
  final int maxAgeDays;
  final double defaultConfidence;

  const MiraConfig({
    this.halfLifeDays = 14.0,
    this.maxAgeDays = 90,
    this.defaultConfidence = 1.0,
  });

  /// Calculate decay factor for a given time delta
  double calculateDecay(Duration delta) {
    final deltaDays = delta.inDays.toDouble();
    if (deltaDays < 0) return 1.0;
    
    final lambda = 0.69314718056 / halfLifeDays; // ln(2) / halfLifeDays
    return math.exp(-lambda * deltaDays);
  }

  /// Check if an item is too old to consider
  bool isTooOld(Duration delta) {
    return delta.inDays > maxAgeDays;
  }
}


