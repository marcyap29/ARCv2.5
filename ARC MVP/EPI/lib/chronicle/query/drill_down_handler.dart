import '../storage/layer0_repository.dart';
import '../storage/aggregation_repository.dart';
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';
import '../../models/journal_entry_model.dart';
import '../../arc/core/journal_repository.dart';

/// Drill-Down Handler for CHRONICLE
/// 
/// Handles cross-layer navigation when user requests evidence
/// or specific entry details from aggregations.

class DrillDownHandler {
  final Layer0Repository _layer0Repo;
  final AggregationRepository _aggregationRepo;
  final JournalRepository _journalRepo;

  DrillDownHandler({
    required Layer0Repository layer0Repo,
    required AggregationRepository aggregationRepo,
    required JournalRepository journalRepo,
  })  : _layer0Repo = layer0Repo,
        _aggregationRepo = aggregationRepo,
        _journalRepo = journalRepo;

  /// Load supporting entries mentioned in aggregations
  /// 
  /// Extracts entry IDs from aggregation content and loads the actual entries.
  Future<List<JournalEntry>> loadSupportingEntries({
    required List<ChronicleAggregation> aggregations,
    int maxEntries = 3,
  }) async {
    final entryIds = <String>{};

    // Extract entry IDs from aggregations
    for (final agg in aggregations) {
      // Look for entry references in content (format: "entries #001, #007" or "entry #001")
      final entryMatches = RegExp(r'entries? #?(\w+)')
          .allMatches(agg.content);
      
      for (final match in entryMatches) {
        final entryId = match.group(1);
        if (entryId != null && entryId.isNotEmpty) {
          entryIds.add(entryId);
        }
      }

      // Also check sourceEntryIds
      entryIds.addAll(agg.sourceEntryIds);
    }

    if (entryIds.isEmpty) {
      return [];
    }

    // Load entries (limit to maxEntries)
    final entriesToLoad = entryIds.take(maxEntries).toList();
    final entries = <JournalEntry>[];

    for (final entryId in entriesToLoad) {
      try {
        final entry = await _journalRepo.getJournalEntryById(entryId);
        if (entry != null) {
          entries.add(entry);
        }
      } catch (e) {
        print('⚠️ DrillDownHandler: Failed to load entry $entryId: $e');
      }
    }

    return entries;
  }

  /// Format supporting entries for prompt
  String formatSupportingEntries(List<JournalEntry> entries) {
    if (entries.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('<supporting_entries>');
    buffer.writeln('Specific supporting entries referenced in CHRONICLE aggregations:');
    buffer.writeln('');

    for (final entry in entries) {
      final dateStr = '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')}';
      buffer.writeln('Entry #${entry.id} ($dateStr):');
      buffer.writeln(entry.content);
      buffer.writeln('');
      buffer.writeln('---');
      buffer.writeln('');
    }

    buffer.writeln('</supporting_entries>');
    return buffer.toString();
  }

  /// Navigate from one layer to another (e.g., yearly -> monthly)
  Future<List<ChronicleAggregation>?> navigateToLayer({
    required String userId,
    required ChronicleLayer fromLayer,
    required ChronicleLayer toLayer,
    required String period,
  }) async {
    // Load source aggregation
    final sourceAgg = await _aggregationRepo.loadLayer(
      userId: userId,
      layer: fromLayer,
      period: period,
    );

    if (sourceAgg == null) return null;

    // Extract periods from source aggregation
    final periods = _extractPeriodsFromAggregation(sourceAgg, toLayer);
    if (periods.isEmpty) return null;

    // Load aggregations for target layer
    final aggregations = <ChronicleAggregation>[];
    for (final p in periods) {
      final agg = await _aggregationRepo.loadLayer(
        userId: userId,
        layer: toLayer,
        period: p,
      );
      if (agg != null) {
        aggregations.add(agg);
      }
    }

    return aggregations;
  }

  /// Extract periods from aggregation for a target layer
  List<String> _extractPeriodsFromAggregation(
    ChronicleAggregation sourceAgg,
    ChronicleLayer targetLayer,
  ) {
    switch (targetLayer) {
      case ChronicleLayer.monthly:
        // Extract monthly periods from yearly aggregation
        if (sourceAgg.layer == ChronicleLayer.yearly) {
          // Check source_monthly_periods in frontmatter or sourceEntryIds
          return sourceAgg.sourceEntryIds; // These should be month periods for yearly
        }
        break;

      case ChronicleLayer.yearly:
        // Extract yearly periods from multi-year aggregation
        if (sourceAgg.layer == ChronicleLayer.multiyear) {
          return sourceAgg.sourceEntryIds; // These should be year periods for multi-year
        }
        break;

      default:
        break;
    }

    return [];
  }
}
