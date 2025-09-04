import 'dart:math' as math;
import 'mira_models.dart';
import 'mira_repo.dart';

/// Service for MIRA semantic memory operations and insights
class MiraService {
  final MiraRepo _repo;
  final MiraConfig _config;

  MiraService({
    MiraRepo? repo,
    MiraConfig? config,
  }) : _repo = repo ?? MiraRepo(),
       _config = config ?? const MiraConfig();

  /// Initialize the service
  Future<void> init() async {
    await _repo.init();
  }

  /// Close the service
  Future<void> close() async {
    await _repo.close();
  }

  /// Add a journal entry to the semantic memory graph
  /// This is called after the user confirms the phase in the Phase Confirmation Dialog
  Future<void> addEntry({
    required String entryId,
    required DateTime timestamp,
    required List<String> selectedKeywords,
    required List<String> emotions,
    required String confirmedPhase,
    double? rivetAlignScore, // Optional RIVET ALIGN score for confidence
  }) async {
    // Check if entry has already been processed (idempotency)
    if (_repo.isEntryProcessed(entryId)) {
      print('DEBUG: Entry $entryId already processed, skipping');
      return;
    }

    print('DEBUG: Adding entry $entryId to MIRA graph');
    final confidence = rivetAlignScore ?? _config.defaultConfidence;

    // Create and upsert nodes
    await _upsertEntryNodes(entryId, timestamp, selectedKeywords, emotions, confirmedPhase);
    
    // Create and upsert edges
    await _upsertEntryEdges(entryId, timestamp, selectedKeywords, emotions, confirmedPhase, confidence);
    
    // Mark entry as processed
    await _repo.markEntryProcessed(entryId);
    
    print('DEBUG: Entry $entryId successfully added to MIRA graph');
  }

  /// Upsert all nodes for an entry
  Future<void> _upsertEntryNodes(
    String entryId,
    DateTime timestamp,
    List<String> selectedKeywords,
    List<String> emotions,
    String confirmedPhase,
  ) async {
    // Entry node
    final entryNode = MiraNode(
      id: entryId,
      type: MiraNodeType.entry,
      label: entryId,
      createdAt: timestamp,
      updatedAt: DateTime.now(),
    );
    await _repo.upsertNode(entryNode);

    // Keyword nodes
    for (final keyword in selectedKeywords) {
      final keywordNode = MiraNode.keyword(keyword);
      await _repo.upsertNode(keywordNode);
    }

    // Phase node
    final phaseNode = MiraNode.phase(confirmedPhase);
    await _repo.upsertNode(phaseNode);

    // Emotion nodes
    for (final emotion in emotions) {
      final emotionNode = MiraNode.emotion(emotion);
      await _repo.upsertNode(emotionNode);
    }

    // Period nodes
    final dayNode = MiraNode.dayPeriod(timestamp);
    final weekNode = MiraNode.weekPeriod(timestamp);
    await _repo.upsertNode(dayNode);
    await _repo.upsertNode(weekNode);
  }

  /// Upsert all edges for an entry
  Future<void> _upsertEntryEdges(
    String entryId,
    DateTime timestamp,
    List<String> selectedKeywords,
    List<String> emotions,
    String confirmedPhase,
    double confidence,
  ) async {
    // Entry -> Keyword mentions
    for (final keyword in selectedKeywords) {
      final keywordId = _normalizeKeywordId(keyword);
      final edge = MiraEdge.create(
        srcId: entryId,
        dstId: keywordId,
        kind: MiraEdgeKind.mentions,
        wConfidence: confidence,
      );
      await _repo.upsertEdge(edge);
    }

    // Entry -> Emotion expressions
    for (final emotion in emotions) {
      final emotionId = 'emotion:$emotion';
      final edge = MiraEdge.create(
        srcId: entryId,
        dstId: emotionId,
        kind: MiraEdgeKind.expresses,
        wConfidence: confidence,
      );
      await _repo.upsertEdge(edge);
    }

    // Entry -> Phase tagging
    final phaseId = 'phase:$confirmedPhase';
    final phaseEdge = MiraEdge.create(
      srcId: entryId,
      dstId: phaseId,
      kind: MiraEdgeKind.taggedAs,
      wConfidence: confidence,
    );
    await _repo.upsertEdge(phaseEdge);

    // Entry -> Period membership
    final dayId = MiraNode.dayPeriod(timestamp).id;
    final weekId = MiraNode.weekPeriod(timestamp).id;
    
    final dayEdge = MiraEdge.create(
      srcId: entryId,
      dstId: dayId,
      kind: MiraEdgeKind.inPeriod,
      wConfidence: confidence,
    );
    final weekEdge = MiraEdge.create(
      srcId: entryId,
      dstId: weekId,
      kind: MiraEdgeKind.inPeriod,
      wConfidence: confidence,
    );
    
    await _repo.upsertEdge(dayEdge);
    await _repo.upsertEdge(weekEdge);

    // Keyword co-occurrence pairs (undirected)
    for (int i = 0; i < selectedKeywords.length; i++) {
      for (int j = i + 1; j < selectedKeywords.length; j++) {
        final keyword1 = _normalizeKeywordId(selectedKeywords[i]);
        final keyword2 = _normalizeKeywordId(selectedKeywords[j]);
        
        final cooccurEdge = MiraEdge.create(
          srcId: keyword1,
          dstId: keyword2,
          kind: MiraEdgeKind.cooccurs,
          wConfidence: confidence,
        );
        await _repo.upsertEdge(cooccurEdge);
      }
    }
  }

