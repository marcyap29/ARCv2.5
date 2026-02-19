// lib/services/chronicle_phase_signal_service.dart
//
// Derives phase scores from LUMARA CHRONICLE (patterns, causal chains, relationships)
// for use as a second signal fused with ATLAS in the RIVET sweep.

import 'package:my_app/models/phase_models.dart';
import 'package:my_app/chronicle/dual/services/dual_chronicle_services.dart';
import 'package:my_app/chronicle/dual/models/chronicle_models.dart';

/// Minimum number of Chronicle items (after optional time filter) to return scores.
/// Below this, returns null so caller keeps ATLAS-only behavior.
const int _minItemsForSignal = 2;

/// Chronicle phase signal: LUMARA patterns, causal chains, relationships → phase scores.
/// Used by RIVET sweep to fuse with ATLAS before [decidePhaseForEntry].
abstract final class ChroniclePhaseSignalService {
  /// Returns phase scores from LUMARA CHRONICLE for [userId], optionally limited to
  /// items whose timestamps overlap [segmentStart]–[segmentEnd].
  /// Returns null if Chronicle has no or very few items (ATLAS-only).
  static Future<Map<PhaseLabel, double>?> getPhaseScores(
    String userId, {
    DateTime? segmentStart,
    DateTime? segmentEnd,
  }) async {
    try {
      final repo = DualChronicleServices.lumaraChronicle;
      final patterns = await repo.loadPatterns(userId);
      final chains = await repo.loadCausalChains(userId);
      final relationships = await repo.loadRelationships(userId);

      final start = segmentStart;
      final end = segmentEnd;
      final hasWindow = start != null && end != null;

      // Optional filter by segment window
      final patternsInRange = hasWindow
          ? patterns.where((p) => _provenanceOverlaps(p.provenance, start, end))
          : patterns;
      final chainsInRange = hasWindow
          ? chains.where((c) => _inRange(c.lastObserved, start, end))
          : chains;
      final relsInRange = hasWindow
          ? relationships.where((r) => _inRange(r.lastMentioned, start, end))
          : relationships;

      final activePatterns = patternsInRange
          .where((p) => p.status == InferenceStatus.active)
          .toList();
      final activeChains = chainsInRange
          .where((c) => c.status == InferenceStatus.active)
          .toList();
      final activeRels = relsInRange
          .where((r) => r.status == InferenceStatus.active)
          .toList();

      final total = activePatterns.length + activeChains.length + activeRels.length;
      if (total < _minItemsForSignal) return null;

      final scores = _emptyScores();

      for (final p in activePatterns) {
        final text = '${p.description} ${p.category} ${p.recurrence}'.toLowerCase();
        _addScoresFromText(scores, text, 0.15 * (p.confidence.clamp(0.0, 1.0)));
      }
      for (final c in activeChains) {
        final text = '${c.trigger} ${c.response} ${c.resolution ?? ''}'.toLowerCase();
        _addScoresFromText(scores, text, 0.2 * (c.confidence.clamp(0.0, 1.0)));
      }
      for (final r in activeRels) {
        final text = '${r.interactionPattern} ${r.role}'.toLowerCase();
        _addScoresFromText(scores, text, 0.15 * (r.confidence.clamp(0.0, 1.0)));
      }

      _normalize(scores);
      return scores;
    } catch (_) {
      return null;
    }
  }

  static bool _inRange(DateTime t, DateTime start, DateTime end) {
    return !t.isBefore(start) && !t.isAfter(end);
  }

  static bool _provenanceOverlaps(Provenance p, DateTime start, DateTime end) {
    return _inRange(p.lastUpdated, start, end) ||
        _inRange(p.generatedAt, start, end);
  }

  static Map<PhaseLabel, double> _emptyScores() {
    return Map.fromEntries(
      PhaseLabel.values.map((e) => MapEntry(e, 0.1)),
    );
  }

  /// Add weighted phase scores from a single text blob (keyword heuristics aligned with ATLAS).
  static void _addScoresFromText(
    Map<PhaseLabel, double> scores,
    String lowerText,
    double weight,
  ) {
    // Discovery
    if (_matches(lowerText, ['new', 'discover', 'learn', 'explore', 'wonder', 'curious', '?'])) {
      scores[PhaseLabel.discovery] = scores[PhaseLabel.discovery]! + weight;
    }
    // Expansion
    if (_matches(lowerText, ['grow', 'expand', 'build', 'develop', 'progress', 'increase'])) {
      scores[PhaseLabel.expansion] = scores[PhaseLabel.expansion]! + weight;
    }
    // Transition
    if (_matches(lowerText, ['change', 'transition', 'shift', 'move', 'transform', 'adjust'])) {
      scores[PhaseLabel.transition] = scores[PhaseLabel.transition]! + weight;
    }
    // Consolidation
    if (_matches(lowerText, ['consolidate', 'stable', 'organize', 'integrate', 'strengthen', 'establish'])) {
      scores[PhaseLabel.consolidation] = scores[PhaseLabel.consolidation]! + weight;
    }
    // Recovery
    if (_matches(lowerText, ['recover', 'heal', 'rest', 'restore', 'repair', 'rejuvenate', 'feel', 'emotion', 'mood'])) {
      scores[PhaseLabel.recovery] = scores[PhaseLabel.recovery]! + weight;
    }
    // Breakthrough
    if (_matches(lowerText, ['breakthrough', 'insight', 'achieve', 'accomplish', 'realize', 'understand'])) {
      scores[PhaseLabel.breakthrough] = scores[PhaseLabel.breakthrough]! + weight;
    }
  }

  static bool _matches(String text, List<String> terms) {
    return terms.any((t) => text.contains(t));
  }

  static void _normalize(Map<PhaseLabel, double> scores) {
    final sum = scores.values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return;
    for (final k in scores.keys.toList()) {
      scores[k] = scores[k]! / sum;
    }
  }
}
