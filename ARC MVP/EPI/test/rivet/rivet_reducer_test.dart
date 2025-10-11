import 'package:flutter_test/flutter_test.dart';
import '../../lib/core/rivet/rivet_models.dart';
import '../../lib/core/rivet/rivet_reducer.dart';

void main() {
  group('RivetReducer', () {
    late RivetConfig config;

    setUp(() {
      config = const RivetConfig(
        Athresh: 0.6,
        Tthresh: 0.6,
        W: 2,
        N: 10,
        K: 20,
      );
    });

    group('recompute', () {
      test('should return empty list for empty events', () {
        final result = RivetReducer.recompute([], config);
        expect(result, isEmpty);
      });

      test('should compute states for single event', () {
        final event = RivetEvent(
          eventId: 'test-1',
          date: DateTime.now(),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        );

        final result = RivetReducer.recompute([event], config);
        
        expect(result, hasLength(1));
        expect(result.first.align, equals(1.0)); // Perfect match
        expect(result.first.trace, greaterThan(0.0)); // Some evidence
        expect(result.first.eventId, equals('test-1'));
        expect(result.first.date, equals(event.date));
      });

      test('should maintain chronological order', () {
        final now = DateTime.now();
        final events = [
          RivetEvent(
            eventId: 'test-1',
            date: now.subtract(const Duration(days: 2)),
            source: EvidenceSource.text,
            keywords: {'old'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
          RivetEvent(
            eventId: 'test-2',
            date: now.subtract(const Duration(days: 1)),
            source: EvidenceSource.text,
            keywords: {'middle'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
          RivetEvent(
            eventId: 'test-3',
            date: now,
            source: EvidenceSource.text,
            keywords: {'new'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
        ];

        final result = RivetReducer.recompute(events, config);
        
        expect(result, hasLength(3));
        expect(result[0].eventId, equals('test-1'));
        expect(result[1].eventId, equals('test-2'));
        expect(result[2].eventId, equals('test-3'));
      });

      test('should sort events by date before processing', () {
        final now = DateTime.now();
        final events = [
          RivetEvent(
            eventId: 'test-3',
            date: now,
            source: EvidenceSource.text,
            keywords: {'new'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
          RivetEvent(
            eventId: 'test-1',
            date: now.subtract(const Duration(days: 2)),
            source: EvidenceSource.text,
            keywords: {'old'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
          RivetEvent(
            eventId: 'test-2',
            date: now.subtract(const Duration(days: 1)),
            source: EvidenceSource.text,
            keywords: {'middle'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
        ];

        final result = RivetReducer.recompute(events, config);
        
        expect(result, hasLength(3));
        expect(result[0].eventId, equals('test-1'));
        expect(result[1].eventId, equals('test-2'));
        expect(result[2].eventId, equals('test-3'));
      });

      test('should maintain bounded indices', () {
        final events = List.generate(10, (i) => RivetEvent(
          eventId: 'test-$i',
          date: DateTime.now().add(Duration(hours: i)),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        ));

        final result = RivetReducer.recompute(events, config);
        
        for (final state in result) {
          expect(state.align, inInclusiveRange(0.0, 1.0));
          expect(state.trace, inInclusiveRange(0.0, 1.0));
        }
      });

      test('should show TRACE monotonicity under additions', () {
        final events = List.generate(5, (i) => RivetEvent(
          eventId: 'test-$i',
          date: DateTime.now().add(Duration(hours: i)),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        ));

        final result = RivetReducer.recompute(events, config);
        
        for (int i = 1; i < result.length; i++) {
          expect(result[i].trace, greaterThanOrEqualTo(result[i-1].trace));
        }
      });

      test('should handle independence correctly', () {
        final now = DateTime.now();
        final events = [
          RivetEvent(
            eventId: 'test-1',
            date: now,
            source: EvidenceSource.text,
            keywords: {'test'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
          RivetEvent(
            eventId: 'test-2',
            date: now.add(const Duration(days: 1)), // Different day
            source: EvidenceSource.voice, // Different source
            keywords: {'different'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
        ];

        final result = RivetReducer.recompute(events, config);
        
        expect(result, hasLength(2));
        expect(result[1].sawIndependentInWindow, isTrue);
      });

      test('should calculate sustainment correctly', () {
        final now = DateTime.now();
        final events = List.generate(5, (i) => RivetEvent(
          eventId: 'test-$i',
          date: now.add(Duration(hours: i)),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        ));

        final result = RivetReducer.recompute(events, config);
        
        // All events should meet thresholds, so sustainment should increase
        for (int i = 0; i < result.length; i++) {
          expect(result[i].sustainCount, lessThanOrEqualTo(i + 1));
        }
      });
    });

    group('getLatestGateDecision', () {
      test('should return closed gate for empty states', () {
        final decision = RivetReducer.getLatestGateDecision([], config);
        
        expect(decision.open, isFalse);
        expect(decision.whyNot, equals("No events processed"));
      });

      test('should return closed gate when ALIGN below threshold', () {
        final states = [
          const RivetState(
            align: 0.5, // Below 0.6 threshold
            trace: 0.7,
            sustainCount: 2,
            sawIndependentInWindow: true,
          ),
        ];

        final decision = RivetReducer.getLatestGateDecision(states, config);
        
        expect(decision.open, isFalse);
        expect(decision.whyNot, contains("ALIGN below threshold"));
      });

      test('should return closed gate when TRACE below threshold', () {
        final states = [
          const RivetState(
            align: 0.7,
            trace: 0.5, // Below 0.6 threshold
            sustainCount: 2,
            sawIndependentInWindow: true,
          ),
        ];

        final decision = RivetReducer.getLatestGateDecision(states, config);
        
        expect(decision.open, isFalse);
        expect(decision.whyNot, contains("TRACE below threshold"));
      });

      test('should return closed gate when sustainment insufficient', () {
        final states = [
          const RivetState(
            align: 0.7,
            trace: 0.7,
            sustainCount: 1, // Below W=2 threshold
            sawIndependentInWindow: true,
          ),
        ];

        final decision = RivetReducer.getLatestGateDecision(states, config);
        
        expect(decision.open, isFalse);
        expect(decision.whyNot, contains("Needs sustainment 1/2"));
      });

      test('should return closed gate when no independent event', () {
        final states = [
          const RivetState(
            align: 0.7,
            trace: 0.7,
            sustainCount: 2,
            sawIndependentInWindow: false, // No independent event
          ),
        ];

        final decision = RivetReducer.getLatestGateDecision(states, config);
        
        expect(decision.open, isFalse);
        expect(decision.whyNot, contains("Need at least one independent event"));
      });

      test('should return open gate when all conditions met', () {
        final states = [
          const RivetState(
            align: 0.7,
            trace: 0.7,
            sustainCount: 2,
            sawIndependentInWindow: true,
          ),
        ];

        final decision = RivetReducer.getLatestGateDecision(states, config);
        
        expect(decision.open, isTrue);
        expect(decision.whyNot, isNull);
      });
    });
  });
}