  /// Get top keywords in a time window
  Future<List<MiraKeywordStat>> topKeywords({
    required Duration window,
    int limit = 10,
  }) async {
    final cutoff = DateTime.now().subtract(window);
    final mentionEdges = _repo.getMentionEdges();
    
    // Filter edges within window and calculate decayed weights
    final keywordWeights = <String, double>{};
    final keywordCounts = <String, int>{};
    
    for (final edge in mentionEdges) {
      if (edge.updatedAt.isAfter(cutoff)) {
        final delta = DateTime.now().difference(edge.updatedAt);
        final decay = _config.calculateDecay(delta);
        final weight = edge.wFreq * decay * edge.wConfidence;
        
        keywordWeights[edge.dstId] = (keywordWeights[edge.dstId] ?? 0.0) + weight;
        keywordCounts[edge.dstId] = (keywordCounts[edge.dstId] ?? 0) + edge.wFreq.round();
      }
    }
    
    // Sort by weight and return top N
    final sortedKeywords = keywordWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedKeywords.take(limit).map((entry) {
      final keyword = entry.key;
      final score = entry.value;
      final count = keywordCounts[keyword] ?? 0;
      
      return MiraKeywordStat(
        keyword: keyword,
        score: score,
        count: count,
      );
    }).toList();
  }

  /// Get co-occurring keyword pairs on the rise
  Future<List<MiraPairStat>> cooccurrencePairsOnRise({
    required Duration window,
    int limit = 10,
  }) async {
    final now = DateTime.now();
    final currentCutoff = now.subtract(window);
    final previousCutoff = now.subtract(window * 2);
    
    final cooccurEdges = _repo.getCooccurrenceEdges();
    
    final pairStats = <String, MiraPairStat>{};
    
    for (final edge in cooccurEdges.values) {
      final delta = now.difference(edge.updatedAt);
      
      // Calculate current window weight
      double currentWeight = 0.0;
      if (edge.updatedAt.isAfter(currentCutoff)) {
        final decay = _config.calculateDecay(delta);
        currentWeight = edge.wFreq * decay * edge.wConfidence;
      }
      
      // Calculate previous window weight
      double previousWeight = 0.0;
      if (edge.updatedAt.isAfter(previousCutoff) && edge.updatedAt.isBefore(currentCutoff)) {
        final decay = _config.calculateDecay(delta);
        previousWeight = edge.wFreq * decay * edge.wConfidence;
      }
      
      // Calculate rise and lift
      final rise = currentWeight - previousWeight;
      final lift = (currentWeight + 1.0) / (previousWeight + 1.0);
      
      if (rise > 0 && lift > 1.0) {
        final key = edge.key;
        final parts = key.split('|');
        if (parts.length >= 2) {
          pairStats[key] = MiraPairStat(
            k1: parts[0],
            k2: parts[1],
            lift: lift,
            count: edge.wFreq.round(),
          );
        }
      }
    }
    
    // Sort by lift and return top N
    final sortedPairs = pairStats.values.toList()
      ..sort((a, b) => b.lift.compareTo(a.lift));
    
    return sortedPairs.take(limit).toList();
  }

