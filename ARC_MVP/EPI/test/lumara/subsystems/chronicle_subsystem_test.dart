import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/models/command_intent.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/subsystems/chronicle_subsystem.dart';
import 'package:my_app/chronicle/query/query_router.dart';
import 'package:my_app/chronicle/query/context_builder.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';

void main() {
  late ChronicleQueryRouter router;
  late ChronicleContextBuilder contextBuilder;
  late ChronicleSubsystem subsystem;

  setUp(() {
    router = ChronicleQueryRouter();
    // Context builder needs AggregationRepository; use real one (will return null if no data).
    contextBuilder = ChronicleContextBuilder(
      aggregationRepo: AggregationRepository(),
    );
    subsystem = ChronicleSubsystem(
      router: router,
      contextBuilder: contextBuilder,
    );
  });

  group('ChronicleSubsystem', () {
    test('name is CHRONICLE', () {
      expect(subsystem.name, 'CHRONICLE');
    });

    group('canHandle', () {
      test('returns true for temporalQuery', () {
        const intent = CommandIntent(type: IntentType.temporalQuery, rawQuery: 'Tell me about January');
        expect(subsystem.canHandle(intent), isTrue);
      });

      test('returns true for patternAnalysis', () {
        const intent = CommandIntent(type: IntentType.patternAnalysis, rawQuery: 'What themes recur?');
        expect(subsystem.canHandle(intent), isTrue);
      });

      test('returns true for developmentalArc', () {
        const intent = CommandIntent(type: IntentType.developmentalArc, rawQuery: 'How have I changed?');
        expect(subsystem.canHandle(intent), isTrue);
      });

      test('returns true for historicalParallel', () {
        const intent = CommandIntent(type: IntentType.historicalParallel, rawQuery: 'Have I dealt with this before?');
        expect(subsystem.canHandle(intent), isTrue);
      });

      test('returns true for comparison', () {
        const intent = CommandIntent(type: IntentType.comparison, rawQuery: 'Compare 2024 vs 2025');
        expect(subsystem.canHandle(intent), isTrue);
      });

      test('returns true for decisionSupport', () {
        const intent = CommandIntent(type: IntentType.decisionSupport, rawQuery: 'Decision support for launch');
        expect(subsystem.canHandle(intent), isTrue);
      });

      test('returns false for usagePatterns', () {
        const intent = CommandIntent(type: IntentType.usagePatterns, rawQuery: 'Show usage patterns');
        expect(subsystem.canHandle(intent), isFalse);
      });

      test('returns false for optimalTiming', () {
        const intent = CommandIntent(type: IntentType.optimalTiming, rawQuery: 'When is best time?');
        expect(subsystem.canHandle(intent), isFalse);
      });

      test('returns false for recentContext', () {
        const intent = CommandIntent(type: IntentType.recentContext, rawQuery: 'Recent context');
        expect(subsystem.canHandle(intent), isFalse);
      });
    });

    group('query', () {
      test('returns error when userId is null', () async {
        const intent = CommandIntent(
          type: IntentType.temporalQuery,
          rawQuery: 'Tell me about my month',
          userId: null,
        );
        final result = await subsystem.query(intent);
        expect(result.isError, isTrue);
        expect(result.errorMessage, contains('userId'));
        expect(result.source, 'CHRONICLE');
      });

      test('returns error when userId is empty', () async {
        const intent = CommandIntent(
          type: IntentType.temporalQuery,
          rawQuery: 'Tell me about my month',
          userId: '',
        );
        final result = await subsystem.query(intent);
        expect(result.isError, isTrue);
        expect(result.errorMessage, contains('userId'));
      });
    });
  });
}
