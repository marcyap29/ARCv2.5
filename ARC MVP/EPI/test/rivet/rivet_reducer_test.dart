import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_reducer.dart';

void main() {
  group('RivetReducer Tests', () {
    late RivetConfig config;
    late List<RivetEvent> testEvents;

    setUp(() {
      config = const RivetConfig();
      testEvents = _createTestEvents();
    });

    test('Golden Recompute - Deterministic Results', () {
      // Test that recompute produces deterministic results
      final states1 = RivetReducer.recompute(testEvents, config);
      final states2 = RivetReducer.recompute(testEvents, config);
      
      expect(states1.length, equals(states2.length));
      for (int i = 0; i < states1.length; i++) {
        expect(states1[i].align, equals(states2[i].align));
        expect(states1[i].trace, equals(states2[i].trace));
        expect(states1[i].sustainCount, equals(states2[i].sustainCount));
        expect(states1[i].sawIndependentInWindow, equals(states2[i].sawIndependentInWindow));
      }
    });

    test('Golden Recompute - Delete Middle Event', () {
      // Test that deleting a middle event produces correct results
      final originalStates = RivetReducer.recompute(testEvents, config);
      
      // Remove middle event
      final modifiedEvents = List<RivetEvent>.from(testEvents);
      modifiedEvents.removeAt(2); // Remove middle event
      
      final modifiedStates = RivetReducer.recompute(modifiedEvents, config);
      
      // Should have one less state
      expect(modifiedStates.length, equals(originalStates.length - 1));
      
      // All indices should be bounded
      for (final state in modifiedStates) {
        expect(state.align, inInclusiveRange(0.0, 1.0));
        expect(state.trace, inInclusiveRange(0.0, 1.0));
        expect(state.sustainCount, greaterThanOrEqualTo(0));
      }
    });

    test('Sustainment and Independence - Gate Opens When Conditions Met', () {
      // Create events that should trigger gate opening
      final events = [
        _createEvent('event1', 'Discovery', 'Discovery', {'keyword1'}, EvidenceSource.text),
        _createEvent('event2', 'Discovery', 'Discovery', {'keyword2'}, EvidenceSource.voice),
        _createEvent('event3', 'Discovery', 'Discovery', {'keyword3'}, EvidenceSource.text),
      ];
      
      final states = RivetReducer.recompute(events, config);
      
      // Check that gate opens when conditions are met
      final lastState = states.last;
      expect(lastState.gateOpen, isTrue);
      expect(lastState.sustainCount, greaterThanOrEqualTo(config.W));
      expect(lastState.sawIndependentInWindow, isTrue);
    });

    test('Sustainment and Independence - Gate Stays Closed When Independence Missing', () {
      // Create events with same source and same day (no independence)
      final sameTime = DateTime.now();
      final events = [
        _createEvent('event1', 'Discovery', 'Discovery', {'keyword1'}, EvidenceSource.text, sameTime),
        _createEvent('event2', 'Discovery', 'Discovery', {'keyword2'}, EvidenceSource.text, sameTime.add(const Duration(minutes: 1))),
        _createEvent('event3', 'Discovery', 'Discovery', {'keyword3'}, EvidenceSource.text, sameTime.add(const Duration(minutes: 2))),
      ];
      
      final states = RivetReducer.recompute(events, config);
      
      // Check that gate stays closed due to lack of independence
      final lastState = states.last;
      expect(lastState.gateOpen, isFalse);
      expect(lastState.sawIndependentInWindow, isFalse);
    });

    test('Saturation Behavior - TRACE Shows Diminishing Returns', () {
      // Create many events with similar keywords (low novelty)
      final events = List.generate(10, (i) => 
        _createEvent('event$i', 'Discovery', 'Discovery', {'keyword1', 'keyword2'}, EvidenceSource.text)
      );
      
      final states = RivetReducer.recompute(events, config);
      
      // TRACE should show diminishing increments
      final traceValues = states.map((s) => s.trace).toList();
      for (int i = 1; i < traceValues.length; i++) {
        final increment = traceValues[i] - traceValues[i - 1];
        expect(increment, greaterThanOrEqualTo(0.0)); // TRACE should not decrease
        if (i > 3) {
          // Later increments should be smaller (diminishing returns)
          expect(increment, lessThanOrEqualTo(0.1));
        }
      }
    });

    test('Monotonicity Under Additions - TRACE Never Decreases When Adding Events', () {
      final states = RivetReducer.recompute(testEvents, config);
      
      // TRACE should be monotonically increasing
      for (int i = 1; i < states.length; i++) {
        expect(states[i].trace, greaterThanOrEqualTo(states[i - 1].trace));
      }
    });

    test('Gate Discipline - Strong ALIGN Weak TRACE', () {
      // Create events that should have strong ALIGN but weak TRACE
      final events = [
        _createEvent('event1', 'Discovery', 'Discovery', {}, EvidenceSource.text), // Perfect match but no keywords
        _createEvent('event2', 'Discovery', 'Discovery', {}, EvidenceSource.text),
        _createEvent('event3', 'Discovery', 'Discovery', {}, EvidenceSource.text),
      ];
      
      final states = RivetReducer.recompute(events, config);
      
      // Gate should stay closed due to weak TRACE
      final lastState = states.last;
      expect(lastState.align, greaterThanOrEqualTo(config.Athresh));
      expect(lastState.trace, lessThan(config.Tthresh));
      expect(lastState.gateOpen, isFalse);
    });

    test('Gate Discipline - Strong TRACE Weak ALIGN', () {
      // Create events that should have strong TRACE but weak ALIGN
      final events = [
        _createEvent('event1', 'Discovery', 'Breakthrough', {'keyword1'}, EvidenceSource.text), // Mismatch
        _createEvent('event2', 'Discovery', 'Breakthrough', {'keyword2'}, EvidenceSource.voice), // Different source
        _createEvent('event3', 'Discovery', 'Breakthrough', {'keyword3'}, EvidenceSource.text),
      ];
      
      final states = RivetReducer.recompute(events, config);
      
      // Gate should stay closed due to weak ALIGN
      final lastState = states.last;
      expect(lastState.align, lessThan(config.Athresh));
      expect(lastState.trace, greaterThanOrEqualTo(config.Tthresh));
      expect(lastState.gateOpen, isFalse);
    });

    test('Independence Multiplier - Different Day Boosts Evidence', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      
      final events = [
        _createEvent('event1', 'Discovery', 'Discovery', {'keyword1'}, EvidenceSource.text, yesterday),
        _createEvent('event2', 'Discovery', 'Discovery', {'keyword2'}, EvidenceSource.text, today),
      ];
      
      final states = RivetReducer.recompute(events, config);
      
      // Second event should have higher TRACE due to independence multiplier
      expect(states[1].trace, greaterThan(states[0].trace));
    });

    test('Novelty Multiplier - Keyword Drift Boosts Evidence', () {
      final events = [
        _createEvent('event1', 'Discovery', 'Discovery', {'keyword1', 'keyword2'}, EvidenceSource.text),
        _createEvent('event2', 'Discovery', 'Discovery', {'keyword3', 'keyword4'}, EvidenceSource.text), // Different keywords
      ];
      
      final states = RivetReducer.recompute(events, config);
      
      // Second event should have higher TRACE due to novelty multiplier
      expect(states[1].trace, greaterThan(states[0].trace));
    });

    test('Empty Event List - Returns Empty States', () {
      final states = RivetReducer.recompute([], config);
      expect(states, isEmpty);
    });

    test('Single Event - Correct Initial State', () {
      final events = [_createEvent('event1', 'Discovery', 'Discovery', {'keyword1'}, EvidenceSource.text)];
      final states = RivetReducer.recompute(events, config);
      
      expect(states.length, equals(1));
      final state = states.first;
      expect(state.align, inInclusiveRange(0.0, 1.0));
      expect(state.trace, inInclusiveRange(0.0, 1.0));
      expect(state.sustainCount, equals(0));
      expect(state.sawIndependentInWindow, isFalse);
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
    eventId: const Uuid().v4(),
    date: date ?? DateTime.now(),
    source: source,
    keywords: keywords,
    predPhase: predPhase,
    refPhase: refPhase,
    tolerance: const {'Discovery': 0.1, 'Breakthrough': 0.1, 'Consolidation': 0.1},
  );
}
