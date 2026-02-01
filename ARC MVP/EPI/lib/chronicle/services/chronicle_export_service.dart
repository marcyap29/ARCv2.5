import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../storage/aggregation_repository.dart';
import '../storage/changelog_repository.dart';
import '../models/chronicle_layer.dart';
import '../models/chronicle_aggregation.dart';

/// CHRONICLE export service
/// 
/// Provides functionality to export CHRONICLE aggregations to user-selected directories.
class ChronicleExportService {
  final AggregationRepository _aggregationRepo;
  final ChangelogRepository _changelogRepo;

  ChronicleExportService({
    required AggregationRepository aggregationRepo,
    required ChangelogRepository changelogRepo,
  })  : _aggregationRepo = aggregationRepo,
        _changelogRepo = changelogRepo;

  /// Export all aggregations to a directory
  /// 
  /// Creates a directory structure:
  ///   exportDir/
  ///     monthly/
  ///       YYYY-MM.md
  ///     yearly/
  ///       YYYY.md
  ///     multiyear/
  ///       YYYY-YYYY.md
  ///     changelog.jsonl
  Future<ChronicleExportResult> exportAll({
    required String userId,
    required Directory exportDir,
  }) async {
    print('📤 ChronicleExportService: Exporting all aggregations to ${exportDir.path}');
    
    final result = ChronicleExportResult();
    
    try {
      // Create directory structure
      final monthlyDir = Directory(path.join(exportDir.path, 'monthly'));
      final yearlyDir = Directory(path.join(exportDir.path, 'yearly'));
      final multiyearDir = Directory(path.join(exportDir.path, 'multiyear'));
      
      await monthlyDir.create(recursive: true);
      await yearlyDir.create(recursive: true);
      await multiyearDir.create(recursive: true);
      
      // Export monthly aggregations
      final monthlyAggs = await _aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
      );
      for (final agg in monthlyAggs) {
        final file = File(path.join(monthlyDir.path, '${agg.period}.md'));
        final content = _buildMarkdownWithFrontmatter(agg);
        await file.writeAsString(content);
        result.monthlyCount++;
      }
      
      // Export yearly aggregations
      final yearlyAggs = await _aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.yearly,
      );
      for (final agg in yearlyAggs) {
        final file = File(path.join(yearlyDir.path, '${agg.period}.md'));
        final content = _buildMarkdownWithFrontmatter(agg);
        await file.writeAsString(content);
        result.yearlyCount++;
      }
      
      // Export multi-year aggregations
      final multiyearAggs = await _aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.multiyear,
      );
      for (final agg in multiyearAggs) {
        final file = File(path.join(multiyearDir.path, '${agg.period}.md'));
        final content = _buildMarkdownWithFrontmatter(agg);
        await file.writeAsString(content);
        result.multiyearCount++;
      }
      
      // Export changelog
      final changelogEntries = await _changelogRepo.getAllEntries();
      final changelogFile = File(path.join(exportDir.path, 'changelog.jsonl'));
      final changelogLines = changelogEntries
          .map((e) => jsonEncode(e.toJson()))
          .join('\n');
      await changelogFile.writeAsString(changelogLines);
      result.changelogEntries = changelogEntries.length;
      
      result.success = true;
      print('✅ ChronicleExportService: Exported ${result.monthlyCount} monthly, ${result.yearlyCount} yearly, ${result.multiyearCount} multi-year aggregations');
      
      return result;
    } catch (e) {
      print('❌ ChronicleExportService: Export failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Export specific layer aggregations
  Future<ChronicleExportResult> exportLayer({
    required String userId,
    required ChronicleLayer layer,
    required Directory exportDir,
    List<String>? periods, // If null, exports all periods for the layer
  }) async {
    print('📤 ChronicleExportService: Exporting ${layer.displayName} aggregations');
    
    final result = ChronicleExportResult();
    
    try {
      final layerDir = Directory(path.join(exportDir.path, layer.name));
      await layerDir.create(recursive: true);
      
      final allAggs = await _aggregationRepo.getAllForLayer(
        userId: userId,
        layer: layer,
      );
      
      final aggsToExport = periods != null
          ? allAggs.where((agg) => periods.contains(agg.period)).toList()
          : allAggs;
      
      for (final agg in aggsToExport) {
        final file = File(path.join(layerDir.path, '${agg.period}.md'));
        final content = _buildMarkdownWithFrontmatter(agg);
        await file.writeAsString(content);
        
        switch (layer) {
          case ChronicleLayer.monthly:
            result.monthlyCount++;
            break;
          case ChronicleLayer.yearly:
            result.yearlyCount++;
            break;
          case ChronicleLayer.multiyear:
            result.multiyearCount++;
            break;
          case ChronicleLayer.layer0:
            break; // Layer 0 is not exported via this service
        }
      }
      
      result.success = true;
      print('✅ ChronicleExportService: Exported ${aggsToExport.length} ${layer.displayName} aggregations');
      
      return result;
    } catch (e) {
      print('❌ ChronicleExportService: Export failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Build markdown content with YAML frontmatter
  String _buildMarkdownWithFrontmatter(ChronicleAggregation aggregation) {
    final frontmatter = '''---
type: ${aggregation.layer.name}_aggregation
period: ${aggregation.period}
synthesis_date: ${aggregation.synthesisDate.toIso8601String()}
entry_count: ${aggregation.entryCount}
compression_ratio: ${aggregation.compressionRatio.toStringAsFixed(3)}
user_edited: ${aggregation.userEdited}
version: ${aggregation.version}
source_entry_ids: ${aggregation.sourceEntryIds.join(', ')}
user_id: ${aggregation.userId}
---

''';
    
    return frontmatter + aggregation.content;
  }
}

/// Result of CHRONICLE export operation
class ChronicleExportResult {
  int monthlyCount = 0;
  int yearlyCount = 0;
  int multiyearCount = 0;
  int changelogEntries = 0;
  bool success = false;
  String? error;
  
  int get totalCount => monthlyCount + yearlyCount + multiyearCount;
  
  @override
  String toString() {
    if (!success) {
      return 'Export failed: $error';
    }
    return 'Exported $monthlyCount monthly, $yearlyCount yearly, $multiyearCount multi-year aggregations, $changelogEntries changelog entries';
  }
}
