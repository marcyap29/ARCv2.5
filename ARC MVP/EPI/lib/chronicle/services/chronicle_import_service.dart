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
    if (totalCount == 0) return 'No aggregation files were imported.';
    return 'Imported $monthlyCount monthly, $yearlyCount yearly, $multiyearCount multi-year aggregations';
  }
}

/// Service to import CHRONICLE aggregations from a directory or from a single file.
///
/// Supports:
/// 1. Standard export layout: folder with monthly/, yearly/, multiyear/ subfolders (from Export).
/// 2. Flat layout: folder that directly contains .md files (layer/period inferred from frontmatter).
/// 3. Single file: one .md aggregation file (layer/period from frontmatter).
class ChronicleImportService {
  final AggregationRepository _aggregationRepo;

  ChronicleImportService({required AggregationRepository aggregationRepo})
      : _aggregationRepo = aggregationRepo;

  /// Import from a directory (standard or flat) or from a single .md file path.
  /// [onProgress] is called with (processedCount, totalCount).
  Future<ChronicleImportResult> importFromDirectory({
    required String userId,
    required Directory exportDir,
    void Function(int processed, int total)? onProgress,
  }) async {
    final result = ChronicleImportResult();
    try {
      // 1) Try standard structure: monthly/, yearly/, multiyear/
      final monthlyDir = Directory(path.join(exportDir.path, 'monthly'));
      final yearlyDir = Directory(path.join(exportDir.path, 'yearly'));
      final multiyearDir = Directory(path.join(exportDir.path, 'multiyear'));

      final monthlyFiles = await _listMdFiles(monthlyDir);
      final yearlyFiles = await _listMdFiles(yearlyDir);
      final multiyearFiles = await _listMdFiles(multiyearDir);

      List<({File file, ChronicleLayer layer, String period})> items = [];

      if (monthlyFiles.isNotEmpty || yearlyFiles.isNotEmpty || multiyearFiles.isNotEmpty) {
        for (final file in monthlyFiles) {
          items.add((file: file, layer: ChronicleLayer.monthly, period: path.basenameWithoutExtension(file.path)));
        }
        for (final file in yearlyFiles) {
          items.add((file: file, layer: ChronicleLayer.yearly, period: path.basenameWithoutExtension(file.path)));
        }
        for (final file in multiyearFiles) {
          items.add((file: file, layer: ChronicleLayer.multiyear, period: path.basenameWithoutExtension(file.path)));
        }
      } else {
        // 2) Flat folder: .md files directly in the selected directory
        final flatFiles = await _listMdFiles(exportDir);
        if (flatFiles.isEmpty) {
          result.success = true;
          result.error = 'No .md aggregation files found. Select the folder you exported to (with monthly, yearly, multiyear subfolders), or a folder containing .md aggregation files.';
          return result;
        }
        for (final file in flatFiles) {
          final typePeriod = _parseTypeAndPeriodFromFile(file);
          if (typePeriod != null) {
            items.add((file: file, layer: typePeriod.layer, period: typePeriod.period));
          }
        }
        if (items.isEmpty) {
          result.success = true;
          result.error = 'No valid aggregation files (missing or invalid frontmatter). Export creates .md files with type and period in the header.';
          return result;
        }
      }

      final total = items.length;
      int processed = 0;
      onProgress?.call(0, total);

      for (final item in items) {
        try {
          final content = await item.file.readAsString();
          final agg = _aggregationRepo.parseFromMarkdownContent(
            content,
            item.layer,
            item.period,
            userId,
          );
          switch (item.layer) {
            case ChronicleLayer.monthly:
              await _aggregationRepo.saveMonthly(userId, agg);
              result.monthlyCount++;
              break;
            case ChronicleLayer.yearly:
              await _aggregationRepo.saveYearly(userId, agg);
              result.yearlyCount++;
              break;
            case ChronicleLayer.multiyear:
              await _aggregationRepo.saveMultiYear(userId, agg);
              result.multiyearCount++;
              break;
            default:
              break;
          }
        } catch (e) {
          print('⚠️ ChronicleImportService: Failed to import ${item.file.path}: $e');
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

  /// Import a single .md file (e.g. user picked a file). Layer and period from frontmatter.
  Future<ChronicleImportResult> importFromFile({
    required String userId,
    required File file,
    void Function(int processed, int total)? onProgress,
  }) async {
    final result = ChronicleImportResult();
    if (!file.path.endsWith('.md')) {
      result.success = false;
      result.error = 'Please select an .md aggregation file (from CHRONICLE Export).';
      return result;
    }
    try {
      onProgress?.call(0, 1);
      final typePeriod = _parseTypeAndPeriodFromFile(file);
      if (typePeriod == null) {
        result.success = false;
        result.error = 'File is not a valid aggregation (missing type/period in frontmatter).';
        return result;
      }
      final content = await file.readAsString();
      final agg = _aggregationRepo.parseFromMarkdownContent(
        content,
        typePeriod.layer,
        typePeriod.period,
        userId,
      );
      switch (typePeriod.layer) {
        case ChronicleLayer.monthly:
          await _aggregationRepo.saveMonthly(userId, agg);
          result.monthlyCount = 1;
          break;
        case ChronicleLayer.yearly:
          await _aggregationRepo.saveYearly(userId, agg);
          result.yearlyCount = 1;
          break;
        case ChronicleLayer.multiyear:
          await _aggregationRepo.saveMultiYear(userId, agg);
          result.multiyearCount = 1;
          break;
        default:
          result.success = false;
          result.error = 'Unsupported aggregation type: ${typePeriod.layer.name}';
          return result;
      }
      onProgress?.call(1, 1);
      result.success = true;
      return result;
    } catch (e) {
      print('❌ ChronicleImportService: Import from file failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Parse type and period from export-format frontmatter (type: monthly_aggregation, period: 2025-01).
  ({ChronicleLayer layer, String period})? _parseTypeAndPeriodFromFile(File file) {
    try {
      final content = file.readAsStringSync();
      if (!content.startsWith('---')) return null;
      final parts = content.split('---');
      if (parts.length < 2) return null;
      final frontmatter = parts[1].trim();
      String? typeStr;
      String? periodStr;
      for (final line in frontmatter.split('\n')) {
        if (line.contains(':')) {
          final idx = line.indexOf(':');
          final key = line.substring(0, idx).trim();
          final value = line.substring(idx + 1).trim();
          if (key == 'type') typeStr = value;
          if (key == 'period') periodStr = value;
        }
      }
      if (typeStr == null || periodStr == null) return null;
      ChronicleLayer layer;
      if (typeStr == 'monthly_aggregation') {
        layer = ChronicleLayer.monthly;
      } else if (typeStr == 'yearly_aggregation') {
        layer = ChronicleLayer.yearly;
      } else if (typeStr == 'multiyear_aggregation') {
        layer = ChronicleLayer.multiyear;
      } else {
        return null;
      }
      return (layer: layer, period: periodStr);
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> _listMdFiles(Directory dir) async {
    if (!await dir.exists()) return [];
    try {
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
