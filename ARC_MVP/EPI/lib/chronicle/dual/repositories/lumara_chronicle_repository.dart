// lib/chronicle/dual/repositories/lumara_chronicle_repository.dart
//
// LUMARA'S CHRONICLE - LEARNING SPACE
//
// System writes freely here. This is where gap-fill events, inferences, and gaps
// are stored. User's Chronicle is never written to from this repository.

import 'dart:convert';
import '../models/chronicle_models.dart';
import '../storage/chronicle_storage.dart';

class LumaraChronicleRepository {
  LumaraChronicleRepository([ChronicleStorage? storage])
      : _storage = storage ?? ChronicleStorage();

  final ChronicleStorage _storage;

  static const String _gapFills = 'gap-fills';
  static const String _gaps = 'gaps';
  static const String _causalChains = 'inferences/causal_chains';
  static const String _patterns = 'inferences/patterns';
  static const String _relationships = 'inferences/relationships';
  static const String _learningTriggersFile = 'learning_triggers.json';
  static const int _maxLearningTriggers = 50;

  /// Default window (days) after which causal chains fade from context/summary.
  /// Chains with lastObserved older than this are excluded from synthesis and prompts.
  static const int defaultCausalChainFadeDays = 180;

  /// Default window (days) after which learning moments (gap-fill events) fade from context/summary.
  static const int defaultGapFillFadeDays = 180;

  /// Record gap-fill event (learning moment).
  Future<void> addGapFillEvent(String userId, GapFillEvent event) async {
    final subPath = '$_gapFills/${event.id}.json';
    await _storage.saveLumaraChronicle(userId, subPath, event.toJson());
    print('[LumaraChronicle] Gap-fill event recorded: ${event.id}');
    print('[LumaraChronicle] Promotable: ${event.promotableToAnnotation}');
  }

