/// Integration Tests for AURORA Circadian Integration
/// 
/// Tests the complete integration of AURORA with VEIL-EDGE and LUMARA

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/aurora/services/circadian_profile_service.dart';
import '../../lib/aurora/models/circadian_context.dart';
import '../../lib/lumara/veil_edge/services/veil_edge_service.dart';
import '../../lib/lumara/veil_edge/models/veil_edge_models.dart';
import '../../lib/lumara/veil_edge/integration/lumara_veil_edge_integration.dart';
import '../../lib/lumara/chat/chat_repo.dart';
import '../../lib/lumara/chat/chat_models.dart';
import '../../lib/models/journal_entry_model.dart';

void main() {
  group('AURORA Integration Tests', () {
    late CircadianProfileService auroraService;
    late VeilEdgeService veilEdgeService;
    late LumaraVeilEdgeIntegration integration;

    setUp(() {
      auroraService = CircadianProfileService();
      veilEdgeService = VeilEdgeService();
      integration = LumaraVeilEdgeIntegration(
        chatRepo: MockChatRepo(),
        veilEdgeService: veilEdgeService,
      );
    });

    group('end-to-end circadian routing', () {
      test('should route morning person in morning with enhanced alignment', () async {
        // Create morning person journal entries
        final entries = [
          _createJournalEntry(hour: 7),
          _createJournalEntry(hour: 8),
          _createJournalEntry(hour: 9),
          _createJournalEntry(hour: 10),
        ];

        // Compute circadian context
        final circadianContext = await auroraService.compute(entries);
        expect(circadianContext.chronotype, 'morning');
        expect(circadianContext.window, isIn(['morning', 'afternoon', 'evening']));

        // Create VEIL-EDGE input
        final input = VeilEdgeInput(
          atlas: AtlasState(
            phase: 'Discovery',
            confidence: 0.8,
            neighbor: 'Breakthrough',
          ),
          rivet: RivetState(
            align: 0.7,
            stability: 0.6,
            windowDays: 7,
            lastSwitchTimestamp: DateTime.now().subtract(const Duration(hours: 50)),
          ),
          sentinel: SentinelState(state: 'ok'),
          signals: SignalExtraction(
            signals: UserSignals(
              actions: ['explore'],
              feelings: ['curious'],
              words: ['discovery', 'new', 'possibilities'],
              outcomes: ['learning'],
            ),
          ),
          circadianWindow: circadianContext.window,
          circadianChronotype: circadianContext.chronotype,
          rhythmScore: circadianContext.rhythmScore,
        );

        // Route through VEIL-EDGE
        final result = veilEdgeService.routeWithCircadian(
          signals: input.signals.signals,
          atlas: input.atlas,
          sentinel: input.sentinel,
          rivet: input.rivet,
          circadianContext: circadianContext,
        );

        expect(result.phaseGroup, 'D-B');
        expect(result.blocks, contains('Mirror'));
        expect(result.blocks, contains('Log'));
        expect(result.metadata['circadian_window'], circadianContext.window);
        expect(result.metadata['circadian_chronotype'], circadianContext.chronotype);
      });

      test('should route evening person with fragmented rhythm conservatively', () async {
        // Create scattered journal entries (fragmented rhythm)
        final entries = [
          _createJournalEntry(hour: 6),
          _createJournalEntry(hour: 12),
          _createJournalEntry(hour: 18),
          _createJournalEntry(hour: 22),
        ];

        // Compute circadian context
        final circadianContext = await auroraService.compute(entries);
        expect(circadianContext.rhythmScore < 0.45, true);

        // Create VEIL-EDGE input for evening
        final input = VeilEdgeInput(
          atlas: AtlasState(
            phase: 'Recovery',
            confidence: 0.7,
            neighbor: 'Transition',
          ),
          rivet: RivetState(
            align: 0.5,
            stability: 0.4,
            windowDays: 7,
            lastSwitchTimestamp: DateTime.now().subtract(const Duration(hours: 50)),
          ),
          sentinel: SentinelState(state: 'ok'),
          signals: SignalExtraction(
            signals: UserSignals(
              actions: ['rest'],
              feelings: ['tired'],
              words: ['recovery', 'rest', 'restore'],
              outcomes: ['renewal'],
            ),
          ),
          circadianWindow: 'evening',
          circadianChronotype: circadianContext.chronotype,
          rhythmScore: circadianContext.rhythmScore,
        );

        // Route through VEIL-EDGE
        final result = veilEdgeService.routeWithCircadian(
          signals: input.signals.signals,
          atlas: input.atlas,
          sentinel: input.sentinel,
          rivet: input.rivet,
          circadianContext: circadianContext,
        );

        expect(result.phaseGroup, 'R-T');
        expect(result.blocks, contains('Mirror'));
        expect(result.blocks, contains('Safeguard'));
        expect(result.blocks, contains('Log'));
        // Commit should be reduced or removed due to fragmented evening rhythm
        expect(result.blocks, isNot(contains('Commit')));
      });

      test('should generate circadian-aware LUMARA responses', () async {
        // Create morning entries
        final entries = [
          _createJournalEntry(hour: 8),
          _createJournalEntry(hour: 9),
          _createJournalEntry(hour: 10),
        ];

        // Process message through integration
        final chatMessage = await integration.processMessage(
          sessionId: 'test_session',
          userMessage: 'I want to explore new possibilities today',
          context: {
            'atlas_phase': 'Discovery',
            'atlas_confidence': 0.8,
            'atlas_neighbor': 'Breakthrough',
            'sentinel_state': 'ok',
            'sentinel_notes': [],
          },
        );

        expect(chatMessage.role, 'assistant');
        expect(chatMessage.provenance, contains('aurora'));
        if (chatMessage.provenance != null) {
          final provenanceMap = jsonDecode(chatMessage.provenance!) as Map<String, dynamic>?;
          if (provenanceMap != null) {
            final aurora = provenanceMap['aurora'] as Map<String, dynamic>?;
            if (aurora != null) {
              expect(aurora.keys, contains('circadian_window'));
              expect(aurora.keys, contains('chronotype'));
              expect(aurora.keys, contains('rhythm_score'));
            }
          }
        }
      });
    });

    group('circadian profile analysis', () {
      test('should analyze chronotype from journal timestamps', () async {
        // Morning person entries
        final morningEntries = [
          _createJournalEntry(hour: 6),
          _createJournalEntry(hour: 7),
          _createJournalEntry(hour: 8),
          _createJournalEntry(hour: 9),
          _createJournalEntry(hour: 10),
        ];

        final morningProfile = await auroraService.computeProfile(morningEntries);
        expect(morningProfile.chronotype, 'morning');
        expect(morningProfile.peakHour, lessThan(11));
        expect(morningProfile.isReliable, true);

        // Evening person entries
        final eveningEntries = [
          _createJournalEntry(hour: 18),
          _createJournalEntry(hour: 19),
          _createJournalEntry(hour: 20),
          _createJournalEntry(hour: 21),
          _createJournalEntry(hour: 22),
        ];

        final eveningProfile = await auroraService.computeProfile(eveningEntries);
        expect(eveningProfile.chronotype, 'evening');
        expect(eveningProfile.peakHour, greaterThan(17));
        expect(eveningProfile.isReliable, true);
      });

      test('should calculate rhythm coherence scores', () async {
        // Concentrated activity (high coherence)
        final concentratedEntries = List.generate(10, (i) => _createJournalEntry(hour: 14));
        final concentratedProfile = await auroraService.computeProfile(concentratedEntries);
        expect(concentratedProfile.rhythmScore, greaterThan(0.7));

        // Scattered activity (low coherence)
        final scatteredEntries = [
          _createJournalEntry(hour: 6),
          _createJournalEntry(hour: 12),
          _createJournalEntry(hour: 18),
          _createJournalEntry(hour: 22),
        ];
        final scatteredProfile = await auroraService.computeProfile(scatteredEntries);
        expect(scatteredProfile.rhythmScore, lessThan(0.5));
      });

      test('should provide circadian descriptions', () {
        expect(auroraService.getChronotypeDescription('morning'), 
               contains('Morning person'));
        expect(auroraService.getChronotypeDescription('evening'), 
               contains('Evening person'));
        expect(auroraService.getChronotypeDescription('balanced'), 
               contains('Balanced chronotype'));

        expect(auroraService.getWindowDescription('morning'), 
               contains('Morning window'));
        expect(auroraService.getWindowDescription('afternoon'), 
               contains('Afternoon window'));
        expect(auroraService.getWindowDescription('evening'), 
               contains('Evening window'));
      });
    });

    group('VEIL-EDGE service integration', () {
      test('should provide circadian context in status', () async {
        final status = await veilEdgeService.getStatus();

        expect(status, contains('circadian_context'));
        expect(status, contains('circadian_data_sufficient'));
        expect(status, contains('aurora_integration'));
        expect(status['aurora_integration'], true);
      });

      test('should generate prompts with circadian guidance', () async {
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'morning',
          rhythmScore: 0.8,
        );

        final routeResult = VeilEdgeRouteResult(
          phaseGroup: 'D-B',
          variant: '',
          blocks: ['Mirror', 'Orient', 'Log'],
        );

        final signals = UserSignals(
          actions: ['explore'],
          feelings: ['curious'],
          words: ['discovery'],
          outcomes: ['learning'],
        );

        final prompt = veilEdgeService.generatePromptWithCircadian(
          routeResult: routeResult,
          signals: signals,
          circadianContext: circadianContext,
        );

        expect(prompt, contains('Time Guidance'));
        expect(prompt, contains('Keep it clear and energizing'));
      });
    });
  });
}

