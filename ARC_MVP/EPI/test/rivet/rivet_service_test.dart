import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_service.dart';

void main() {
  group('RivetService Tests', () {
    late RivetService service;
    late List<RivetEvent> testEvents;

    setUp(() {
      service = RivetService();
      testEvents = _createTestEvents();
    });

    test('Apply Event - Adds to History and Recomputes', () async {
      final event = testEvents.first;
      final decision = await service.apply(event);
      
      expect(service.eventHistory.length, equals(1));
      expect(service.stateHistory.length, equals(1));
      expect(service.currentState, isNotNull);
      expect(service.eventHistory.first.eventId, equals(event.eventId));
    });

    test('Delete Event - Removes from History and Recomputes', () async {
      // Add multiple events
      for (final event in testEvents) {
        await service.apply(event);
      }
      
      final originalLength = service.eventHistory.length;
      final eventToDelete = testEvents[2];
      
      // Delete middle event
      final decision = await service.delete(eventToDelete.eventId);
      
      expect(service.eventHistory.length, equals(originalLength - 1));
      expect(service.eventHistory.any((e) => e.eventId == eventToDelete.eventId), isFalse);
      expect(service.stateHistory.length, equals(originalLength - 1));
    });

    test('Edit Event - Updates in History and Recomputes', () async {
      // Add an event
      final originalEvent = testEvents.first;
      await service.apply(originalEvent);
      
      // Edit the event
      final editedEvent = originalEvent.copyWith(
        refPhase: 'Breakthrough',
        keywords: {'new_keyword'},
      );
      
      final decision = await service.edit(editedEvent);
      
      expect(service.eventHistory.length, equals(1));
      expect(service.eventHistory.first.refPhase, equals('Breakthrough'));
      expect(service.eventHistory.first.keywords, equals({'new_keyword'}));
    });

    test('Delete Non-Existent Event - No Change', () async {
      // Add an event
      await service.apply(testEvents.first);
      
      final originalLength = service.eventHistory.length;
      
      // Try to delete non-existent event
      final decision = await service.delete('non_existent_id');
      
      expect(service.eventHistory.length, equals(originalLength));
      expect(service.currentState, isNotNull);
    });

    test('Edit Non-Existent Event - Treats as New Event', () async {
      final originalLength = service.eventHistory.length;
      
      // Try to edit non-existent event
      final newEvent = testEvents.first;
      final decision = await service.edit(newEvent);
      
      expect(service.eventHistory.length, equals(originalLength + 1));
      expect(service.eventHistory.first.eventId, equals(newEvent.eventId));
    });

    test('Load From History - Recomputes All States', () async {
      // Load events from history by applying each one
      for (final event in testEvents) {
        await service.apply(event);
      }
      
      expect(service.eventHistory.length, equals(testEvents.length));
      expect(service.stateHistory.length, equals(testEvents.length));
      expect(service.currentState, isNotNull);
    });

    test('Reset - Clears All Data', () async {
      // Add some events
      for (final event in testEvents.take(3)) {
        await service.apply(event);
      }
      
      // Reset
      service.reset();
      
      expect(service.eventHistory, isEmpty);
      expect(service.stateHistory, isEmpty);
      expect(service.currentState, isNull);
    });

    test('Would Gate Open - Correctly Evaluates Current State', () async {
      // Add events that should open gate
      final events = [
        _createEvent('event1', 'Discovery', 'Discovery', {'keyword1'}, EvidenceSource.text),
        _createEvent('event2', 'Discovery', 'Discovery', {'keyword2'}, EvidenceSource.voice),
        _createEvent('event3', 'Discovery', 'Discovery', {'keyword3'}, EvidenceSource.text),
      ];
      
      for (final event in events) {
        await service.apply(event);
      }
      
      // Gate should be open
      expect(service.wouldGateOpen(), isTrue);
    });

    test('Status Summary - Provides Human Readable Status', () async {
      await service.apply(testEvents.first);
      
      final summary = service.getStatusSummary();
      expect(summary, isA<String>());
      expect(summary, contains('ALIGN'));
      expect(summary, contains('TRACE'));
      expect(summary, contains('Sustain'));
      expect(summary, contains('Independent'));
    });

    test('Gate Explanation - Provides Clear Gate Status', () async {
      await service.apply(testEvents.first);
      
      final explanation = service.getGateExplanation();
      expect(explanation, isA<String>());
      expect(explanation, anyOf(contains('OPEN'), contains('CLOSED')));
    });

    test('Legacy Methods - Backward Compatibility', () async {
      final event = testEvents.first;
      
      // Test legacy ingest method
      final decision = service.ingest(event);
      expect(decision, isA<RivetGateDecision>());
      
      // Test legacy getCurrentState method
      final state = service.getCurrentState();
      expect(state, isA<RivetState>());
    });

    test('Multiple Operations - Maintains Consistency', () async {
      // Apply events
      for (final event in testEvents) {
        await service.apply(event);
      }
      
      final originalLength = service.eventHistory.length;
      
      // Delete an event
      await service.delete(testEvents[1].eventId);
      expect(service.eventHistory.length, equals(originalLength - 1));
      
      // Edit an event
      final editedEvent = testEvents[2].copyWith(refPhase: 'Breakthrough');
      await service.edit(editedEvent);
      expect(service.eventHistory.length, equals(originalLength - 1));
      
      // Add a new event
      final newEvent = _createEvent('new_event', 'Discovery', 'Discovery', {'new_keyword'}, EvidenceSource.text);
      await service.apply(newEvent);
      expect(service.eventHistory.length, equals(originalLength));
    });

    test('Event History Immutability - Cannot Modify Directly', () async {
      await service.apply(testEvents.first);
      
      // Try to modify the returned list
      final history = service.eventHistory;
      expect(() => history.add(testEvents[1]), throwsA(isA<UnsupportedError>()));
    });

    test('State History Immutability - Cannot Modify Directly', () async {
      await service.apply(testEvents.first);
      
      // Try to modify the returned list
      final history = service.stateHistory;
      expect(() => history.add(service.currentState), throwsA(isA<UnsupportedError>()));
    });
  });
}

/// Helper function to create test events
List<RivetEvent> _createTestEvents() {
  final now = DateTime.now();
  return [
    _createEvent('event1', 'Discovery', 'Discovery', {'keyword1'}, EvidenceSource.text, now),
    _createEvent('event2', 'Discovery', 'Discovery', {'keyword2'}, EvidenceSource.voice, now.add(const Duration(hours: 1))),
    _createEvent('event3', 'Discovery', 'Discovery', {'keyword3'}, EvidenceSource.text, now.add(const Duration(hours: 2))),
    _createEvent('event4', 'Discovery', 'Discovery', {'keyword4'}, EvidenceSource.therapistTag, now.add(const Duration(hours: 3))),
    _createEvent('event5', 'Discovery', 'Discovery', {'keyword5'}, EvidenceSource.text, now.add(const Duration(hours: 4))),
  ];
}

/// Helper function to create a single test event
RivetEvent _createEvent(
  String eventId,
  String predPhase,
  String refPhase,
  Set<String> keywords,
  EvidenceSource source, [
  DateTime? date,
]) {
    return RivetEvent(
      eventId: eventId,
      date: date ?? DateTime.now(),
      source: source,
      keywords: keywords,
      predPhase: predPhase,
      refPhase: refPhase,
      tolerance: const {'Discovery': 0.1, 'Breakthrough': 0.1, 'Consolidation': 0.1},
    );
}
