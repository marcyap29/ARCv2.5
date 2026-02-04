import 'package:my_app/chronicle/query/query_router.dart';
import 'package:my_app/chronicle/query/context_builder.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';

import '../models/command_intent.dart';
import '../models/subsystem_result.dart';
import '../models/intent_type.dart';
import 'subsystem.dart';

/// LUMARA subsystem that wraps existing CHRONICLE infrastructure.
///
/// Delegates to [ChronicleQueryRouter] and [ChronicleContextBuilder].
/// Does not change CHRONICLE behavior—only exposes it via [Subsystem].
class ChronicleSubsystem implements Subsystem {
  final ChronicleQueryRouter _router;
  final ChronicleContextBuilder _contextBuilder;

  ChronicleSubsystem({
    required ChronicleQueryRouter router,
    required ChronicleContextBuilder contextBuilder,
  })  : _router = router,
        _contextBuilder = contextBuilder;

  @override
  String get name => 'CHRONICLE';

  @override
  Future<SubsystemResult> query(CommandIntent intent) async {
    if (intent.userId == null || intent.userId!.isEmpty) {
      return SubsystemResult.error(
        source: name,
        message: 'CHRONICLE requires userId',
      );
    }

    try {
      final queryPlan = await _router.route(
        query: intent.rawQuery,
        userContext: {
          'userId': intent.userId,
          if (intent.domain != null) 'domain': intent.domain,
        },
      );

      if (!queryPlan.usesChronicle || queryPlan.layers.isEmpty) {
        return SubsystemResult(
          source: name,
          data: {
            'aggregations': null,
            'layers': <String>[],
            'strategy': queryPlan.strategy,
          },
          metadata: {
            'uses_chronicle': false,
            'intent': queryPlan.intent.toString(),
          },
        );
      }

      final contextString = await _contextBuilder.buildContext(
        userId: intent.userId!,
        queryPlan: queryPlan,
      );

      final layerNames = queryPlan.layers
          .map((l) => _layerDisplayName(l))
          .toList();

      return SubsystemResult(
        source: name,
        data: {
          'aggregations': contextString ?? '',
          'layers': layerNames,
          'strategy': queryPlan.strategy,
        },
        metadata: {
          'uses_chronicle': true,
          'drill_down': queryPlan.drillDown,
          'intent': queryPlan.intent.toString(),
        },
      );
    } catch (e) {
      return SubsystemResult.error(
        source: name,
        message: 'CHRONICLE query failed: $e',
      );
    }
  }

  @override
  bool canHandle(CommandIntent intent) {
    switch (intent.type) {
      case IntentType.temporalQuery:
      case IntentType.patternAnalysis:
      case IntentType.developmentalArc:
      case IntentType.historicalParallel:
      case IntentType.comparison:
      case IntentType.decisionSupport:
        return true;
      default:
        return false;
    }
  }

  static String _layerDisplayName(ChronicleLayer layer) {
    switch (layer) {
      case ChronicleLayer.monthly:
        return 'Monthly';
      case ChronicleLayer.yearly:
        return 'Yearly';
      case ChronicleLayer.multiyear:
        return 'Multi-Year';
      case ChronicleLayer.layer0:
        return 'Raw Entries';
    }
  }
}
