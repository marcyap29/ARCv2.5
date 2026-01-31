import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_app/chronicle/scheduling/synthesis_scheduler.dart';
import 'package:my_app/chronicle/synthesis/synthesis_engine.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';

import 'synthesis_scheduler_test.mocks.dart';

@GenerateMocks([
  SynthesisEngine,
  ChangelogRepository,
  AggregationRepository,
  Layer0Repository,
])
void main() {
  group('SynthesisScheduler', () {
    late MockSynthesisEngine mockSynthesisEngine;
    late MockChangelogRepository mockChangelogRepo;
    late MockAggregationRepository mockAggregationRepo;
    late MockLayer0Repository mockLayer0Repo;
    late SynthesisScheduler scheduler;

    setUp(() {
      mockSynthesisEngine = MockSynthesisEngine();
      mockChangelogRepo = MockChangelogRepository();
      mockAggregationRepo = MockAggregationRepository();
      mockLayer0Repo = MockLayer0Repository();

      final cadence = SynthesisCadence.forTier(SynthesisTier.premium);
      scheduler = SynthesisScheduler(
        synthesisEngine: mockSynthesisEngine,
        changelogRepo: mockChangelogRepo,
        aggregationRepo: mockAggregationRepo,
        layer0Repo: mockLayer0Repo,
        cadence: cadence,
        userId: 'test_user',
      );
    });

    test('getNextSynthesisTime returns next scheduled time', () {
      final nextTime = scheduler.getNextSynthesisTime();
      expect(nextTime, isNotNull);
      expect(nextTime!.isAfter(DateTime.now()), isTrue);
    });

    test('SynthesisCadence.forTier returns correct cadence for premium tier', () {
      final cadence = SynthesisCadence.forTier(SynthesisTier.premium);
      expect(cadence.enableMonthly, isTrue);
      expect(cadence.enableYearly, isTrue);
      expect(cadence.enableMultiYear, isFalse);
      expect(cadence.layer0RetentionDays, 90);
    });

    test('SynthesisCadence.forTier returns correct cadence for free tier', () {
      final cadence = SynthesisCadence.forTier(SynthesisTier.free);
      expect(cadence.enableMonthly, isFalse);
      expect(cadence.enableYearly, isFalse);
      expect(cadence.enableMultiYear, isFalse);
      expect(cadence.layer0RetentionDays, 0);
    });
  });
}
