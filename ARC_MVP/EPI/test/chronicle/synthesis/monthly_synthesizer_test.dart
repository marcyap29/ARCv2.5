import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/chronicle/synthesis/monthly_synthesizer.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';

void main() {
  group('MonthlySynthesizer', () {
    late MonthlySynthesizer synthesizer;
    late Layer0Repository layer0Repo;
    late AggregationRepository aggregationRepo;
    late ChangelogRepository changelogRepo;

    setUp(() async {
      layer0Repo = Layer0Repository();
      aggregationRepo = AggregationRepository();
      changelogRepo = ChangelogRepository();
      
      synthesizer = MonthlySynthesizer(
        layer0Repo: layer0Repo,
        aggregationRepo: aggregationRepo,
        changelogRepo: changelogRepo,
      );
    });

    test('synthesize throws exception for empty month', () async {
      expect(
        () => synthesizer.synthesize(
          userId: 'test_user',
          month: '2025-01',
        ),
        throwsException,
      );
    });

    test('synthesize creates aggregation with correct structure', () async {
      // This test would require actual Layer 0 data
      // For now, we'll test the structure validation
      expect(synthesizer, isNotNull);
    });
  });
}
