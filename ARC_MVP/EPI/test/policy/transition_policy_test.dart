/// Comprehensive test suite for Transition Policy
/// 
/// Tests cover all decision paths, edge cases, and integration scenarios
/// for the unified ATLAS/RIVET/SENTINEL transition policy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/policy/transition_policy.dart';
// import 'package:my_app/prism/atlas/phase/phase_tracker.dart';
// import 'package:my_app/atlas/rivet/rivet_models.dart';
import 'package:my_app/prism/extractors/sentinel_risk_detector.dart';

void main() {
  group('TransitionPolicy', () {
    late TransitionPolicy policy;
    late TransitionPolicyConfig config;

    setUp(() {
      config = TransitionPolicyConfig.production;
      policy = TransitionPolicy(config);
    });

    group('Decision Logic', () {
      test('should promote when all conditions are met', () async {
        // Arrange
        final atlas = AtlasSnapshot(
          posteriorScores: {'Discovery': 0.3, 'Expansion': 0.7},
          margin: 0.65, // Above threshold
          currentPhase: 'Discovery',
          lastChangeAt: DateTime.now().subtract(const Duration(days: 10)),
          cooldownActive: false,
          hysteresisBlocked: false,
        );

        const rivet = RivetSnapshot(
          align: 0.65, // Above threshold
          trace: 0.65, // Above threshold
          sustainCount: 3, // Above threshold
          sawIndependentInWindow: true,
          independenceSet: {'day1-text', 'day2-voice'},
          noveltyScore: 0.15, // Below cap
          gateOpen: true,
        );

        final sentinel = SentinelSnapshot(
          riskBand: RiskLevel.low,
          patternSeverity: 0.2, // Below threshold
          sustainOk: true,
          activePatterns: [],
          riskScore: 0.2, // Below threshold
          lastAnalysisAt: DateTime.now(),
        );

        // Act
        final outcome = await policy.decide(
          atlas: atlas,
          rivet: rivet,
          sentinel: sentinel,
          cooldownActive: false,
        );

        // Assert
        expect(outcome.decision, TransitionDecision.promote);
        expect(outcome.reason, contains('All conditions satisfied'));
        expect(outcome.telemetry['all_conditions_met'], true);
        expect(outcome.telemetry['blocking_reasons'], isEmpty);
      });

      test('should hold when cooldown is active', () async {
        // Arrange
        final atlas = AtlasSnapshot(
          posteriorScores: {'Discovery': 0.3, 'Expansion': 0.7},
          margin: 0.65,
          currentPhase: 'Discovery',
          lastChangeAt: DateTime.now().subtract(const Duration(days: 1)),
          cooldownActive: true,
          hysteresisBlocked: false,
        );

        const rivet = RivetSnapshot(
          align: 0.65,
          trace: 0.65,
          sustainCount: 3,
          sawIndependentInWindow: true,
          independenceSet: {'day1-text'},
          noveltyScore: 0.15,
          gateOpen: true,
        );

        final sentinel = SentinelSnapshot(
          riskBand: RiskLevel.low,
          patternSeverity: 0.2,
          sustainOk: true,
          activePatterns: [],
          riskScore: 0.2,
          lastAnalysisAt: DateTime.now(),
        );

        // Act
        final outcome = await policy.decide(
          atlas: atlas,
          rivet: rivet,
          sentinel: sentinel,
          cooldownActive: true,
        );

        // Assert
        expect(outcome.decision, TransitionDecision.hold);
        expect(outcome.reason, contains('Cooldown active'));
        expect(outcome.telemetry['blocked_by'], 'cooldown');
      });

      test('should hold when ATLAS margin is insufficient', () async {
        // Arrange
        final atlas = AtlasSnapshot(
          posteriorScores: {'Discovery': 0.4, 'Expansion': 0.6},
          margin: 0.2, // Below threshold
          currentPhase: 'Discovery',
          lastChangeAt: DateTime.now().subtract(const Duration(days: 10)),
          cooldownActive: false,
          hysteresisBlocked: false,
        );

        const rivet = RivetSnapshot(
          align: 0.65,
          trace: 0.65,
          sustainCount: 3,
          sawIndependentInWindow: true,
          independenceSet: {'day1-text'},
          noveltyScore: 0.15,
          gateOpen: true,
        );

        final sentinel = SentinelSnapshot(
          riskBand: RiskLevel.low,
          patternSeverity: 0.2,
          sustainOk: true,
          activePatterns: [],
          riskScore: 0.2,
          lastAnalysisAt: DateTime.now(),
        );

        // Act
        final outcome = await policy.decide(
          atlas: atlas,
          rivet: rivet,
          sentinel: sentinel,
          cooldownActive: false,
        );

        // Assert
        expect(outcome.decision, TransitionDecision.hold);
        expect(outcome.reason, contains('ATLAS margin insufficient'));
        expect(outcome.telemetry['blocking_reasons'], contains('ATLAS margin insufficient'));
      });

      test('should hold when RIVET thresholds are not met', () async {
        // Arrange
        final atlas = AtlasSnapshot(
          posteriorScores: {'Discovery': 0.3, 'Expansion': 0.7},
          margin: 0.65,
          currentPhase: 'Discovery',
          lastChangeAt: DateTime.now().subtract(const Duration(days: 10)),
          cooldownActive: false,
          hysteresisBlocked: false,
        );

        const rivet = RivetSnapshot(
          align: 0.5, // Below threshold
          trace: 0.5, // Below threshold
          sustainCount: 1, // Below threshold
          sawIndependentInWindow: false,
          independenceSet: {},
          noveltyScore: 0.15,
          gateOpen: false,
        );

        final sentinel = SentinelSnapshot(
          riskBand: RiskLevel.low,
          patternSeverity: 0.2,
          sustainOk: true,
          activePatterns: [],
          riskScore: 0.2,
          lastAnalysisAt: DateTime.now(),
        );

        // Act
        final outcome = await policy.decide(
          atlas: atlas,
          rivet: rivet,
          sentinel: sentinel,
          cooldownActive: false,
        );

        // Assert
        expect(outcome.decision, TransitionDecision.hold);
        expect(outcome.reason, contains('RIVET'));
        expect(outcome.telemetry['blocking_reasons'], anyOf(
          contains('RIVET ALIGN insufficient'),
          contains('RIVET TRACE insufficient'),
          contains('RIVET sustainment insufficient'),
        ));
      });

      test('should hold when SENTINEL risk is too high', () async {
        // Arrange
        final atlas = AtlasSnapshot(
          posteriorScores: {'Discovery': 0.3, 'Expansion': 0.7},
          margin: 0.65,
          currentPhase: 'Discovery',
          lastChangeAt: DateTime.now().subtract(const Duration(days: 10)),
          cooldownActive: false,
          hysteresisBlocked: false,
        );

        const rivet = RivetSnapshot(
          align: 0.65,
          trace: 0.65,
          sustainCount: 3,
          sawIndependentInWindow: true,
          independenceSet: {'day1-text'},
          noveltyScore: 0.15,
          gateOpen: true,
        );

        final sentinel = SentinelSnapshot(
          riskBand: RiskLevel.elevated, // High risk
          patternSeverity: 0.5, // Above threshold
          sustainOk: false,
          activePatterns: [
            const RiskPattern(
              type: 'escalating_distress',
              description: 'Increasing negative patterns',
              severity: 0.8,
              affectedDates: [],
              triggerKeywords: ['anxiety', 'stress'],
            ),
          ],
          riskScore: 0.5, // Above threshold
          lastAnalysisAt: DateTime.now(),
        );

        // Act
        final outcome = await policy.decide(
          atlas: atlas,
          rivet: rivet,
          sentinel: sentinel,
          cooldownActive: false,
        );

        // Assert
        expect(outcome.decision, TransitionDecision.hold);
        expect(outcome.reason, contains('SENTINEL'));
        expect(outcome.telemetry['blocking_reasons'], anyOf(
          contains('SENTINEL risk too high'),
          contains('SENTINEL risk band too high'),
          contains('SENTINEL pattern severity too high'),
          contains('SENTINEL risk not sustained'),
        ));
      });

      test('should hold when novelty score is too high', () async {
        // Arrange
        final atlas = AtlasSnapshot(
          posteriorScores: {'Discovery': 0.3, 'Expansion': 0.7},
          margin: 0.65,
          currentPhase: 'Discovery',
          lastChangeAt: DateTime.now().subtract(const Duration(days: 10)),
          cooldownActive: false,
          hysteresisBlocked: false,
        );

        const rivet = RivetSnapshot(
          align: 0.65,
          trace: 0.65,
          sustainCount: 3,
          sawIndependentInWindow: true,
          independenceSet: {'day1-text'},
          noveltyScore: 0.3, // Above cap
          gateOpen: true,
        );

        final sentinel = SentinelSnapshot(
          riskBand: RiskLevel.low,
          patternSeverity: 0.2,
          sustainOk: true,
          activePatterns: [],
          riskScore: 0.2,
          lastAnalysisAt: DateTime.now(),
        );

        // Act
        final outcome = await policy.decide(
          atlas: atlas,
          rivet: rivet,
          sentinel: sentinel,
          cooldownActive: false,
        );

        // Assert
        expect(outcome.decision, TransitionDecision.hold);
        expect(outcome.reason, contains('Novelty score too high'));
        expect(outcome.telemetry['blocking_reasons'], contains('Novelty score too high'));
      });
    });

    group('Risk Decay', () {
      test('should apply risk decay based on time', () {
        // Arrange
        final policy = TransitionPolicy(const TransitionPolicyConfig(
          riskDecayRate: 0.1, // 10% decay per day
        ));

        const riskScore = 0.5;
        final lastAnalysisAt = DateTime.now().subtract(const Duration(days: 2));

        // Act
        final adjustedScore = policy.applyRiskDecay(riskScore, lastAnalysisAt);

        // Assert
        // After 2 days: 0.5 * exp(-0.1 * 2) = 0.5 * exp(-0.2) ≈ 0.409
        expect(adjustedScore, closeTo(0.409, 0.01));
      });

      test('should not decay risk if analysis is recent', () {
        // Arrange
        final policy = TransitionPolicy(const TransitionPolicyConfig(
          riskDecayRate: 0.1,
        ));

        const riskScore = 0.5;
        final lastAnalysisAt = DateTime.now().subtract(const Duration(hours: 1));

        // Act
        final adjustedScore = policy.applyRiskDecay(riskScore, lastAnalysisAt);

        // Assert
        // After 1 hour: 0.5 * exp(-0.1 * 0.04) ≈ 0.5
        expect(adjustedScore, closeTo(0.5, 0.01));
      });
    });

    group('Configuration Validation', () {
      test('should validate production configuration', () {
        // Act
        final errors = TransitionPolicyValidator.validateConfig(
          TransitionPolicyConfig.production,
        );

        // Assert
        expect(errors, isEmpty);
      });

      test('should detect invalid threshold ranges', () {
        // Arrange
        const invalidConfig = TransitionPolicyConfig(
          atlasMargin: 1.5, // Invalid: > 1.0
          rivetAlign: -0.1, // Invalid: < 0.0
          riskThreshold: 2.0, // Invalid: > 1.0
        );

        // Act
        final errors = TransitionPolicyValidator.validateConfig(invalidConfig);

        // Assert
        expect(errors, isNotEmpty);
        expect(errors, contains('ATLAS margin must be between 0.0 and 1.0'));
        expect(errors, contains('RIVET ALIGN threshold must be between 0.0 and 1.0'));
        expect(errors, contains('Risk threshold must be between 0.0 and 1.0'));
      });

      test('should check production safety', () {
        // Act
        final isSafe = TransitionPolicyValidator.isProductionSafe(
          TransitionPolicyConfig.production,
        );

        // Assert
        expect(isSafe, true);
      });

      test('should reject unsafe configurations', () {
        // Arrange
        const unsafeConfig = TransitionPolicyConfig(
          atlasMargin: 0.3, // Too permissive
          rivetAlign: 0.3, // Too permissive
          riskThreshold: 0.8, // Too restrictive
          sustainW: 1, // Too permissive
        );

        // Act
        final isSafe = TransitionPolicyValidator.isProductionSafe(unsafeConfig);

        // Assert
        expect(isSafe, false);
      });
    });

    group('Factory Methods', () {
      test('should create production policy', () {
        // Act
        final policy = TransitionPolicyFactory.createProduction();

        // Assert
        expect(policy.config.atlasMargin, 0.62);
        expect(policy.config.rivetAlign, 0.60);
        expect(policy.config.riskThreshold, 0.3);
      });

      test('should create conservative policy', () {
        // Act
        final policy = TransitionPolicyFactory.createConservative();

        // Assert
        expect(policy.config.atlasMargin, 0.65);
        expect(policy.config.rivetAlign, 0.65);
        expect(policy.config.riskThreshold, 0.2);
      });

      test('should create aggressive policy', () {
        // Act
        final policy = TransitionPolicyFactory.createAggressive();

        // Assert
        expect(policy.config.atlasMargin, 0.58);
        expect(policy.config.rivetAlign, 0.55);
        expect(policy.config.riskThreshold, 0.4);
      });

      test('should create custom policy', () {
        // Arrange
        const customConfig = TransitionPolicyConfig(
          atlasMargin: 0.7,
          rivetAlign: 0.8,
        );

        // Act
        final policy = TransitionPolicyFactory.createCustom(customConfig);

        // Assert
        expect(policy.config.atlasMargin, 0.7);
        expect(policy.config.rivetAlign, 0.8);
      });
    });

    group('Telemetry', () {
      test('should include comprehensive telemetry', () async {
        // Arrange
        final atlas = AtlasSnapshot(
          posteriorScores: {'Discovery': 0.3, 'Expansion': 0.7},
          margin: 0.65,
          currentPhase: 'Discovery',
          lastChangeAt: DateTime.now().subtract(const Duration(days: 10)),
          cooldownActive: false,
          hysteresisBlocked: false,
        );

        const rivet = RivetSnapshot(
          align: 0.65,
          trace: 0.65,
          sustainCount: 3,
          sawIndependentInWindow: true,
          independenceSet: {'day1-text'},
          noveltyScore: 0.15,
          gateOpen: true,
        );

        final sentinel = SentinelSnapshot(
          riskBand: RiskLevel.low,
          patternSeverity: 0.2,
          sustainOk: true,
          activePatterns: [],
          riskScore: 0.2,
          lastAnalysisAt: DateTime.now(),
        );

        // Act
        final outcome = await policy.decide(
          atlas: atlas,
          rivet: rivet,
          sentinel: sentinel,
          cooldownActive: false,
        );

        // Assert
        expect(outcome.telemetry, containsPair('timestamp', isA<String>()));
        expect(outcome.telemetry, containsPair('config', isA<Map<String, dynamic>>()));
        expect(outcome.telemetry, containsPair('atlas', isA<Map<String, dynamic>>()));
        expect(outcome.telemetry, containsPair('rivet', isA<Map<String, dynamic>>()));
        expect(outcome.telemetry, containsPair('sentinel', isA<Map<String, dynamic>>()));
        expect(outcome.telemetry, containsPair('decision', isA<String>()));
        expect(outcome.telemetry, containsPair('all_conditions_met', isA<bool>()));
      });
    });
  });
}
