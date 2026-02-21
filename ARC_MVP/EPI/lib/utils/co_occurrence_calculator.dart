// lib/utils/co_occurrence_calculator.dart
// Calculate co-occurrence relationships between keywords

import 'dart:math' as math;

/// Result of co-occurrence calculation
class CoOccurrence {
  final String keywordA;
  final String keywordB;
  final int count; // How many times they appear together
  final double lift; // Lift metric (how much more than random)
  final double confidence; // Confidence metric
  final double weight; // Normalized weight (0.0-1.0)

  const CoOccurrence({
    required this.keywordA,
    required this.keywordB,
    required this.count,
    required this.lift,
    required this.confidence,
    required this.weight,
  });

  @override
  String toString() => '$keywordA ↔ $keywordB (count: $count, lift: ${lift.toStringAsFixed(2)}, weight: ${weight.toStringAsFixed(2)})';
}

/// Calculator for keyword co-occurrence relationships
class CoOccurrenceCalculator {
  /// Calculate co-occurrence matrix for keywords
  /// Returns list of co-occurrence relationships
  static List<CoOccurrence> calculate({
    required List<Set<String>> documentKeywords,
    required Set<String> targetKeywords,
    double minLift = 1.2,
    double minCount = 2,
  }) {
    if (documentKeywords.isEmpty || targetKeywords.isEmpty) {
      return [];
    }

    final coOccurrences = <CoOccurrence>[];
    final totalDocuments = documentKeywords.length;

    // Calculate frequency of each keyword
    final keywordFrequency = <String, int>{};
    for (final doc in documentKeywords) {
      for (final keyword in doc) {
        if (targetKeywords.contains(keyword)) {
          keywordFrequency[keyword] = (keywordFrequency[keyword] ?? 0) + 1;
        }
      }
    }

    // Calculate co-occurrence for each pair
    final keywords = targetKeywords.toList();
    for (int i = 0; i < keywords.length; i++) {
      final keywordA = keywords[i];
      final freqA = keywordFrequency[keywordA] ?? 0;

      for (int j = i + 1; j < keywords.length; j++) {
        final keywordB = keywords[j];
        final freqB = keywordFrequency[keywordB] ?? 0;

        // Count documents containing both keywords
        int coOccurCount = 0;
        for (final doc in documentKeywords) {
          if (doc.contains(keywordA) && doc.contains(keywordB)) {
            coOccurCount++;
          }
        }

        // Skip if below minimum count
        if (coOccurCount < minCount) continue;

        // Calculate metrics
        final pA = freqA / totalDocuments;
        final pB = freqB / totalDocuments;
        final pAB = coOccurCount / totalDocuments;

        // Lift: how much more than random chance
        // Lift = P(A,B) / (P(A) * P(B))
        // Lift > 1 means keywords appear together more than random
        final lift = pA > 0 && pB > 0 ? pAB / (pA * pB) : 0.0;

        // Skip if below minimum lift
        if (lift < minLift) continue;

        // Confidence: P(B|A) = P(A,B) / P(A)
        final confidence = pA > 0 ? pAB / pA : 0.0;

        coOccurrences.add(CoOccurrence(
          keywordA: keywordA,
          keywordB: keywordB,
          count: coOccurCount,
          lift: lift,
          confidence: confidence,
          weight: 0.0, // Will be normalized later
        ));
      }
    }

    // Normalize weights (0.0-1.0) based on lift
    return _normalizeWeights(coOccurrences);
  }

  /// Normalize weights to 0.0-1.0 range
  static List<CoOccurrence> _normalizeWeights(List<CoOccurrence> coOccurrences) {
    if (coOccurrences.isEmpty) return [];

    // Find max lift for normalization
    final maxLift = coOccurrences
        .map((c) => c.lift)
        .reduce((a, b) => a > b ? a : b);

    if (maxLift == 0) return coOccurrences;

    return coOccurrences.map((c) {
      // Normalize lift to 0-1, with some dampening for very high values
      final normalizedLift = math.min(1.0, c.lift / maxLift);

      // Weight is combination of normalized lift and confidence
      final weight = (normalizedLift * 0.7 + c.confidence * 0.3).clamp(0.0, 1.0);

      return CoOccurrence(
        keywordA: c.keywordA,
        keywordB: c.keywordB,
        count: c.count,
        lift: c.lift,
        confidence: c.confidence,
        weight: weight,
      );
    }).toList();
  }

