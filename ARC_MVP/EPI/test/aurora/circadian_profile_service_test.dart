/// Tests for AURORA Circadian Profile Service
/// 
/// Tests for CircadianProfileService chronotype detection and rhythm analysis
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/aurora/services/circadian_profile_service.dart';
import 'package:my_app/models/journal_entry_model.dart';

void main() {
  group('CircadianProfileService', () {
    late CircadianProfileService service;

    setUp(() {
      service = CircadianProfileService();
    });

    group('compute', () {
      test('should return default context for empty entries', () async {
        final context = await service.compute([]);

        expect(context.window, isIn(['morning', 'afternoon', 'evening']));
        expect(context.chronotype, 'balanced');
        expect(context.rhythmScore, 0.5);
      });

      test('should detect morning chronotype from early entries', () async {
        final entries = [
          _createJournalEntry(hour: 6),  // 6 AM
          _createJournalEntry(hour: 7),  // 7 AM
          _createJournalEntry(hour: 8),  // 8 AM
          _createJournalEntry(hour: 9),  // 9 AM
          _createJournalEntry(hour: 10), // 10 AM
        ];

        final context = await service.compute(entries);

        expect(context.chronotype, 'morning');
      });

      test('should detect evening chronotype from late entries', () async {
        final entries = [
          _createJournalEntry(hour: 18), // 6 PM
          _createJournalEntry(hour: 19), // 7 PM
          _createJournalEntry(hour: 20), // 8 PM
          _createJournalEntry(hour: 21), // 9 PM
          _createJournalEntry(hour: 22), // 10 PM
        ];

        final context = await service.compute(entries);

        expect(context.chronotype, 'evening');
      });

      test('should detect balanced chronotype from midday entries', () async {
        final entries = [
          _createJournalEntry(hour: 12), // 12 PM
          _createJournalEntry(hour: 13), // 1 PM
          _createJournalEntry(hour: 14), // 2 PM
          _createJournalEntry(hour: 15), // 3 PM
          _createJournalEntry(hour: 16), // 4 PM
        ];

        final context = await service.compute(entries);

        expect(context.chronotype, 'balanced');
      });

      test('should calculate high rhythm score for concentrated activity', () async {
        // All entries at the same hour (high concentration)
        final entries = List.generate(10, (i) => _createJournalEntry(hour: 14));

        final context = await service.compute(entries);

        expect(context.rhythmScore, greaterThan(0.7));
      });

      test('should calculate low rhythm score for scattered activity', () async {
        // Entries spread across many hours (low concentration)
        final entries = [
          _createJournalEntry(hour: 6),
          _createJournalEntry(hour: 10),
          _createJournalEntry(hour: 14),
          _createJournalEntry(hour: 18),
          _createJournalEntry(hour: 22),
        ];

        final context = await service.compute(entries);

        expect(context.rhythmScore, lessThan(0.5));
      });

      test('should handle mixed chronotype entries', () async {
        final entries = [
          _createJournalEntry(hour: 7),  // Morning
          _createJournalEntry(hour: 8),  // Morning
          _createJournalEntry(hour: 14), // Afternoon
          _createJournalEntry(hour: 20), // Evening
          _createJournalEntry(hour: 21), // Evening
        ];

        final context = await service.compute(entries);

        // Should detect the most common pattern (morning in this case)
        expect(context.chronotype, 'morning');
      });
    });

    group('computeProfile', () {
      test('should return default profile for empty entries', () async {
        final profile = await service.computeProfile([]);

        expect(profile.chronotype, 'balanced');
        expect(profile.hourlyActivity.length, 24);
        expect(profile.rhythmScore, 0.5);
        expect(profile.entryCount, 0);
      });

      test('should create detailed profile with hourly activity', () async {
        final entries = [
          _createJournalEntry(hour: 8),
          _createJournalEntry(hour: 8),
          _createJournalEntry(hour: 14),
          _createJournalEntry(hour: 20),
        ];

        final profile = await service.computeProfile(entries);

        expect(profile.entryCount, 4);
        expect(profile.hourlyActivity[8], greaterThan(0)); // 8 AM activity
        expect(profile.hourlyActivity[14], greaterThan(0)); // 2 PM activity
        expect(profile.hourlyActivity[20], greaterThan(0)); // 8 PM activity
      });

      test('should identify peak hour correctly', () async {
        final entries = [
          _createJournalEntry(hour: 6),
          _createJournalEntry(hour: 14),
          _createJournalEntry(hour: 14),
          _createJournalEntry(hour: 14), // Peak at 2 PM
          _createJournalEntry(hour: 20),
        ];

        final profile = await service.computeProfile(entries);

        expect(profile.peakHour, 14);
      });
    });

    group('hasSufficientData', () {
      test('should return false for insufficient entries', () {
        final entries = List.generate(5, (i) => _createJournalEntry(hour: 12));

        expect(service.hasSufficientData(entries), false);
      });

      test('should return true for sufficient entries', () {
        final entries = List.generate(10, (i) => _createJournalEntry(hour: 12));

        expect(service.hasSufficientData(entries), true);
      });
    });

    group('descriptions', () {
      test('should provide chronotype descriptions', () {
        expect(service.getChronotypeDescription('morning'), 
               'Morning person - most active before 11 AM');
        expect(service.getChronotypeDescription('evening'), 
               'Evening person - most active after 5 PM');
        expect(service.getChronotypeDescription('balanced'), 
               'Balanced chronotype - consistent activity throughout day');
      });

      test('should provide window descriptions', () {
        expect(service.getWindowDescription('morning'), 
               'Morning window - 6 AM to 11 AM');
        expect(service.getWindowDescription('afternoon'), 
               'Afternoon window - 11 AM to 5 PM');
        expect(service.getWindowDescription('evening'), 
               'Evening window - 5 PM to 6 AM');
      });
    });
  });
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
    tags: const [],
    mood: 'neutral',
    audioUri: null,
    media: const [],
    sageAnnotation: null,
    keywords: const [],
    emotion: null,
    emotionReason: null,
    metadata: null,
  );
}
