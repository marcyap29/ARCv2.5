import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mode/first_responder/debrief/debrief_to_journal_mapper.dart';
import 'package:my_app/mode/first_responder/debrief/debrief_models.dart';

void main() {
  group('DebriefToJournalMapper', () {
    test('maps complete debrief record to journal entry correctly', () {
      final debrief = DebriefRecord(
        id: 'test-debrief-1',
        createdAt: DateTime(2025, 1, 9, 14, 30),
        snapshot: 'Responded to motor vehicle accident on Highway 101.',
        wentWell: const ['Communication', 'Teamwork'],
        wasHard: const ['Time pressure', 'Weather'],
        bodyScore: 3,
        breathCompleted: true,
        essence: 'Good coordination made the difference.',
        nextStep: 'Debrief with team about equipment.',
      );

      final journalEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(debrief);

      expect(journalEntry.id, equals('test-debrief-1'));
      expect(journalEntry.title, equals('Debrief — Jan 9, 2:30 PM'));
      expect(journalEntry.createdAt, equals(debrief.createdAt));
      expect(journalEntry.updatedAt, equals(debrief.createdAt));
    });

    test('generates correct body content with all sections', () {
      final debrief = DebriefRecord(
        id: 'test-debrief-2',
        createdAt: DateTime.now(),
        snapshot: 'Emergency call at downtown location.',
        wentWell: const ['Quick response', 'Good communication'],
        wasHard: const ['Heavy traffic', 'Limited resources'],
        bodyScore: 4,
        breathCompleted: true,
        essence: 'Preparation made the difference.',
        nextStep: 'Review protocols with supervisor.',
      );

      final journalEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(debrief);

      expect(journalEntry.content, contains('## Snapshot'));
      expect(journalEntry.content, contains('Emergency call at downtown location.'));
      expect(journalEntry.content, contains('## What Went Well'));
      expect(journalEntry.content, contains('• Quick response'));
      expect(journalEntry.content, contains('• Good communication'));
      expect(journalEntry.content, contains('## What Was Challenging'));
      expect(journalEntry.content, contains('• Heavy traffic'));
      expect(journalEntry.content, contains('• Limited resources'));
      expect(journalEntry.content, contains('## Body Check'));
      expect(journalEntry.content, contains('Overall feeling: 4/5'));
      expect(journalEntry.content, contains('Completed breathing exercise'));
      expect(journalEntry.content, contains('## Key Takeaway'));
      expect(journalEntry.content, contains('Preparation made the difference.'));
      expect(journalEntry.content, contains('## Next Step'));
      expect(journalEntry.content, contains('Review protocols with supervisor.'));
    });

    test('handles minimal debrief record correctly', () {
      final debrief = DebriefRecord(
        id: 'test-debrief-3',
        createdAt: DateTime.now(),
        snapshot: '',
        wentWell: const [],
        wasHard: const [],
        bodyScore: 3,
        breathCompleted: false,
        essence: '',
        nextStep: '',
      );

      final journalEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(debrief);

      // Should only contain body check section
      expect(journalEntry.content, contains('## Body Check'));
      expect(journalEntry.content, contains('Overall feeling: 3/5'));
      expect(journalEntry.content, isNot(contains('Completed breathing exercise')));
      expect(journalEntry.content, isNot(contains('## Snapshot')));
      expect(journalEntry.content, isNot(contains('## What Went Well')));
      expect(journalEntry.content, isNot(contains('## Key Takeaway')));
      expect(journalEntry.content, isNot(contains('## Next Step')));
    });

    test('generates correct tags from debrief content', () {
      final debrief = DebriefRecord(
        id: 'test-debrief-4',
        createdAt: DateTime.now(),
        snapshot: 'Test snapshot',
        wentWell: const ['Communication', 'Team Work'],
        wasHard: const ['Time Pressure'],
        bodyScore: 3,
        breathCompleted: false,
        essence: 'Test essence',
        nextStep: '',
      );

      final journalEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(debrief);

      expect(journalEntry.tags, contains('first_responder'));
      expect(journalEntry.tags, contains('debrief'));
      expect(journalEntry.tags, contains('communication'));
      expect(journalEntry.tags, contains('team_work'));
      expect(journalEntry.tags, contains('time_pressure'));
    });

    test('infers mood correctly based on body score', () {
      final goodDebrief = DebriefRecord(
        id: 'test-good',
        createdAt: DateTime.now(),
        snapshot: '',
        wentWell: const [],
        wasHard: const [],
        bodyScore: 4,
        breathCompleted: false,
        essence: '',
        nextStep: '',
      );

      final challengingDebrief = DebriefRecord(
        id: 'test-challenging',
        createdAt: DateTime.now(),
        snapshot: '',
        wentWell: const [],
        wasHard: const [],
        bodyScore: 2,
        breathCompleted: false,
        essence: '',
        nextStep: '',
      );

      final mixedDebrief = DebriefRecord(
        id: 'test-mixed',
        createdAt: DateTime.now(),
        snapshot: '',
        wentWell: const [],
        wasHard: const [],
        bodyScore: 3,
        breathCompleted: false,
        essence: '',
        nextStep: '',
      );

      final goodEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(goodDebrief);
      final challengingEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(challengingDebrief);
      final mixedEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(mixedDebrief);

      expect(goodEntry.mood, equals('Good'));
      expect(challengingEntry.mood, equals('Challenging'));
      expect(mixedEntry.mood, equals('Mixed'));
    });

    test('generates correct metadata', () {
      final debrief = DebriefRecord(
        id: 'test-debrief-5',
        createdAt: DateTime.now(),
        snapshot: 'Test',
        wentWell: const ['Item 1', 'Item 2'],
        wasHard: const ['Item 3'],
        bodyScore: 4,
        breathCompleted: true,
        essence: 'Key insight',
        nextStep: 'Next action',
      );

      final journalEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(debrief);

      expect(journalEntry.metadata?['frMode'], equals(true));
      expect(journalEntry.metadata?['breathCompleted'], equals(true));
      expect(journalEntry.metadata?['bodyScore'], equals(4));
      expect(journalEntry.metadata?['stepCount'], equals(5));
      expect(journalEntry.metadata?['debriefType'], equals('rapid'));
      expect(journalEntry.metadata?['wentWellCount'], equals(2));
      expect(journalEntry.metadata?['wasHardCount'], equals(1));
      expect(journalEntry.metadata?['hasEssence'], equals(true));
      expect(journalEntry.metadata?['hasNextStep'], equals(true));
    });

    test('formats datetime correctly in title', () {
      final morningTime = DateTime(2025, 1, 9, 9, 15);
      final afternoonTime = DateTime(2025, 1, 9, 14, 30);
      final eveningTime = DateTime(2025, 1, 9, 21, 45);

      final morningDebrief = DebriefRecord(
        id: 'morning',
        createdAt: morningTime,
        snapshot: '',
        wentWell: const [],
        wasHard: const [],
        bodyScore: 3,
        breathCompleted: false,
        essence: '',
        nextStep: '',
      );

      final afternoonDebrief = DebriefRecord(
        id: 'afternoon',
        createdAt: afternoonTime,
        snapshot: '',
        wentWell: const [],
        wasHard: const [],
        bodyScore: 3,
        breathCompleted: false,
        essence: '',
        nextStep: '',
      );

      final eveningDebrief = DebriefRecord(
        id: 'evening',
        createdAt: eveningTime,
        snapshot: '',
        wentWell: const [],
        wasHard: const [],
        bodyScore: 3,
        breathCompleted: false,
        essence: '',
        nextStep: '',
      );

      final morningEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(morningDebrief);
      final afternoonEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(afternoonDebrief);
      final eveningEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(eveningDebrief);

      expect(morningEntry.title, equals('Debrief — Jan 9, 9:15 AM'));
      expect(afternoonEntry.title, equals('Debrief — Jan 9, 2:30 PM'));
      expect(eveningEntry.title, equals('Debrief — Jan 9, 9:45 PM'));
    });

    test('extracts keywords from essence and other content', () {
      final debrief = DebriefRecord(
        id: 'test-keywords',
        createdAt: DateTime.now(),
        snapshot: '',
        wentWell: const ['communication', 'teamwork'],
        wasHard: const ['pressure'],
        bodyScore: 3,
        breathCompleted: false,
        essence: 'Team coordination was essential for success',
        nextStep: '',
      );

      final journalEntry = DebriefToJournalMapper.mapDebriefToJournalEntry(debrief);

      expect(journalEntry.keywords, contains('communication'));
      expect(journalEntry.keywords, contains('teamwork'));
      expect(journalEntry.keywords, contains('pressure'));
      expect(journalEntry.keywords, contains('team'));
      expect(journalEntry.keywords, contains('coordination'));
      expect(journalEntry.keywords, contains('essential'));
      expect(journalEntry.keywords, contains('success'));
      
      // Should not contain stop words
      expect(journalEntry.keywords, isNot(contains('was')));
      expect(journalEntry.keywords, isNot(contains('for')));
    });
  });
}