  /// Get phase trajectory over time
  Future<List<MiraPhasePoint>> phaseTrajectory({
    required Duration window,
    String granularity = "day",
  }) async {
    final cutoff = DateTime.now().subtract(window);
    final phaseEdges = _repo.getPhaseTagEdges();
    
    // Group entries by time period
    final periodGroups = <String, Map<String, int>>{};
    
    for (final edge in phaseEdges) {
      if (edge.updatedAt.isAfter(cutoff)) {
        String periodKey;
        if (granularity == "week") {
          periodKey = MiraNode.weekPeriod(edge.updatedAt).id;
        } else {
          periodKey = MiraNode.dayPeriod(edge.updatedAt).id;
        }
        
        final phase = edge.dstId.replaceFirst('phase:', '');
        periodGroups[periodKey] ??= <String, int>{};
        periodGroups[periodKey]![phase] = (periodGroups[periodKey]![phase] ?? 0) + 1;
      }
    }
    
    // Convert to time series points
    final points = <MiraPhasePoint>[];
    for (final entry in periodGroups.entries) {
      final periodId = entry.key;
      final phaseCounts = entry.value;
      
      // Parse timestamp from period ID
      DateTime timestamp;
      if (granularity == "week") {
        // Parse week:YYYY-Www format
        final weekPart = periodId.replaceFirst('week:', '');
        final parts = weekPart.split('-W');
        if (parts.length == 2) {
          final year = int.parse(parts[0]);
          final week = int.parse(parts[1]);
          // Approximate week start (Monday)
          timestamp = DateTime(year, 1, 1).add(Duration(days: (week - 1) * 7));
        } else {
          timestamp = DateTime.now();
        }
      } else {
        // Parse day:YYYY-MM-DD format
        final datePart = periodId.replaceFirst('day:', '');
        final parts = datePart.split('-');
        if (parts.length == 3) {
          timestamp = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } else {
          timestamp = DateTime.now();
        }
      }
      
      points.add(MiraPhasePoint(
        timestamp: timestamp,
        countsByPhase: phaseCounts,
      ));
    }
    
    // Sort by timestamp
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return points;
  }

  /// Get breakthrough precursors
  Future<List<MiraKeywordStat>> breakthroughPrecursors({
    Duration lookback = const Duration(days: 30),
    int limit = 10,
  }) async {
    final now = DateTime.now();
    
    // Find all breakthrough entries in lookback period
    final breakthroughEntries = _repo.getEntriesByPhaseInWindow('Breakthrough', lookback);
    
    if (breakthroughEntries.isEmpty) {
      return [];
    }
    
    // For each breakthrough entry, look 3-5 days before
    final precursorWindows = <Duration, List<String>>{};
    for (final entryId in breakthroughEntries) {
      final entryNode = _repo.getNode(entryId);
      if (entryNode != null) {
        final entryTime = entryNode.createdAt;
        final precursorStart = entryTime.subtract(const Duration(days: 5));
        final precursorEnd = entryTime.subtract(const Duration(days: 3));
        
        // Find entries in precursor window
        final precursorEntries = _repo.getEntriesInWindow(Duration(days: 2))
            .where((id) {
              final node = _repo.getNode(id);
              if (node != null) {
                final nodeTime = node.createdAt;
                return nodeTime.isAfter(precursorStart) && nodeTime.isBefore(precursorEnd);
              }
              return false;
            })
            .toList();
        
        precursorWindows[Duration(days: 2)] = precursorEntries;
      }
    }
    
    // Aggregate keyword weights from precursor windows
    final keywordWeights = <String, double>{};
    final keywordCounts = <String, int>{};
    
    for (final entryIds in precursorWindows.values) {
      for (final entryId in entryIds) {
        final mentionEdges = _repo.getEdgesFromNode(entryId)
            .where((edge) => edge.kind == MiraEdgeKind.mentions);
        
        for (final edge in mentionEdges) {
          final delta = now.difference(edge.updatedAt);
          final decay = _config.calculateDecay(delta);
          final weight = edge.wFreq * decay * edge.wConfidence;
          
          keywordWeights[edge.dstId] = (keywordWeights[edge.dstId] ?? 0.0) + weight;
          keywordCounts[edge.dstId] = (keywordCounts[edge.dstId] ?? 0) + edge.wFreq.round();
        }
      }
    }
    
    // Sort by weight and return top N
    final sortedKeywords = keywordWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedKeywords.take(limit).map((entry) {
      final keyword = entry.key;
      final score = entry.value;
      final count = keywordCounts[keyword] ?? 0;
      
      return MiraKeywordStat(
        keyword: keyword,
        score: score,
        count: count,
      );
    }).toList();
  }

