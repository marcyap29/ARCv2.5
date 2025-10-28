/// Tests for RIVET Policy Engine with AURORA Integration
/// 
/// Tests for circadian-aware policy violations and recommendations

import 'package:flutter_test/flutter_test.dart';
import '../../lib/lumara/veil_edge/core/rivet_policy_engine.dart';
import '../../lib/lumara/veil_edge/models/veil_edge_models.dart';
import '../../lib/aurora/models/circadian_context.dart';

void main() {
  group('RivetPolicyEngine with AURORA', () {
    late RivetPolicyEngine engine;

    setUp(() {
      engine = RivetPolicyEngine();
    });

    group('circadian-aware alignment calculation', () {
      test('should apply evening fragmented rhythm adjustment', () {
        final log = _createLogSchema(ease: 4, mood: 4, energy: 4);
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented
        );

        final alignment = engine.calculateAlignment(log, circadianContext: circadianContext);

        // Should be slightly reduced due to fragmented evening rhythm
        expect(alignment, lessThan(0.8)); // Base would be ~0.8
      });

      test('should apply morning person boost', () {
        final log = _createLogSchema(ease: 4, mood: 4, energy: 4);
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'morning',
          rhythmScore: 0.7,
        );

        final alignment = engine.calculateAlignment(log, circadianContext: circadianContext);

        // Should be slightly boosted for morning person in morning
        expect(alignment, greaterThan(0.8)); // Base would be ~0.8
      });

      test('should apply evening person boost', () {
        final log = _createLogSchema(ease: 4, mood: 4, energy: 4);
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'evening',
          rhythmScore: 0.7,
        );

        final alignment = engine.calculateAlignment(log, circadianContext: circadianContext);

        // Should be slightly boosted for evening person in evening
        expect(alignment, greaterThan(0.8)); // Base would be ~0.8
      });

      test('should not apply adjustments without circadian context', () {
        final log = _createLogSchema(ease: 4, mood: 4, energy: 4);

        final alignment = engine._calculateAlignment(log);

        // Should be base alignment without adjustments
        expect(alignment, closeTo(0.8, 0.1));
      });
    });

    group('circadian-aware policy violations', () {
      test('should adjust threshold for fragmented evening rhythm', () {
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented
        );

        // Add logs with alignment just above normal threshold but below evening threshold
        engine.processLog(_createLogSchema(ease: 2, mood: 2, energy: 2), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 2, mood: 2, energy: 2), circadianContext: circadianContext);

        final violations = engine.checkPolicyViolations(circadianContext);

        expect(violations, contains('low_alignment'));
        expect(violations, contains('circadian_adjusted_threshold'));
      });

      test('should adjust threshold for morning person in morning', () {
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'morning',
          rhythmScore: 0.7,
        );

        // Add logs with alignment above normal threshold
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);

        final violations = engine.checkPolicyViolations(circadianContext);

        // Should not have low alignment violation due to adjusted threshold
        expect(violations, isNot(contains('low_alignment')));
      });

      test('should adjust phase change threshold for evening fragmented rhythm', () {
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented
        );

        // Add logs with alignment above normal threshold but below evening threshold
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);

        final violations = engine.checkPolicyViolations(circadianContext);

        expect(violations, contains('insufficient_alignment_for_phase_change'));
        expect(violations, contains('circadian_adjusted_phase_change_threshold'));
      });

      test('should adjust phase change threshold for morning person in morning', () {
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'morning',
          rhythmScore: 0.7,
        );

        // Add logs with alignment above normal threshold
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);

        final violations = engine.checkPolicyViolations(circadianContext);

        // Should not have phase change violation due to adjusted threshold
        expect(violations, isNot(contains('insufficient_alignment_for_phase_change')));
      });
    });

    group('circadian-aware recommendations', () {
      test('should provide evening-specific recommendations for fragmented rhythm', () {
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented
        );

        engine.processLog(_createLogSchema(ease: 2, mood: 2, energy: 2), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 2, mood: 2, energy: 2), circadianContext: circadianContext);

        final violations = engine.checkPolicyViolations(circadianContext);
        final recommendations = engine.generateRecommendations(0.3, 0.4, violations, circadianContext);

        expect(recommendations, contains('Force safe variant - evening rhythm fragmentation detected'));
        expect(recommendations, contains('Consider establishing more consistent daily rhythms'));
      });

      test('should provide morning-specific recommendations', () {
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'evening', // Mismatch
          rhythmScore: 0.6,
        );

        final recommendations = engine._generateRecommendations(0.4, 0.5, ['low_alignment'], circadianContext);

        expect(recommendations, contains('Consider adjusting morning activities to match your chronotype'));
      });

      test('should provide evening-specific recommendations', () {
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'morning', // Mismatch
          rhythmScore: 0.6,
        );

        final recommendations = engine._generateRecommendations(0.4, 0.5, ['low_alignment'], circadianContext);

        expect(recommendations, contains('Consider adjusting evening activities to match your chronotype'));
      });

      test('should provide gentle evening recommendations', () {
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'balanced',
          rhythmScore: 0.6,
        );

        final recommendations = engine._generateRecommendations(0.4, 0.5, ['low_alignment'], circadianContext);

        expect(recommendations, contains('Consider gentle restorative activities appropriate for evening'));
      });

      test('should provide rhythm coherence recommendations', () {
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented
        );

        final recommendations = engine._generateRecommendations(0.5, 0.4, [], circadianContext);

        expect(recommendations, contains('Focus on stabilizing current practices - rhythm coherence needed'));
      });
    });

    group('circadian-aware phase change policy', () {
      test('should allow phase change for morning person in morning', () {
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'morning',
          rhythmScore: 0.7,
        );

        // Add logs with good alignment
        engine.processLog(_createLogSchema(ease: 4, mood: 4, energy: 4), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 4, mood: 4, energy: 4), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 4, mood: 4, energy: 4), circadianContext: circadianContext);

        final canChange = engine.canChangePhase(circadianContext: circadianContext);

        expect(canChange, true);
      });

      test('should deny phase change for evening fragmented rhythm', () {
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented
        );

        // Add logs with good alignment
        engine.processLog(_createLogSchema(ease: 4, mood: 4, energy: 4), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 4, mood: 4, energy: 4), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 4, mood: 4, energy: 4), circadianContext: circadianContext);

        final canChange = engine.canChangePhase(circadianContext: circadianContext);

        expect(canChange, false);
      });

      test('should adjust threshold for evening fragmented rhythm', () {
        final circadianContext = CircadianContext(
          window: 'evening',
          chronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented
        );

        // Add logs with alignment above normal threshold but below evening threshold
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);

        final canChange = engine.canChangePhase(circadianContext: circadianContext);

        expect(canChange, false);
      });

      test('should adjust threshold for morning person in morning', () {
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'morning',
          rhythmScore: 0.7,
        );

        // Add logs with alignment above normal threshold
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);
        engine.processLog(_createLogSchema(ease: 3, mood: 3, energy: 3), circadianContext: circadianContext);

        final canChange = engine.canChangePhase(circadianContext: circadianContext);

        expect(canChange, true);
      });
    });

    group('processLog with circadian context', () {
      test('should include circadian context in response', () {
        final log = _createLogSchema(ease: 4, mood: 4, energy: 4);
        final circadianContext = CircadianContext(
          window: 'morning',
          chronotype: 'morning',
          rhythmScore: 0.8,
        );

        final update = engine.processLog(log, circadianContext: circadianContext);

        expect(update.rivetUpdates['circadian_context'], isNotNull);
        expect(update.rivetUpdates['circadian_context']['window'], 'morning');
        expect(update.rivetUpdates['circadian_context']['chronotype'], 'morning');
        expect(update.rivetUpdates['circadian_context']['rhythm_score'], 0.8);
      });

      test('should not include circadian context when not provided', () {
        final log = _createLogSchema(ease: 4, mood: 4, energy: 4);

        final update = engine.processLog(log);

        expect(update.rivetUpdates['circadian_context'], isNull);
      });
    });
  });
}

/// Helper function to create a LogSchema for testing
LogSchema _createLogSchema({
  required int ease,
  required int mood,
  required int energy,
}) {
  return LogSchema(
    timestamp: DateTime.now(),
    phaseGroup: 'D-B',
    blocksUsed: ['Mirror', 'Orient'],
    action: 'test',
    outcomeMetric: {'name': 'test', 'value': 5.0, 'unit': 'score'},
    ease: ease,
    mood: mood,
    energy: energy,
    note: 'Test log entry',
    sentinelState: 'ok',
  );
}
