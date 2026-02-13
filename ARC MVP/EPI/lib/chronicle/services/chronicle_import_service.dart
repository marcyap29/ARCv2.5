import 'dart:io';
import 'package:path/path.dart' as path;
import '../storage/aggregation_repository.dart';
import '../models/chronicle_layer.dart';

/// Result of CHRONICLE aggregation import.
class ChronicleImportResult {
  int monthlyCount = 0;
  int yearlyCount = 0;
  int multiyearCount = 0;
  bool success = false;
  String? error;

  int get totalCount => monthlyCount + yearlyCount + multiyearCount;

  @override
  String toString() {
    if (!success) return 'Import failed: $error';
    return 'Imported $monthlyCount monthly, $yearlyCount yearly, $multiyearCount multi-year aggregations';
  }
}

/// Service to import CHRONICLE aggregations from a directory
/// that was created by ChronicleExportService.exportAll.
///
/// Expects directory structure:
///   exportDir/monthly/*.md
///   exportDir/yearly/*.md
///   exportDir/multiyear/*.md
class ChronicleImportService {
  final AggregationRepository _aggregationRepo;

  ChronicleImportService({required AggregationRepository aggregationRepo})
      : _aggregationRepo = aggregationRepo;

  /// Import all aggregations from an export directory.
  /// [onProgress] is called with (processedCount, totalCount).
  Future<ChronicleImportResult> importFromDirectory({
    required String userId,
    required Directory exportDir,
    void Function(int processed, int total)? onProgress,
  }) async {
    final result = ChronicleImportResult();
    try {
      final monthlyDir = Directory(path.join(exportDir.path, 'monthly'));
      final yearlyDir = Directory(path.join(exportDir.path, 'yearly'));
      final multiyearDir = Directory(path.join(exportDir.path, 'multiyear'));

      final monthlyFiles = await _listMdFiles(monthlyDir);
      final yearlyFiles = await _listMdFiles(yearlyDir);
      final multiyearFiles = await _listMdFiles(multiyearDir);

      final total = monthlyFiles.length + yearlyFiles.length + multiyearFiles.length;
      if (total == 0) {
        result.success = true;
        result.error = 'No aggregation files found in this directory';
        return result;
      }

      int processed = 0;
      onProgress?.call(0, total);

      for (final file in monthlyFiles) {
        try {
          final content = await file.readAsString();
          final period = path.basenameWithoutExtension(file.path);
          final agg = _aggregationRepo.parseFromMarkdownContent(
            content,
            ChronicleLayer.monthly,
            period,
            userId,
          );
          await _aggregationRepo.saveMonthly(userId, agg);
          result.monthlyCount++;
        } catch (e) {
          print('⚠️ ChronicleImportService: Failed to import ${file.path}: $e');
        }
        processed++;
        onProgress?.call(processed, total);
      }

      for (final file in yearlyFiles) {
        try {
          final content = await file.readAsString();
          final period = path.basenameWithoutExtension(file.path);
          final agg = _aggregationRepo.parseFromMarkdownContent(
            content,
            ChronicleLayer.yearly,
            period,
            userId,
          );
          await _aggregationRepo.saveYearly(userId, agg);
          result.yearlyCount++;
        } catch (e) {
          print('⚠️ ChronicleImportService: Failed to import ${file.path}: $e');
        }
        processed++;
        onProgress?.call(processed, total);
      }

      for (final file in multiyearFiles) {
        try {
          final content = await file.readAsString();
          final period = path.basenameWithoutExtension(file.path);
          final agg = _aggregationRepo.parseFromMarkdownContent(
            content,
            ChronicleLayer.multiyear,
            period,
            userId,
          );
          await _aggregationRepo.saveMultiYear(userId, agg);
          result.multiyearCount++;
        } catch (e) {
          print('⚠️ ChronicleImportService: Failed to import ${file.path}: $e');
        }
        processed++;
        onProgress?.call(processed, total);
      }

      result.success = true;
      print('✅ ChronicleImportService: Imported ${result.totalCount} aggregations');
      return result;
    } catch (e) {
      print('❌ ChronicleImportService: Import failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  Future<List<File>> _listMdFiles(Directory dir) async {
    if (!await dir.exists()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
  }
}