  /// Build a co-occurrence matrix as a map
  /// Returns Map<String, Map<String, CoOccurrence>>
  /// Access like: matrix[keywordA][keywordB]
  static Map<String, Map<String, CoOccurrence>> buildMatrix(
    List<CoOccurrence> coOccurrences,
  ) {
    final matrix = <String, Map<String, CoOccurrence>>{};

    for (final coOcc in coOccurrences) {
      // Add bidirectional edges
      matrix[coOcc.keywordA] ??= {};
      matrix[coOcc.keywordA]![coOcc.keywordB] = coOcc;

      matrix[coOcc.keywordB] ??= {};
      matrix[coOcc.keywordB]![coOcc.keywordA] = coOcc;
    }

    return matrix;
  }

  /// Get neighbors (connected keywords) for a specific keyword
  static List<String> getNeighbors(
    String keyword,
    Map<String, Map<String, CoOccurrence>> matrix, {
    double minWeight = 0.3,
    int limit = 10,
  }) {
    if (!matrix.containsKey(keyword)) return [];

    final neighbors = matrix[keyword]!
        .entries
        .where((e) => e.value.weight >= minWeight)
        .toList()
      ..sort((a, b) => b.value.weight.compareTo(a.value.weight));

    return neighbors
        .take(limit)
        .map((e) => e.key)
        .toList();
  }

  /// Calculate clustering coefficient for a keyword
  /// Measures how connected a keyword's neighbors are to each other
  /// Returns value between 0.0 (no clustering) and 1.0 (fully clustered)
  static double calculateClusteringCoefficient(
    String keyword,
    Map<String, Map<String, CoOccurrence>> matrix,
  ) {
    final neighbors = getNeighbors(keyword, matrix, minWeight: 0.2, limit: 100);

    if (neighbors.length < 2) return 0.0;

    int connections = 0;
    int possibleConnections = 0;

    // Check connections between neighbors
    for (int i = 0; i < neighbors.length; i++) {
      for (int j = i + 1; j < neighbors.length; j++) {
        possibleConnections++;

        final neighborA = neighbors[i];
        final neighborB = neighbors[j];

        if (matrix[neighborA]?.containsKey(neighborB) ?? false) {
          connections++;
        }
      }
    }

    return possibleConnections > 0 ? connections / possibleConnections : 0.0;
  }

  /// Find strongly connected keywords (communities/clusters)
  /// Returns groups of keywords that are densely interconnected
  static List<List<String>> findClusters(
    Map<String, Map<String, CoOccurrence>> matrix, {
    double minWeight = 0.5,
    int minClusterSize = 3,
  }) {
    final clusters = <List<String>>[];
    final visited = <String>{};

    for (final keyword in matrix.keys) {
      if (visited.contains(keyword)) continue;

      // Start a new cluster with this keyword
      final cluster = _expandCluster(
        keyword,
        matrix,
        visited,
        minWeight: minWeight,
      );

      if (cluster.length >= minClusterSize) {
        clusters.add(cluster);
      }
    }

    return clusters;
  }

  /// Expand cluster using DFS from a starting keyword
  static List<String> _expandCluster(
    String startKeyword,
    Map<String, Map<String, CoOccurrence>> matrix,
    Set<String> visited, {
    required double minWeight,
  }) {
    final cluster = <String>[startKeyword];
    final queue = <String>[startKeyword];
    visited.add(startKeyword);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final neighbors = getNeighbors(current, matrix, minWeight: minWeight);

      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          cluster.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    return cluster;
  }

  /// Calculate PMI (Pointwise Mutual Information) for a keyword pair
  /// Alternative metric to lift for measuring association strength
  static double calculatePMI(
    String keywordA,
    String keywordB,
    List<Set<String>> documentKeywords,
  ) {
    final totalDocs = documentKeywords.length;

    int countA = 0;
    int countB = 0;
    int countAB = 0;

    for (final doc in documentKeywords) {
      if (doc.contains(keywordA)) countA++;
      if (doc.contains(keywordB)) countB++;
      if (doc.contains(keywordA) && doc.contains(keywordB)) countAB++;
    }

    if (countA == 0 || countB == 0 || countAB == 0) return 0.0;

    final pA = countA / totalDocs;
    final pB = countB / totalDocs;
    final pAB = countAB / totalDocs;

    // PMI = log(P(A,B) / (P(A) * P(B)))
    return math.log(pAB / (pA * pB));
  }
}
