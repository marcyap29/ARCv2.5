import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_app/features/atlas/phase_history_repository.dart';

void main() {
  group('PhaseHistoryRepository', () {
    setUpAll(() async {
      // Initialize Hive for testing
      Hive.init('test_data');
    });

    tearDownAll(() async {
      // Clean up after tests
      await Hive.close();
    });
    late PhaseHistoryEntry testEntry1;
    late PhaseHistoryEntry testEntry2;

    setUp(() {
      testEntry1 = PhaseHistoryEntry(
        id: 'test-1',
        timestamp: DateTime(2024, 1, 1),
        phaseScores: {
          'Discovery': 0.8,
          'Expansion': 0.2,
          'Transition': 0.1,
          'Consolidation': 0.3,
          'Recovery': 0.1,
          'Breakthrough': 0.2,
        },
        journalEntryId: 'journal-1',
        emotion: 'excited',
        reason: 'learning',
        text: 'I am excited to learn new things',
      );

      testEntry2 = PhaseHistoryEntry(
        id: 'test-2',
        timestamp: DateTime(2024, 1, 2),
        phaseScores: {
          'Discovery': 0.3,
          'Expansion': 0.7,
          'Transition': 0.2,
          'Consolidation': 0.4,
          'Recovery': 0.1,
          'Breakthrough': 0.1,
        },
        journalEntryId: 'journal-2',
        emotion: 'happy',
        reason: 'work',
        text: 'I feel great about my progress',
      );
    });

    test('PhaseHistoryEntry should serialize and deserialize correctly', () {
      final json = testEntry1.toJson();
      final deserialized = PhaseHistoryEntry.fromJson(json);
      
      expect(deserialized.id, equals(testEntry1.id));
      expect(deserialized.timestamp, equals(testEntry1.timestamp));
      expect(deserialized.phaseScores, equals(testEntry1.phaseScores));
      expect(deserialized.journalEntryId, equals(testEntry1.journalEntryId));
      expect(deserialized.emotion, equals(testEntry1.emotion));
      expect(deserialized.reason, equals(testEntry1.reason));
      expect(deserialized.text, equals(testEntry1.text));
    });

    test('PhaseHistoryEntry equality should work correctly', () {
      final entry1 = PhaseHistoryEntry(
        id: 'same-id',
        timestamp: DateTime.now(),
        phaseScores: {'Discovery': 0.5},
        journalEntryId: 'journal-1',
        emotion: 'happy',
        reason: 'work',
        text: 'test',
      );

      final entry2 = PhaseHistoryEntry(
        id: 'same-id',
        timestamp: DateTime.now().add(const Duration(hours: 1)),
        phaseScores: {'Discovery': 0.8},
        journalEntryId: 'journal-2',
        emotion: 'sad',
        reason: 'family',
        text: 'different',
      );

      expect(entry1, equals(entry2));
      expect(entry1.hashCode, equals(entry2.hashCode));
    });

    test('PhaseHistoryRepository should handle empty state', () async {
      await PhaseHistoryRepository.clearAll();
      
      final entries = await PhaseHistoryRepository.getAllEntries();
      expect(entries, isEmpty);
      
      final count = await PhaseHistoryRepository.getEntryCount();
      expect(count, equals(0));
      
      final hasData = await PhaseHistoryRepository.hasData();
      expect(hasData, isFalse);
    });

    test('PhaseHistoryRepository should add and retrieve entries', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final entries = await PhaseHistoryRepository.getAllEntries();
      expect(entries.length, equals(2));
      expect(entries.first.id, equals(testEntry1.id)); // Should be sorted by timestamp
      expect(entries.last.id, equals(testEntry2.id));
    });

    test('PhaseHistoryRepository should get entries in time range', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 1, 23, 59, 59);
      
      final entries = await PhaseHistoryRepository.getEntriesInRange(start, end);
      expect(entries.length, equals(1));
      expect(entries.first.id, equals(testEntry1.id));
    });

    test('PhaseHistoryRepository should get recent entries', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final recentEntries = await PhaseHistoryRepository.getRecentEntries(1);
      expect(recentEntries.length, equals(1));
      expect(recentEntries.first.id, equals(testEntry2.id));
    });

    test('PhaseHistoryRepository should get entry by journal ID', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final entry = await PhaseHistoryRepository.getEntryByJournalId('journal-1');
      expect(entry, isNotNull);
      expect(entry!.id, equals(testEntry1.id));
      
      final nonExistent = await PhaseHistoryRepository.getEntryByJournalId('non-existent');
      expect(nonExistent, isNull);
    });

    test('PhaseHistoryRepository should get entries for specific phase', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final discoveryEntries = await PhaseHistoryRepository.getEntriesForPhase('Discovery');
      expect(discoveryEntries.length, equals(2));
      
      final recoveryEntries = await PhaseHistoryRepository.getEntriesForPhase('Recovery');
      expect(recoveryEntries.length, equals(2));
    });

    test('PhaseHistoryRepository should calculate average score for phase', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 3);
      
      final avgDiscovery = await PhaseHistoryRepository.getAverageScoreForPhase(
        'Discovery', start, end);
      expect(avgDiscovery, equals(0.55)); // (0.8 + 0.3) / 2
      
      final avgExpansion = await PhaseHistoryRepository.getAverageScoreForPhase(
        'Expansion', start, end);
      expect(avgExpansion, closeTo(0.45, 0.01)); // (0.2 + 0.7) / 2
    });

    test('PhaseHistoryRepository should calculate phase trend', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final trend = await PhaseHistoryRepository.getPhaseTrend('Discovery');
      expect(trend, isA<double>());
      // With only 2 entries, trend calculation may be 0 or very small
      expect(trend, lessThanOrEqualTo(0.1));
    });

    test('PhaseHistoryRepository should provide statistics', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      final stats = await PhaseHistoryRepository.getStatistics();
      expect(stats['totalEntries'], equals(2));
      expect(stats['mostCommonPhase'], isNotNull);
      expect(stats['averageScores'], isA<Map<String, double>>());
      expect(stats['averageScores'].keys.length, equals(6)); // All phases
    });

    test('PhaseHistoryRepository should delete entries', () async {
      await PhaseHistoryRepository.clearAll();
      
      await PhaseHistoryRepository.addEntry(testEntry1);
      await PhaseHistoryRepository.addEntry(testEntry2);
      
      expect(await PhaseHistoryRepository.getEntryCount(), equals(2));
      
      await PhaseHistoryRepository.deleteEntry(testEntry1.id);
      expect(await PhaseHistoryRepository.getEntryCount(), equals(1));
      
      await PhaseHistoryRepository.clearAll();
      expect(await PhaseHistoryRepository.getEntryCount(), equals(0));
    });
  });
}
