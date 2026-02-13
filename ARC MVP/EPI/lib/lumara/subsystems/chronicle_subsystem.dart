import 'package:my_app/chronicle/query/query_router.dart';
import 'package:my_app/chronicle/query/context_builder.dart';
import 'package:my_app/chronicle/query/pattern_query_router.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';

import '../models/command_intent.dart';
import '../models/subsystem_result.dart';
import '../models/intent_type.dart';
import 'subsystem.dart';

/// LUMARA subsystem that wraps existing CHRONICLE infrastructure.
///
/// Delegates to [ChronicleQueryRouter] and [ChronicleContextBuilder].
/// When [patternQueryRouter] is set, pattern-like queries also use the
/// cross-temporal index (vectorizer) and merge result into CHRONICLE context.
class ChronicleSubsystem implements Subsystem {
  final ChronicleQueryRouter _router;
  final ChronicleContextBuilder _contextBuilder;
  final PatternQueryRouter? _patternQueryRouter;

  ChronicleSubsystem({
    required ChronicleQueryRouter router,
    required ChronicleContextBuilder contextBuilder,
    PatternQueryRouter? patternQueryRouter,
  })  : _router = router,
        _contextBuilder = contextBuilder,
        _patternQueryRouter = patternQueryRouter;

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
      // Optional: run pattern index (vectorizer) for pattern-like intents
      String? patternContext;
      if (_patternQueryRouter != null &&
          (intent.type == IntentType.patternAnalysis ||
              intent.type == IntentType.developmentalArc ||
              intent.type == IntentType.historicalParallel)) {
        try {
          final patternResponse = await _patternQueryRouter!.routeQuery(
            userId: intent.userId!,
            query: intent.rawQuery,
          );
          if (patternResponse.type == QueryType.patternRecognition &&
              patternResponse.response.isNotEmpty) {
            patternContext = patternResponse.response;
          }
        } catch (_) {
          // Non-fatal: continue with aggregation context only
        }
      }

      final queryPlan = await _router.route(
        query: intent.rawQuery,
        userContext: {
          'userId': intent.userId,
          if (intent.domain != null) 'domain': intent.domain,
        },
      );

      if (!queryPlan.usesChronicle || queryPlan.layers.isEmpty) {
        final aggregations = patternContext != null
            ? '<chronicle_pattern_index>\n$patternContext\n</chronicle_pattern_index>'
            : null;
        return SubsystemResult(
          source: name,
          data: {
            'aggregations': aggregations,
            'layers': <String>[],
            'strategy': queryPlan.strategy,
          },
          metadata: {
            'uses_chronicle': patternContext != null,
            'intent': queryPlan.intent.toString(),
          },
        );
      }

      final contextString = await _contextBuilder.buildContext(
        userId: intent.userId!,
        queryPlan: queryPlan,
      );

      var fullContext = contextString ?? '';
      if (patternContext != null && patternContext.isNotEmpty) {
        fullContext =
            '<chronicle_pattern_index>\n$patternContext\n</chronicle_pattern_index>\n\n$fullContext';
      }

      final layerNames = queryPlan.layers
          .map((l) => _layerDisplayName(l))
          .toList();

      return SubsystemResult(
        source: name,
        data: {
          'aggregations': fullContext,
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
