// lib/chronicle/dual/services/chronicle_query_adapter.dart
//
// Adapter that provides UserChronicleLayer0Result-shaped data from the user's CHRONICLE
// (Layer 0) and LUMARA CHRONICLE (promoted gap-fill events as "annotations").
// Replaces reading from the separate User Chronicle store.
// User's CHRONICLE is SACRED; annotations come from LUMARA CHRONICLE promoted items.

import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/dual/models/chronicle_models.dart';
import 'package:my_app/chronicle/dual/repositories/lumara_chronicle_repository.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';

/// Provides entries from the user's CHRONICLE Layer 0 and annotations from LUMARA CHRONICLE
/// (promoted gap-fill events). Used by agentic loop, intelligence summary, and gap analyzer.
class ChronicleQueryAdapter {
  ChronicleQueryAdapter({
    Layer0Repository? layer0Repo,
    LumaraChronicleRepository? lumaraRepo,
    Future<List<UserEntry>> Function(String userId)? loadEntriesOverride,
  })  : _layer0 = layer0Repo ?? ChronicleRepos.layer0,
        _lumaraRepo = lumaraRepo ?? LumaraChronicleRepository(),
        _loadEntriesOverride = loadEntriesOverride;

  final Layer0Repository _layer0;
  final LumaraChronicleRepository _lumaraRepo;
  final Future<List<UserEntry>> Function(String userId)? _loadEntriesOverride;

  static const int _maxEntriesForLoad = 2000;

  /// Load all Layer 0 entries for [userId] from CHRONICLE (sorted newest first).
  Future<List<UserEntry>> loadEntries(String userId) async {
    if (_loadEntriesOverride != null) return _loadEntriesOverride!(userId);
    await _layer0.initialize();
    final raw = await _layer0.getRecentEntries(userId, _maxEntriesForLoad);
    return raw.map(_rawToUserEntry).toList();
  }

  /// Load all user-approved "annotations" from LUMARA CHRONICLE (promoted gap-fill events).
  Future<List<UserAnnotation>> loadAnnotations(String userId) async {
    final events = await _lumaraRepo.loadGapFillEvents(userId);
    final promoted = events.where((e) => e.promotedToAnnotation != null).toList();
    promoted.sort((a, b) {
      final at = a.promotedToAnnotation!.promotedAt;
      final bt = b.promotedToAnnotation!.promotedAt;
      return bt.compareTo(at);
    });
    return promoted.map(_gapFillToAnnotation).toList();
  }

  /// Query Layer 0 entries and promoted annotations, optionally filtered by [query].
  Future<UserChronicleLayer0Result> queryLayer0(String userId, String query) async {
    final entries = await loadEntries(userId);
    final annotations = await loadAnnotations(userId);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return UserChronicleLayer0Result(entries: entries, annotations: annotations);
    }
    final relevantEntries = entries.where((e) =>
        e.content.toLowerCase().contains(q) ||
        (e.extractedKeywords?.any((k) => k.toLowerCase().contains(q)) ?? false) ||
        (e.thematicTags?.any((t) => t.toLowerCase().contains(q)) ?? false)).toList();
    final relevantAnnotations = annotations
        .where((a) => a.content.toLowerCase().contains(q))
        .toList();
    return UserChronicleLayer0Result(
      entries: relevantEntries,
      annotations: relevantAnnotations,
    );
  }

  UserEntry _rawToUserEntry(dynamic raw) {
    // ChronicleRawEntry from Layer0Repository
    final id = raw.entryId as String;
    final timestamp = raw.timestamp as DateTime;
    final content = raw.content as String;
    final analysis = raw.analysis as Map<String, dynamic>? ?? {};
    final metadata = raw.metadata as Map<String, dynamic>? ?? {};
    final keywords = analysis['keywords'] as List?;
    final extractedThemes = analysis['extracted_themes'] as List?;
    final entryType = analysis['entry_type'] as String?;
    final voiceTranscribed = metadata['voice_transcribed'] == true;
    UserEntryModality modality = UserEntryModality.reflect;
    if (voiceTranscribed) {
      modality = UserEntryModality.voice;
    } else if (entryType == 'decision') {
      modality = UserEntryModality.reflect;
    }
    final type = modality == UserEntryModality.voice
        ? UserEntryType.voice
        : (modality == UserEntryModality.chat ? UserEntryType.chat : UserEntryType.reflect);
    return UserEntry(
      id: id,
      timestamp: timestamp,
      type: type,
      content: content,
      modality: modality,
      extractedKeywords: keywords != null ? List<String>.from(keywords) : null,
      thematicTags: extractedThemes != null ? List<String>.from(extractedThemes) : null,
      authoredBy: 'user',
    );
  }

  UserAnnotation _gapFillToAnnotation(GapFillEvent e) {
    final prom = e.promotedToAnnotation!;
    final content = _annotationContentFromGapFill(e);
    return UserAnnotation(
      id: prom.annotationId,
      timestamp: prom.promotedAt,
      content: content,
      source: AnnotationSource.lumara_gap_fill,
      provenance: UserAnnotationProvenance(
        gapFillEventId: e.id,
        userApproved: true,
        approvedAt: prom.promotedAt,
      ),
      editable: true,
    );
  }

  String _annotationContentFromGapFill(GapFillEvent event) {
    final s = event.extractedSignal;
    if (s.causalChain != null) {
      final c = s.causalChain!;
      return '${c.trigger} → ${c.response}';
    }
    if (s.pattern != null) return s.pattern!.description;
    if (s.relationship != null) {
      return '${s.relationship!.entity} — ${s.relationship!.role}';
    }
    if (s.value != null) return s.value!.value;
    return event.trigger.identifiedGap.description;
  }
}
