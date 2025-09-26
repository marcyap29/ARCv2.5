import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/arc/models/journal_entry_model.dart';
import 'package:my_app/mode/first_responder/context_trigger_service.dart';
import 'package:my_app/mode/first_responder/fr_settings.dart';

void main() {
  group('ContextTriggerService', () {
    late Box mockBox;
    late ContextTriggerService service;
    late FRSettings settings;

    setUpAll(() async {
      Hive.init('./test_hive');
    });

    setUp(() async {
      mockBox = await Hive.openBox('test_context_triggers');
      service = ContextTriggerService(mockBox);
      settings = FRSettings.defaults().copyWith(postHeavyEntryCheckIn: true);
    });

    tearDown(() async {
      await mockBox.clear();
      await mockBox.close();
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk();
    });

    group('shouldOfferDebrief', () {
      test('returns false when feature is disabled', () async {
        final disabledSettings = settings.copyWith(postHeavyEntryCheckIn: false);
        final entry = _createTestEntry(content: 'Emergency call with multiple casualties');

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: disabledSettings,
        );

        expect(result, false);
      });

      test('returns false when dismissed today', () async {
        await service.markDismissedToday();
        final entry = _createTestEntry(content: 'Severe trauma call at scene');

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, false);
      });

      test('returns false when recently triggered', () async {
        // Simulate recent trigger
        await mockBox.put('last_debrief_trigger', DateTime.now().millisecondsSinceEpoch);
        final entry = _createTestEntry(content: 'Critical patient overdose scene');

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, false);
      });

      test('returns true for heavy entry with FR keywords', () async {
        final entry = _createTestEntry(
          content: 'Responded to emergency call with patient trauma. Multiple casualties at scene.',
          keywords: ['stress', 'pressure', 'difficult'],
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });

      test('returns true for crisis terms', () async {
        final entry = _createTestEntry(
          content: 'Cardiac arrest at downtown location. Pediatric patient involved.',
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });

      test('returns true for challenging mood entry', () async {
        final entry = _createTestEntry(
          content: 'Call went okay overall.',
          mood: 'Challenging',
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });

      test('returns false for light entry', () async {
        final entry = _createTestEntry(
          content: 'Nice weather today. Had lunch with team.',
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, false);
      });

      test('handles long entries appropriately', () async {
        final longText = List.generate(50, (i) => 'Routine call response. ').join();
        final entry = _createTestEntry(content: longText);

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        // Should not trigger on length alone without other heavy indicators
        expect(result, false);
      });
    });

    group('markDismissedToday', () {
      test('marks current day as dismissed', () async {
        await service.markDismissedToday();
        
        final today = DateTime.now();
        final expectedKey = '${today.year}-${today.month}-${today.day}';
        final stored = mockBox.get('dismissed_debrief_today');
        
        expect(stored, expectedKey);
      });

      test('prevents offering debrief after dismissal', () async {
        await service.markDismissedToday();
        final heavyEntry = _createTestEntry(
          content: 'Severe trauma emergency call with multiple casualties and fatality.',
        );

        final result = await service.shouldOfferDebrief(
          entry: heavyEntry,
          settings: settings,
        );

        expect(result, false);
      });
    });

    group('resetTriggerStates', () {
      test('clears all trigger states', () async {
        // Set up some trigger states
        await service.markDismissedToday();
        await mockBox.put('last_debrief_trigger', DateTime.now().millisecondsSinceEpoch);

        // Reset states
        await service.resetTriggerStates();

        expect(mockBox.get('last_debrief_trigger'), isNull);
        expect(mockBox.get('dismissed_debrief_today'), isNull);
      });
    });

    group('getTriggerStats', () {
      test('returns current trigger statistics', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await mockBox.put('last_debrief_trigger', now);
        await service.markDismissedToday();

        final stats = service.getTriggerStats();

        expect(stats['lastTrigger'], equals(now));
        expect(stats['dismissedToday'], isNotNull);
      });

      test('returns null values when no data exists', () {
        final stats = service.getTriggerStats();

        expect(stats['lastTrigger'], isNull);
        expect(stats['dismissedToday'], isNull);
      });
    });

    group('heavy entry detection', () {
      test('detects FR keywords correctly', () async {
        final entry = _createTestEntry(
          content: 'Emergency call dispatch. Patient trauma at scene with ambulance response.',
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });

      test('detects crisis terms correctly', () async {
        final entry = _createTestEntry(
          content: 'Overdose situation with severe complications.',
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });

      test('considers multiple factors in scoring', () async {
        final entry = _createTestEntry(
          content: 'Emergency call with patient. Feeling overwhelmed by the pressure.',
          keywords: ['stress', 'anxiety', 'pressure'],
          mood: 'Difficult',
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });

      test('does not trigger on false positives', () async {
        final entry = _createTestEntry(
          content: 'Called my friend John. We had a great patient discussion about Monday.',
        );

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, false);
      });
    });

    group('time-based restrictions', () {
      test('respects 2-hour cooldown period', () async {
        // Simulate trigger 1 hour ago
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
        await mockBox.put('last_debrief_trigger', oneHourAgo.millisecondsSinceEpoch);

        final entry = _createTestEntry(content: 'Critical emergency with casualties');

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, false);
      });

      test('allows trigger after cooldown expires', () async {
        // Simulate trigger 3 hours ago
        final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
        await mockBox.put('last_debrief_trigger', threeHoursAgo.millisecondsSinceEpoch);

        final entry = _createTestEntry(content: 'Emergency trauma call with fatality');

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });

      test('dismissal is day-specific', () async {
        // Manually set dismissed for yesterday
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
        await mockBox.put('dismissed_debrief_today', yesterdayKey);

        final entry = _createTestEntry(content: 'Severe emergency call with trauma');

        final result = await service.shouldOfferDebrief(
          entry: entry,
          settings: settings,
        );

        expect(result, true);
      });
    });
  });
}

JournalEntry _createTestEntry({
  String? content,
  List<String>? keywords,
  String? mood,
}) {
  return JournalEntry(
    id: 'test-${DateTime.now().millisecondsSinceEpoch}',
    title: 'Test Entry',
    content: content ?? '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    tags: const [],
    mood: mood ?? '',
    keywords: keywords ?? [],
  );
}