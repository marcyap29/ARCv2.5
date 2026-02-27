import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/models/command_intent.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/models/subsystem_result.dart';
import 'package:my_app/lumara/orchestrator/command_parser.dart';
import 'package:my_app/lumara/orchestrator/lumara_orchestrator.dart';
import 'package:my_app/lumara/orchestrator/result_aggregator.dart';
import 'package:my_app/lumara/subsystems/subsystem.dart';

void main() {
  group('LumaraOrchestrator', () {
    test('execute returns error when no subsystem can handle intent', () async {
      final fakeSubsystem = _FakeSubsystem(handles: {IntentType.usagePatterns});
      final orchestrator = LumaraOrchestrator(
        subsystems: [fakeSubsystem],
        parser: CommandParser(),
        aggregator: ResultAggregator(),
      );
      final result = await orchestrator.execute('Tell me about my month');
      expect(result.isError, isTrue);
      expect(result.subsystemResults.single.errorMessage, contains('No subsystem'));
    });

    test('execute routes to subsystem that canHandle and returns aggregated result', () async {
      final fakeSubsystem = _FakeSubsystem(
        handles: {IntentType.temporalQuery, IntentType.recentContext},
        result: const SubsystemResult(
          source: 'FAKE',
          data: {'aggregations': 'Fake CHRONICLE content'},
        ),
      );
      final orchestrator = LumaraOrchestrator(
        subsystems: [fakeSubsystem],
        parser: CommandParser(),
        aggregator: ResultAggregator(),
      );
      final result = await orchestrator.execute('Tell me about my month');
      expect(result.isError, isFalse);
      expect(result.subsystemResults.length, 1);
      expect(result.subsystemResults.single.source, 'FAKE');
      expect(result.getSubsystemData('FAKE')!['aggregations'], 'Fake CHRONICLE content');
      expect(result.toContextMap()['FAKE'], 'Fake CHRONICLE content');
    });

    test('execute attaches userId to intent when provided', () async {
      String? capturedUserId;
      final fakeSubsystem = _FakeSubsystem(
        handles: {IntentType.temporalQuery},
        result: const SubsystemResult(source: 'FAKE', data: {}),
        onQuery: (intent) => capturedUserId = intent.userId,
      );
      final orchestrator = LumaraOrchestrator(
        subsystems: [fakeSubsystem],
        parser: CommandParser(),
        aggregator: ResultAggregator(),
      );
      await orchestrator.execute('Tell me about January', userId: 'user-123');
      expect(capturedUserId, 'user-123');
    });

    test('execute queries multiple subsystems when both canHandle', () async {
      final chronicle = _FakeSubsystem(
        name: 'CHRONICLE',
        handles: {IntentType.temporalQuery},
        result: const SubsystemResult(
          source: 'CHRONICLE',
          data: {'aggregations': 'Chronicle text'},
        ),
      );
      final arc = _FakeSubsystem(
        name: 'ARC',
        handles: {IntentType.temporalQuery, IntentType.recentContext},
        result: const SubsystemResult(
          source: 'ARC',
          data: {'entries': ['e1', 'e2']},
        ),
      );
      final orchestrator = LumaraOrchestrator(
        subsystems: [chronicle, arc],
        parser: CommandParser(),
        aggregator: ResultAggregator(),
      );
      final result = await orchestrator.execute('Tell me about my month');
      expect(result.isError, isFalse);
      expect(result.subsystemResults.length, 2);
      expect(result.toContextMap().keys, containsAll(['CHRONICLE', 'ARC']));
    });

    test('execute returns ARC data shape (recentEntries, entryContents) when ARC subsystem used', () async {
      final arc = _FakeSubsystem(
        name: 'ARC',
        handles: {IntentType.temporalQuery, IntentType.recentContext},
        result: SubsystemResult(
          source: 'ARC',
          data: {
            'recentEntries': [
              {'date': DateTime(2025, 1, 1), 'title': 'Entry 1', 'id': 'id1'},
            ],
            'entryContents': ['Content of entry 1'],
          },
        ),
      );
      final orchestrator = LumaraOrchestrator(
        subsystems: [arc],
        parser: CommandParser(),
        aggregator: ResultAggregator(),
      );
      final result = await orchestrator.execute('Reflect on my week');
      expect(result.isError, isFalse);
      final arcData = result.getSubsystemData('ARC');
      expect(arcData, isNotNull);
      expect(arcData!.containsKey('recentEntries'), isTrue);
      expect(arcData.containsKey('entryContents'), isTrue);
      expect(arcData['recentEntries'], isA<List>());
      expect(arcData['entryContents'], isA<List>());
    });

    test('execute catches subsystem throw and returns error result for that source', () async {
      final failing = _FakeSubsystem(
        name: 'FAIL',
        handles: {IntentType.temporalQuery},
        result: null,
        throwOnQuery: true,
      );
      final orchestrator = LumaraOrchestrator(
        subsystems: [failing],
        parser: CommandParser(),
        aggregator: ResultAggregator(),
      );
      final result = await orchestrator.execute('Tell me about my month');
      expect(result.isError, isFalse);
      expect(result.subsystemResults.length, 1);
      expect(result.subsystemResults.single.source, 'FAIL');
      expect(result.subsystemResults.single.isError, isTrue);
      expect(result.subsystemResults.single.errorMessage, contains('Query failed'));
    });
  });
}

class _FakeSubsystem implements Subsystem {
  @override
  final String name;
  final Set<IntentType> handles;
  final SubsystemResult result;
  final bool throwOnQuery;
  final void Function(CommandIntent)? onQuery;

  _FakeSubsystem({
    this.name = 'FAKE',
    required this.handles,
    SubsystemResult? result,
    this.throwOnQuery = false,
    this.onQuery,
  }) : result = result ?? SubsystemResult(source: name, data: {});

  @override
  bool canHandle(CommandIntent intent) => handles.contains(intent.type);

  @override
  Future<SubsystemResult> query(CommandIntent intent) async {
    onQuery?.call(intent);
    if (throwOnQuery) throw Exception('fake failure');
    return result;
  }
}
