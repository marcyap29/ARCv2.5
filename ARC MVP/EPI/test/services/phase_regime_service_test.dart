// test/services/phase_regime_service_test.dart
// Unit tests for PhaseRegimeService

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('PhaseRegimeService', () {
    late PhaseRegimeService service;
    late MockAnalyticsService mockAnalytics;

    setUp(() {
      mockAnalytics = MockAnalyticsService();
      service = PhaseRegimeService(mockAnalytics, null); // TODO: Add RivetSweepService
    });

    test('should create phase regime', () async {
      // Given
      const label = PhaseLabel.discovery;
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);

      // When
      final regime = await service.createRegime(
        label: label,
        start: start,
        end: end,
        source: PhaseSource.user,
      );

      // Then
      expect(regime.label, equals(label));
      expect(regime.start, equals(start));
      expect(regime.end, equals(end));
      expect(regime.source, equals(PhaseSource.user));
      expect(regime.isOngoing, isFalse);
    });

    test('should create ongoing regime', () async {
      // Given
      const label = PhaseLabel.expansion;
      final start = DateTime.now();

      // When
      final regime = await service.createRegime(
        label: label,
        start: start,
        source: PhaseSource.user,
      );

      // Then
      expect(regime.label, equals(label));
      expect(regime.start, equals(start));
      expect(regime.end, isNull);
      expect(regime.isOngoing, isTrue);
    });

    test('should get current phase', () {
      // Given
      final now = DateTime.now();
      service.createRegime(
        label: PhaseLabel.consolidation,
        start: now.subtract(const Duration(days: 1)),
        source: PhaseSource.user,
      );

      // When
      final currentPhase = service.currentPhase;

      // Then
      expect(currentPhase, equals(PhaseLabel.consolidation));
    });

    test('should get phase for timestamp', () {
      // Given
      final regimeStart = DateTime(2024, 1, 1);
      final regimeEnd = DateTime(2024, 1, 31);
      service.createRegime(
        label: PhaseLabel.transition,
        start: regimeStart,
        end: regimeEnd,
        source: PhaseSource.user,
      );

      // When
      final phaseInRange = service.getPhaseFor(DateTime(2024, 1, 15));
      final phaseOutOfRange = service.getPhaseFor(DateTime(2024, 2, 1));

      // Then
      expect(phaseInRange, equals(PhaseLabel.transition));
      expect(phaseOutOfRange, isNull);
    });

    test('should change current phase', () async {
      // Given
      final now = DateTime.now();
      service.createRegime(
        label: PhaseLabel.discovery,
        start: now.subtract(const Duration(days: 1)),
        source: PhaseSource.user,
      );

      // When
      final newRegime = await service.changeCurrentPhase(PhaseLabel.expansion);

      // Then
      expect(newRegime.label, equals(PhaseLabel.expansion));
      expect(newRegime.source, equals(PhaseSource.user));
      expect(newRegime.isOngoing, isTrue);
    });

    test('should export for MCP', () {
      // Given
      service.createRegime(
        label: PhaseLabel.breakthrough,
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 31),
        source: PhaseSource.rivet,
        confidence: 0.85,
      );

      // When
      final exportData = service.exportForMcp();

      // Then
      expect(exportData, contains('phase_regimes'));
      expect(exportData, contains('exported_at'));
      expect(exportData, contains('version'));
    });
  });

  group('PhaseIndex', () {
    test('should find regime for timestamp', () {
      // Given
      final regimes = [
        PhaseRegime(
          id: '1',
          label: PhaseLabel.discovery,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 31),
          source: PhaseSource.user,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PhaseRegime(
          id: '2',
          label: PhaseLabel.expansion,
          start: DateTime(2024, 2, 1),
          end: DateTime(2024, 2, 28),
          source: PhaseSource.user,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // When
      final index = PhaseIndex(regimes);
      final regime1 = index.regimeFor(DateTime(2024, 1, 15));
      final regime2 = index.regimeFor(DateTime(2024, 2, 15));
      final noRegime = index.regimeFor(DateTime(2024, 3, 15));

      // Then
      expect(regime1?.label, equals(PhaseLabel.discovery));
      expect(regime2?.label, equals(PhaseLabel.expansion));
      expect(noRegime, isNull);
    });

    test('should get phase for timestamp', () {
      // Given
      final regimes = [
        PhaseRegime(
          id: '1',
          label: PhaseLabel.consolidation,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 31),
          source: PhaseSource.user,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // When
      final index = PhaseIndex(regimes);
      final phase = index.phaseFor(DateTime(2024, 1, 15));

      // Then
      expect(phase, equals(PhaseLabel.consolidation));
    });

    test('should find regimes needing attention', () {
      // Given
      final now = DateTime.now();
      final regimes = [
        PhaseRegime(
          id: '1',
          label: PhaseLabel.discovery,
          start: now.subtract(const Duration(days: 90)), // Long ongoing
          source: PhaseSource.user,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PhaseRegime(
          id: '2',
          label: PhaseLabel.expansion,
          start: now.subtract(const Duration(days: 30)),
          end: now.subtract(const Duration(days: 1)),
          source: PhaseSource.rivet,
          confidence: 0.3, // Low confidence
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // When
      final index = PhaseIndex(regimes);
      final needingAttention = index.findRegimesNeedingAttention();

      // Then
      expect(needingAttention.length, equals(2));
    });
  });
}
