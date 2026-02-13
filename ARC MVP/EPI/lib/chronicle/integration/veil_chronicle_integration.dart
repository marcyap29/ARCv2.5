import '../index/chronicle_index_builder.dart';
import '../index/monthly_aggregation_adapter.dart';
import '../models/chronicle_layer.dart';
import '../synthesis/synthesis_engine.dart';

/// Integration point between VEIL synthesis cycle and CHRONICLE cross-temporal index.
/// Runs monthly synthesis (EXAMINE) then updates the pattern index.
class VeilChronicleIntegration {
  final ChronicleIndexBuilder _indexBuilder;
  final SynthesisEngine _synthesisEngine;

  VeilChronicleIntegration({
    required ChronicleIndexBuilder indexBuilder,
    required SynthesisEngine synthesisEngine,
  })  : _indexBuilder = indexBuilder,
        _synthesisEngine = synthesisEngine;

  /// Run monthly synthesis and update pattern index.
  /// Main entry point for the nightly cycle.
  Future<void> runMonthlySynthesisWithIndexing({
    required String userId,
    required String period,
  }) async {
    // ignore: avoid_print
    print('\n🔄 Running monthly synthesis for $period');

    final aggregation = await _synthesisEngine.synthesizeLayer(
      userId: userId,
      layer: ChronicleLayer.monthly,
      period: period,
    );

    if (aggregation == null) {
      // ignore: avoid_print
      print('⚠️ No aggregation produced for $period (no entries or error)');
      return;
    }

    // ignore: avoid_print
    print('✓ Monthly synthesis complete');
    // ignore: avoid_print
    print('   Dominant themes: ${_extractThemesFromContent(aggregation.content).join(", ")}');

    final synthesis = MonthlyAggregation.fromChronicleAggregation(aggregation);
    await _indexBuilder.updateIndexAfterSynthesis(
      userId: userId,
      synthesis: synthesis,
    );

    // ignore: avoid_print
    print('✓ Pattern index updated');
  }

  static List<String> _extractThemesFromContent(String content) {
    final themePattern = RegExp(r'\*\*(.+?)\*\* \(confidence: (\w+)\)');
    final matches = themePattern.allMatches(content);
    return matches
        .map((m) => (m.group(1) ?? '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
