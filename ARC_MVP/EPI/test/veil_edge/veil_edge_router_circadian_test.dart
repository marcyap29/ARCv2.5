/// Tests for VEIL-EDGE Router with AURORA Integration
/// 
/// Tests for time-aware policy weights and circadian routing
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/veil_edge/core/veil_edge_router.dart';
import 'package:my_app/lumara/veil_edge/models/veil_edge_models.dart';

void main() {
  group('VeilEdgeRouter with AURORA', () {
    late VeilEdgeRouter router;

    setUp(() {
      router = VeilEdgeRouter();
    });

    group('time-aware routing', () {
      test('should apply evening weights correctly', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'evening',
          circadianChronotype: 'evening',
          rhythmScore: 0.6,
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'ok',
        );

        final result = router.route(input);

        expect(result.blocks, contains('Mirror'));
        expect(result.blocks, contains('Log'));
        expect(result.metadata['circadian_window'], 'evening');
        expect(result.metadata['circadian_chronotype'], 'evening');
        expect(result.metadata['rhythm_score'], 0.6);
      });

      test('should apply morning weights correctly', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'morning',
          circadianChronotype: 'morning',
          rhythmScore: 0.8,
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'ok',
        );

        final result = router.route(input);

        expect(result.blocks, contains('Mirror'));
        expect(result.blocks, contains('Log'));
        expect(result.metadata['circadian_window'], 'morning');
      });

      test('should apply afternoon weights correctly', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'afternoon',
          circadianChronotype: 'balanced',
          rhythmScore: 0.7,
          rivetAlign: 0.6,
          rivetStability: 0.5,
          sentinelState: 'ok',
        );

        final result = router.route(input);

        expect(result.blocks, contains('Mirror'));
        expect(result.blocks, contains('Log'));
        expect(result.metadata['circadian_window'], 'afternoon');
      });

      test('should reduce Commit in evening with fragmented rhythm', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'evening',
          circadianChronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented rhythm
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'ok',
        );

        final result = router.route(input);

        // Commit should be reduced or removed due to fragmented evening rhythm
        expect(result.blocks, isNot(contains('Commit')));
        expect(result.metadata['rhythm_score'], 0.3);
      });

      test('should enforce SENTINEL constraints regardless of time', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'morning',
          circadianChronotype: 'morning',
          rhythmScore: 0.8,
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'alert',
        );

        final result = router.route(input);

        // Should only have Mirror, Safeguard, and Log in alert mode
        expect(result.blocks, contains('Mirror'));
        expect(result.blocks, contains('Safeguard'));
        expect(result.blocks, contains('Log'));
        expect(result.blocks.length, 3);
        expect(result.variant, ':alert');
      });

      test('should apply RIVET policy constraints', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'morning',
          circadianChronotype: 'morning',
          rhythmScore: 0.8,
          rivetAlign: 0.3, // Low alignment
          rivetStability: 0.4, // Low stability
          sentinelState: 'ok',
        );

        final result = router.route(input);

        // Should force safe variant due to low alignment
        expect(result.variant, ':safe');
      });
    });

    group('policy hooks', () {
      test('should allow Commit in morning with good conditions', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'morning',
          circadianChronotype: 'morning',
          rhythmScore: 0.8,
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'ok',
          lastSwitchHoursAgo: 50, // Past cooldown
        );

        final canCommit = router.allowCommitNow(input);

        expect(canCommit, true);
      });

      test('should deny Commit in evening with fragmented rhythm', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'evening',
          circadianChronotype: 'balanced',
          rhythmScore: 0.3, // Fragmented rhythm
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'ok',
          lastSwitchHoursAgo: 50,
        );

        final canCommit = router.allowCommitNow(input);

        expect(canCommit, false);
      });

      test('should deny Commit with low RIVET scores', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'morning',
          circadianChronotype: 'morning',
          rhythmScore: 0.8,
          rivetAlign: 0.5, // Below threshold
          rivetStability: 0.4, // Below threshold
          sentinelState: 'ok',
          lastSwitchHoursAgo: 50,
        );

        final canCommit = router.allowCommitNow(input);

        expect(canCommit, false);
      });

      test('should deny Commit with SENTINEL alert', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'morning',
          circadianChronotype: 'morning',
          rhythmScore: 0.8,
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'alert',
          lastSwitchHoursAgo: 50,
        );

        final canCommit = router.allowCommitNow(input);

        expect(canCommit, false);
      });

      test('should deny Commit during cooldown period', () {
        final input = _createVeilEdgeInput(
          circadianWindow: 'morning',
          circadianChronotype: 'morning',
          rhythmScore: 0.8,
          rivetAlign: 0.7,
          rivetStability: 0.6,
          sentinelState: 'ok',
          lastSwitchHoursAgo: 24, // Within cooldown
        );

        final canCommit = router.allowCommitNow(input);

        expect(canCommit, false);
      });
    });

    group('circadian context properties', () {
      test('should correctly identify time windows', () {
        final morningInput = _createVeilEdgeInput(circadianWindow: 'morning');
        final afternoonInput = _createVeilEdgeInput(circadianWindow: 'afternoon');
        final eveningInput = _createVeilEdgeInput(circadianWindow: 'evening');

        expect(morningInput.isMorning, true);
        expect(morningInput.isAfternoon, false);
        expect(morningInput.isEvening, false);

        expect(afternoonInput.isMorning, false);
        expect(afternoonInput.isAfternoon, true);
        expect(afternoonInput.isEvening, false);

        expect(eveningInput.isMorning, false);
        expect(eveningInput.isAfternoon, false);
        expect(eveningInput.isEvening, true);
      });

      test('should correctly identify rhythm coherence', () {
        final fragmentedInput = _createVeilEdgeInput(rhythmScore: 0.3);
        final coherentInput = _createVeilEdgeInput(rhythmScore: 0.7);

        expect(fragmentedInput.isRhythmFragmented, true);
        expect(fragmentedInput.isRhythmCoherent, false);

        expect(coherentInput.isRhythmFragmented, false);
        expect(coherentInput.isRhythmCoherent, true);
      });

      test('should correctly identify chronotypes', () {
        final morningPersonInput = _createVeilEdgeInput(circadianChronotype: 'morning');
        final eveningPersonInput = _createVeilEdgeInput(circadianChronotype: 'evening');

        expect(morningPersonInput.isMorningPerson, true);
        expect(morningPersonInput.isEveningPerson, false);

        expect(eveningPersonInput.isMorningPerson, false);
        expect(eveningPersonInput.isEveningPerson, true);
      });
    });
  });
}