/// Mock ChatRepo for testing
class MockChatRepo implements ChatRepo {
  final List<Map<String, dynamic>> _messages = [];

  @override
  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    _messages.add({
      'sessionId': sessionId,
      'role': role,
      'content': content,
    });
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId, {bool lazy = false}) async {
    return _messages.where((msg) => msg['sessionId'] == sessionId).map((msg) => 
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: sessionId,
        role: msg['role'] as String,
        textContent: msg['content'] as String,
        createdAt: DateTime.now(),
      )
    ).toList();
  }

  @override
  Future<void> clearMessages(String sessionId) async {
    _messages.removeWhere((msg) => msg['sessionId'] == sessionId);
  }

  // Implement other required methods as no-ops for testing
  @override
  Future<void> addTags(String sessionId, List<String> tags) async {}

  @override
  Future<void> archiveSession(String sessionId, bool archive) async {}

  @override
  Future<void> close() async {}

  @override
  Future<String> createSession({required String subject, List<String>? tags}) async => 'test_session';

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> deleteSessions(List<String> sessionIds) async {}

  @override
  Future<Map<String, int>> getStats() async => {};

  @override
  Future<List<ChatSession>> listActive({String? query}) async => [];

  @override
  Future<List<ChatSession>> listArchived({String? query}) async => [];

  @override
  Future<List<ChatSession>> listAll({bool includeArchived = true}) async => [];

  @override
  Future<ChatSession?> getSession(String sessionId) async => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pinSession(String sessionId, bool pin) async {}

  @override
  Future<void> pruneByPolicy({Duration maxAge = const Duration(days: 30)}) async {}

  @override
  Future<void> removeTags(String sessionId, List<String> tags) async {}

  @override
  Future<void> renameSession(String sessionId, String subject) async {}
}

/// Helper function to create a journal entry with a specific hour
JournalEntry _createJournalEntry({required int hour}) {
  final now = DateTime.now();
  final entryTime = DateTime(now.year, now.month, now.day, hour);
  
  return JournalEntry(
    id: 'test_${hour}_${DateTime.now().millisecondsSinceEpoch}',
    title: 'Test Entry',
    content: 'Test content for hour $hour',
    createdAt: entryTime,
    updatedAt: entryTime,
    tags: [],
    mood: 'neutral',
    audioUri: null,
    media: [],
    sageAnnotation: null,
    keywords: [],
    emotion: null,
    emotionReason: null,
    metadata: null,
  );
}
