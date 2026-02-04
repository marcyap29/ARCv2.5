import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/models/command_intent.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/models/orchestration_result.dart';
import 'package:my_app/lumara/models/subsystem_result.dart';
import 'package:my_app/lumara/orchestrator/result_aggregator.dart';

void main() {
  late ResultAggregator aggregator;

  setUp(() {
    aggregator = ResultAggregator();
  });

  group('ResultAggregator', () {
    test('aggregate returns OrchestrationResult with same results and intent', () {
      final intent = CommandIntent(type: IntentType.temporalQuery, rawQuery: 'Tell me about January');
      final results = [
        SubsystemResult(
          source: 'CHRONICLE',
          data: {'aggregations': 'January 2025 summary...', 'layers': ['Monthly']},
        ),
      ];
      final out = aggregator.aggregate(results, intent);
      expect(out.intent, intent);
      expect(out.subsystemResults.length, 1);
      expect(out.subsystemResults.first.source, 'CHRONICLE');
      expect(out.timestamp, isNotNull);
    });

    test('aggregate preserves multiple results', () {
      final intent = CommandIntent(type: IntentType.decisionSupport, rawQuery: 'Decision support for X');
      final results = [
        SubsystemResult(source: 'ARC', data: {'entries': ['e1', 'e2']}),
        SubsystemResult(source: 'CHRONICLE', data: {'aggregations': 'Context from CHRONICLE'}),
      ];
      final out = aggregator.aggregate(results, intent);
      expect(out.subsystemResults.length, 2);
    });
  });

  group('OrchestrationResult', () {
    test('toContextMap includes CHRONICLE when aggregations present', () {
      final results = [
        SubsystemResult(
          source: 'CHRONICLE',
          data: {'aggregations': 'Monthly summary text'},
        ),
      ];
      final intent = CommandIntent(type: IntentType.temporalQuery, rawQuery: 'q');
      final out = OrchestrationResult(
        intent: intent,
        subsystemResults: results,
        timestamp: DateTime.now(),
      );
      final map = out.toContextMap();
      expect(map['CHRONICLE'], 'Monthly summary text');
    });

    test('toContextMap omits error results', () {
      final results = [
        SubsystemResult.error(source: 'CHRONICLE', message: 'failed'),
        SubsystemResult(source: 'ARC', data: {'entries': ['a']}),
      ];
      final out = OrchestrationResult(
        intent: CommandIntent(type: IntentType.recentContext, rawQuery: 'q'),
        subsystemResults: results,
        timestamp: DateTime.now(),
      );
      final map = out.toContextMap();
      expect(map.containsKey('CHRONICLE'), isFalse);
      expect(map.containsKey('ARC'), isTrue);
    });

    test('getSubsystemResult returns result by source', () {
      final results = [
        SubsystemResult(source: 'CHRONICLE', data: {'aggregations': 'x'}),
      ];
      final out = OrchestrationResult(
        intent: CommandIntent(type: IntentType.temporalQuery, rawQuery: 'q'),
        subsystemResults: results,
        timestamp: DateTime.now(),
      );
      expect(out.getSubsystemResult('CHRONICLE')?.data['aggregations'], 'x');
      expect(out.getSubsystemResult('ARC'), isNull);
    });

    test('getSubsystemData returns data map by source', () {
      final results = [
        SubsystemResult(source: 'CHRONICLE', data: {'aggregations': 'y', 'layers': ['Monthly']}),
      ];
      final out = OrchestrationResult(
        intent: CommandIntent(type: IntentType.temporalQuery, rawQuery: 'q'),
        subsystemResults: results,
        timestamp: DateTime.now(),
      );
      expect(out.getSubsystemData('CHRONICLE'), {'aggregations': 'y', 'layers': ['Monthly']});
      expect(out.getSubsystemData('ARC'), isNull);
    });

    test('OrchestrationResult.error creates error result', () {
      final intent = CommandIntent(type: IntentType.recentContext, rawQuery: 'q');
      final out = OrchestrationResult.error(intent: intent, message: 'No subsystems');
      expect(out.isError, isTrue);
      expect(out.subsystemResults.single.source, 'ORCHESTRATOR');
      expect(out.subsystemResults.single.errorMessage, 'No subsystems');
    });
  });
}
