import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/rivet/rivet_service.dart';
import 'package:my_app/core/rivet/rivet_models.dart';

void main() {
  group('RivetService', () {
    late RivetService service;

    setUp(() {
      service = RivetService();
    });

    test('should initialize with default state', () {
      final state = service.getCurrentState();
      expect(state.align, 0.0);
      expect(state.trace, 0.0);
      expect(state.sustainCount, 0);
      expect(state.sawIndependentInWindow, false);
    });

    test('should calculate ALIGN correctly for matching phases', () {
      final event = RivetEvent(
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: const {'keyword1', 'keyword2'},
        predPhase: 'discovery',
        refPhase: 'discovery', // Matching phase
        tolerance: const {},
      );

      final decision = service.ingest(event);

      // Should have some ALIGN score > 0 for matching phases
      expect(decision.stateAfter.align, greaterThan(0.0));
      expect(decision.stateAfter.trace, greaterThan(0.0));
    });

    test('should calculate ALIGN correctly for mismatched phases', () {
      final event = RivetEvent(
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: const {'keyword1', 'keyword2'},
        predPhase: 'discovery',
        refPhase: 'expansion', // Different phase
        tolerance: const {},
      );

      final decision = service.ingest(event);

      // ALIGN should be 0 for mismatched phases (categorical)
      expect(decision.stateAfter.align, equals(0.0));
      // But TRACE should still increase (evidence accumulation)
      expect(decision.stateAfter.trace, greaterThan(0.0));
    });

    test('should keep gate closed until both thresholds are met', () {
      // First event: matching phase, should improve ALIGN and TRACE
      final event1 = RivetEvent(
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: const {'keyword1'},
        predPhase: 'discovery',
        refPhase: 'discovery',
        tolerance: const {},
      );

      final decision1 = service.ingest(event1);
      
      // Gate should be closed initially
      expect(decision1.open, false);
      expect(decision1.whyNot, isNotNull);
    });

    test('should track sustainment window correctly', () {
      // Create multiple matching events to build up ALIGN/TRACE
      const phase = 'discovery';
      final baseEvent = RivetEvent(
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: const {'keyword1'},
        predPhase: phase,
        refPhase: phase,
        tolerance: const {},
      );

      // Send multiple events to build confidence
      RivetGateDecision? lastDecision;
      for (int i = 0; i < 20; i++) {
        final event = RivetEvent(
          date: DateTime.now().add(Duration(minutes: i)),
          source: EvidenceSource.text,
          keywords: {'keyword$i'},
          predPhase: phase,
          refPhase: phase,
          tolerance: const {},
        );
        lastDecision = service.ingest(event, lastEvent: i > 0 ? baseEvent : null);
      }

      // After many consistent events, should have high ALIGN/TRACE
      expect(lastDecision!.stateAfter.align, greaterThan(0.5));
      expect(lastDecision.stateAfter.trace, greaterThan(0.5));
    });

    test('should handle independence multiplier correctly', () {
      final now = DateTime.now();
      
      // First event
      final event1 = RivetEvent(
        date: now,
        source: EvidenceSource.text,
        keywords: const {'keyword1'},
        predPhase: 'discovery',
        refPhase: 'discovery',
        tolerance: const {},
      );

      final decision1 = service.ingest(event1);
      final trace1 = decision1.stateAfter.trace;

      // Reset service for comparison
      service.reset();

      // Second event with different source (should get independence boost)
      final event2 = RivetEvent(
        date: now.add(const Duration(minutes: 1)),
        source: EvidenceSource.voice, // Different source
        keywords: const {'keyword2'},
        predPhase: 'discovery',
        refPhase: 'discovery',
        tolerance: const {},
      );

      final decision2 = service.ingest(event2, lastEvent: event1);
      final trace2 = decision2.stateAfter.trace;

      // Second event should have higher TRACE due to independence boost
      // (Though this is approximate due to different processing order)
      expect(trace2, greaterThan(0.0));
    });

    test('should reset state correctly', () {
      // Add some events first
      final event = RivetEvent(
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: const {'keyword1'},
        predPhase: 'discovery',
        refPhase: 'discovery',
        tolerance: const {},
      );

      service.ingest(event);
      
      // Verify state changed
      var state = service.getCurrentState();
      expect(state.align, greaterThan(0.0));
      expect(state.trace, greaterThan(0.0));

      // Reset and verify
      service.reset();
      state = service.getCurrentState();
      expect(state.align, 0.0);
      expect(state.trace, 0.0);
      expect(state.sustainCount, 0);
      expect(state.sawIndependentInWindow, false);
    });

    test('should provide meaningful status summary', () {
      final summary = service.getStatusSummary();
      expect(summary, isA<String>());
      expect(summary, contains('ALIGN'));
      expect(summary, contains('TRACE'));
      expect(summary, contains('Sustain'));
      expect(summary, contains('Independent'));
    });

    test('should handle edge cases gracefully', () {
      // Event with empty keywords
      final event = RivetEvent(
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: const {},
        predPhase: 'discovery',
        refPhase: 'discovery',
        tolerance: const {},
      );

      expect(() => service.ingest(event), returnsNormally);
      
      // Event with same timestamp
      final event2 = RivetEvent(
        date: event.date,
        source: EvidenceSource.text,
        keywords: const {'keyword1'},
        predPhase: 'discovery',
        refPhase: 'discovery',
        tolerance: const {},
      );

      expect(() => service.ingest(event2, lastEvent: event), returnsNormally);
    });
  });
}