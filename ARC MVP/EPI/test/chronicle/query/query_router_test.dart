import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/chronicle/query/query_router.dart';
import 'package:my_app/chronicle/models/query_plan.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';

void main() {
  group('ChronicleQueryRouter', () {
    late ChronicleQueryRouter router;

    setUp(() {
      router = ChronicleQueryRouter();
    });

    test('can be instantiated', () {
      expect(router, isNotNull);
    });

    test('selectLayers returns empty for specificRecall', () {
      // Test layer selection logic directly
      final layers = router.selectLayers(QueryIntent.specificRecall, 'test');
      expect(layers, isEmpty);
    });

    test('selectLayers returns monthly for temporal month query', () {
      final layers = router.selectLayers(
        QueryIntent.temporalQuery,
        'Tell me about my month',
      );
      expect(layers, contains(ChronicleLayer.monthly));
    });

    test('selectLayers returns yearly for temporal year query', () {
      final layers = router.selectLayers(
        QueryIntent.temporalQuery,
        'Tell me about my year',
      );
      expect(layers, contains(ChronicleLayer.yearly));
    });

    test('selectLayers returns multiple layers for patternIdentification', () {
      final layers = router.selectLayers(
        QueryIntent.patternIdentification,
        'What patterns do you see?',
      );
      expect(layers.length, greaterThan(1));
      expect(layers, contains(ChronicleLayer.monthly));
      expect(layers, contains(ChronicleLayer.yearly));
    });

    test('extractDateFilter extracts year from query', () {
      final filter = router.extractDateFilter('Tell me about 2024');
      expect(filter, isNotNull);
      expect(filter!.start.year, 2024);
      expect(filter.end.year, 2024);
    });

    test('shouldDrillDown returns true for evidence requests', () {
      final drillDown = router.shouldDrillDown(
        QueryIntent.patternIdentification,
        'Show me evidence of this pattern',
      );
      expect(drillDown, isTrue);
    });
  });
}
