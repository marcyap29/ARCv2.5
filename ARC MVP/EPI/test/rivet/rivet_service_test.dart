import 'package:flutter_test/flutter_test.dart';
import '../../lib/core/rivet/rivet_models.dart';
import '../../lib/core/rivet/rivet_service.dart';

void main() {
  group('RivetService', () {
    late RivetService service;
    late RivetConfig config;

    setUp(() {
      config = const RivetConfig(
        Athresh: 0.6,
        Tthresh: 0.6,
        W: 2,
        N: 10,
        K: 20,
      );
      service = RivetService(config: config);
    });

    group('apply', () {
      test('should add event and recompute state', () {
        final event = RivetEvent(
          eventId: 'test-1',
          date: DateTime.now(),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        );

        final decision = service.apply(event);
        
        expect(service.eventHistory, hasLength(1));
        expect(service.eventHistory.first.eventId, equals('test-1'));
        expect(service.getCurrentState().align, equals(1.0));
        expect(service.getCurrentState().trace, greaterThan(0.0));
        expect(decision.stateAfter.eventId, equals('test-1'));
      });

      test('should maintain event history order', () {
        final now = DateTime.now();
        final events = [
          RivetEvent(
            eventId: 'test-1',
            date: now.subtract(const Duration(days: 1)),
            source: EvidenceSource.text,
            keywords: {'old'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
          RivetEvent(
            eventId: 'test-2',
            date: now,
            source: EvidenceSource.text,
            keywords: {'new'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
        ];

        for (final event in events) {
          service.apply(event);
        }

        expect(service.eventHistory, hasLength(2));
        expect(service.eventHistory[0].eventId, equals('test-1'));
        expect(service.eventHistory[1].eventId, equals('test-2'));
      });
    });

    group('delete', () {
      test('should remove event and recompute state', () {
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

        // Add all events
        for (final event in events) {
          service.apply(event);
        }

        expect(service.eventHistory, hasLength(3));

        // Delete middle event
        final decision = service.delete('test-2');
        
        expect(service.eventHistory, hasLength(2));
        expect(service.eventHistory.any((e) => e.eventId == 'test-2'), isFalse);
        expect(service.eventHistory[0].eventId, equals('test-1'));
        expect(service.eventHistory[1].eventId, equals('test-3'));
        expect(decision.stateAfter.eventId, equals('test-3'));
      });

      test('should reset to initial state when all events deleted', () {
        final event = RivetEvent(
          eventId: 'test-1',
          date: DateTime.now(),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        );

        service.apply(event);
        expect(service.eventHistory, hasLength(1));

        final decision = service.delete('test-1');
        
        expect(service.eventHistory, isEmpty);
        expect(service.getCurrentState().align, equals(0.0));
        expect(service.getCurrentState().trace, equals(0.0));
        expect(service.getCurrentState().sustainCount, equals(0));
        expect(service.getCurrentState().sawIndependentInWindow, isFalse);
      });

      test('should handle deletion of non-existent event gracefully', () {
        final event = RivetEvent(
          eventId: 'test-1',
          date: DateTime.now(),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        );

        service.apply(event);
        expect(service.eventHistory, hasLength(1));

        final decision = service.delete('non-existent');
        
        expect(service.eventHistory, hasLength(1)); // Unchanged
        expect(service.eventHistory[0].eventId, equals('test-1'));
      });
    });

    group('edit', () {
      test('should update event and recompute state', () {
        final now = DateTime.now();
        final originalEvent = RivetEvent(
          eventId: 'test-1',
          date: now,
          source: EvidenceSource.text,
          keywords: {'old'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        );

        service.apply(originalEvent);
        expect(service.eventHistory, hasLength(1));
        expect(service.eventHistory[0].keywords, equals({'old'}));

        final updatedEvent = originalEvent.copyWith(
          keywords: {'new'},
          version: 2,
        );

        final decision = service.edit(updatedEvent);
        
        expect(service.eventHistory, hasLength(1));
        expect(service.eventHistory[0].keywords, equals({'new'}));
        expect(service.eventHistory[0].version, equals(2));
        expect(decision.stateAfter.eventId, equals('test-1'));
      });

      test('should add event if not found during edit', () {
        final event = RivetEvent(
          eventId: 'test-1',
          date: DateTime.now(),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        );

        expect(service.eventHistory, isEmpty);

        final decision = service.edit(event);
        
        expect(service.eventHistory, hasLength(1));
        expect(service.eventHistory[0].eventId, equals('test-1'));
      });
    });

    group('setEventHistory', () {
      test('should load event history and recompute state', () {
        final now = DateTime.now();
        final events = [
          RivetEvent(
            eventId: 'test-1',
            date: now.subtract(const Duration(days: 1)),
            source: EvidenceSource.text,
            keywords: {'old'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
          RivetEvent(
            eventId: 'test-2',
            date: now,
            source: EvidenceSource.text,
            keywords: {'new'},
            predPhase: 'Discovery',
            refPhase: 'Discovery',
            tolerance: {},
          ),
        ];

        service.setEventHistory(events);
        
        expect(service.eventHistory, hasLength(2));
        expect(service.eventHistory[0].eventId, equals('test-1'));
        expect(service.eventHistory[1].eventId, equals('test-2'));
        expect(service.getCurrentState().eventId, equals('test-2'));
      });

      test('should handle empty event history', () {
        service.setEventHistory([]);
        
        expect(service.eventHistory, isEmpty);
        expect(service.getCurrentState().align, equals(0.0));
        expect(service.getCurrentState().trace, equals(0.0));
      });
    });

    group('reset', () {
      test('should clear event history and reset state', () {
        final event = RivetEvent(
          eventId: 'test-1',
          date: DateTime.now(),
          source: EvidenceSource.text,
          keywords: {'test'},
          predPhase: 'Discovery',
          refPhase: 'Discovery',
          tolerance: {},
        );

        service.apply(event);
        expect(service.eventHistory, hasLength(1));

        service.reset();
        
        expect(service.eventHistory, isEmpty);
        expect(service.getCurrentState().align, equals(0.0));
        expect(service.getCurrentState().trace, equals(0.0));
        expect(service.getCurrentState().sustainCount, equals(0));
        expect(service.getCurrentState().sawIndependentInWindow, isFalse);
      });
    });

    group('deterministic recompute', () {
      test('should produce same result for same event sequence', () {
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
            source: EvidenceSource.voice,
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

        // First computation
        for (final event in events) {
          service.apply(event);
        }
        final firstResult = service.getCurrentState();

        // Reset and recompute
        service.reset();
        for (final event in events) {
          service.apply(event);
        }
        final secondResult = service.getCurrentState();

        expect(firstResult.align, closeTo(secondResult.align, 0.001));
        expect(firstResult.trace, closeTo(secondResult.trace, 0.001));
        expect(firstResult.sustainCount, equals(secondResult.sustainCount));
        expect(firstResult.sawIndependentInWindow, equals(secondResult.sawIndependentInWindow));
      });

      test('should produce different result after event deletion', () {
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
            source: EvidenceSource.voice,
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

        // Add all events
        for (final event in events) {
          service.apply(event);
        }
        final fullResult = service.getCurrentState();

        // Delete middle event
        service.delete('test-2');
        final partialResult = service.getCurrentState();

        // Results should be different due to different event sequences
        expect(fullResult.align, isNot(closeTo(partialResult.align, 0.001)));
        expect(fullResult.trace, isNot(closeTo(partialResult.trace, 0.001)));
      });
    });
  });
}
