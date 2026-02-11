import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/aurora/reflection/aurora_reflection_service.dart';
import 'package:my_app/models/reflection_session.dart';
import 'package:my_app/repositories/reflection_session_repository.dart';
import 'package:my_app/arc/chat/models/lumara_reflection_options.dart' as models;
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/models/engagement_discipline.dart' show EngagementMode;
import 'enhanced_lumara_api.dart';

/// Response from reflection request.
class ReflectionResponse {
  final String text;
  final String? notice; // Level 1: shown but non-blocking
  final String? sessionId;
  final bool isPaused;
  final DateTime? pausedUntil;
  final List<AttributionTrace>? attributionTraces;

  ReflectionResponse.success({
    required this.text,
    this.notice,
    required this.sessionId,
    this.attributionTraces,
  })  : isPaused = false,
        pausedUntil = null;

  ReflectionResponse.intervention({
    required String message,
    required this.pausedUntil,
  })  : text = message,
        notice = null,
        sessionId = null,
        isPaused = true,
        attributionTraces = null;

  ReflectionResponse.paused({
    required String message,
    required DateTime resumeAt,
  })  : text = message,
        notice = null,
        sessionId = null,
        isPaused = true,
        pausedUntil = resumeAt,
        attributionTraces = null;
}

/// Handles reflection sessions with safety monitoring.
class ReflectionHandler {
  final ReflectionSessionRepository _sessionRepo;
  final JournalRepository _journalRepo;
  final AuroraReflectionService _aurora;
  final EnhancedLumaraApi _lumaraApi;

  ReflectionHandler({
    required ReflectionSessionRepository sessionRepo,
    required JournalRepository journalRepo,
    required AuroraReflectionService aurora,
    required EnhancedLumaraApi lumaraApi,
  })  : _sessionRepo = sessionRepo,
        _journalRepo = journalRepo,
        _aurora = aurora,
        _lumaraApi = lumaraApi;

  /// Handles reflection with optional session/AURORA when [entryId] is set.
  /// When [entryId] is null (e.g. voice, overview), skips session tracking and AURORA and calls LUMARA only.
  /// When [onStreamChunk] is set, response text is streamed to the callback as it arrives.
  Future<ReflectionResponse> handleReflectionRequest({
    required String userQuery,
    String? entryId,
    String? userId,
    String? sessionId,
    models.LumaraReflectionOptions? options,
    String? chatContext,
    String? mood,
    Map<String, dynamic>? chronoContext,
    String? mediaContext,
    bool forceQuickResponse = false,
    bool skipHeavyProcessing = false,
    EngagementMode? voiceEngagementModeOverride,
    void Function(String message)? onProgress,
    void Function(String chunk)? onStreamChunk,
  }) async {
    final effectiveUserId = userId ?? '';

    // Pass-through when no entry (voice, overview, etc.): no session, no AURORA
    if (entryId == null || entryId.isEmpty) {
      final request = models.LumaraReflectionRequest(
        userText: userQuery,
        entryType: models.EntryType.journal,
        priorKeywords: [],
        matchedNodeHints: [],
        mediaCandidates: [],
        options: options ?? models.LumaraReflectionOptions(),
      );
      final result = await _lumaraApi.generatePromptedReflectionV23(
        request: request,
        userId: effectiveUserId.isEmpty ? null : effectiveUserId,
        mood: mood,
        chronoContext: chronoContext,
        chatContext: chatContext,
        mediaContext: mediaContext,
        entryId: null,
        forceQuickResponse: forceQuickResponse,
        skipHeavyProcessing: skipHeavyProcessing,
        voiceEngagementModeOverride: voiceEngagementModeOverride,
        onProgress: onProgress,
        onStreamChunk: onStreamChunk,
      );
      return ReflectionResponse.success(
        text: result.reflection,
        sessionId: null,
        attributionTraces: result.attributionTraces,
      );
    }

    // 1. Load or create session (key by entryId)
    var session = await _sessionRepo.getActiveSession(entryId);
    if (session == null) {
      session = ReflectionSession.create(userId: effectiveUserId, entryId: entryId);
      await _sessionRepo.putSession(session);
    }

    if (session.isPaused) {
      final remaining = session.pausedUntil!.difference(DateTime.now());
      return ReflectionResponse.paused(
        message:
            'Reflection paused. Available in ${remaining.inMinutes} minutes.',
        resumeAt: session.pausedUntil!,
      );
    }

    // 2. Get entry for AURORA assessment
    final entry = await _journalRepo.getJournalEntryById(entryId);
    if (entry == null) {
      throw Exception('Entry not found: $entryId');
    }

    // 3. Check AURORA for intervention
    final intervention =
        await _aurora.assessReflectionRisk(entry, session);

    if (intervention?.shouldPause == true) {
      await _sessionRepo.pauseSession(session.id, intervention!.duration!);
      return ReflectionResponse.intervention(
        message: intervention.message,
        pausedUntil: DateTime.now().add(intervention.duration!),
      );
    }

    // 4. Process with LUMARA (existing API)
    final request = models.LumaraReflectionRequest(
      userText: userQuery,
      entryType: models.EntryType.journal,
      priorKeywords: [],
      matchedNodeHints: [],
      mediaCandidates: [],
      options: options ?? models.LumaraReflectionOptions(),
    );

    final result = await _lumaraApi.generatePromptedReflectionV23(
      request: request,
      userId: effectiveUserId.isEmpty ? null : effectiveUserId,
      entryId: entryId,
      onProgress: onProgress,
      onStreamChunk: onStreamChunk,
    );

    final lumaraResponse = result.reflection;

    // 5. Detect CHRONICLE usage
    final citedChronicle = _checkForChronicleUsage(lumaraResponse);

    // 6. Track exchange
    session.exchanges.add(ReflectionExchange(
      timestamp: DateTime.now(),
      userQuery: userQuery,
      lumaraResponse: lumaraResponse,
      citedChronicle: citedChronicle,
    ));

    await _sessionRepo.saveSession(session);

    return ReflectionResponse.success(
      text: lumaraResponse,
      notice: intervention?.message,
      sessionId: session.id,
      attributionTraces: result.attributionTraces,
    );
  }

  bool _checkForChronicleUsage(String responseText) {
    const chronicleMarkers = [
      'chronicle shows',
      'your entries from',
      'pattern across',
      'looking at your',
      'aggregation shows',
      'monthly aggregation',
      'yearly aggregation',
    ];

    final lower = responseText.toLowerCase();
    return chronicleMarkers.any((marker) => lower.contains(marker));
  }
}