/// Helper function to create a VeilEdgeInput for testing
VeilEdgeInput _createVeilEdgeInput({
  String circadianWindow = 'morning',
  String circadianChronotype = 'balanced',
  double rhythmScore = 0.5,
  String atlasPhase = 'Discovery',
  double atlasConfidence = 0.7,
  String atlasNeighbor = 'Transition',
  double rivetAlign = 0.6,
  double rivetStability = 0.5,
  int lastSwitchHoursAgo = 50,
  String sentinelState = 'ok',
  List<String> sentinelNotes = const [],
}) {
  final now = DateTime.now();
  final lastSwitch = now.subtract(Duration(hours: lastSwitchHoursAgo));

  return VeilEdgeInput(
    atlas: AtlasState(
      phase: atlasPhase,
      confidence: atlasConfidence,
      neighbor: atlasNeighbor,
    ),
    rivet: RivetState(
      align: rivetAlign,
      stability: rivetStability,
      windowDays: 7,
      lastSwitchTimestamp: lastSwitch,
    ),
    sentinel: SentinelState(
      state: sentinelState,
      notes: sentinelNotes,
    ),
    signals: SignalExtraction(
      signals: UserSignals(
        actions: ['test'],
        feelings: ['neutral'],
        words: ['test'],
        outcomes: ['test'],
      ),
    ),
    circadianWindow: circadianWindow,
    circadianChronotype: circadianChronotype,
    rhythmScore: rhythmScore,
  );
}