  /// RIVET TRACE helper: calculate trace score from graph
  double traceScoreFromGraph({
    required List<String> candidateKeywords,
    required DateTime now,
  }) {
    if (candidateKeywords.isEmpty) return 0.0;
    
    final normalizedKeywords = candidateKeywords.map((k) => _normalizeKeywordId(k)).toList();
    
    // Calculate prior mentions (30-day window)
    final priorWindow = const Duration(days: 30);
    final priorCutoff = now.subtract(priorWindow);
    final mentionEdges = _repo.getMentionEdges();
    
    double priorMentions = 0.0;
    for (final edge in mentionEdges) {
      if (edge.updatedAt.isAfter(priorCutoff) && normalizedKeywords.contains(edge.dstId)) {
        final delta = now.difference(edge.updatedAt);
        final decay = _config.calculateDecay(delta);
        priorMentions += edge.wFreq * decay * edge.wConfidence;
      }
    }
    
    // Normalize prior mentions
    priorMentions = math.min(priorMentions / normalizedKeywords.length, 10.0) / 10.0;
    
    // Calculate co-occurrence lift (14-day window)
    final cooccurWindow = const Duration(days: 14);
    final cooccurCutoff = now.subtract(cooccurWindow);
    final cooccurEdges = _repo.getCooccurrenceEdges();
    
    double cooccurLift = 0.0;
    int pairCount = 0;
    
    for (int i = 0; i < normalizedKeywords.length; i++) {
      for (int j = i + 1; j < normalizedKeywords.length; j++) {
        final key1 = normalizedKeywords[i];
        final key2 = normalizedKeywords[j];
        final ordered = [key1, key2]..sort();
        final edgeKey = '${ordered[0]}|${ordered[1]}|cooccurs';
        
        final edge = cooccurEdges[edgeKey];
        if (edge != null && edge.updatedAt.isAfter(cooccurCutoff)) {
          final delta = now.difference(edge.updatedAt);
          final decay = _config.calculateDecay(delta);
          final weight = edge.wFreq * decay * edge.wConfidence;
          cooccurLift += weight;
          pairCount++;
        }
      }
    }
    
    cooccurLift = pairCount > 0 ? cooccurLift / pairCount : 0.0;
    cooccurLift = math.min(cooccurLift, 5.0) / 5.0; // Normalize to [0,1]
    
    // Calculate recency bonus
    double recencyBonus = 0.0;
    for (final keyword in normalizedKeywords) {
      final mentionEdges = _repo.getEdgesToNode(keyword)
          .where((edge) => edge.kind == MiraEdgeKind.mentions);
      
      for (final edge in mentionEdges) {
        final delta = now.difference(edge.updatedAt);
        final decay = _config.calculateDecay(delta);
        final weight = edge.wFreq * decay * edge.wConfidence;
        recencyBonus = math.max(recencyBonus, weight);
      }
    }
    
    recencyBonus = math.min(recencyBonus, 10.0) / 10.0; // Normalize to [0,1]
    
    // Calculate novelty penalty
    double noveltyPenalty = 0.0;
    for (final keyword in normalizedKeywords) {
      final hasRecentMentions = mentionEdges.any((edge) => 
        edge.dstId == keyword && edge.updatedAt.isAfter(priorCutoff));
      if (!hasRecentMentions) {
        noveltyPenalty += 0.1;
      }
    }
    
    noveltyPenalty = math.min(noveltyPenalty, 0.5); // Cap at 0.5
    
    // Combine scores
    final raw = 0.5 * priorMentions + 0.3 * cooccurLift + 0.2 * recencyBonus - noveltyPenalty;
    
    // Clamp to [0,1]
    return math.max(0.0, math.min(1.0, raw));
  }

  /// Get repository statistics
  Map<String, dynamic> getStats() {
    return _repo.getStats();
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    await _repo.clearAll();
  }

  /// Normalize keyword to ID format (lowercase, spaces to underscores)
  String _normalizeKeywordId(String keyword) {
    return keyword.toLowerCase().replaceAll(' ', '_');
  }
}