  /// Get a single gap-fill event by ID.
  Future<GapFillEvent?> getGapFillEvent(String userId, String eventId) async {
    final subPath = '$_gapFills/$eventId.json';
    final json = await _storage.loadLumaraChronicle(userId, subPath);
    if (json == null) return null;
    try {
      return GapFillEvent.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Update gap-fill event (e.g. mark as promoted).
  Future<void> updateGapFillEvent(
    String userId,
    String eventId,
    GapFillEvent updated,
  ) async {
    final subPath = '$_gapFills/$eventId.json';
    await _storage.saveLumaraChronicle(userId, subPath, updated.toJson());
    print('[LumaraChronicle] Gap-fill event updated: $eventId');
  }

  /// Add inference (causal chain).
  Future<void> addCausalChain(String userId, CausalChain inference) async {
    final subPath = '$_causalChains/${inference.id}.json';
    await _storage.saveLumaraChronicle(userId, subPath, inference.toJson());
    print('[LumaraChronicle] Inference added: causal_chain/${inference.id}');
  }

  /// Add pattern inference.
  Future<void> addPattern(String userId, Pattern inference) async {
    final subPath = '$_patterns/${inference.id}.json';
    await _storage.saveLumaraChronicle(userId, subPath, inference.toJson());
    print('[LumaraChronicle] Inference added: pattern/${inference.id}');
  }

  /// Add relationship inference.
  Future<void> addRelationship(String userId, RelationshipModel inference) async {
    final subPath = '$_relationships/${inference.entityId}.json';
    await _storage.saveLumaraChronicle(userId, subPath, inference.toJson());
    print('[LumaraChronicle] Inference added: relationship/${inference.entityId}');
  }

  /// Add identified gap.
  Future<void> addGap(String userId, Gap gap) async {
    final subPath = '$_gaps/${gap.id}.json';
    await _storage.saveLumaraChronicle(userId, subPath, gap.toJson());
    print('[LumaraChronicle] Gap identified: ${gap.type.name} - ${gap.description}');
  }

  /// Get gap by ID.
  Future<Gap?> getGap(String userId, String gapId) async {
    final subPath = '$_gaps/$gapId.json';
    final json = await _storage.loadLumaraChronicle(userId, subPath);
    if (json == null) return null;
    try {
      return Gap.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Update gap (e.g. status to filled).
  Future<void> updateGap(String userId, String gapId, Gap updated) async {
    final subPath = '$_gaps/$gapId.json';
    await _storage.saveLumaraChronicle(userId, subPath, updated.toJson());
  }

  /// Load causal chains for user. If [activeAfter] is set, only chains with
  /// lastObserved >= activeAfter are returned (gradual fade from memory).
  /// Pass null for export or when you need all (e.g. reinforcing existing chain).
  Future<List<CausalChain>> loadCausalChains(
    String userId, {
    DateTime? activeAfter,
  }) async {
    final dir = await _storage.getLumaraChronicleDir(userId, _causalChains);
    final files = await _storage.listJsonFiles(dir);
    final list = <CausalChain>[];
    for (final file in files) {
      final json = _tryDecode(await file.readAsString());
      if (json != null) {
        try {
          final c = CausalChain.fromJson(json);
          if (activeAfter == null || !c.lastObserved.isBefore(activeAfter)) {
            list.add(c);
          }
        } catch (_) {}
      }
    }
    return list;
  }

  /// Load all patterns for user.
  Future<List<Pattern>> loadPatterns(String userId) async {
    final dir = await _storage.getLumaraChronicleDir(userId, _patterns);
    final files = await _storage.listJsonFiles(dir);
    final list = <Pattern>[];
    for (final file in files) {
      final json = _tryDecode(await file.readAsString());
      if (json != null) {
        try {
          list.add(Pattern.fromJson(json));
        } catch (_) {}
      }
    }
    return list;
  }

  /// Load all relationship models for user.
  Future<List<RelationshipModel>> loadRelationships(String userId) async {
    final dir = await _storage.getLumaraChronicleDir(userId, _relationships);
    final files = await _storage.listJsonFiles(dir);
    final list = <RelationshipModel>[];
    for (final file in files) {
      final json = _tryDecode(await file.readAsString());
      if (json != null) {
        try {
          list.add(RelationshipModel.fromJson(json));
        } catch (_) {}
      }
    }
    return list;
  }

  /// Record that learning was triggered (agentic loop ran). Keeps last [_maxLearningTriggers].
  Future<void> recordLearningTrigger(
    String userId,
    String modality, {
    String? sourceSummary,
  }) async {
    final record = LearningTriggerRecord(
      at: DateTime.now().toUtc(),
      modality: modality,
      sourceSummary: sourceSummary,
    );
    final list = await loadRecentLearningTriggers(userId, limit: _maxLearningTriggers);
    list.insert(0, record);
    final capped = list.take(_maxLearningTriggers).toList();
    final data = {'triggers': capped.map((e) => e.toJson()).toList()};
    await _storage.saveLumaraChronicle(userId, _learningTriggersFile, data);
  }

  /// Load recent learning triggers (newest first).
  Future<List<LearningTriggerRecord>> loadRecentLearningTriggers(
    String userId, {
    int limit = 20,
  }) async {
    final json = await _storage.loadLumaraChronicle(userId, _learningTriggersFile);
    if (json == null) return [];
    final list = json['triggers'] as List?;
    if (list == null) return [];
    final records = <LearningTriggerRecord>[];
    for (final e in list) {
      if (e is Map) {
        try {
          records.add(LearningTriggerRecord.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    return records.take(limit).toList();
  }

  /// Load gap-fill events (learning moments) for user. If [activeAfter] is set,
  /// only events with recordedAt >= activeAfter are returned (gradual fade).
  /// Pass null for export or when you need all (e.g. promoted annotations).
  Future<List<GapFillEvent>> loadGapFillEvents(
    String userId, {
    DateTime? activeAfter,
  }) async {
    final dir = await _storage.getLumaraChronicleDir(userId, _gapFills);
    final files = await _storage.listJsonFiles(dir);
    final list = <GapFillEvent>[];
    for (final file in files) {
      final json = _tryDecode(await file.readAsString());
      if (json != null) {
        try {
          final e = GapFillEvent.fromJson(json);
          if (activeAfter == null || !e.recordedAt.isBefore(activeAfter)) {
            list.add(e);
          }
        } catch (_) {}
      }
    }
    list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return list;
  }

  /// Load all gaps for user.
  Future<List<Gap>> loadGaps(String userId) async {
    final dir = await _storage.getLumaraChronicleDir(userId, _gaps);
    final files = await _storage.listJsonFiles(dir);
    final list = <Gap>[];
    for (final file in files) {
      final json = _tryDecode(await file.readAsString());
      if (json != null) {
        try {
          list.add(Gap.fromJson(json));
        } catch (_) {}
      }
    }
    return list;
  }

  /// Query inferences by topic. Pass [activeAfter] to restrict to recent
  /// causal chains (fade); patterns/relationships are unfaded.
  Future<LumaraInferredResult> queryInferences(
    String userId,
    String query, {
    DateTime? activeAfter,
  }) async {
    final causalChains = await loadCausalChains(userId, activeAfter: activeAfter);
    final patterns = await loadPatterns(userId);
    final relationships = await loadRelationships(userId);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return LumaraInferredResult(
        causalChains: causalChains,
        patterns: patterns,
        relationships: relationships,
      );
    }
    bool match(String text) =>
        text.toLowerCase().contains(q);
    return LumaraInferredResult(
      causalChains: causalChains
          .where((c) =>
              c.status == InferenceStatus.active &&
              (match(c.trigger) || match(c.response)))
          .toList(),
      patterns: patterns
          .where((p) =>
              p.status == InferenceStatus.active && match(p.description))
          .toList(),
      relationships: relationships
          .where((r) =>
              r.status == InferenceStatus.active &&
              (match(r.entityName) || match(r.role)))
          .toList(),
    );
  }

  /// Get inference by ID (search across causal, pattern, relationship).
  Future<CausalChain?> getCausalChainById(String userId, String inferenceId) async {
    final subPath = '$_causalChains/$inferenceId.json';
    final json = await _storage.loadLumaraChronicle(userId, subPath);
    if (json == null) return null;
    try {
      return CausalChain.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<Pattern?> getPatternById(String userId, String inferenceId) async {
    final subPath = '$_patterns/$inferenceId.json';
    final json = await _storage.loadLumaraChronicle(userId, subPath);
    if (json == null) return null;
    try {
      return Pattern.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Update causal chain (e.g. after user correct/refine/reject).
  Future<void> updateCausalChain(String userId, String inferenceId, CausalChain updated) async {
    final subPath = '$_causalChains/$inferenceId.json';
    await _storage.saveLumaraChronicle(userId, subPath, updated.toJson());
  }

  /// Update pattern.
  Future<void> updatePattern(String userId, String inferenceId, Pattern updated) async {
    final subPath = '$_patterns/$inferenceId.json';
    await _storage.saveLumaraChronicle(userId, subPath, updated.toJson());
  }

  /// Update relationship.
  Future<void> updateRelationship(String userId, String entityId, RelationshipModel updated) async {
    final subPath = '$_relationships/$entityId.json';
    await _storage.saveLumaraChronicle(userId, subPath, updated.toJson());
  }

  Map<String, dynamic>? _tryDecode(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}

/// Result of querying LUMARA inferred intelligence.
class LumaraInferredResult {
  final List<CausalChain> causalChains;
  final List<Pattern> patterns;
  final List<RelationshipModel> relationships;

  LumaraInferredResult({
    required this.causalChains,
    required this.patterns,
    required this.relationships,
  });
}
