import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/chronicle/synthesis/yearly_synthesizer.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/models/chronicle_aggregation.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';

void main() {
  group('YearlySynthesizer', () {
    late YearlySynthesizer synthesizer;
    late AggregationRepository aggregationRepo;
    late ChangelogRepository changelogRepo;

    setUp(() {
      aggregationRepo = AggregationRepository();
      changelogRepo = ChangelogRepository();
      
      synthesizer = YearlySynthesizer(
        aggregationRepo: aggregationRepo,
        changelogRepo: changelogRepo,
      );
    });

    test('synthesize throws exception for insufficient months', () async {
      expect(
        () => synthesizer.synthesize(
          userId: 'test_user',
          year: '2025',
        ),
        throwsException,
      );
    });

    test('can be instantiated', () {
      expect(synthesizer, isNotNull);
    });
  });
}
